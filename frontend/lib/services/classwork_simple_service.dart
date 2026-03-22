// lib/services/classwork_simple_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:frontend/models/classwork.dart';
import 'auth_service.dart' show AuthService;

// ให้ใช้รูปแบบเดียวกับไฟล์อื่นๆ ในโปรเจกต์คุณ
const String API_BASE_URL = 'http://192.168.1.103:8000/api/v1';
const Duration _kTimeout = Duration(seconds: 20);

class ClassworkSimpleService {
  static String get _base => '$API_BASE_URL/classwork-simple';

  // ---------- common headers & error ----------
  static Future<Map<String, String>> _headersJson() async {
    final token = await AuthService.getAccessToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, String>> _headersAuthOnly() async {
    final token = await AuthService.getAccessToken();
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Exception _errorFrom(http.Response res) {
    try {
      final m = json.decode(res.body);
      final msg = m['detail'] ?? m['message'] ?? res.body;
      return Exception(msg.toString());
    } catch (_) {
      return Exception(res.body);
    }
  }

  // ============ STUDENT (raw) ============
  static Future<List<dynamic>> getStudentAssignments(String classId) async {
    final url = Uri.parse('$_base/student/$classId/assignments');
    final res = await http
        .get(url, headers: await _headersAuthOnly())
        .timeout(_kTimeout);
    if (res.statusCode == 200) {
      return (json.decode(res.body) as List).cast<dynamic>();
    }
    throw _errorFrom(res);
  }

  static Future<Map<String, dynamic>> submitPdf({
    required String assignmentId,
    required File pdfFile,
  }) async {
    final url = Uri.parse('$_base/assignments/$assignmentId/submit');
    final req = http.MultipartRequest('POST', url);
    final headers = await _headersAuthOnly();
    req.headers.addAll(headers);

    final mime = (lookupMimeType(pdfFile.path) ?? '').toLowerCase();
    if (!mime.contains('pdf')) {
      throw Exception('กรุณาเลือกไฟล์ PDF เท่านั้น');
    }

    req.files.add(
      await http.MultipartFile.fromPath(
        'file',
        pdfFile.path,
        contentType: MediaType.parse(mime.isEmpty ? 'application/pdf' : mime),
      ),
    );

    final streamed = await req.send().timeout(_kTimeout);
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    }
    throw _errorFrom(res);
  }

  // ============ TEACHER (raw) ============
  static Future<Map<String, dynamic>> createAssignment({
    required String classId,
    required String title,
    required int maxScore,
    required DateTime dueDate,
  }) async {
    final url = Uri.parse('$_base/assignments');
    final payload = {
      'class_id': classId,
      'title': title,
      'max_score': maxScore,
      'due_date': dueDate.toUtc().toIso8601String(),
    };
    final res = await http
        .post(url, headers: await _headersJson(), body: json.encode(payload))
        .timeout(_kTimeout);
    if (res.statusCode == 201 || res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    }
    throw _errorFrom(res);
  }

  static Future<List<dynamic>> listSubmissionsForTeacher(
    String assignmentId,
  ) async {
    final url = Uri.parse('$_base/assignments/$assignmentId/submissions');
    final res = await http
        .get(url, headers: await _headersAuthOnly())
        .timeout(_kTimeout);
    if (res.statusCode == 200) {
      return (json.decode(res.body) as List).cast<dynamic>();
    }
    throw _errorFrom(res);
  }

  static Future<Map<String, dynamic>> gradeSubmission({
    required String assignmentId,
    required String studentId,
    required int score,
  }) async {
    final url = Uri.parse('$_base/assignments/$assignmentId/grade');
    final payload = {'student_id': studentId, 'score': score};
    final res = await http
        .post(url, headers: await _headersJson(), body: json.encode(payload))
        .timeout(_kTimeout);
    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    }
    throw _errorFrom(res);
  }

  static Future<List<dynamic>> listAssignmentsForClassAsTeacher(
    String classId,
  ) async {
    final url = Uri.parse('$_base/teacher/$classId/assignments');
    final res = await http
        .get(url, headers: await _headersAuthOnly())
        .timeout(_kTimeout);
    if (res.statusCode == 200) {
      return (json.decode(res.body) as List).cast<dynamic>();
    }
    throw _errorFrom(res);
  }

  // =======================
  // ====== TYPED API ======
  // =======================
  static Future<List<StudentAssignmentView>> getStudentAssignmentsTyped(
    String classId,
  ) async {
    final url = Uri.parse('$_base/student/$classId/assignments');
    final res = await http
        .get(url, headers: await _headersAuthOnly())
        .timeout(_kTimeout);
    if (res.statusCode == 200) {
      return decodeList(res.body, (m) => StudentAssignmentView.fromJson(m));
    }
    throw _errorFrom(res);
  }

  static Future<List<TeacherSubmissionRow>> listSubmissionsForTeacherTyped(
    String assignmentId,
  ) async {
    final url = Uri.parse('$_base/assignments/$assignmentId/submissions');
    final res = await http
        .get(url, headers: await _headersAuthOnly())
        .timeout(_kTimeout);
    if (res.statusCode == 200) {
      return decodeList(res.body, (m) => TeacherSubmissionRow.fromJson(m));
    }
    throw _errorFrom(res);
  }

  static Future<ClassworkAssignment> createAssignmentTyped({
    required String classId,
    required String title,
    required int maxScore,
    required DateTime dueDate,
  }) async {
    final url = Uri.parse('$_base/assignments');
    final payload = {
      'class_id': classId,
      'title': title,
      'max_score': maxScore,
      'due_date': dueDate.toUtc().toIso8601String(),
    };
    final res = await http
        .post(url, headers: await _headersJson(), body: json.encode(payload))
        .timeout(_kTimeout);
    if (res.statusCode == 201 || res.statusCode == 200) {
      return ClassworkAssignment.fromJson(json.decode(res.body));
    }
    throw _errorFrom(res);
  }

  static Future<List<ClassworkAssignment>>
  listAssignmentsForClassAsTeacherTyped(String classId) async {
    final url = Uri.parse('$_base/teacher/$classId/assignments');
    final res = await http
        .get(url, headers: await _headersAuthOnly())
        .timeout(_kTimeout);
    if (res.statusCode == 200) {
      return decodeList(res.body, (m) => ClassworkAssignment.fromJson(m));
    }
    throw _errorFrom(res);
  }

  // ✅ เพิ่มฟังก์ชันพิเศษที่ใช้ในหน้า “ดูงานนักเรียน”
  static Future<List<ClassworkSubmission>> getSubmissionsForAssignment(
    String assignmentId,
  ) async {
    final url = Uri.parse('$_base/assignments/$assignmentId/submissions');
    final res = await http
        .get(url, headers: await _headersAuthOnly())
        .timeout(_kTimeout);
    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      return data.map((e) => ClassworkSubmission.fromJson(e)).toList();
    }
    throw _errorFrom(res);
  }

  static Future<void> gradeSubmissionForAssignment({
    required String assignmentId,
    required String studentId,
    required int score,
  }) async {
    final url = Uri.parse('$_base/assignments/$assignmentId/grade');
    final body = json.encode({'student_id': studentId, 'score': score});
    final res = await http
        .post(url, headers: await _headersJson(), body: body)
        .timeout(_kTimeout);
    if (res.statusCode != 200) {
      throw _errorFrom(res);
    }
  }
}
