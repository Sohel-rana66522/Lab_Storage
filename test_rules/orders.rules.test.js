// Firestore security-rules tests for the client-order workflow.
//
// Run from this folder:   npm install && npm test
// (needs Java 11+ and network access for the Firebase Emulator download.)
//
// These tests exercise the SAME write sets that OrderAdminRepository.approve()/reject()
// and TransactionRepository.record() commit: stock update + ledger entry + order update.
// They prove the RULES refuse everything that is not that exact, atomic, admin-only shape.

const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp, collection, query, where, getDocs,
} = require('firebase/firestore');

let env;
const ORDER = 'LAB-ABCD2345';

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-lab-ledger',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8') },
  });
});
after(async () => env && env.cleanup());

// ---- identities ------------------------------------------------------------------------
const adminDb = () =>
  env.authenticatedContext('admin1', { firebase: { sign_in_provider: 'password' } }).firestore();
const staffDb = () => // real account, but NOT an admin
  env.authenticatedContext('staff1', { firebase: { sign_in_provider: 'password' } }).firestore();
const clientDb = (uid = 'anon1') =>
  env.authenticatedContext(uid, { firebase: { sign_in_provider: 'anonymous' } }).firestore();
const outsiderDb = () => env.unauthenticatedContext().firestore();

// ---- fixtures --------------------------------------------------------------------------
const items = (n = 2) =>
  Array.from({ length: n }, (_, i) => ({
    chemicalId: `chem${i + 1}`,
    chemicalName: `Chemical ${i + 1}`,
    formula: 'X',
    requestedQuantity: 500,
    unit: 'mL',
    categoryId: 'cat1',
    categoryName: 'Acids',
    baseQuantity: 0.5,
    baseUnit: 'L',
    availableAtRequest: 2,
  }));

const newOrder = (over = {}) => ({
  id: ORDER,
  clientName: 'Rahim Ahmed',
  clientId: '2024001',
  clientBatch: '15th',
  clientPhone: '01700000000',
  items: items(2),
  itemCount: 2,
  status: 'Pending',
  clientUid: 'anon1',
  createdAt: serverTimestamp(),
  ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/admin1'), { role: 'ADMIN' });
    await setDoc(doc(db, 'users/staff1'), { role: 'LAB_STAFF' });
    for (const n of [1, 2, 3]) {
      await setDoc(doc(db, `chemicals/chem${n}`), {
        id: `chem${n}`, name: `Chemical ${n}`, categoryId: 'cat1', unit: 'L',
        currentStock: 2, lastTransactionId: null,
      });
    }
    await setDoc(doc(db, `orders/${ORDER}`), {
      ...newOrder(), createdAt: new Date(),
    });
    await setDoc(doc(db, 'orders/LAB-OTHER222'), {
      ...newOrder({ id: 'LAB-OTHER222', clientUid: 'anon2' }), createdAt: new Date(),
    });
  });
});

// The exact write set of OrderAdminRepository.approve() for the 2-item fixture order.
function approvalBatch(db, { as = 'admin1', orderOver = {}, ledgerOver = {}, skipLedger = false } = {}) {
  const b = writeBatch(db);
  const ids = [`${ORDER}-1`, `${ORDER}-2`];
  ids.forEach((tid, i) => {
    b.update(doc(db, `chemicals/chem${i + 1}`), {
      currentStock: 1.5, lastTransactionId: tid, lastEntryAt: serverTimestamp(),
      lastEntryDelta: -0.5, updatedAt: serverTimestamp(),
    });
    if (!skipLedger) {
      b.set(doc(db, `transactions/${tid}`), {
        id: tid, chemicalId: `chem${i + 1}`, type: 'OUT', quantity: 0.5, unit: 'L',
        balanceAfter: 1.5, orderId: ORDER, createdBy: as, createdByName: 'Admin',
        ...ledgerOver,
      });
    }
  });
  b.update(doc(db, `orders/${ORDER}`), {
    status: 'Approved', approvedAt: serverTimestamp(), approvedBy: as, approvedByName: 'Admin',
    transactionIds: ids, updatedAt: serverTimestamp(), ...orderOver,
  });
  return b;
}

// ---- 1. client submission --------------------------------------------------------------
test('a client can submit a Pending order', async () => {
  await assertSucceeds(setDoc(doc(clientDb('anon9'), 'orders/LAB-NEWORD22'),
    newOrder({ id: 'LAB-NEWORD22', clientUid: 'anon9' })));
});

