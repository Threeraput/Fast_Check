import 'package:flutter/material.dart';
import 'package:frontend/screens/announcement/announcement_detail_screen.dart';
import 'package:intl/intl.dart';
import '../models/feed_item.dart';
import '../screens/attendance/student_checkin_screen.dart';
import 'package:frontend/services/sessions_service.dart';
import 'package:frontend/services/attendance_service.dart';
import 'package:frontend/utils/location_helper.dart';
import 'package:frontend/services/announcement_service.dart';

// ✅ การ์ด assignment
import 'package:frontend/widgets/assignment_card.dart';

class FeedList extends StatelessWidget {
  final List<FeedItem> items;
  final bool isTeacher;
  final String classId;
  final VoidCallback? onChanged; // callback ให้หน้าแม่รีเฟรช

  const FeedList({
    super.key,
    required this.items,
    required this.isTeacher,
    required this.classId,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Card(
        margin: const EdgeInsets.only(top: 8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No announcements yet.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // ✅ เรียงลำดับใหม่ให้ "โพสต์ล่าสุดอยู่บนสุด"
    final now = DateTime.now().toUtc();

    final sortedItems = List<FeedItem>.from(items)
      ..sort((a, b) {
        final aKind = a.extra['kind']?.toString();
        final bKind = b.extra['kind']?.toString();

        final aIsCheckin = a.type == FeedType.checkin || aKind == 'checkin';
        final bIsCheckin = b.type == FeedType.checkin || bKind == 'checkin';

        //  เช็คชื่อทั้งหมดอยู่บนสุด
        if (aIsCheckin != bIsCheckin) return aIsCheckin ? -1 : 1;

        //  ถ้าเป็นเช็คชื่อทั้งคู่ — ยังไม่หมดเวลาอยู่ก่อน
        if (aIsCheckin && bIsCheckin) {
          final aExpired = a.expiresAt != null && a.expiresAt!.isBefore(now);
          final bExpired = b.expiresAt != null && b.expiresAt!.isBefore(now);
          if (aExpired != bExpired) return aExpired ? 1 : -1;
        }

        //  ถ้าเป็นประกาศทั้งคู่ → pinned มาก่อน
        final aIsAnn = aKind == 'announcement';
        final bIsAnn = bKind == 'announcement';
        if (aIsAnn && bIsAnn) {
          final ap = a.extra['pinned'] == true;
          final bp = b.extra['pinned'] == true;
          if (ap != bp) return bp ? 1 : -1;
        }

        //  สุดท้ายเรียงตามเวลาใหม่สุด
        return b.postedAt.compareTo(a.postedAt);
      });

    //  วนลูปสร้างการ์ดตามลำดับใหม่
    return Column(
      children: sortedItems
          .map(
            (e) => _FeedCard(
              item: e,
              isTeacher: isTeacher,
              classId: classId,
              onChanged: onChanged,
            ),
          )
          .toList(),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final FeedItem item;
  final bool isTeacher;
  final String classId;
  final VoidCallback? onChanged;

  const _FeedCard({
    required this.item,
    required this.isTeacher,
    required this.classId,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final extra = Map<String, dynamic>.from(item.extra ?? {});

    final kind = (extra['kind']?.toString().toLowerCase() ?? '');

    // ✅ ถ้า backend ยังไม่ใส่ kind ให้ใช้ item.type เป็น fallback
    final effectiveKind = kind.isEmpty
        ? switch (item.type) {
            FeedType.assignment => 'assignment',
            FeedType.announcement => 'announcement',
            _ => '',
          }
        : kind;

    switch (effectiveKind) {
      case 'assignment':
        return AssignmentCard(
          classId: classId,
          extra: extra,
          postedAt: item.postedAt,
          isTeacher: isTeacher,
          onChanged: onChanged,
        );
      // ✅ สามารถขยายในอนาคต เช่น case 'announcement', 'quiz' ได้
      case 'announcement':
        // 🔹 strip prefix "ann:" ออก ถ้ามี
        final rawId = item.id ?? '';
        final annId = rawId.startsWith('ann:') ? rawId.split(':').last : rawId;

        return _AnnouncementCard(
          title: item.title.isNotEmpty ? item.title : 'ประกาศ',
          body: (extra['body'] ?? '') as String,
          postedAt: item.postedAt,
          pinned: extra['pinned'] == true,
          author: (extra['author_name'] ?? '') as String,
          expiresAt: item.expiresAt,
          announcementId: annId, //  ส่ง UUID แบบเพียว ๆ
          isTeacher: isTeacher,
          onChanged: onChanged,
        );

      default:
        // ✅ ค่าเริ่มต้น: การ์ดเช็คชื่อ (เดิม)
        return _buildCheckinCard(context);
    }
  }

  /// ===== การ์ดเช็คชื่อ (เดิม) =====
  Widget _buildCheckinCard(BuildContext context) {
    final dfTime = DateFormat('d MMM, HH:mm');
    final expText = item.expiresAt != null
        ? 'หมดอายุ: ${dfTime.format(item.expiresAt!.toLocal())}'
        : 'กำลังเปิดอยู่';

    final radius = item.extra['radius']?.toString();
    final lat = item.extra['anchor_lat']?.toString();
    final lon = item.extra['anchor_lon']?.toString();

    final sessionId = item.extra['session_id']?.toString();
    final reverifyEnabled = item.extra['reverify_enabled'] == true;

    final nowUtc = DateTime.now().toUtc();
    final notExpired =
        item.expiresAt != null && item.expiresAt!.toUtc().isAfter(nowUtc);

    // ไม่มี sessionId → แสดงการ์ดพื้นฐาน
    if (sessionId == null || sessionId.isEmpty) {
      return _baseCard(
        context: context,
        title: 'เช็คชื่อ',
        expText: expText,
        radius: radius,
        lat: lat,
        lon: lon,
        reverifyEnabled: reverifyEnabled,
        trailing: _studentOrTeacherButtons(
          context: context,
          sessionId: null,
          hasCheckedIn: false,
          canReverify: false,
        ),
      );
    }

    // มี sessionId → โหลดสถานะนักเรียน
    return FutureBuilder<Map<String, dynamic>>(
      future: AttendanceService.getMyStatusForSession(sessionId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(
              color: Colors.blue,
            )),
          );
        }

        final status = snap.data ?? {};
        final hasCheckedIn = status['has_checked_in'] == true;
        final canReverifyFlag = status['can_reverify'] == true;
        final canReverify = canReverifyFlag || (reverifyEnabled && notExpired);

        return _baseCard(
          context: context,
          title: 'เช็คชื่อ',
          expText: expText,
          radius: radius,
          lat: lat,
          lon: lon,
          reverifyEnabled: reverifyEnabled,
          trailing: _studentOrTeacherButtons(
            context: context,
            sessionId: sessionId,
            hasCheckedIn: hasCheckedIn,
            canReverify: canReverify,
          ),
        );
      },
    );
  }

  /// ===== การ์ดพื้นฐาน =====
  Widget _baseCard({
    required BuildContext context,
    required String title,
    required String expText,
    required String? radius,
    required String? lat,
    required String? lon,
    required bool reverifyEnabled,
    required Widget trailing,
  }) {
    final dfTime = DateFormat('d MMM, HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderRow(
              icon: Icons.access_time,
              iconColor: Colors.blueAccent,
              title: title,
              dateText: dfTime.format(item.postedAt.toLocal()),
            ),
            const SizedBox(height: 8),

            // RichText สำหรับ expText และ radius
            RichText(
              text: TextSpan(
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: 14),
                children: [
                  TextSpan(text: '$expText · '),
                  const TextSpan(
                    text: 'รัศมี ',
                    style: TextStyle(fontSize: 15),
                  ),
                  TextSpan(
                    text: '${radius ?? '-'} m',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 3),

            // แสดง Anchor
            if (lat != null && lon != null)
              Text(
                'Anchor: $lat, $lon',
                style: Theme.of(context).textTheme.bodySmall,
              ),

            const SizedBox(height: 3),

            // แสดง Reverify (ON/OFF)
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodySmall,
                children: [
                  const TextSpan(text: 'Reverify: '),
                  TextSpan(
                    text: reverifyEnabled ? 'ON' : 'OFF',
                    style: TextStyle(
                      color: reverifyEnabled ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Row(children: [trailing]),
          ],
        ),
      ),
    );
  }

  /// ===== ปุ่มของนักเรียน / ครู =====
  Widget _studentOrTeacherButtons({
    required BuildContext context,
    required String? sessionId,
    required bool hasCheckedIn,
    required bool canReverify,
  }) {
    if (isTeacher) {
      // ปุ่มสำหรับครู: toggle reverify
      final isEnabled = item.extra['reverify_enabled'] == true;

      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white, // สีตัวอักษร
          backgroundColor: isEnabled
              ? Colors.green
              : Colors.red, // ✅ เปิด=เขียว, ปิด=แดง
          side: BorderSide(
            color: isEnabled ? Colors.green : Colors.red,
          ), // เส้นขอบตามสี
        ),
        onPressed: (sessionId == null)
            ? null
            : () async {
                try {
                  final next = !isEnabled; // toggle สถานะใหม่
                  final newEnabled = await SessionsService.toggleReverify(
                    sessionId: sessionId,
                    enabled: next,
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          newEnabled
                              ? 'เปิด reverify แล้ว'
                              : 'ปิด reverify แล้ว',
                          
                        ),
                        // behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }

                  onChanged?.call(); // reload UI
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('สลับ reverify ไม่สำเร็จ: $e')),
                    );
                  }
                }
              },
        child: Text(
          isEnabled ? 'ปิด reverify' : 'เปิด reverify',
          style: const TextStyle(
            color: Colors.white,
          ), // ✅ ตัวอักษรสีขาวบนปุ่มสีเข้ม
        ),
      );
    }

