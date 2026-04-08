// lib/services/feed_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:frontend/services/classwork_simple_service.dart';
import 'package:frontend/models/classwork.dart';
import '../models/feed_item.dart';
import 'attendance_service.dart';

//  เพิ่มบริการประกาศ
import 'package:frontend/services/announcement_service.dart';

/// Helper เล็กๆ: แปลงค่าจาก backend เป็น boolean
bool _truthy(Map<String, dynamic>? m, List<String> keys) {
  if (m == null) return false;
  for (final k in keys) {
    final v = m[k];
    if (v == true) return true;
    if (v is String) {
      final s = v.toLowerCase();
      if (s == 'true' || s == 'passed' || s == 'completed' || s == 'ok') {
        return true;
      }
    }
    if (v is Map && (v['passed'] == true || v['completed'] == true)) {
      return true;
    }
  }
  return false;
}

// ✅ ช่วย dedupe โดยใช้ id+kind เป็นกุญแจ
List<FeedItem> _uniqByIdKind(Iterable<FeedItem> items) {
  final seen = <String>{};
  final out = <FeedItem>[];
  for (final it in items) {
    final kind = it.extra['kind']?.toString() ?? it.type.toString();
    final key = '${it.id}|$kind';
    if (seen.add(key)) out.add(it);
  }
  return out;
}

class FeedService {
  /// ✅ ดึงฟีดพื้นฐาน (เช็คชื่อ) + ✅ รวม "ประกาศ" + ✅ ต่อท้าย "งาน (ครู)"
  static Future<List<FeedItem>> getClassFeed(String classId) async {
    final items = <FeedItem>[];

    // 1) เช็คชื่อ (เดิม)
    try {
      final sessions = await AttendanceService.getActiveSessions();
      for (final s in sessions) {
        if ((s['class_id']?.toString() ?? '') != classId) continue;

        final id = s['session_id']?.toString() ?? s['id']?.toString() ?? '';
        if (id.isEmpty) continue;

        final expires = DateTime.tryParse(
          s['end_time']?.toString() ?? s['expires_at']?.toString() ?? '',
        );

        final postedAt =
            DateTime.tryParse(s['start_time']?.toString() ?? '') ??
            DateTime.now().subtract(const Duration(minutes: 1));

        items.add(
          FeedItem(
            id: id,
            classId: classId,
            type: FeedType.checkin,
            title: 'เช็คชื่อกำลังเปิดอยู่',
            postedAt: postedAt,
            expiresAt: expires,
            extra: {
              'session_id': id,
              'reverify_enabled': s['reverify_enabled'] == true,
              'radius': s['radius_meters'],
              'anchor_lat': s['anchor_lat'],
              'anchor_lon': s['anchor_lon'],
              'kind': 'checkin',
            },
          ),
        );
      }
    } catch (e) {
      print('⚠️ โหลด session feed ไม่สำเร็จ: $e');
    }

    // 2) ✅ ประกาศ (announcements)
    try {
      final anns = await AnnouncementService.listByClassId(classId);
      for (final a in anns) {
        items.add(
          FeedItem(
            id: 'ann:${a['announcement_id']}',
            classId: classId,
            type: FeedType.announcement,
            title: (a['title']?.isEmpty ?? true) ? 'ประกาศ' : a['title'],
            postedAt:
                DateTime.tryParse(a['created_at']?.toString() ?? '') ??
                DateTime.now(),
            expiresAt: a['expires_at'],
            extra: {
              'kind': 'announcement',
              'body': a['body'],
              'pinned': a['pinned'],
              'visible': a['visible'],
              'author_name': a['author_name'],
            },
          ),
        );
      }
    } catch (e) {
      print('⚠️ โหลดประกาศไม่สำเร็จ: $e');
    }

    // 3) ✅ งาน (สำหรับครู) — ของเดิม
    try {
      final asgs =
          await ClassworkSimpleService.listAssignmentsForClassAsTeacherTyped(
            classId,
          );
      for (final a in asgs) {
        items.add(
          FeedItem(
            id: 'asg:${a.assignmentId}',
            classId: classId,
            type: FeedType.assignment,
            title: 'งาน: ${a.title}',
            postedAt: a.createdAt,
            expiresAt: a.dueDate,
            extra: {
              'kind': 'assignment',
              'assignment_id': a.assignmentId,
              'title': a.title,
              'due_date': a.dueDate.toIso8601String(),
              'max_score': a.maxScore,
            },
          ),
        );
      }
    } catch (e) {
      print('⚠️ โหลด assignments (ครู) ไม่สำเร็จ: $e');
    }

    // ✅ เรียงลำดับ
    items.sort((a, b) {
      final aKind = a.extra['kind']?.toString();
      final bKind = b.extra['kind']?.toString();

      final aIsCheckin = a.type == FeedType.checkin || aKind == 'checkin';
      final bIsCheckin = b.type == FeedType.checkin || bKind == 'checkin';

      if (aIsCheckin != bIsCheckin) {
        return aIsCheckin ? -1 : 1;
      }
      final aIsAnn = aKind == 'announcement';
      final bIsAnn = bKind == 'announcement';
      if (aIsAnn && bIsAnn) {
        final ap = a.extra['pinned'] == true;
        final bp = b.extra['pinned'] == true;
        if (ap != bp) return bp ? 1 : -1;
      }
      return b.postedAt.compareTo(a.postedAt);
    });

    return items;
  }