test('a client cannot submit an order that is already Approved', async () => {
  await assertFails(setDoc(doc(clientDb('anon9'), 'orders/LAB-NEWORD22'),
    newOrder({ id: 'LAB-NEWORD22', clientUid: 'anon9', status: 'Approved' })));
});

test('a client cannot submit more items than an approval can verify (7)', async () => {
  await assertFails(setDoc(doc(clientDb('anon9'), 'orders/LAB-NEWORD22'),
    newOrder({ id: 'LAB-NEWORD22', clientUid: 'anon9', items: items(8), itemCount: 8 })));
  await assertSucceeds(setDoc(doc(clientDb('anon9'), 'orders/LAB-NEWORD33'),
    newOrder({ id: 'LAB-NEWORD33', clientUid: 'anon9', items: items(7), itemCount: 7 })));
});

// ---- 8. reading ------------------------------------------------------------------------
test('staff can read every order', async () => {
  await assertSucceeds(getDoc(doc(staffDb(), `orders/${ORDER}`)));
  await assertSucceeds(getDoc(doc(adminDb(), 'orders/LAB-OTHER222')));
});

test('a client reads only its own orders', async () => {
  const db = clientDb('anon1');
  await assertSucceeds(getDoc(doc(db, `orders/${ORDER}`)));
  await assertFails(getDoc(doc(db, 'orders/LAB-OTHER222')));
  await assertSucceeds(getDocs(query(collection(db, 'orders'), where('clientUid', '==', 'anon1'))));
  await assertFails(getDocs(collection(db, 'orders'))); // an unfiltered list would expose others
});

test('an unauthenticated visitor reads nothing', async () => {
  await assertFails(getDoc(doc(outsiderDb(), `orders/${ORDER}`)));
});

// ---- 9. clients cannot approve, reject, edit, or move stock ------------------------------
test('a client cannot approve, reject, edit or delete an order — even its own', async () => {
  const db = clientDb('anon1');
  await assertFails(updateDoc(doc(db, `orders/${ORDER}`), { status: 'Approved', approvedBy: 'anon1' }));
  await assertFails(updateDoc(doc(db, `orders/${ORDER}`), { status: 'Rejected', rejectedBy: 'anon1' }));
  await assertFails(updateDoc(doc(db, `orders/${ORDER}`), { clientName: 'Someone else' }));
  await assertFails(deleteDoc(doc(db, `orders/${ORDER}`)));
});

test('a client cannot change stock or write the ledger', async () => {
  const db = clientDb('anon1');
  await assertFails(updateDoc(doc(db, 'chemicals/chem1'), { currentStock: 99 }));
  await assertFails(setDoc(doc(db, `transactions/${ORDER}-1`), {
    id: `${ORDER}-1`, chemicalId: 'chem1', type: 'OUT', orderId: ORDER, createdBy: 'anon1',
  }));
  await assertFails(getDoc(doc(db, `transactions/${ORDER}-1`)));
});

// ---- 2. approval ---------------------------------------------------------------------
test('an admin approval commits stock + ledger + order together', async () => {
  const db = adminDb();
  await assertSucceeds(approvalBatch(db).commit());
  const order = (await getDoc(doc(db, `orders/${ORDER}`))).data();
  assert.equal(order.status, 'Approved');
  assert.equal(order.approvedBy, 'admin1');
  assert.equal((await getDoc(doc(db, 'chemicals/chem1'))).data().currentStock, 1.5);
  assert.equal((await getDoc(doc(db, `transactions/${ORDER}-2`))).data().orderId, ORDER);
});

// ---- 5/8. nothing partial ---------------------------------------------------------------
test('approving the order without its ledger entries is refused', async () => {
  await assertFails(approvalBatch(adminDb(), { skipLedger: true }).commit());
});

test('stock cannot be changed without a ledger entry (manual path too)', async () => {
  await assertFails(updateDoc(doc(adminDb(), 'chemicals/chem1'), {
    currentStock: 1, lastTransactionId: 'nope',
  }));
});

test('a ledger entry for an order is refused if the order is not approved in the same write', async () => {
  const db = adminDb();
  const b = writeBatch(db);
  b.update(doc(db, 'chemicals/chem1'), { currentStock: 1.5, lastTransactionId: `${ORDER}-1` });
  b.set(doc(db, `transactions/${ORDER}-1`), {
    id: `${ORDER}-1`, chemicalId: 'chem1', type: 'OUT', orderId: ORDER, createdBy: 'admin1',
  });
  await assertFails(b.commit());
});

