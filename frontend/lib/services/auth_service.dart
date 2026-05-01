import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
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

  static Future<Map<String, dynamic>> getTokenPayload() async {
    final token = await getAccessToken();
    if (token == null) return {};
    try {
      return JwtDecoder.decode(token);
    } catch (_) {
      return {};
    }
  }

  static Future<List<String>> getTokenRoles() async {
    final payload = await getTokenPayload();
    final roles = payload['roles'];
    if (roles is List) {
      return roles.map((e) => e.toString()).toList();
    }
    return [];
  }

  static Future<User?> getCurrentUserFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('currentUser');
    if (userJson == null) return null;

    final user = User.fromJson(json.decode(userJson));
    final payload = await getTokenPayload();
    final tokenRoles = payload['roles'];
    if (tokenRoles is List) {
      return user.copyWith(roles: tokenRoles.map((e) => e.toString()).toList());
    }
    return user;
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

  /// ฟังก์ชันสำหรับสลับบทบาท (Switch Role)
  static Future<bool> switchRole(String targetRole) async {
    try {
      // 1. ดึง Token ปัจจุบันที่อยู่ในเครื่อง
      final currentToken =
          await getAccessToken(); // แก้ไข: ใช้ getAccessToken()
      if (currentToken == null) return false;

      final url = Uri.parse(
        '$API_BASE_URL/auth/switch-role',
      ); // แก้ไข: ใช้ API_BASE_URL

      // 2. ยิง API ขอสลับร่าง
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $currentToken', // แนบตั๋วเดิมไปยืนยันตัว
        },
        body: jsonEncode({
          'target_role': targetRole, // 'student' หรือ 'teacher'
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final newToken = data['access_token'];

        print(
          '🔐 [SWITCH ROLE] New token received: ${newToken.substring(0, 50)}...',
        );

        // 3. เซฟตั๋วใบใหม่ทับของเดิมลงในเครื่อง
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('accessToken', newToken);

        // ตรวจสอบว่าเก็บสำเร็จไหม
        final savedToken = prefs.getString('accessToken');
        print(
          '💾 Token saved to SharedPreferences: ${savedToken == newToken ? '✅ SUCCESS' : '❌ FAILED'}',
        );
        if (savedToken != newToken) {
          print('⚠️ Token mismatch! Expected: ${newToken.substring(0, 30)}...');
          print('⚠️ Got: ${savedToken?.substring(0, 30) ?? 'NULL'}...');
        }

        // 4. อ่าน roles จาก token ใหม่ และ sync ไปที่ cached currentUser
        try {
          final newPayload = JwtDecoder.decode(newToken);
          final newRoles = List<String>.from(newPayload['roles'] ?? []);
          print('🔄 Switch role สำเร็จ! Token ใหม่มี roles: $newRoles');

          // อ่าน cached user
          final userJson = prefs.getString('currentUser');
          if (userJson != null) {
            final user = User.fromJson(json.decode(userJson));
            // สร้าง user ใหม่ที่มี roles อัปเดตจาก token
            final updatedUser = user.copyWith(roles: newRoles);
            // เซฟกลับลง SharedPreferences
            await prefs.setString(
              'currentUser',
              json.encode(updatedUser.toJson()),
            );
            print('✅ Cached user roles updated: $newRoles');
          }
        } catch (e) {
          print('⚠️ Error syncing user roles: $e');
        }

        print('🎉 สลับร่างสำเร็จ! ได้ Token ใหม่มาแล้ว');
        return true;
      } else {
        print('❌ สลับร่างไม่สำเร็จ: ${response.body}');
        return false;
      }
    } catch (e) {
      print('⚠️ Error switchRole: $e');
      return false;
    }
  }

  /// เช็คว่าตอนนี้ผู้ใช้กำลังอยู่ใน "โหมดจำแลงกาย" หรือไม่?
  static Future<bool> isCurrentlySwapped() async {
    final token = await getAccessToken(); // แก้ไข: ใช้ getAccessToken()
    if (token == null) return false;

    // ถอดรหัส Token มาดูไส้ใน
    try {
      final decodedToken = JwtDecoder.decode(token);
      return decodedToken['is_swapped'] == true;
    } catch (_) {
      return false;
    }
  }
}
