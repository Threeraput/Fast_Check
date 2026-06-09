import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/classroom.dart';
import 'auth_service.dart' show AuthService; // ใช้ getAccessToken()
import 'package:frontend/config.dart';

const String API_BASE_URL = AppConfig.baseUrl;

class ClassService {
  // ===== Headers =====
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getAccessToken();
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    if (token != null) {
      print('🔐 [_HEADERS] Token loaded: ${token.substring(0, 50)}...');
    } else {
      print('⚠️ [_HEADERS] NO TOKEN FOUND!');
    }

    return headers;
  }

  // ===== Utilities =====
  static Exception _errorFrom(http.Response res) {
    try {
      final m = json.decode(res.body);
      final msg = m['detail'] ?? m['message'] ?? res.body;
      return Exception(msg.toString());
    } catch (_) {
      return Exception(res.body);
    }
  }

  // ===== API Calls =====

  /// 1) POST /classes/ (สร้างห้องเรียน)
  static Future<Classroom> createClassroom(ClassroomCreate data) async {
    final url = Uri.parse('$API_BASE_URL/classes/');
    final res = await http.post(
      url,
      headers: await _headers(),
      body: json.encode(data.toJson()),
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      return Classroom.fromJson(json.decode(res.body));
    }
    throw _errorFrom(res);
  }

  /// 2) GET /classes/taught (ห้องเรียนที่สอน)
  // 1. เพิ่มพารามิเตอร์ {bool isArchived = false} เข้ามา
  static Future<List<Classroom>> getTaughtClasses({
    bool isArchived = false,
  }) async {
    // final url = Uri.parse('$API_BASE_URL/classes/taught');

    // 2. เติม ?is_archived=$isArchived ต่อท้าย URL
    final url = Uri.parse(
      '$API_BASE_URL/classes/taught?is_archived=$isArchived',
    );
    final res = await http.get(url, headers: await _headers());
    if (res.statusCode == 200) {
      final list = (json.decode(res.body) as List).cast<dynamic>();
      return list
          .map((e) => Classroom.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw _errorFrom(res);
  }

  /// 11) PATCH /classes/{class_id}/restore (กู้คืนห้องเรียน)
  static Future<void> restoreClassroom(String classId) async {
    final url = Uri.parse('$API_BASE_URL/classes/$classId/restore');

    // ใช้ http.patch เพราะเราแค่เข้าไปอัปเดตข้อมูลบางส่วน
    final res = await http.patch(url, headers: await _headers());

    if (res.statusCode == 200) return; // สำเร็จ
    throw _errorFrom(res);
  }

  /// 3) POST /classes/join (นักเรียนเข้าร่วม)
  static Future<void> joinClassroom(String code) async {
    final url = Uri.parse('$API_BASE_URL/classes/join');
    final headers = await _headers();
    final token = headers['Authorization'];

    print('🔍 [DEBUG] Join Class Request:');
    print('   URL: $url');
    print(
      '   Token: ${token != null ? token.substring(0, 20) + '...' : 'NO TOKEN'}',
    );

    final res = await http.post(
      url,
      headers: headers,
      body: json.encode({'code': code}),
    );

    print('   Response: ${res.statusCode}');
    if (res.statusCode != 200) {
      print('   Body: ${res.body}');
    }

    if (res.statusCode == 200) return;
    try {
      final data = json.decode(res.body);
      throw Exception(data['detail'] ?? 'เข้าร่วมคลาสไม่สำเร็จ');
    } catch (_) {
      throw Exception('เข้าร่วมคลาสไม่สำเร็จ');
    }
  }

  /// 4) DELETE /classes/{class_id}/students/{student_id}
  static Future<void> removeStudent(String classId, String studentId) async {
    final url = Uri.parse('$API_BASE_URL/classes/$classId/students/$studentId');
    final res = await http.delete(url, headers: await _headers());
    if (res.statusCode == 204) return;
    throw _errorFrom(res);
  }

  /// 5) PATCH /classes/{class_id}
  static Future<Classroom> updateClassroom(
    String classId,
    ClassroomUpdate data,
  ) async {
    final url = Uri.parse('$API_BASE_URL/classes/$classId');
    final res = await http.patch(
      url,
      headers: await _headers(),
      body: json.encode(data.toJson()),
    );
    if (res.statusCode == 200) {
      return Classroom.fromJson(json.decode(res.body));
    }
    throw _errorFrom(res);
  }

  /// 6) DELETE /classes/{class_id}
  static Future<void> deleteClassroom(String classId) async {
    final url = Uri.parse('$API_BASE_URL/classes/$classId');
    final res = await http.delete(url, headers: await _headers());
    if (res.statusCode == 204) return;
    throw _errorFrom(res);
  }

  /// 7) GET /classes/{class_id}
  static Future<Classroom> getClassroomDetails(String classId) async {
    final url = Uri.parse('$API_BASE_URL/classes/$classId');
    final res = await http.get(url, headers: await _headers());
    if (res.statusCode == 200) {
      return Classroom.fromJson(json.decode(res.body));
    }
    throw _errorFrom(res);
  }

  /// 8) GET /classes/enrolled
  static Future<List<Classroom>> getJoinedClasses() async {
    final url = Uri.parse('$API_BASE_URL/classes/enrolled');
    final res = await http.get(url, headers: await _headers());
    if (res.statusCode == 200) {
      final list = (json.decode(res.body) as List).cast<dynamic>();
      return list
          .map((e) => Classroom.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw _errorFrom(res);
  }

  /// 9) นักเรียนออกจากคลาส
  static Future<void> leaveClassroom(String classId) async {
    final token = await AuthService.getAccessToken();
    final user = await AuthService.getCurrentUserFromLocal();
    if (user == null) throw Exception('ไม่พบข้อมูลผู้ใช้ในระบบ');
    final studentId = user.userId;
    final url = Uri.parse('$API_BASE_URL/classes/$classId/students/$studentId');
    final res = await http.delete(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (res.statusCode == 204) return;
    try {
      final data = json.decode(res.body);
      throw Exception(data['detail'] ?? 'ออกจากคลาสไม่สำเร็จ');
    } catch (_) {
      throw Exception('ออกจากคลาสไม่สำเร็จ (status: ${res.statusCode})');
    }
  }

  /// 10) GET /classes/{class_id}/members : ใช้ดึงรายชื่อครู + เพื่อนในคลาส
  static Future<Classroom> getClassroomMembers(String classId) async {
    final url = Uri.parse('$API_BASE_URL/classes/$classId/members');
    final res = await http.get(url, headers: await _headers());
    if (res.statusCode == 200) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      return Classroom.fromJson(data);
    }
    if (res.statusCode == 403) throw Exception('Forbidden');
    if (res.statusCode == 404) throw Exception('Class not found');
    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }

  // 2. เพิ่มฟังก์ชันใหม่สำหรับนักเรียนโดยเฉพาะ (GET /classes/{class_id} ที่ครูใช้กับนักเรียนไม่ได้)
  static Future<Classroom?> getStudentClassroomDetails(String classId) async {
    try {
      final token = await AuthService.getAccessToken();

      // เปลี่ยน URL ตรงนี้ให้เป็น API เส้นที่นักเรียนมีสิทธิ์เรียกได้ของหลังบ้านคุณ
      // เช่น /api/v1/student/classes/{classId} หรือ /api/v1/classes/{classId}
      final response = await http.get(
        Uri.parse('http://<IP_หลังบ้าน>/api/v1/student/classes/$classId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // แปลง JSON กลับเป็น Model Classroom ของคุณ
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return Classroom.fromJson(data);
      } else {
        print('ดึงข้อมูลคลาสนักเรียนไม่สำเร็จ: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getStudentClassroomDetails: $e');
      return null;
    }
  }

  // 3. เพิ่มฟังก์ชันใหม่สำหรับนักเรียนโดยเฉพาะ (GET /classes/enrolled ที่ครูใช้กับนักเรียนไม่ได้)
  static Future<List<Classroom>> getEnrolledClasses({
    bool isArchived = false,
  }) async {
    try {
      final token = await AuthService.getAccessToken();

      // เปลี่ยน URL ตรงนี้ให้ตรงกับ API ของนักเรียนในหลังบ้าน FastAPI ของคุณ
      // เช่น /api/v1/classes/enrolled หรือ /api/v1/student/classes
      final url = Uri.parse(
        'http://<IP_หลังบ้าน>/api/v1/classes/enrolled?is_archived=$isArchived',
      );

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => Classroom.fromJson(json)).toList();
      } else {
        print('โหลดคลาสของนักเรียนพลาด: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error getEnrolledClasses: $e');
      return [];
    }
  }
}
