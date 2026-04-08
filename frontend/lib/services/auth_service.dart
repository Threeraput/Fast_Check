import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/users.dart'; // ตรวจสอบให้แน่ใจว่า import ถูกต้อง
import '../models/token.dart';
import 'package:frontend/config.dart';

// ตรวจสอบ BASE_URL ของคุณให้ตรงกับ Backend
const String API_BASE_URL = AppConfig.baseUrl;

class AuthService {
  // ... (โค้ด login, register, getAccessToken, getCurrentUserFromLocal, logout เดิม) ...

  static Future<Token?> login(String username, String password) async {
    // แก้ไข: ลบ 'auth/' ที่ซ้ำกันออก
    final url = Uri.parse('$API_BASE_URL/auth/token');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'password',
          'username': username,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final token = Token.fromJson(json.decode(response.body));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('accessToken', token.accessToken);
        await prefs.setString('currentUser', json.encode(token.user.toJson()));
        return token;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Failed to login');
      }
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  static Future<User> register(Map<String, dynamic> userData) async {
    // แก้ไข: ลบ 'auth/' ที่ซ้ำกันออก
    final url = Uri.parse('$API_BASE_URL/auth/register');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(userData),
      );

      if (response.statusCode == 201) {
        return User.fromJson(json.decode(response.body));
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Failed to register');
      }
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  static Future<User?> getCurrentUserFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('currentUser');
    if (userJson != null) {
      return User.fromJson(json.decode(userJson));
    }
    return null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('currentUser');
  }

  // --- เพิ่มฟังก์ชันใหม่สำหรับ OTP และ Password Reset ด้านล่างนี้ ---

  static Future<bool> requestOtp(String email) async {
    // แก้ไข: ลบ 'auth/' ที่ซ้ำกันออก
    final url = Uri.parse('$API_BASE_URL/auth/request-otp');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      if (response.statusCode == 200) {
        return true; // OTP request successful
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Failed to request OTP');
      }
    } catch (e) {
      throw Exception('Request OTP failed: $e');
    }
  }

  static Future<bool> verifyOtp(String email, String otpCode) async {
    final url = Uri.parse('$API_BASE_URL/auth/verify-otp');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'otp_code': otpCode}),
      );

      if (response.statusCode == 200) {
        // ถ้า Backend คืนแค่ 200 OK โดยไม่มี User object กลับมา
        return true; // คืนค่าเป็น true เมื่อสำเร็จ
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Failed to verify OTP');
      }
    } catch (e) {
      throw Exception('OTP verification failed: $e');
    }
  }

  static Future<bool> resetPassword(
    String email,
    String otpCode,
    String newPassword,
  ) async {
    // แก้ไข: ลบ 'auth/' ที่ซ้ำกันออก
    final url = Uri.parse('$API_BASE_URL/auth/reset-password');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'otp_code': otpCode,
          'new_password': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return true; // Password reset successful
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Failed to reset password');
      }
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }


  static Future<List<User>> getPendingTeachers() async {
    final url = Uri.parse('$API_BASE_URL/admin/pending-teachers');
    final accessToken = await getAccessToken();
    if (accessToken == null) {
      throw Exception('Not authenticated');
    }
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => User.fromJson(json)).toList();
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Failed to fetch pending teachers');
      }
    } catch (e) {
      throw Exception('Failed to fetch pending teachers: $e');
    }
  }

  static Future<void> approveTeacher(String userId) async {
    final url = Uri.parse('$API_BASE_URL/admin/users/$userId/approve-teacher');
    final accessToken = await getAccessToken();
    if (accessToken == null) {
      throw Exception('Not authenticated');
    }
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Failed to approve teacher');
      }
    } catch (e) {
      throw Exception('Failed to approve teacher: $e');
    }
  }

  static Future getCurrentUser() async {}
}
