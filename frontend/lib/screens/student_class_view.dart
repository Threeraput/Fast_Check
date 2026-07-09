import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/models/feed_item.dart';
import 'package:frontend/services/feed_service.dart';
import 'package:frontend/widgets/feed_cards.dart';
import 'package:frontend/widgets/active_sessions_banner.dart';
import 'package:frontend/widgets/glass_card.dart';
import 'package:frontend/utils/location_helper.dart';
import 'package:intl/intl.dart';
import 'package:frontend/services/attendance_service.dart';
import 'package:frontend/screens/attendance/student_checkin_screen.dart';
import 'package:frontend/screens/classroom/chat_screen.dart';
import 'package:frontend/screens/classroom/classroom_home_screen.dart';
import 'package:frontend/screens/attendance/student_report_tab.dart';
import 'package:frontend/utils/app_theme.dart';

// Added for People tab (fetching class members)
import 'package:frontend/services/class_service.dart';
import 'package:frontend/models/classroom.dart';
import 'package:frontend/models/users.dart';

// ใช้สำหรับแปลง avatarUrl ให้เป็น URL เต็ม
import 'package:frontend/services/user_service.dart';

class StudentClassView extends StatefulWidget {
  final String classId;
  final String className;
  final String teacherName;
  final String? description;

  const StudentClassView({
    super.key,
    required this.classId,
    required this.className,
    required this.teacherName,
    this.description,
  });

  @override
  State<StudentClassView> createState() => _StudentClassViewState();
}