  /// ✅ ฟีดสำหรับนักเรียน (เช็คชื่อ + งานนักเรียน + ประกาศ)
  static Future<List<FeedItem>> getClassFeedForStudentWithAssignments(
    String classId,
  ) async {
    final result = <FeedItem>[];

    // ✳️ ดึง base แค่ครั้งเดียว
    final base = await getClassFeed(classId);

    // 1) รวม "ประกาศ" จาก base ครั้งเดียว
    for (final f in base) {
      final kind = f.extra['kind']?.toString();
      if (kind == 'announcement') {
        result.add(f);
      }
    }

    // 2) รวม "เช็คชื่อ" ที่ยังต้องแสดง (ยังไม่ตรวจครบ)
    final checkins = base.where((f) {
      final kind = f.extra['kind']?.toString();
      return f.type == FeedType.checkin || kind == 'checkin';
    });
    for (final f in checkins) {
      final sid = f.extra['session_id']?.toString();
      if (sid == null || sid.isEmpty) {
        result.add(f);
        continue;
      }
      try {
        final status = await AttendanceService.getMyStatusForSession(sid);
        final hasCheckedIn = _truthy(status, [
          'has_checked_in',
          'checked_in',
          'present',
        ]);
        final reverifyCompleted = _truthy(status, [
          'reverify_completed',
          'has_reverified',
          'reverify_passed',
          'reverified',
        ]);

        // แสดงเฉพาะกรณีที่ยังไม่ครบขั้นตอน
        if (!(hasCheckedIn && reverifyCompleted)) {
          result.add(f);
        }
      } catch (_) {
        result.add(f); // fallback ถ้าเรียกไม่สำเร็จ
      }
    }

    // 3) เพิ่ม “งานของนักเรียน” (สถานะของฉัน) — ไม่ต้องดึงงานครูซ้ำอีก
    try {
      final list = await ClassworkSimpleService.getStudentAssignmentsTyped(
        classId,
      );
      for (final v in list) {
        final a = v.assignment;
        result.add(
          FeedItem(
            id: 'asg:${a.assignmentId}',
            classId: classId,
            type: FeedType.assignment,
            title: 'งาน: ${a.title}',
            postedAt: a.createdAt,
            expiresAt: a.dueDate,
            extra: {
              'kind': 'assignment',
              'assignment_id': a.assignmentId,
              'title': a.title,
              'due_date': a.dueDate.toIso8601String(),
              'max_score': a.maxScore,
              'computed_status': latenessToString(v.computedStatus),
              'my_submission': v.mySubmission?.toJson(),
            },
          ),
        );
      }
    } catch (e) {
      print('⚠️ โหลด assignments (นักเรียน) ไม่สำเร็จ: $e');
    }

    // ✅ กันพลาด: dedupe อีกรอบ
    final deduped = _uniqByIdKind(result);

    // ✅ เรียงลำดับ (เช็คชื่อที่ยังเปิด > ประกาศปักหมุด > ใหม่สุด)
    deduped.sort((a, b) {
      final now = DateTime.now();
      final aKind = a.extra['kind']?.toString();
      final bKind = b.extra['kind']?.toString();

      final aIsCheckin = a.type == FeedType.checkin || aKind == 'checkin';
      final bIsCheckin = b.type == FeedType.checkin || bKind == 'checkin';

      if (aIsCheckin || bIsCheckin) {
        final aExpired = a.expiresAt != null && a.expiresAt!.isBefore(now);
        final bExpired = b.expiresAt != null && b.expiresAt!.isBefore(now);

        if (aExpired != bExpired) return aExpired ? 1 : -1; // ยังเปิดก่อน
        if (aIsCheckin != bIsCheckin) return aIsCheckin ? -1 : 1;
      }

      final aIsAnn = aKind == 'announcement';
      final bIsAnn = bKind == 'announcement';
      if (aIsAnn && bIsAnn) {
        final ap = a.extra['pinned'] == true;
        final bp = b.extra['pinned'] == true;
        if (ap != bp) return bp ? 1 : -1; // pinned มาก่อน
      }

      return b.postedAt.compareTo(a.postedAt);
    });

    return deduped;
  }

  /// ✅ ฟีดของครู (เช็คชื่อ + งานครู + ประกาศ)
  static Future<List<FeedItem>> getClassFeedForTeacherWithAssignments(
    String classId,
  ) async {
    final items = await getClassFeed(classId);
    items.sort((a, b) {
      final aIsAnn = (a.extra['kind']?.toString() == 'announcement');
      final bIsAnn = (b.extra['kind']?.toString() == 'announcement');
      if (aIsAnn && bIsAnn) {
        final ap = a.extra['pinned'] == true;
        final bp = b.extra['pinned'] == true;
        if (ap != bp) return bp ? 1 : -1;
      }
      return b.postedAt.compareTo(a.postedAt);
    });
    return items;
  }
}
