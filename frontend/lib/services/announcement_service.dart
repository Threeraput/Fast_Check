import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:frontend/models/comment_model.dart';
import 'auth_service.dart' show AuthService;
import 'package:frontend/config.dart';

const String API_BASE_URL = AppConfig.baseUrl;

class AnnouncementAttachmentDto {
  final String attachmentId;
  final String fileName;
  final String storagePath;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;

  AnnouncementAttachmentDto({
    required this.attachmentId,
    required this.fileName,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
  });

  factory AnnouncementAttachmentDto.fromJson(Map<String, dynamic> j) {
    return AnnouncementAttachmentDto(
      attachmentId: j['attachment_id']?.toString() ?? '',
      fileName: j['file_name']?.toString() ?? '',
      storagePath: j['storage_path']?.toString() ?? '',
      mimeType: j['mime_type']?.toString() ?? '',
      sizeBytes: j['size_bytes'] ?? 0,
      createdAt:
          DateTime.tryParse(j['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

class AnnouncementDto {
  final String announcementId;
  final String classId;
  final String teacherId;
  final String title;
  final String? body;
  final bool pinned;
  final bool visible;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;
  final List<AnnouncementAttachmentDto> attachments;

  AnnouncementDto({
    required this.announcementId,
    required this.classId,
    required this.teacherId,
    required this.title,
    this.body,
    required this.pinned,
    required this.visible,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
    this.attachments = const [],
  });

  factory AnnouncementDto.fromJson(Map<String, dynamic> j) {
    DateTime? _p(String? s) =>
        s == null ? null : DateTime.tryParse(s)?.toLocal();
    
    var attsList = j['attachments'] as List?;
    List<AnnouncementAttachmentDto> atts = attsList != null
        ? attsList.map((e) => AnnouncementAttachmentDto.fromJson(e)).toList()
        : [];

    return AnnouncementDto(
      announcementId:
          j['announcement_id']?.toString() ?? j['id']?.toString() ?? '',
      classId: j['class_id']?.toString() ?? '',
      teacherId: j['teacher_id']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      body: j['body']?.toString(),
      pinned: j['pinned'] == true,
      visible: j['visible'] == true,
      createdAt:
          DateTime.tryParse(j['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(j['updated_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      expiresAt: _p(j['expires_at']?.toString()),
      attachments: atts,
    );
  }
}

class AnnouncementService {
  /// แนบ token ทุกครั้ง
  static Future<Map<String, String>> _authHeaders() async {
    final t = await AuthService.getAccessToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  /// อัปโหลดไฟล์แนบประกาศ
  static Future<AnnouncementAttachmentDto> uploadAttachment(
    String announcementId,
    File file,
  ) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('$API_BASE_URL/announcements/$announcementId/attachments');
    final request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';

    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType.parse(mimeType),
      ),
    );

    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);

    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('อัปโหลดไฟล์ไม่สำเร็จ: ${res.body}');
    }

    return AnnouncementAttachmentDto.fromJson(jsonDecode(res.body));
  }

  /// สร้างประกาศและคืน DTO กลับมา
  static Future<AnnouncementDto> createDto({
    required String classId,
    required String title,
    String? body,
    bool pinned = false,
    bool visible = true,
    DateTime? expiresAt,
  }) async {
    final url = Uri.parse('$API_BASE_URL/announcements');
    final payload = {
      'class_id': classId,
      'title': title,
      'body': body,
      'pinned': pinned,
      'visible': visible,
      'expires_at': expiresAt?.toUtc().toIso8601String(),
    };

    final res = await http.post(
      url,
      headers: await _authHeaders(),
      body: jsonEncode(payload),
    );

    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('สร้างประกาศไม่สำเร็จ: ${res.body}');
    }
    return AnnouncementDto.fromJson(jsonDecode(res.body));
  }

  /// ดึงรายการประกาศของคลาส
  static Future<List<AnnouncementDto>> listForClass(String classId) async {
    final url = Uri.parse('$API_BASE_URL/announcements/class/$classId');
    final res = await http.get(url, headers: await _authHeaders());
    if (res.statusCode != 200) {
      throw Exception('โหลดประกาศไม่สำเร็จ: ${res.body}');
    }
    final List arr = jsonDecode(res.body) as List;
    return arr.map((e) => AnnouncementDto.fromJson(e)).toList();
  }

  /// ดึงประกาศชิ้นเดียวตาม ID
  static Future<AnnouncementDto> getById(String announcementId) async {
    final url = Uri.parse('$API_BASE_URL/announcements/$announcementId');
    final res = await http.get(url, headers: await _authHeaders());
    if (res.statusCode != 200) {
      throw Exception('โหลดข้อมูลประกาศไม่สำเร็จ: ${res.body}');
    }
    return AnnouncementDto.fromJson(jsonDecode(res.body));
  }

  /// ใช้สำหรับ feed service (คืนค่า Map)
  static Future<List<Map<String, dynamic>>> listByClassId(
    String classId,
  ) async {
    final url = Uri.parse('$API_BASE_URL/announcements/class/$classId');
    final res = await http.get(url, headers: await _authHeaders());
    if (res.statusCode != 200) {
      throw Exception('โหลดประกาศไม่สำเร็จ (${res.statusCode})');
    }

    final data = jsonDecode(res.body);
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      return [];
    }
  }

  /// สำหรับ CreateAnnouncementScreen (คืน DTO กลับมาเพื่อให้ใช้ ID อัปโหลดไฟล์ได้)
  static Future<AnnouncementDto> create({
    required String classId,
    required String title,
    String? body,
    bool pinned = false,
    bool visible = true,
    DateTime? expiresAt,
  }) async {
    final url = Uri.parse('$API_BASE_URL/announcements');
    final payload = {
      'class_id': classId,
      'title': title,
      if (body != null && body.isNotEmpty) 'body': body,
      'pinned': pinned,
      'visible': visible,
      if (expiresAt != null) 'expires_at': expiresAt.toUtc().toIso8601String(),
    };

    final res = await http.post(
      url,
      headers: await _authHeaders(),
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('สร้างประกาศไม่สำเร็จ: ${res.body}');
    }

    return AnnouncementDto.fromJson(jsonDecode(res.body));
  }

  /// อัปเดตประกาศ (PATCH /announcements/{id})
  static Future<AnnouncementDto> update({
    required String announcementId,
    String? title,
    String? body,
    bool? pinned,
    bool? visible,
    DateTime? expiresAt,
  }) async {
    final url = Uri.parse('$API_BASE_URL/announcements/$announcementId');
    final payload = {
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (pinned != null) 'pinned': pinned,
      if (visible != null) 'visible': visible,
      if (expiresAt != null) 'expires_at': expiresAt.toUtc().toIso8601String(),
    };

    final res = await http.patch(
      url,
      headers: await _authHeaders(),
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception('อัปเดตประกาศไม่สำเร็จ: ${res.body}');
    }

    return AnnouncementDto.fromJson(jsonDecode(res.body));
  }

  /// ลบประกาศ (DELETE /announcements/{id})
  static Future<void> delete(String announcementId) async {
    final url = Uri.parse('$API_BASE_URL/announcements/$announcementId');
    final res = await http.delete(url, headers: await _authHeaders());

    if (res.statusCode != 204) {
      throw Exception('ลบประกาศไม่สำเร็จ: ${res.body}');
    }
  }

  /// ลบไฟล์แนบประกาศ (DELETE /announcements/attachments/{id})
  static Future<void> deleteAttachment(String attachmentId) async {
    final url = Uri.parse('$API_BASE_URL/announcements/attachments/$attachmentId');
    final res = await http.delete(url, headers: await _authHeaders());

    if (res.statusCode != 204) {
      throw Exception('ลบไฟล์แนบไม่สำเร็จ: ${res.body}');
    }
  }

  /// ดึงคอมเมนต์ทั้งหมดของประกาศ
  static Future<List<AnnouncementComment>> getComments(
    String announcementId,
  ) async {
    final url = Uri.parse(
      '$API_BASE_URL/announcements/$announcementId/comments',
    );
    final res = await http.get(url, headers: await _authHeaders());

    if (res.statusCode == 200) {
      final List data = json.decode(utf8.decode(res.bodyBytes));
      return data.map((e) => AnnouncementComment.fromJson(e)).toList();
    }
    throw Exception('โหลดคอมเมนต์ไม่สำเร็จ: ${res.body}');
  }

  /// ส่งคอมเมนต์ใหม่ในประกาศ
  static Future<AnnouncementComment> addComment({
    required String announcementId,
    required String content,
  }) async {
    final url = Uri.parse(
      '$API_BASE_URL/announcements/$announcementId/comments',
    );
    final payload = {'content': content};

    final res = await http.post(
      url,
      headers: await _authHeaders(),
      body: jsonEncode(payload),
    );

    if (res.statusCode == 201 || res.statusCode == 200) {
      return AnnouncementComment.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)),
      );
    }
    throw Exception('ส่งคอมเมนต์ไม่สำเร็จ: ${res.body}');
  }
}
