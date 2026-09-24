import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/formatters.dart';

enum UserRole {
  admin('ADMIN', 'Admin'),
  labStaff('LAB_STAFF', 'Lab Staff'),
  student('STUDENT', 'Student');

  const UserRole(this.wire, this.label);
  final String wire;
  final String label;

  static UserRole parse(String? v) =>
      UserRole.values.firstWhere((r) => r.wire == v, orElse: () => UserRole.student);
}

class UserModel {
  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.studentId,
    this.createdAt,
  });

  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? studentId;
  final DateTime? createdAt;

  bool get isStaff => role != UserRole.student;
  bool get isAdmin => role == UserRole.admin;
  String get initials => Fmt.initials(displayName);

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final email = (d['email'] as String?) ?? '';
    final name = (d['displayName'] as String?)?.trim() ?? '';
    return UserModel(
      uid: doc.id,
      email: email,
      displayName: name.isNotEmpty ? name : (email.isNotEmpty ? email.split('@').first : 'User'),
      role: UserRole.parse(d['role'] as String?),
      studentId: d['studentId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'role': role.wire,
        'studentId': studentId,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };

  UserModel copyWith({String? displayName, UserRole? role, String? studentId}) => UserModel(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        studentId: studentId ?? this.studentId,
        createdAt: createdAt,
      );
}