test('an admin cannot spoof another admin as approver', async () => {
  await assertFails(approvalBatch(adminDb(), { orderOver: { approvedBy: 'someone-else' } }).commit());
});

test('order ledger entries must be OUT and use the <orderId>-<n> id', async () => {
  await assertFails(approvalBatch(adminDb(), { ledgerOver: { type: 'IN' } }).commit());
});

// ---- admin gate -------------------------------------------------------------------------
test('staff without the ADMIN role cannot approve or reject', async () => {
  await assertFails(approvalBatch(staffDb(), { as: 'staff1' }).commit());
  await assertFails(updateDoc(doc(staffDb(), `orders/${ORDER}`), {
    status: 'Rejected', rejectedAt: serverTimestamp(), rejectedBy: 'staff1', updatedAt: serverTimestamp(),
  }));
});

test('non-admin staff cannot forge an order-linked ledger entry', async () => {
  const db = staffDb();
  const b = writeBatch(db);
  b.update(doc(db, 'chemicals/chem1'), { currentStock: 1.5, lastTransactionId: `${ORDER}-1` });
  b.set(doc(db, `transactions/${ORDER}-1`), {
    id: `${ORDER}-1`, chemicalId: 'chem1', type: 'OUT', orderId: ORDER, createdBy: 'staff1',
  });
  await assertFails(b.commit());
});

// ---- 6/7. no double deduction ----------------------------------------------------------
test('a second approval of an already Approved order is refused', async () => {
  const db = adminDb();
  await assertSucceeds(approvalBatch(db).commit());
  await assertFails(approvalBatch(db).commit()); // ledger entries exist, order no longer Pending
  assert.equal((await getDoc(doc(db, 'chemicals/chem1'))).data().currentStock, 1.5);
});

test('two admins racing: only the first approval can win', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/admin2'), { role: 'ADMIN' });
  });
  const second = env.authenticatedContext('admin2', { firebase: { sign_in_provider: 'password' } }).firestore();
  await assertSucceeds(approvalBatch(adminDb()).commit());
  await assertFails(approvalBatch(second, { as: 'admin2' }).commit());
});

// ---- 4. rejection ----------------------------------------------------------------------
test('an admin can reject with an optional reason, and stock is untouched', async () => {
  const db = adminDb();
  await assertSucceeds(updateDoc(doc(db, `orders/${ORDER}`), {
    status: 'Rejected', rejectedAt: serverTimestamp(), rejectedBy: 'admin1',
    rejectedByName: 'Admin', rejectionReason: 'Supervisor missing', updatedAt: serverTimestamp(),
  }));
  assert.equal((await getDoc(doc(db, 'chemicals/chem1'))).data().currentStock, 2);
});

test('a rejection cannot smuggle in other fields', async () => {
  await assertFails(updateDoc(doc(adminDb(), `orders/${ORDER}`), {
    status: 'Rejected', rejectedAt: serverTimestamp(), rejectedBy: 'admin1', clientName: 'Edited',
  }));
});

test('Approved and Rejected orders are final', async () => {
  const db = adminDb();
  await assertSucceeds(updateDoc(doc(db, `orders/${ORDER}`), {
    status: 'Rejected', rejectedAt: serverTimestamp(), rejectedBy: 'admin1', updatedAt: serverTimestamp(),
  }));
  await assertFails(approvalBatch(db).commit());
  await assertFails(updateDoc(doc(db, `orders/${ORDER}`), {
    status: 'Pending', updatedAt: serverTimestamp(),
  }));
});

// ---- 10. existing manual workflow still works ------------------------------------------
test('manual Add Stock / Record Usage by staff still commits (chemical + ledger pair)', async () => {
  const db = staffDb();
  const b = writeBatch(db);
  b.update(doc(db, 'chemicals/chem3'), {
    currentStock: 3, lastTransactionId: 'manual1', lastEntryAt: serverTimestamp(), lastEntryDelta: 1,
  });
  b.set(doc(db, 'transactions/manual1'), {
    id: 'manual1', chemicalId: 'chem3', type: 'IN', quantity: 1, unit: 'L',
    balanceAfter: 3, orderId: null, createdBy: 'staff1', createdByName: 'Staff',
  });
  await assertSucceeds(b.commit());
});

test('role records cannot be written from the app', async () => {
  await assertFails(setDoc(doc(staffDb(), 'users/staff1'), { role: 'ADMIN' }));
  await assertFails(setDoc(doc(adminDb(), 'users/admin9'), { role: 'ADMIN' }));
});
