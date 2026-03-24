import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class LocationService {
  static const String baseUrl = '$API_BASE_URL/attendance';

  /// อาจารย์อัปเดตพิกัด
  static Future<void> updateTeacherLocation({
    required String teacherId,
    required String classId,
    required double latitude,
    required double longitude,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('$baseUrl/teacher-location');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'teacher_id': teacherId,
        'class_id': classId,
        'latitude': latitude,
        'longitude': longitude,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Update teacher location failed: ${response.body}');
    }
  }

  /// นักเรียนบันทึกพิกัดระหว่างคาบ
  static Future<void> logStudentLocation({
    required String studentId,
    required String classId,
    required double latitude,
    required double longitude,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('$baseUrl/student-tracking');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'student_id': studentId,
        'class_id': classId,
        'latitude': latitude,
        'longitude': longitude,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Log student location failed: ${response.body}');
    }
  }
}
