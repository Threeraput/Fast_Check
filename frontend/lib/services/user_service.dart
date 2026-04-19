// lib/services/user_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../models/users.dart';
import 'auth_service.dart'; // ต้องมี getToken()
import 'package:frontend/config.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  const ApiException(this.message, {this.statusCode});
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class UserService {
  // -------------------------
  //  กำหนดค่าเซิร์ฟเวอร์ของคุณที่นี่
  // -------------------------

  static const String _baseUrl = AppConfig.baseUrl;
  static const Duration _timeout = Duration(seconds: 20);

  // -------------------------
  //  helper สำหรับแปลง JSON หรือโยน error
  // -------------------------
  static Map<String, dynamic> _decodeOrThrow(
    http.Response res, {
    String? onFail,
  }) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        onFail ?? 'Request failed: ${res.body}',
        statusCode: res.statusCode,
      );
    }
    try {
      return json.decode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ApiException('Invalid JSON response');
    }
  }

  // -------------------------
  // 👤 ดึงข้อมูลผู้ใช้ปัจจุบัน
  // -------------------------
  static Future<User> fetchMe() async {
    final token = await AuthService.getAccessToken();
    final res = await http
        .get(
          Uri.parse('$_baseUrl/users/me'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(_timeout);
    final data = _decodeOrThrow(
      res,
      onFail: 'Failed to load profile: ${res.body}',
    );
    return User.fromJson(data);
  }

  // -------------------------
  // ✏️ อัปเดตข้อมูลโปรไฟล์ (ยกเว้น email)
  // -------------------------
  static Future<User> updateUser({
    required String userId,
    String? username,
    String? firstName,
    String? lastName,
    String? studentId,
    String? teacherId,
    bool? isActive,
  }) async {
    final token = await AuthService.getAccessToken();
    final body = <String, dynamic>{
      if (username != null && username.trim().isNotEmpty)
        'username': username.trim(),
      if (firstName != null) 'first_name': firstName.trim(),
      if (lastName != null) 'last_name': lastName.trim(),
      if (studentId != null && studentId.trim().isNotEmpty)
        'student_id': studentId.trim(),
      if (teacherId != null && teacherId.trim().isNotEmpty)
        'teacher_id': teacherId.trim(),
      if (isActive != null) 'is_active': isActive,
    };

    final res = await http
        .put(
          Uri.parse('$_baseUrl/users/$userId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode(body),
        )
        .timeout(_timeout);

    final data = _decodeOrThrow(res, onFail: 'Update failed: ${res.body}');
    return User.fromJson(data);
  }

  // -------------------------
  //  อัปโหลดรูปโปรไฟล์ (JPEG/PNG ≤ 3MB)
  // -------------------------
  static Future<User> uploadAvatar(File file) async {
    final token = await AuthService.getAccessToken();
    final req =
        http.MultipartRequest('POST', Uri.parse('$_baseUrl/users/me/avatar'))
          ..headers['Authorization'] = 'Bearer $token'
          ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await req.send().timeout(_timeout);
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      throw ApiException(
        'Upload failed: $body',
        statusCode: streamed.statusCode,
      );
    }
    final data = json.decode(body) as Map<String, dynamic>;
    return User.fromJson(data);
  }

  // -------------------------
  //  ลบรูปโปรไฟล์
  // -------------------------
  static Future<User> deleteAvatar() async {
    final token = await AuthService.getAccessToken();
    final res = await http
        .delete(
          Uri.parse('$_baseUrl/users/me/avatar'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(_timeout);

    final data = _decodeOrThrow(res, onFail: 'Delete failed: ${res.body}');
    return User.fromJson(data);
  }

  // -------------------------
  //  ใช้ใน UI เพื่อแปลง avatarUrl -> URL เต็ม
  // -------------------------
  static String? absoluteAvatarUrl(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    if (avatarUrl.startsWith('http')) return avatarUrl;

    // ตัด /api/v1 ออกจาก Base URL เพื่อให้ได้เฉพาะ Root (IP:Port)
    final rootUrl = _baseUrl.replaceAll('/api/v1', '');

    // จัดการเครื่องหมาย / ให้ถูกต้อง เพื่อไม่ให้เกิด // ซ้ำซ้อน
    final cleanPath = avatarUrl.startsWith('/') ? avatarUrl : '/$avatarUrl';

    final fullUrl = '$rootUrl$cleanPath';

    // พิมพ์เช็คใน Console เพื่อตรวจสอบความถูกต้อง
    print("💕💕💕DEBUG: Avatar Path from DB: $avatarUrl");
    print("💕💕💕DEBUG: Final Result URL: $fullUrl");

    return fullUrl;
  }
  // 🌟 ฟังก์ชันเช็คสถานะก่อนอนุญาตให้เปลี่ยนรูปใบหน้า
  static Future<Map<String, dynamic>> checkCanChangeFace(String token) async {
    try {
      // ปรับ URL ให้ตรงกับที่ตั้งไว้ใน FastAPI 
      final url = Uri.parse('${AppConfig.baseUrl}/attendance/active-sessions/check-face-change');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // แปลงข้อมูล JSON ที่ได้จากหลังบ้านกลับมาเป็น Map
        return jsonDecode(utf8.decode(response.bodyBytes)); 
      } else {
        throw Exception('เกิดข้อผิดพลาดจากเซิร์ฟเวอร์ (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้: $e');
    }
  }
}
