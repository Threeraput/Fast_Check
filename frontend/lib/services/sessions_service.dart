import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/attendance_session.dart';
import '../services/auth_service.dart';

class SessionsService {
  static const String _attendanceBase = '$API_BASE_URL/attendance';
  static const String _sessionsBase = '$_attendanceBase/sessions';
  static const String _reverifyBase = '$_attendanceBase/re-verify';

  static const Duration _timeout = Duration(seconds: 20);

  /// เปิด session เช็คชื่อของอาจารย์
  static Future<AttendanceSession> openSession({
    required String classId,
    required int durationMinutes,
    required double radiusMeters,
    double? anchorLat,
    double? anchorLon,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('$_sessionsBase/open');
    final body = {
      'class_id': classId,
      'duration_minutes': durationMinutes,
      'radius_meters': radiusMeters,
      if (anchorLat != null) 'anchor_lat': anchorLat,
      if (anchorLon != null) 'anchor_lon': anchorLon,
    };

    try {
      final response = await http
          .post(
            url,
            headers: {
              HttpHeaders.contentTypeHeader: 'application/json',
              HttpHeaders.authorizationHeader: 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        return AttendanceSession.fromJson(json);
      } else {
        throw Exception(
          'Open session failed [${response.statusCode}]: ${response.body}',
        );
      }
    } on SocketException {
      throw Exception('Network error while opening session');
    }
  }

  /// ดึงรายการ session ที่ active
  static Future<List<AttendanceSession>> fetchActiveSessions() async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('$_sessionsBase/active');

    try {
      final response = await http
          .get(
            url,
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $token',
              HttpHeaders.acceptHeader: 'application/json',
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list
            .map((e) => AttendanceSession.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(
          'Fetch sessions failed [${response.statusCode}]: ${response.body}',
        );
      }
    } on SocketException {
      throw Exception('Network error while fetching sessions');
    }
  }

  /// 🔹 เปิด/ปิด reverify สำหรับ session
  /// ใช้ endpoint: POST /attendance/re-verify/toggle
  static Future<bool> toggleReverify({
    required String sessionId,
    required bool enabled,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('$_reverifyBase/toggle');
    final body = {'session_id': sessionId, 'enabled': enabled};

    try {
      final response = await http
          .post(
            url,
            headers: {
              HttpHeaders.contentTypeHeader: 'application/json',
              HttpHeaders.authorizationHeader: 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        return map['reverify_enabled'] == true;
      } else {
        throw Exception(
          'Toggle reverify failed [${response.statusCode}]: ${response.body}',
        );
      }
    } on SocketException {
      throw Exception('Network error while toggling reverify');
    }
  }
}