    if (sessionId == null) return const SizedBox.shrink();

    final buttons = <Widget>[];

    // ปุ่มเช็คชื่อ
    if (!hasCheckedIn) {
      buttons.add(
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.blue),
          onPressed: () async {
            final ok = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StudentCheckinScreen(classId: classId),
              ),
            );
            if (ok == true) onChanged?.call();
          },
          icon: const Icon(Icons.verified_user),
          label: const Text('เช็คชื่อ'),
        ),
      );
      buttons.add(const SizedBox(width: 12));
    }

    // ปุ่มยืนยันซ้ำ
    buttons.add(
      FutureBuilder<bool>(
        future: AttendanceService.getIsReverified(sessionId),
        builder: (context, snap) {
          final isReverified = snap.data == true;
          final enableReverify = hasCheckedIn && canReverify && !isReverified;

          return OutlinedButton.icon(
            onPressed: enableReverify
                ? () async {
                    try {
                      final result = await Navigator.pushNamed(
                        context,
                        '/reverify-face',
                      );
                      if (result == null || result is! String || result.isEmpty)
                        return;

                      final pos =
                          await LocationHelper.getCurrentPositionOrThrow();
                      await AttendanceService.reVerify(
                        sessionId: sessionId,
                        imagePath: result,
                        latitude: pos.latitude,
                        longitude: pos.longitude,
                      );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ยืนยันตัวตนซ้ำสำเร็จ')),
                        );
                      }
                      onChanged?.call();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
                        );
                      }
                    }
                  }
                : null,
            label: Text(
              style: TextStyle(color: Colors.black),
              isReverified ? 'ยืนยันแล้ว' : 'ยืนยันซ้ำ',
            ),
          );
        },
      ),
    );

    return Row(children: buttons);
  }
}

