import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../models/attendance_report.dart';
import '../models/attendance_report_detail.dart';
import 'auth_service.dart';
import 'package:frontend/config.dart';

class AttendanceReportService {
  static const String baseUrl = AppConfig.baseUrl;
  static const Duration _timeout = Duration(seconds: 15);

  static Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ---------- Helpers ----------
  static Future<http.Response> _get(Uri url, String token) =>
      http.get(url, headers: _headers(token)).timeout(_timeout);

  static Future<http.Response> _post(Uri url, String token) =>
      http.post(url, headers: _headers(token)).timeout(_timeout);

  static List<T> _parseList<T>(
    http.Response res,
    T Function(Map<String, dynamic>) fromJson, {
    bool emptyOn404 = false,
  }) {
    if (res.statusCode == 200) {
      final raw = json.decode(res.body);
      if (raw is List) {
        return raw.map<T>((e) => fromJson(e as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Unexpected payload (not a list): ${res.body}');
      }
    }
    if (emptyOn404 && res.statusCode == 404) {
      return <T>[];
    }
    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }

  static Map<String, dynamic> _parseMap(http.Response res) {
    if (res.statusCode == 200) {
      final raw = json.decode(res.body);
      if (raw is Map<String, dynamic>) return raw;
      throw Exception('Unexpected payload (not a map): ${res.body}');
    }
    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }

  // -------------------------------------------------------------
  // นักเรียน
  // -------------------------------------------------------------

  /// นักเรียนดูรายงานรวมของตัวเอง
  static Future<List<AttendanceReport>> getMyReports() async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('$baseUrl/attendance/reports/my-report');
    try {
      final res = await _get(url, token);

      // รองรับทุกเคสแบบไม่ทำให้ UI ล้ม
      if (res.statusCode == 200) {
        final raw = json.decode(res.body);
        if (raw is List) {
          return raw
              .map<AttendanceReport>(
                (e) => AttendanceReport.fromJson(e as Map<String, dynamic>),
              )
              .toList();
        } else {
          throw Exception('Unexpected payload (not a list): ${res.body}');
        }
      }

      // ยังไม่ generate หรือ backend พัง → คืนลิสต์ว่างให้ UI แทน
      if (res.statusCode == 404 ||
          res.statusCode == 500 ||
          res.statusCode == 204) {
        return <AttendanceReport>[];
      }

      // อย่างอื่นให้เด้งขึ้น (จะมีข้อความแจ้ง)
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    } on SocketException {
      throw Exception('Network error while fetching my reports');
    }
  }

  /// นักเรียนดูรายงานรายวันของตัวเอง
  static Future<List<AttendanceReportDetail>> getMyDailyReports() async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('$baseUrl/attendance/reports/details/my');
    try {
      final res = await _get(url, token);
      // หลังบ้านจะ 404 ถ้ายังไม่มี detail → คืนลิสต์ว่าง
      return _parseList<AttendanceReportDetail>(
        res,
        (m) => AttendanceReportDetail.fromJson(m),
        emptyOn404: true,
      );
    } on SocketException {
      throw Exception('Network error while fetching my daily reports');
    }
  }

  // -------------------------------------------------------------
  // ครู
  // -------------------------------------------------------------

