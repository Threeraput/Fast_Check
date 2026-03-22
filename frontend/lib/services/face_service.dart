import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'auth_service.dart';

/// ===== CONFIG =====
/// ใช้ 10.0.2.2 เมื่อรันบน Android Emulator แล้ว backend อยู่ที่เครื่องเดียวกัน
/// ใช้ IP ใน LAN เมื่อรันบนอุปกรณ์จริง
const String _API_BASE_URL = 'http://192.168.1.103:8000/api/v1';
// ตัวอย่างสำหรับอุปกรณ์จริง: 'http://192.168.0.200:8000/api/v1';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class FaceService {
  FaceService._();
  static final http.Client _client = http.Client();
  static const Duration _timeout = Duration(seconds: 20);

  static Uri _u(String path) => Uri.parse('$_API_BASE_URL$path');

  static Future<http.StreamedResponse> _sendMultipart({
    required String path,
    required String accessToken,
    required String filePath,
    String fieldName = 'file', // ต้องตรงกับ FastAPI: UploadFile = File(...)
    Map<String, String>? fields,
  }) async {
    final request = http.MultipartRequest('POST', _u(path))
      ..headers['Authorization'] = 'Bearer $accessToken';

    if (fields != null && fields.isNotEmpty) {
      request.fields.addAll(fields);
    }

    // ใส่ Content-Type ให้พาร์ทไฟล์เป็น image/*
    final mimeType = lookupMimeType(filePath) ?? 'image/jpeg';
    final mediaType = MediaType.parse(mimeType);

    request.files.add(
      await http.MultipartFile.fromPath(
        fieldName,
        filePath,
        contentType: mediaType,
      ),
    );

    final streamed = await _client.send(request).timeout(_timeout);
    return streamed;
  }

  /// 1) Upload face image -> ได้ JSON กลับมา (FaceSampleResponse)
  static Future<Map<String, dynamic>> uploadFace(String imagePath) async {
    final token = await AuthService.getAccessToken();
    if (token == null) {
      throw ApiException('Authentication token missing.', statusCode: 401);
    }

    //  path ที่ถูกต้อง (ไม่ซ้ำ prefix)
    const path = '/face-recognition/upload-face';

    try {
      final res = await _sendMultipart(
        path: path,
        accessToken: token,
        filePath: imagePath,
      );

      final body = await res.stream.bytesToString();
      final code = res.statusCode;

      if (code == 200 || code == 201) {
        try {
          return json.decode(body) as Map<String, dynamic>;
        } catch (_) {
          return {'message': body};
        }
      } else {
        String msg = 'Failed to upload face.';
        try {
          final err = json.decode(body);
          msg = err is Map && err['detail'] != null
              ? err['detail'].toString()
              : msg;
        } catch (_) {
          msg = body.isNotEmpty ? body : msg;
        }
        throw ApiException(msg, statusCode: code);
      }
    } on SocketException {
      throw ApiException(
        'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ (ตรวจสอบ Wi-Fi/IP/Firewall).',
      );
    } on HttpException {
      throw ApiException('การเชื่อมต่อ HTTP ผิดพลาด.');
    } on FormatException {
      throw ApiException('รูปแบบข้อมูลตอบกลับไม่ถูกต้อง.');
    }
  }

  /// 2) Verify face -> คืนค่า bool
  static Future<bool> verifyFace(String imagePath) async {
    final token = await AuthService.getAccessToken();
    if (token == null) {
      throw ApiException('Authentication token missing.', statusCode: 401);
    }

    //  path ที่ถูกต้อง (ไม่ซ้ำ prefix)
    const path = '/face-recognition/verify-face';

    try {
      final res = await _sendMultipart(
        path: path,
        accessToken: token,
        filePath: imagePath,
      );

      final body = await res.stream.bytesToString();
      final code = res.statusCode;

      if (code == 200) {
        // backend คืนคีย์ "matched"
        try {
          final data = json.decode(body);
          if (data is Map && data.containsKey('matched')) {
            return data['matched'] == true;
          }
          return true; // กันกรณี backend ตอบ 200 แต่ฟอร์แมตต่างไป
        } catch (_) {
          return true;
        }
      } else if (code == 401 || code == 404) {
        // 401: ไม่ match / token ผิด / ไม่มี sample
        return false;
      } else {
        String msg = 'Face verification failed.';
        try {
          final err = json.decode(body);
          msg = err is Map && err['detail'] != null
              ? err['detail'].toString()
              : msg;
        } catch (_) {
          msg = body.isNotEmpty ? body : msg;
        }
        throw ApiException(msg, statusCode: code);
      }
    } on SocketException {
      throw ApiException(
        'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ (ตรวจสอบ Wi-Fi/IP/Firewall).',
      );
    } on HttpException {
      throw ApiException('การเชื่อมต่อ HTTP ผิดพลาด.');
    } on FormatException {
      throw ApiException('รูปแบบข้อมูลตอบกลับไม่ถูกต้อง.');
    }
  }

   // 3 ตรวจว่านักเรียนมีใบหน้าในระบบแล้วหรือไม่
  static Future<bool> checkHasFace(String userId) async {
    try {
      final token = await AuthService.getAccessToken();
      final url = Uri.parse(
        '$API_BASE_URL/face-recognition/check-face/$userId',
      );
      final res = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return data['has_face'] == true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

 static Future<void> deleteFace() async {
    try {
      // ดึง token จาก AuthService
      final token = await AuthService.getAccessToken();
      if (token == null) {
        throw Exception('ไม่พบโทเคน โปรดเข้าสู่ระบบใหม่');
      }

      // สร้าง URL และ Header
      final url = Uri.parse('$API_BASE_URL/face-recognition/delete-face');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // ส่งคำขอ DELETE
      final response = await http.delete(url, headers: headers);

      if (response.statusCode != 200) {
        throw Exception('ลบใบหน้าไม่สำเร็จ: ${response.body}');
      }
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการลบใบหน้า: $e');
    }
  }
}


