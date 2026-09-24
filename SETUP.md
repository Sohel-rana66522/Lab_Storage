# Lab Ledger — Setup

Digitizes a laboratory's physical chemical entry book as a Flutter + Firebase app,
built like a file manager (Folders → Chemical files → Entry history → Add Stock / Record Usage).

## 1. Prerequisites

- Flutter SDK (stable channel), `flutter doctor` passing for your target platforms.
- A Firebase project (Console → Firestore + Authentication enabled).
- `dart pub global activate flutterfire_cli` (once).

## 2. Install dependencies

```bash
flutter pub get
```

## 3. Connect Firebase

This project does **not** ship a `firebase_options.dart` — it's generated per-project:

```bash
flutterfire configure
```

Pick or create your Firebase project, select the platforms you need (make sure to
check **web** if you'll run this in a browser), and it will write
`lib/firebase_options.dart` plus the native config files (`google-services.json`, etc.).

## 4. Enable Firebase products

In the Firebase Console for your project:

1. **Authentication** → Sign-in method → enable **Email/Password**.
2. **Firestore Database** → **Create database** (do this manually in the console —
   don't rely on the CLI to create it for you, see the note below).

## 5. Publish security rules

Easiest: paste the contents of `firestore.rules` directly into the Firestore
**Security** tab in the console and click **Publish**.

Or via the CLI:

```bash
npm install -g firebase-tools   # once
firebase login
firebase use --add                # pick your project
firebase deploy --only firestore:rules
```

> **Known Firebase quirk:** the CLI's own "ensure database exists" preflight check
> can fail with a "billing required" error even on the free Spark plan, *even if
> the database already exists* — this is a CLI-side gate, not a real billing
> requirement. If you hit it, create the database manually in the console first
> (step 4), then deploy rules by pasting them into the console instead of via
> the CLI.

`firestore.rules` only requires the request to be signed in — there's no role
system, so every authenticated account has full access.

## 6. Indexes (optional, only needed for the chemical entry-history screen)

Firestore auto-indexes every single field by default. The only *composite*
index this app needs is on `transactions`: `chemicalId` (Ascending) +
`createdAt` (Descending). Either:

- Run `firebase deploy --only firestore:indexes`, or
- Just use the app — if that specific screen ever needs the index, Firestore's
  error message contains a direct link that creates it for you with one click.

## 7. Run

```bash
flutter run
```

Sign in with any email/password — self-sign-up creates a Firebase Auth account
directly (**Create student account** on the login screen, despite the label,
just creates a normal account — there's no student/staff distinction). Once
the email and password match a Firebase Auth account, that's it — full access.

## Project structure

```
lib/
├── core/          theme, constants, utils (units, formatting, error mapping), Firebase providers
├── models/        ChemicalModel, CategoryModel, TransactionModel
├── repositories/  Firestore/Auth access — the ONLY place that touches them directly
├── providers/     Riverpod providers wiring repositories to the UI
├── screens/       auth, home, folders, chemicals, transactions, reports, settings
├── widgets/       file_card, folder_card, transaction_table, dialogs/…
└── main.dart
```

## Data model

See `DESIGN.md` for the visual system. In short: `categories` (folders), `chemicals`
(files, current stock only — **no embedded history**), `transactions` (the immutable
ledger; each entry records the running `balanceAfter` so history and reports never
need to replay everything). There's no `users` collection — accounts are Firebase
Auth only, with the account's own `displayName`/`email` used wherever a name is shown.

Stock only ever changes inside `TransactionRepository.record()`, which uses a single
Firestore transaction to re-read the chemical, validate the quantity, block negative stock,
and write the new balance and the ledger entry atomically — so two people editing
the same chemical at once can never corrupt the balance.
