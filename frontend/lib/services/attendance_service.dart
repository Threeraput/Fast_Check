import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../services/auth_service.dart';
import '../models/attendance_session.dart';
import '../models/attendance.dart';

/// Endpoints ที่คาดหวัง (จะพยายามลองแบบมี /attendance และ fallback ให้)
/// - GET  /attendance/sessions/active   (fallback -> /sessions/active)
/// - POST /attendance/sessions/open     (fallback -> /sessions/open)
/// - POST /attendance/teacher-location
/// - POST /attendance/check-in          (multipart: file + fields)
/// - POST /attendance/re-verify         (multipart: file + fields)
/// - PATCH /attendance/override/{id}
/// - GET  /attendance/my-status?session_id=...
class AttendanceService {
  static const Duration _timeout = Duration(seconds: 20);

  // ==============================
  // Sessions
  // ==============================

  /// ดึง session ที่กำลังเปิด (แบบ Map ให้ใช้กับหน้าเดิม ๆ ได้เลย)
  /// เพิ่มตัวเลือก [force] เพื่อ bust cache หลังเปิดเช็คชื่อทันที
  static Future<List<Map<String, dynamic>>> getActiveSessions({
    bool force = false,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    // query-bust ถ้า force = true
    final ts = DateTime.now().millisecondsSinceEpoch;
    final primary = Uri.parse(
      '$API_BASE_URL/attendance/sessions/active${force ? '?_=$ts' : ''}',
    );
    final fallback = Uri.parse(
      '$API_BASE_URL/sessions/active${force ? '?_=$ts' : ''}',
    );

    http.Response res;
    try {
      res = await http
          .get(
            primary,
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $token',
              HttpHeaders.acceptHeader: 'application/json',
              // กัน cache ฝั่ง client/proxy
              HttpHeaders.cacheControlHeader: 'no-cache, no-store, max-age=0',
              'Pragma': 'no-cache',
            },
          )
          .timeout(_timeout);

      if (res.statusCode == 404) {
        // ลอง fallback
        res = await http
            .get(
              fallback,
              headers: {
                HttpHeaders.authorizationHeader: 'Bearer $token',
                HttpHeaders.acceptHeader: 'application/json',
                HttpHeaders.cacheControlHeader: 'no-cache, no-store, max-age=0',
                'Pragma': 'no-cache',
              },
            )
            .timeout(_timeout);
      }
    } on SocketException {
      throw Exception('Network error while fetching sessions');
    }

    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } else {
      throw Exception(
        'Fetch active sessions failed [${res.statusCode}]: ${res.body}',
      );
    }
  }

  /// alias ให้เรียกชื่อเดิมในบางหน้า (ยังเรียกได้เหมือนเดิม; จะใส่ force ก็ได้)
  static Future<List<Map<String, dynamic>>> fetchActiveSessions({
    bool force = false,
  }) {
    return getActiveSessions(force: force);
  }

  /// (ครู) เปิด session เช็คชื่อ — สร้างช่วงเวลา UTC ตาม minutes ที่ระบุ
  static Future<AttendanceSession> openSession({
    required String classId,
    required int expiresInMinutes,
    required int radiusMeters,
    required double latitude,
    required double longitude,
    int lateCutoffMinutes = 10,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final nowUtc = DateTime.now().toUtc();
    final startUtc = DateTime.utc(
      nowUtc.year,
      nowUtc.month,
      nowUtc.day,
      nowUtc.hour,
      nowUtc.minute,
      nowUtc.second,
    );
    final safeLate = lateCutoffMinutes > expiresInMinutes
        ? expiresInMinutes
        : lateCutoffMinutes;

    final lateCutoffUtc = startUtc.add(Duration(minutes: safeLate));
    final endUtc = startUtc.add(Duration(minutes: expiresInMinutes));
    String _isoZ(DateTime dt) => dt.toIso8601String();

    final primary = Uri.parse('$API_BASE_URL/attendance/sessions/open');
    final fallback = Uri.parse('$API_BASE_URL/sessions/open');

    final body = <String, dynamic>{
      'class_id': classId,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters.toDouble(),
      'start_time': _isoZ(startUtc),
      'late_cutoff_time': _isoZ(lateCutoffUtc),
      'end_time': _isoZ(endUtc),
    };

    http.Response res;
    try {
      res = await http
          .post(
            primary,
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $token',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (res.statusCode == 404) {
        res = await http
            .post(
              fallback,
              headers: {
                HttpHeaders.authorizationHeader: 'Bearer $token',
                HttpHeaders.contentTypeHeader: 'application/json',
              },
              body: jsonEncode(body),
            )
            .timeout(_timeout);
      }
    } on SocketException {
      throw Exception('Network error while opening session');
    }

    if (res.statusCode == 200 || res.statusCode == 201) {
      return AttendanceSession.fromJson(jsonDecode(res.body));
    } else {
      throw Exception('Open session failed [${res.statusCode}]: ${res.body}');
    }
  }

  /// (ครู) อัปเดตตำแหน่งครู/anchor ปัจจุบัน
  static Future<void> updateTeacherAnchor({
    required String classId,
    required double latitude,
    required double longitude,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('$API_BASE_URL/attendance/teacher-location');
    final body = {
      'class_id': classId,
      'latitude': latitude,
      'longitude': longitude,
    };

    final res = await http
        .post(
          url,
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(
        'Update teacher anchor failed [${res.statusCode}]: ${res.body}',
      );
    }
  }

  // ==============================
  // Attendance (Student)
  // ==============================

  /// เช็คชื่อด้วยรูป + GPS
  static Future<void> checkIn({
    required String sessionId,
    required String imagePath,
    required double latitude,
    required double longitude,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('$API_BASE_URL/attendance/check-in');
    final req = http.MultipartRequest('POST', url)
      ..headers[HttpHeaders.authorizationHeader] = 'Bearer $token'
      ..fields['session_id'] = sessionId
      ..fields['latitude'] = latitude.toString()
      ..fields['longitude'] = longitude.toString()
      // สำรองชื่อฟิลด์ ถ้า backend บางจุดอ่านอีกชื่อหนึ่ง
      ..fields['student_lat'] = latitude.toString()
      ..fields['student_lon'] = longitude.toString();

    final mime = lookupMimeType(imagePath) ?? 'image/jpeg';
    final parts = mime.split('/');
    final filePart = await http.MultipartFile.fromPath(
      'file', // สำคัญ: ให้ชื่อพาร์ทเป็น 'file'
      imagePath,
      contentType: MediaType(parts.first, parts.last),
    );
    req.files.add(filePart);

    final streamed = await req.send().timeout(_timeout);
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      throw Exception('Check-in failed [${streamed.statusCode}]: $body');
    }
  }

  /// ยืนยันซ้ำ (ใช้ได้เมื่อ reverify เปิด + ยังไม่หมดเวลา + เคยเช็คชื่อแล้ว)
  static Future<void> reVerify({
    required String sessionId,
    required String imagePath,
    required double latitude,
    required double longitude,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final uri = Uri.parse('$API_BASE_URL/attendance/re-verify');
    final req = http.MultipartRequest('POST', uri)
      ..headers[HttpHeaders.authorizationHeader] = 'Bearer $token'
      ..fields['session_id'] = sessionId
      ..fields['latitude'] = latitude.toString()
      ..fields['longitude'] = longitude.toString();

    final mime = lookupMimeType(imagePath) ?? 'image/jpeg';
    final parts = mime.split('/');
    final file = await http.MultipartFile.fromPath(
      'file',
      imagePath,
      contentType: MediaType(parts.first, parts.last),
    );
    req.files.add(file);

    final res = await http.Response.fromStream(
      await req.send(),
    ).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('Re-verify failed [${res.statusCode}]: ${res.body}');
    }
  }

  /// ตรวจว่า "นักเรียนคนนี้" เคยเช็คชื่อใน session นี้แล้วหรือยัง
  /// ใช้ในแบนเนอร์/การ์ดเพื่อ enable ปุ่ม "ยืนยันซ้ำ"
  /// backend ควรตอบรูปแบบ: {"has_checked_in": true/false, ...}
  static Future<Map<String, dynamic>> getMyStatusForSession(
    String sessionId,
  ) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final uri = Uri.parse(
      '$API_BASE_URL/attendance/my-status?session_id=$sessionId',
    );
    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } else if (res.statusCode == 404) {
      return {'has_checked_in': false};
    } else {
      throw Exception(
        'getMyStatusForSession failed [${res.statusCode}]: ${res.body}',
      );
    }
  }

  // ==============================
  // Admin/Teacher override (optional)
  // ==============================

  static Future<Attendance> manualOverride({
    required String attendanceId,
    required String newStatus, // "present" | "absent" | "late" | "suspected"
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('$API_BASE_URL/attendance/override/$attendanceId');
    final res = await http
        .patch(
          url,
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode({'status': newStatus}),
        )
        .timeout(_timeout);

    if (res.statusCode == 200) {
      return Attendance.fromJson(jsonDecode(res.body));
    } else {
      throw Exception('Override failed [${res.statusCode}]: ${res.body}');
    }
  }

  static Future<bool> getIsReverified(String sessionId) async {
    final res = await http.get(
      Uri.parse('$API_BASE_URL/attendance/is-reverified/$sessionId'),
      headers: await _headersWithAuth(),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['is_reverified'] == true;
    } else {
      return false;
    }
  }

  static Future<Map<String, String>> _headersWithAuth() async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');
    return {
      HttpHeaders.authorizationHeader: 'Bearer $token',
      HttpHeaders.acceptHeader: 'application/json',
    };
  }
}
