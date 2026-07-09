import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:frontend/screens/announcement/announcement_detail_screen.dart';
import 'package:frontend/screens/announcement/edit_announcement_screen.dart';
import 'package:intl/intl.dart';
import '../models/feed_item.dart';
import '../screens/attendance/student_checkin_screen.dart';
import 'package:frontend/services/attendance_service.dart';
import 'package:frontend/services/announcement_service.dart';
import 'package:frontend/screens/attendance/teacher_live_attendance_screen.dart';
import 'package:frontend/utils/app_theme.dart';

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
      return AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.inbox_outlined, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No announcements yet.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
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

        // เช็คชื่อทั้งหมดอยู่บนสุด
        if (aIsCheckin != bIsCheckin) return aIsCheckin ? -1 : 1;

        // ถ้าเป็นเช็คชื่อทั้งคู่ — ยังไม่หมดเวลาอยู่ก่อน
        if (aIsCheckin && bIsCheckin) {
          final aExpired = a.expiresAt != null && a.expiresAt!.isBefore(now);
          final bExpired = b.expiresAt != null && b.expiresAt!.isBefore(now);
          if (aExpired != bExpired) return aExpired ? 1 : -1;
        }

        // ถ้าเป็นประกาศทั้งคู่ → pinned มาก่อน
        final aIsAnn = aKind == 'announcement';
        final bIsAnn = bKind == 'announcement';
        if (aIsAnn && bIsAnn) {
          final ap = a.extra['pinned'] == true;
          final bp = b.extra['pinned'] == true;
          if (ap != bp) return bp ? 1 : -1;
        }

        // สุดท้ายเรียงตามเวลาใหม่สุด
        return b.postedAt.compareTo(a.postedAt);
      });

    // วนลูปสร้างการ์ดตามลำดับใหม่
    return Column(
      children: sortedItems.asMap().entries.map((entry) {
        final i = entry.key;
        final e = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _AnimatedFeedItem(
            index: i,
            child: _FeedCard(
              item: e,
              isTeacher: isTeacher,
              classId: classId,
              onChanged: onChanged,
            ),
          ),
        );
      }).toList(),
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
    final extra = Map<String, dynamic>.from(item.extra);
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
      case 'announcement':
        // strip prefix "ann:" ออก ถ้ามี
        final rawId = item.id;
        final annId = rawId.startsWith('ann:') ? rawId.split(':').last : rawId;

        return _AnnouncementCard(
          title: item.title.isNotEmpty ? item.title : 'ประกาศ',
          body: (extra['body'] ?? '') as String,
          postedAt: item.postedAt,
          pinned: extra['pinned'] == true,
          author: (extra['author_name'] ?? '') as String,
          expiresAt: item.expiresAt,
          announcementId: annId, // ส่ง UUID แบบเพียว ๆ
          attachments: extra['attachments'] as List?, 
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

    final lateStr = item.extra['late_cutoff_time']?.toString();
    final late = lateStr != null ? DateTime.tryParse(lateStr) : null;
    final lateTxt = late != null
        ? DateFormat('HH:mm').format(late.toLocal())
        : null;

    final radius = item.extra['radius']?.toString();
    final lat = item.extra['anchor_lat']?.toString();
    final lon = item.extra['anchor_lon']?.toString();

    final sessionId = item.extra['session_id']?.toString();

    if (sessionId == null || sessionId.isEmpty) {
      return _baseCard(
        context: context,
        title: 'เช็คชื่อ',
        expText: expText,
        lateTxt: lateTxt,
        radius: radius,
        lat: isTeacher ? lat : null,
        lon: isTeacher ? lon : null,
        trailing: _studentOrTeacherButtons(
          context: context,
          sessionId: null,
          hasCheckedIn: false,
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: AttendanceService.getMyStatusForSession(sessionId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(color: Colors.blue)),
          );
        }

        final status = snap.data ?? {};
        final hasCheckedIn = status['has_checked_in'] == true;

        return _baseCard(
          context: context,
          title: 'เช็คชื่อ',
          expText: expText,
          lateTxt: lateTxt,
          radius: radius,
          lat: isTeacher ? lat : null,
          lon: isTeacher ? lon : null,
          trailing: _studentOrTeacherButtons(
            context: context,
            sessionId: sessionId,
            hasCheckedIn: hasCheckedIn,
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
    required String? lateTxt,
    required String? radius,
    required String? lat,
    required String? lon,
    required Widget trailing,
  }) {
    final dfTime = DateFormat('d MMM, HH:mm');

    return _GlassFeedShell(
      accent: Colors.blueAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderRow(
            icon: Icons.access_time,
            iconColor: Colors.blueAccent,
            title: title,
            dateText: dfTime.format(item.postedAt.toLocal()),
            label: 'CHECK-IN',
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: const Color(0xFF1A365D),
                fontWeight: FontWeight.w600,
              ),
              children: [
                TextSpan(text: '$expText · '),
                const TextSpan(
                  text: 'รัศมี ',
                  style: TextStyle(fontSize: 12),
                ),
                TextSpan(
                  text: '${radius ?? '-'} m',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (lateTxt != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                'สายหลังจาก: $lateTxt น.',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF0B3A7A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 3),
          if (lat != null && lon != null)
            Text(
              'Anchor: $lat, $lon',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF2D4A73)),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: trailing,
          ),
        ],
      ),
    );
  }

  /// ===== ปุ่มของนักเรียน / ครู =====
  Widget _studentOrTeacherButtons({
    required BuildContext context,
    required String? sessionId,
    required bool hasCheckedIn,
  }) {
    if (isTeacher) {
      if (sessionId == null || sessionId.isEmpty) {
        return const SizedBox.shrink();
      }

      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          minimumSize: const Size(0, 38),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TeacherLiveAttendanceScreen(
                sessionId: sessionId,
                classId: classId,
              ),
            ),
          );
        },
        icon: const Icon(Icons.visibility_outlined),
        label: const Text('ดูคนเช็คชื่อปัจจุบัน'),
      );
    }

    if (sessionId == null) return const SizedBox.shrink();

    final buttons = <Widget>[];

    if (!hasCheckedIn) {
      buttons.add(
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size(0, 36),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
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

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: buttons,
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? dateText; 
  final Color iconColor;
  final String? label;

  const _HeaderRow({
    required this.icon,
    required this.title,
    this.dateText, 
    required this.iconColor,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                iconColor.withValues(alpha: 0.95),
                iconColor.withValues(alpha: 0.65),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: iconColor.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.75),
              width: 1,
            ),
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label != null && label!.isNotEmpty)
                Text(
                  label!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.05,
                    color: iconColor.withValues(alpha: 0.95),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 32.0), // กันระยะไว้สำหรับปุ่มเมนูขวาบน
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: const Color(0xFF0F2547),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (dateText != null && dateText!.isNotEmpty)
          Text(
            dateText!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: const Color(0xFF38567D),
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _GlassFeedShell extends StatelessWidget {
  final Color accent;
  final Widget child;
  final VoidCallback? onTap;
  final Widget? overlayAction;

  const _GlassFeedShell({
    required this.accent,
    required this.child,
    this.onTap,
    this.overlayAction,
  });

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: child,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.85, -0.75),
                  radius: 1.45,
                  colors: [
                    accent.withValues(alpha: 0.28),
                    const Color(0xFF4A90E2).withValues(alpha: 0.14),
                    const Color(0xFF7C8CFF).withValues(alpha: 0.10),
                    Colors.white.withValues(alpha: 0.08),
                  ],
                  stops: const [0.0, 0.33, 0.67, 1.0],
                ),
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.75),
                  width: 1.05,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF13325B).withValues(alpha: 0.14),
                    blurRadius: 22,
                    spreadRadius: -6,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: -30,
                    top: -34,
                    child: IgnorePointer(
                      child: Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              accent.withValues(alpha: 0.26),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.90),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            accent.withValues(alpha: 0.95),
                            accent.withValues(alpha: 0.45),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 4),
                      Expanded(
                        child: onTap == null
                            ? body
                            : Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: onTap,
                                  splashColor: accent.withValues(alpha: 0.14),
                                  highlightColor: Colors.white.withValues(
                                    alpha: 0.08,
                                  ),
                                  child: body,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (overlayAction != null)
            Positioned(
              top: 2,
              right: 2,
              child: overlayAction!,
            ),
        ],
      ),
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
  final List? attachments; 
  final bool isTeacher;
  final VoidCallback? onChanged;

  const _AnnouncementCard({
    required this.title,
    required this.body,
    required this.postedAt,
    required this.pinned,
    required this.author,
    required this.announcementId,
    this.attachments, 
    required this.isTeacher,
    this.expiresAt,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM, HH:mm');

    return _GlassFeedShell(
      accent: pinned ? Colors.red.shade600 : Colors.blue.shade600,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnnouncementDetailScreen(
              announcementId: announcementId, 
              title: title, 
              body: body, 
              postedAt: postedAt, 
              pinned: pinned,
              attachments: attachments, 
            ),
          ),
        ).then((_) {
          onChanged?.call();
        });
      },      
      // ✨ ใช้ PopupMenu ธรรมดาตามเดิม แต่แต่งสไตล์กล่องให้มีความเป็นกระจกใสพรีเมียมคุมโทน
      overlayAction: isTeacher
          ? PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.more_vert,
                color: (pinned ? Colors.red.shade600 : Colors.blue.shade700).withValues(alpha: 0.85),
                size: 20,
              ),
              // 🔮 แต่งหน้าตาตัวเลือกให้เป็นกระจกโปร่งแสง (Translucent Glass Popup)
              color: Colors.white.withValues(alpha: 0.78), 
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.65),
                  width: 1.2,
                ),
              ),
              itemBuilder: (_) => [
                PopupMenuItem<String>(
                  value: 'edit',
                  height: 38,
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 17, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      'แก้ไข', 
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F2547)),
                    ),
                  ]),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  height: 38,
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 17, color: const Color(0xFFE11D48)),
                    const SizedBox(width: 8),
                    const Text(
                      'ลบ', 
                      style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ]),
                ),
              ],
              onSelected: (value) async {
                if (value == 'edit') {
                  final ok = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditAnnouncementScreen(
                        announcementId: announcementId,
                        title: title,
                        body: body,
                      ),
                    ),
                  );
                  if (ok == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('อัปเดตประกาศสำเร็จ')),
                    );
                    onChanged?.call();
                  }
                } else if (value == 'delete') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('ยืนยันการลบ'),
                      content: const Text('คุณแน่ใจหรือไม่ว่าจะลบประกาศนี้?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('ยกเลิก'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('ลบ'),
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
            )
          : null,      
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderRow(
            icon: pinned ? Icons.push_pin : Icons.campaign_outlined,
            iconColor: pinned ? Colors.red.shade700 : Colors.blue.shade700,
            title: pinned ? '[ปักหมุด] $title' : title,
            dateText: null, // 👈 ซ่อนวันที่ด้านบน เพื่อเลี่ยงการทับซ้อนกับปุ่ม 3 จุด
            label: pinned ? 'PINNED ANNOUNCEMENT' : 'ANNOUNCEMENT',
          ),
          if (author.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'โดย: $author',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: const Color(0xFF28466D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                body,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Color(0xFF0E2B50),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (expiresAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'หมดอายุ: ${df.format(expiresAt!.toLocal())}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF38567D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          
          // 👈 ย้ายเวลาโพสต์มาอยู่ขอบล่างขวาตรงนี้อย่างถาวร ปลอดภัยจากการทับกัน 100%
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'โพสต์เมื่อ ${df.format(postedAt.toLocal())}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: const Color(0xFF38567D).withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedFeedItem extends StatelessWidget {
  final int index;
  final Widget child;

  const _AnimatedFeedItem({
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final delay = (index.clamp(0, 8)) * 40;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, t, c) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}