  /// ครูสร้างรายงานใหม่ทั้งคลาส
  static Future<Map<String, dynamic>> generateClassReport(
    String classId,
  ) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse(
      '$baseUrl/attendance/reports/class/$classId/generate',
    );
    try {
      final res = await _post(url, token);
      return _parseMap(res);
    } on SocketException {
      throw Exception('Network error while generating class report');
    }
  }

  /// ครูดูรายงานรวมของคลาส
  static Future<List<AttendanceReport>> getClassReports(String classId) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('$baseUrl/attendance/reports/class/$classId');
    try {
      final res = await _get(url, token);
      // ถ้า 404 (ยังไม่ generate) → คืนลิสต์ว่าง
      return _parseList<AttendanceReport>(
        res,
        (m) => AttendanceReport.fromJson(m),
        emptyOn404: true,
      );
    } on SocketException {
      throw Exception('Network error while fetching class reports');
    }
  }

  /// ครูดูรายงานรายวันของคลาส
  static Future<List<AttendanceReportDetail>> getClassDailyReports(
    String classId,
  ) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('$baseUrl/attendance/reports/details/class/$classId');
    try {
      final res = await _get(url, token);
      // หลังบ้าน 404 เมื่อยังไม่มี detail → คืนลิสต์ว่าง
      return _parseList<AttendanceReportDetail>(
        res,
        (m) => AttendanceReportDetail.fromJson(m),
        emptyOn404: true,
      );
    } on SocketException {
      throw Exception('Network error while fetching class daily reports');
    }
  }

  /// ครูดูรายงานของนักเรียนรายคน
  static Future<List<AttendanceReport>> getStudentReport(
    String studentId,
  ) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('$baseUrl/attendance/reports/student/$studentId');
    try {
      final res = await _get(url, token);
      // ถ้าไม่พบ → คืนลิสต์ว่าง
      return _parseList<AttendanceReport>(
        res,
        (m) => AttendanceReport.fromJson(m),
        emptyOn404: true,
      );
    } on SocketException {
      throw Exception('Network error while fetching student report');
    }
  }

  /// ครูดูสรุปของคลาส
  static Future<Map<String, dynamic>> getClassSummary(String classId) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('$baseUrl/attendance/reports/class/$classId/summary');
    try {
      final res = await _get(url, token);

      //  ถ้ายังไม่เคย generate → 404 → คืน summary ว่าง
      if (res.statusCode == 404) {
        return {
          'total_students': 0,
          'average_attendance_rate': 0.0,
          'total_sessions': 0,
        };
      }

      return _parseMap(res);
    } on SocketException {
      throw Exception('Network error while fetching class summary');
    }
  }

  /// ครูดูรายงานรายวันของนักเรียน "เจาะจงรายบุคคล" (เพื่อดูรูปเช็คชื่อ)
  static Future<List<AttendanceReportDetail>> getStudentDailyReports(
    String studentId,
  ) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');
    final url = Uri.parse(
      '$baseUrl/attendance/reports/details/student/$studentId',
    );
    try {
      final res = await _get(url, token);

      return _parseList<AttendanceReportDetail>(
        res,
        (m) => AttendanceReportDetail.fromJson(m),
        emptyOn404: true,
      );
    } on SocketException {
      throw Exception('Network error while fetching student daily reports');
    }
  }

 // ฟังก์ชันดาวน์โหลดรายงาน (เวอร์ชันใช้งานจริง - Clean Code)
  static Future<void> exportDetailedReport(String classId, String token) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/attendance/reports/details/class/$classId/export/detailed');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // 1. หาพื้นที่ว่างในเครื่อง
        final dir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        
        // 2. เซฟไฟล์เป็น .xlsx ให้ตรงกับที่ Backend ส่งมา
        final filePath = '${dir.path}/detailed_report_$timestamp.xlsx'; 
        
        // 3. เขียนไฟล์ลงเครื่อง
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // 4. สั่งเปิดไฟล์ด้วย OpenFilex
        final result = await OpenFilex.open(filePath);
        
        // 5. ดักจับ Error กรณีต่างๆ เพื่อแจ้งเตือนเป็นภาษาไทย
        if (result.type == ResultType.noAppToOpen) {
          throw Exception("ไม่มีแอปสำหรับเปิดไฟล์ Excel กรุณาติดตั้ง Google Sheets หรือ Microsoft Excel");
        } else if (result.type != ResultType.done) {
          throw Exception("ไม่สามารถเปิดไฟล์ได้: ${result.message}");
        }
        
      } else {
        throw Exception("ดาวน์โหลดล้มเหลว (รหัสข้อผิดพลาด: ${response.statusCode})");
      }
    } catch (e) {
      // โยน Error ออกไปให้หน้าจอ UI จัดการแสดง SnackBar สีแดง
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