class _HeaderRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String dateText;
  final Color iconColor;

  const _HeaderRow({
    required this.icon,
    required this.title,
    required this.dateText,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.red,
          child: Icon(icon, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        Text(dateText, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final String title;
  final String body;
  final DateTime postedAt;
  final DateTime? expiresAt;
  final bool pinned;
  final String author;
  final String announcementId;
  final bool isTeacher;
  final VoidCallback? onChanged;

  const _AnnouncementCard({
    required this.title,
    required this.body,
    required this.postedAt,
    required this.pinned,
    required this.author,
    required this.announcementId,
    required this.isTeacher,
    this.expiresAt,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM, HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // 👈 3. พอกดแล้วให้เด้งไปหน้า AnnouncementDetailScreen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AnnouncementDetailScreen(
                announcementId: announcementId, // ต้องส่ง ID ประกาศไป
                title: title, // ส่งชื่อเรื่อง
                body: body, // ส่งเนื้อหา
                postedAt: postedAt, // ส่งเวลา
              ),
            ),
          ).then((_) {
            // ถ้ารีเฟรชได้ ให้เรียกตรงนี้ครับ
            onChanged?.call(); 
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderRow(
                icon: pinned ? Icons.push_pin : Icons.campaign_outlined,
                iconColor: pinned ? Colors.red : Colors.blueGrey,
                title: pinned ? '[ปักหมุด] $title' : title,
                dateText: df.format(postedAt.toLocal()),
              ),
              if (author.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'โดย: $author',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (body.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(body),
                ),
              if (expiresAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'หมดอายุ: ${df.format(expiresAt!.toLocal())}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
        
              // 🔹 เพิ่มเมนู 3 จุด สำหรับครูเท่านั้น
              if (isTeacher)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          // ---------- ฟังก์ชันแก้ไข ----------
                          final titleCtrl = TextEditingController(text: title);
                          final bodyCtrl = TextEditingController(text: body);
        
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('แก้ไขประกาศ'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    controller: titleCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'หัวข้อ',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: bodyCtrl,
                                    maxLines: 4,
                                    decoration: const InputDecoration(
                                      labelText: 'เนื้อหา',
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text(
                                    'ยกเลิก',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('บันทึก'),
                                ),
                              ],
                            ),
                          );
        
                          if (ok == true) {
                            try {
                              await AnnouncementService.update(
                                announcementId: announcementId,
                                title: titleCtrl.text,
                                body: bodyCtrl.text,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('อัปเดตประกาศสำเร็จ'),
                                  ),
                                );
                              }
                              onChanged?.call();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('อัปเดตไม่สำเร็จ: $e')),
                                );
                              }
                            }
                          }
                        } else if (value == 'delete') {
                          // ---------- ฟังก์ชันลบ ----------
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('ยืนยันการลบ'),
                              content: const Text(
                                'คุณแน่ใจหรือไม่ว่าจะลบประกาศนี้?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text(
                                    'ยกเลิก',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    'ลบ',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          );
        
                          if (ok == true) {
                            try {
                              await AnnouncementService.delete(announcementId);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('ลบประกาศสำเร็จ')),
                                );
                              }
                              onChanged?.call();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('ลบไม่สำเร็จ: $e')),
                                );
                              }
                            }
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.blueAccent),
                              SizedBox(width: 8),
                              Text('แก้ไข'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('ลบ'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
