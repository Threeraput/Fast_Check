// lib/models/user.dart
import 'package:meta/meta.dart';

import 'package:meta/meta.dart';

@immutable
class User {
  final String userId;
  final String username;
  final String? firstName;
  final String? lastName;

  /// email แก้ไขไม่ได้ – ใช้แสดงผลเท่านั้น
  final String? email;

  final String? studentId;
  final String? teacherId;
  final bool isActive;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;

  final List<String> roles;

  /// สำหรับ API อื่น ๆ ที่อาจส่ง full_name มา
  final String? fullName;

  /// รูปโปรไฟล์จาก backend (เช่น "/media/profile_upload/xxx.png")
  final String? avatarUrl;

  const User({
    required this.userId,
    required this.username,
    this.firstName,
    this.lastName,
    this.email,
    this.studentId,
    this.teacherId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
    required this.roles,
    this.fullName,
    this.avatarUrl,
  });

  /// แปลง String/Null -> DateTime?
  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final roles = (json['roles'] is List)
        ? List<String>.from(json['roles'] as List)
        : <String>[];

    final isActive = json['is_active'] is bool
        ? json['is_active'] as bool
        : (json['is_active'] == true ||
              json['is_active']?.toString() == 'true');

    return User(
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      email: json['email']?.toString(),
      studentId: json['student_id']?.toString(),
      teacherId: json['teacher_id']?.toString(),
      isActive: isActive,
      createdAt: _dt(json['created_at']) ?? DateTime.now(),
      updatedAt: _dt(json['updated_at']) ?? DateTime.now(),
      lastLoginAt: _dt(json['last_login_at']),
      roles: roles,
      fullName: json['full_name']?.toString(),
      // ✅ แม็ปค่า avatar_url -> avatarUrl (แก้ตัวอักษรผิดพลาดเดิม)
      avatarUrl: json['avatar_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'email': email, // read-only ฝั่ง UI อย่าส่งไปอัปเดต
      'student_id': studentId,
      'teacher_id': teacherId,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_login_at': lastLoginAt?.toIso8601String(),
      'roles': roles,
      'full_name': fullName,
      'avatar_url': avatarUrl,
    };
  }

  /// ใช้กับ PUT /users/{id} — ส่งเฉพาะฟิลด์ที่อนุญาต (ไม่มี email/ avatar_url)
  Map<String, dynamic> toUpdatePayload({
    String? usernameOverride,
    String? firstNameOverride,
    String? lastNameOverride,
    String? studentIdOverride,
    String? teacherIdOverride,
    bool? isActiveOverride,
  }) {
    final map = <String, dynamic>{
      if (usernameOverride != null && usernameOverride.trim().isNotEmpty)
        'username': usernameOverride.trim(),
      if (firstNameOverride != null) 'first_name': firstNameOverride.trim(),
      if (lastNameOverride != null) 'last_name': lastNameOverride.trim(),
      if (studentIdOverride != null) 'student_id': studentIdOverride.trim(),
      if (teacherIdOverride != null) 'teacher_id': teacherIdOverride.trim(),
      if (isActiveOverride != null) 'is_active': isActiveOverride,
    };
    return map;
  }

  /// ชื่อที่เหมาะสมสำหรับแสดงผล (People/เมนูต่าง ๆ)
  String get displayName {
    if ((fullName ?? '').trim().isNotEmpty) return fullName!.trim();
    final fn = (firstName ?? '').trim();
    final ln = (lastName ?? '').trim();
    if (fn.isNotEmpty || ln.isNotEmpty) {
      return [fn, ln].where((s) => s.isNotEmpty).join(' ');
    }
    if (username.isNotEmpty) return username;
    if ((email ?? '').isNotEmpty) return email!;
    return userId;
  }

  /// คืน URL เต็มสำหรับโหลดรูป (เช่น BASE_URL_ROOT + avatarUrl)
  /// ตัวอย่างใช้: NetworkImage(user.avatarAbsoluteUrl(BASE_URL_ROOT))
  String? avatarAbsoluteUrl(String baseUrlRoot) {
    if (avatarUrl == null || avatarUrl!.isEmpty) return null;
    // ถ้า backend คืนเป็น URL เต็มแล้ว
    if (avatarUrl!.startsWith('http')) return avatarUrl!;
    return '$baseUrlRoot${avatarUrl!}';
  }

  User copyWith({
    String? userId,
    String? username,
    String? firstName,
    String? lastName,
    String? email, // แม้แก้ไม่ได้ที่ backend แต่ให้ copy ในฝั่ง UI ได้
    String? studentId,
    String? teacherId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    List<String>? roles,
    String? fullName,
    String? avatarUrl,
  }) {
    return User(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      studentId: studentId ?? this.studentId,
      teacherId: teacherId ?? this.teacherId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      roles: roles ?? this.roles,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
