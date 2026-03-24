// lib/widgets/active_sessions_banner.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/screens/student_class_view.dart';
import 'package:intl/intl.dart';
import 'package:frontend/services/attendance_service.dart';
import 'package:frontend/screens/student_checkin_screen.dart';
import 'package:frontend/utils/location_helper.dart';
import 'package:frontend/services/sessions_service.dart';


class ActiveSessionsBanner extends StatefulWidget {
  final String classId; // filter เฉพาะคลาสนี้
  final bool isTeacherView; // ถ้าเป็นหน้าครู จะไม่แสดงปุ่มนักเรียน
  const ActiveSessionsBanner({
    super.key,
    required this.classId,
    this.isTeacherView = true,
  });

  @override
  State<ActiveSessionsBanner> createState() => _ActiveSessionsBannerState();
}

class _ActiveSessionsBannerState extends State<ActiveSessionsBanner> {
  late Future<List<Map<String, dynamic>>> _future;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _future = _load());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load({bool force = false}) async {
   final all = await AttendanceService.getActiveSessions(force: force);
    String? _classIdOf(Map<String, dynamic> s) {
      final v1 = s['class_id'];
      if (v1 is String && v1.isNotEmpty) return v1;
      final v2 = s['classId'];
      if (v2 is String && v2.isNotEmpty) return v2;
      final c = s['class'] as Map<String, dynamic>?;
      if (c != null) {
        final v3 = c['class_id'] ?? c['id'];
        if (v3 is String && v3.isNotEmpty) return v3;
      }
      return null;
    }

    return all.where((m) => _classIdOf(m) == widget.classId).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('โหลด Active Sessions ไม่สำเร็จ: ${snap.error}'),
            ),
          );
        }

        final sessions = snap.data ?? const [];
        if (sessions.isEmpty) {
          return Card(
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 12),
                  Expanded(child: Text('ยังไม่มีการเปิดเช็คชื่อในขณะนี้')),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'เช็คชื่อที่กำลังเปิดอยู่',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...sessions.map(
              (s) => _SessionRow(
                data: s,
                isTeacherView: widget.isTeacherView,
                onChanged: () {
                  if (mounted) setState(() => _future = _load(force: true));
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SessionRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isTeacherView;
  final VoidCallback onChanged;
  const _SessionRow({
    required this.data,
    required this.isTeacherView,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('HH:mm');
    final sessionId = (data['session_id'] ?? data['id'] ?? data['sessionId'])?.toString();


    final endStr =
        data['expires_at']?.toString() ?? data['end_time']?.toString();
    final end = endStr != null ? DateTime.tryParse(endStr) : null;
    final endTxt = end != null ? df.format(end.toLocal()) : '-';

    final radius = data['radius_meters']?.toString();
    final lat = data['anchor_lat']?.toString();
    final lon = data['anchor_lon']?.toString();

    final reverifyEnabled = data['reverify_enabled'] == true;

    final nowUtc = DateTime.now().toUtc();
    final notExpired = end != null && end.toUtc().isAfter(nowUtc);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.access_time),
        title: const Text(
          'Session กำลังเปิดอยู่',
          style: TextStyle(fontSize: 16),
        ),
        subtitle: Text(
          [
            if (end != null) 'หมดอายุ: $endTxt',
            if (radius != null) 'รัศมี $radius m',
            if (lat != null && lon != null) 'Anchor: $lat, $lon',
            'Reverify: ${reverifyEnabled ? "ON" : "OFF"}',
          ].join(' · '),
        ),
      trailing: isTeacherView
            ? Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    // ✅ เอา notExpired ออก ถ้าอยากให้กดได้ตลอด (เหลือแค่เช็คว่ามี sessionId)
                    style: OutlinedButton.styleFrom(
                      backgroundColor: reverifyEnabled ? Colors.green : Colors.red, // สีพื้นตามสถานะ
                    foregroundColor: Colors.white, // สีตัวอักษร
                    side: BorderSide(
                    color: reverifyEnabled ? Colors.green : Colors.red, // สีขอบ
                    width: 1.5,
                      ),
                    ),
                    onPressed: (sessionId != null)
                        ? () async {
                            try {
                              final next = !reverifyEnabled;
                              final enabled =
                                  await SessionsService.toggleReverify(
                                    sessionId: sessionId!,
                                    enabled: next,
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      enabled
                                        
                                          ? 'เปิด reverify แล้ว'
                                          : 'ปิด reverify แล้ว',
                                      style: const TextStyle(color: Colors.black),
                                    ),
                                   behavior: SnackBarBehavior.floating, // ทำให้มันลอยสวยขึ้น (optional)
                                  ),
                                );
                              }
                              onChanged(); // 🔁 reload
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'สลับ reverify ไม่สำเร็จ: $e',
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                        : null, // ไม่มี sessionId -> ปิดปุ่ม
                    child: Text(
                      reverifyEnabled ? 'ปิด reverify' : 'เปิด reverify',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              )
            : Wrap(
                spacing: 8,
                children: [
                  // ปุ่มนักเรียน (เหมือนเดิม)
                  FilledButton(
                    onPressed: () async {
                      if (sessionId == null) return;
                      final ok = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentCheckinScreen(
                            classId: (data['class_id'] ?? '').toString(),
                          ),
                        ),
                      );
                      if (ok == true) onChanged();
                    },
                    child: const Text('เช็คชื่อ'),
                  ),
                  FutureBuilder<bool>(
                    future: _hasCheckedIn(sessionId),
                    builder: (context, snap) {
                      final hasCheckedIn = snap.data == true;

                      // ✅ เรียกเช็ค reverify เพิ่มอีกชั้น
                      return FutureBuilder<bool>(
                        future: sessionId != null
                            ? AttendanceService.getIsReverified(sessionId!)
                            : Future.value(false),
                        builder: (context, snap2) {
                          final isReverified = snap2.data == true;

                          // เดิม: เปิดปุ่มเมื่อ reverifyEnabled && notExpired && hasCheckedIn
                          // ใหม่: ถ้า isReverified แล้ว → ปิดปุ่มและเปลี่ยนข้อความ
                          final canReverifyNow =
                              reverifyEnabled &&
                              notExpired &&
                              hasCheckedIn &&
                              !isReverified;

                          return OutlinedButton.icon(
                            onPressed: (sessionId != null && canReverifyNow)
                                ? () async {
                                    try {
                                      final result = await Navigator.pushNamed(
                                        context,
                                        '/reverify-face',
                                      );
                                      if (result == null ||
                                          result is! String ||
                                          result.isEmpty)
                                        return;

                                      final pos =
                                          await LocationHelper.getCurrentPositionOrThrow();
                                      await AttendanceService.reVerify(
                                        sessionId: sessionId!,
                                        imagePath: result,
                                        latitude: pos.latitude,
                                        longitude: pos.longitude,
                                      );

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'ยืนยันตัวตนซ้ำสำเร็จ',
                                            ),
                                          ),
                                        );
                                      }
                                      onChanged();
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('เกิดข้อผิดพลาด: $e'),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                : null,
                            icon: const Icon(Icons.verified_user_outlined),
                            label: Text(
                              isReverified ? 'ยืนยันแล้ว' : 'ยืนยันซ้ำ',
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }

  // เรียกดูว่าผู้ใช้เคยเช็คชื่อ session นี้หรือยัง
  Future<bool> _hasCheckedIn(String? sessionId) async {
    if (sessionId == null) return false;
    try {
      final m = await AttendanceService.getMyStatusForSession(sessionId);
      // สมมติ backend คืน {"has_checked_in": true/false}
      return m['has_checked_in'] == true;
    } catch (_) {
      return false;
    }
  }
}