class _StudentClassViewState extends State<StudentClassView> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD6E4FF)),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.className, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              'Class ID: ${widget.classId.substring(0, 8)}...',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    const items = [
      (Icons.forum_outlined, 'Stream'),
      (Icons.assignment_outlined, 'Classwork'),
      (Icons.bar_chart_outlined, 'Report'),
      (Icons.people_outline, 'People'),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
        child: GlassCard(
          accent: const Color(0xFF0EA5A4),
          radius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = _currentIndex == i;
              final (icon, label) = items[i];
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Material(
                    color: selected
                        ? const Color(0xFF0EA5A4).withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _currentIndex = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 20,
                              color: selected
                                  ? const Color(0xFF0F766E)
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: selected
                                    ? const Color(0xFF0F766E)
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _StudentStreamTab(
          classId: widget.classId,
          className: widget.className,
          teacherName: widget.teacherName,
          description: widget.description,
        );
      case 1:
        // เปลี่ยนจาก const _StudentClassworkTab() -> ส่ง classId และ isTeacher=false
        return StudentClassworkTab(classId: widget.classId);
      case 2:
        return StudentReportTab(classId: widget.classId);
      case 3:
        // People tab now loads real members from API
        return _StudentPeopleTab(
          classId: widget.classId,
          fallbackTeacherName: widget.teacherName,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/// ======================
/// 🔹 STREAM TAB (ฟีดเช็คชื่อ/ประกาศ)
/// ======================
class _StudentStreamTab extends StatefulWidget {
  final String classId;
  final String className;
  final String teacherName;
  final String? description;
  const _StudentStreamTab({
    required this.classId,
    required this.className,
    required this.teacherName,
    this.description,
  });

  @override
  State<_StudentStreamTab> createState() => _StudentStreamTabState();
}

class _StudentStreamTabState extends State<_StudentStreamTab> {
  late Future<List<FeedItem>> _futureFeed;
  static const Color _studentTone = Color(0xFF0EA5A4);

  @override
  void initState() {
    super.initState();
    _futureFeed = FeedService.getClassFeedForStudentWithAssignments(
      widget.classId,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _futureFeed = FeedService.getClassFeedForStudentWithAssignments(
        widget.classId,
      );
    });
  }

  Widget _buildRoleDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _studentTone.withValues(alpha: 0.0),
                  _studentTone.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _studentTone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _studentTone.withValues(alpha: 0.35)),
          ),
          child: const Text(
            'Student Stream',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color.fromARGB(255, 15, 1, 1),
              letterSpacing: 0.25,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _studentTone.withValues(alpha: 0.72),
                  _studentTone.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _studentTone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _studentTone.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color.fromARGB(255, 15, 1, 1),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final className = widget.className;
    final teacherName = widget.teacherName;
    final classId = widget.classId;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildRoleDivider(),
          const SizedBox(height: 12),
          // Header การ์ดห้องเรียน
          GlassCard(
            accent: getClassColor(className),
            radius: 16,
            padding: const EdgeInsets.all(0),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        className,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0xFF0F2547),
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0EA5A4).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFA6E3DE)),
                        ),
                        child: Text(
                          'Class: ${classId.substring(0, 8)}...',
                          style: const TextStyle(
                            color: Color(0xFF0F766E),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Teacher: $teacherName',
                        style: const TextStyle(
                          color: Color(0xFF2E536F),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.white),
                    tooltip: 'คำอธิบายคลาส',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 8),
                              Text('คำอธิบายคลาส'),
                            ],
                          ),
                          content: Text(
                            (widget.description != null &&
                                    widget.description!.isNotEmpty)
                                ? widget.description!
                                : 'ยังไม่มีคำอธิบายสำหรับคลาสนี้',
                            style: const TextStyle(fontSize: 13),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('ปิด'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // แบนเนอร์เช็คชื่อที่กำลังเปิด (นักเรียน)
          // ActiveSessionsBanner(classId: classId, isTeacherView: false),
          const SizedBox(height: 16),
          _sectionTitle('Announcements'),
          const SizedBox(height: 6),

          // ฟีด Stream จริง (feed_cards)
          FutureBuilder<List<FeedItem>>(
            future: _futureFeed,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }
              if (snap.hasError) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('โหลดฟีดไม่สำเร็จ: ${snap.error}'),
                  ),
                );
              }
              final feed = snap.data ?? const <FeedItem>[];
              if (feed.isEmpty) {
                return AppCard(
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    'ยังไม่มีประกาศหรือกิจกรรมในคลาสนี้',
                    style: TextStyle(fontSize: 13),
                  ),
                );
              }
              return FeedList(
                items: feed,
                isTeacher: false,
                classId: classId,
                onChanged: _refresh,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// ======================
/// 🔹 CLASSWORK TAB (งาน/Assignment)
/// ======================
class StudentClassworkTab extends StatefulWidget {
  final String classId;
  final bool isTeacher; // เผื่อไว้ ถ้าอยาก reuse โค้ด
  const StudentClassworkTab({
    super.key,
    required this.classId,
    this.isTeacher = false,
  });

  @override
  State<StudentClassworkTab> createState() => _StudentClassworkTabState();
}

class _StudentClassworkTabState extends State<StudentClassworkTab> {
  late Future<List<FeedItem>> _future;
  static const Color _studentTone = Color(0xFF0EA5A4);

  Widget _buildRoleDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _studentTone.withValues(alpha: 0.0),
                  _studentTone.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _studentTone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: _studentTone.withValues(alpha: 0.35)),
          ),
          child: const Text(
            'Student Classwork',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color.fromARGB(255, 15, 1, 1),
              letterSpacing: 0.25,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _studentTone.withValues(alpha: 0.72),
                  _studentTone.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    // โหลดเฉพาะ feed ที่เหมาะกับนักเรียน (รวม assignments)
    _future = FeedService.getClassFeedForStudentWithAssignments(widget.classId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = FeedService.getClassFeedForStudentWithAssignments(
        widget.classId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildRoleDivider(),
          const SizedBox(height: 12),
          Text(
            'Classwork',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 6),
          FutureBuilder<List<FeedItem>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }
              if (snap.hasError) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('โหลดงานไม่สำเร็จ: ${snap.error}'),
                  ),
                );
              }
              final items = (snap.data ?? const <FeedItem>[])
                  // แสดงเฉพาะการ์ด assignment ในแท็บ Classwork
                  .where((f) {
                    final kind = f.extra['kind']?.toString().toLowerCase();
                    return kind == 'assignment' || f.type == FeedType.assignment;
                  })
                  .toList();

              if (items.isEmpty) {
                return AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: const [
                      Icon(Icons.assignment_late_outlined, color: _studentTone, size: 26),
                      SizedBox(height: 8),
                      Text('ยังไม่มีงานในชั้นเรียนนี้', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                );
              }

              return FeedList(
                items: items,
                isTeacher: widget.isTeacher, // false สำหรับนักเรียน
                classId: widget.classId,
                onChanged: _refresh,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// ======================
/// 🔹 REPORT TAB
/// ======================
class _StudentReportTab extends StatelessWidget {
  const _StudentReportTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Report — สถิติการเข้าเรียนของฉันจะอยู่ที่นี่',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// ======================
/// 🔹 PEOPLE TAB (Student)
/// ======================
class _StudentPeopleTab extends StatefulWidget {
  final String classId;
  final String fallbackTeacherName;
  const _StudentPeopleTab({
    required this.classId,
    required this.fallbackTeacherName,
  });

  @override
  State<_StudentPeopleTab> createState() => _StudentPeopleTabState();
}

class _StudentPeopleTabState extends State<_StudentPeopleTab> {
  static const Color _teacherTone = Color(0xFF2563EB);
  static const Color _studentTone = Color(0xFF0EA5A4);
  bool _loading = true;
  bool _error = false;
  String _errorMsg = '';
  Classroom? _classroom;

  @override
  void initState() {
    super.initState();
    _loadClassroom();
  }

  Future<void> _loadClassroom() async {
    setState(() {
      _loading = true;
      _error = false;
      _errorMsg = '';
    });
    try {
      final cls = await ClassService.getClassroomMembers(widget.classId);
      setState(() {
        _classroom = cls;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = true;
        _errorMsg = e.toString();
        _loading = false;
      });
    }
  }

  String _displayUserName(User u) => u.displayName;

  CircleAvatar _avatarFor(User u, {double radius = 20}) {
    final url = UserService.absoluteAvatarUrl(u.avatarUrl);
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(url));
    }
    final initial =
        (u.username.isNotEmpty
                ? u.username[0]
                : (u.email?.isNotEmpty == true ? u.email![0] : '?'))
            .toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade300,
      child: Text(initial, style: const TextStyle(color: Colors.black87)),
    );
  }

  Widget _buildRoleDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _studentTone.withValues(alpha: 0.0),
                  _studentTone.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _studentTone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _studentTone.withValues(alpha: 0.35)),
          ),
          child: const Text(
            'Student People View',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color.fromARGB(255, 15, 1, 1),
              letterSpacing: 0.25,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _studentTone.withValues(alpha: 0.72),
                  _studentTone.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, Color tone) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: tone,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));

    if (_error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 8),
              Text(
                'โหลดรายชื่อสมาชิกไม่สำเร็จ\n$_errorMsg',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _loadClassroom,
                icon: const Icon(Icons.refresh),
                label: const Text('ลองใหม่'),
              ),
            ],
          ),
        ),
      );
    }

    final cls = _classroom;
    final students = cls?.students ?? const <User>[];

    return RefreshIndicator(
      onRefresh: _loadClassroom,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildRoleDivider(),
          const SizedBox(height: 12),
          _sectionTitle('Teacher', _teacherTone),
          const SizedBox(height: 6),
          GlassCard(
            accent: _teacherTone,
            radius: 14,
            padding: const EdgeInsets.all(4),
            child: ListTile(
              contentPadding: const EdgeInsets.only(left: 0, right: 8),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 4, height: 44, color: _teacherTone),
                  const SizedBox(width: 10),
                  cls?.teacher != null
                      ? _avatarFor(cls!.teacher!, radius: 22)
                      : CircleAvatar(
                          radius: 22,
                          child: Text(
                            widget.fallbackTeacherName.isNotEmpty
                                ? widget.fallbackTeacherName[0].toUpperCase()
                                : '?',
                          ),
                        ),
                ],
              ),
              title: Text(
                cls?.teacher != null
                    ? _displayUserName(cls!.teacher!)
                    : widget.fallbackTeacherName,
              ),
              subtitle: Text(cls?.teacher?.email ?? ''),
              trailing: cls?.teacher != null
                  ? IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                      tooltip: 'Chat teacher',
                      onPressed: () {
                        if (cls?.teacher != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                classId: widget.classId,
                                otherUser: cls!.teacher!,
                              ),
                            ),
                          );
                        }
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          _sectionTitle('Students (${students.length})', _studentTone),
          const SizedBox(height: 6),
          if (students.isEmpty)
            const GlassCard(
              accent: _studentTone,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('ยังไม่มีนักเรียน'),
              ),
            )
          else
            ...students.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GlassCard(
                  accent: _studentTone,
                  radius: 12,
                  padding: const EdgeInsets.all(4),
                  child: ListTile(
                  contentPadding: const EdgeInsets.only(left: 0, right: 12),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 4, height: 40, color: _studentTone),
                      const SizedBox(width: 10),
                      _avatarFor(s),
                    ],
                  ),
                  dense: true,
                  title: Text(_displayUserName(s), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(s.email ?? '', style: const TextStyle(fontSize: 12)),
                ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
