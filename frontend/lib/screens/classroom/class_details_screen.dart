import 'package:flutter/material.dart';
import 'package:frontend/models/classroom.dart';
import 'package:frontend/models/users.dart';
import 'package:frontend/screens/attendance/class_report_tab.dart';
import 'package:frontend/screens/classroom/classroom_home_screen.dart';
import 'package:frontend/screens/announcement/create_announcement_screen.dart';
import 'package:frontend/screens/attendance/teacher_open_checkin_sheet.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/class_service.dart';
import 'package:frontend/services/feed_service.dart';
import 'package:frontend/widgets/feed_cards.dart';
import 'package:frontend/models/feed_item.dart';
import 'package:intl/intl.dart';

// ✅ ใช้สำหรับ URL รูปโปรไฟล์
import 'package:frontend/services/user_service.dart';

class ClassDetailsScreen extends StatefulWidget {
  final String classId;
  final String? className;

  const ClassDetailsScreen({super.key, required this.classId, this.className});

  @override
  State<ClassDetailsScreen> createState() => _ClassDetailsScreenState();
}

class _ClassDetailsScreenState extends State<ClassDetailsScreen> {
  final GlobalKey<_StreamTabState> _streamKey = GlobalKey<_StreamTabState>();
  int _currentIndex = 0;
  bool _loading = true;
  bool _error = false;
  bool _isTeacher = false;

  Classroom? _classroom;
  User? _me;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final me = await AuthService.getCurrentUserFromLocal();
      final isTeacher =
          me?.roles.contains('teacher') == true ||
          me?.roles.contains('admin') == true;

      Classroom? cls;
      if (isTeacher) {
        // ครูใช้รายละเอียดคลาส (ควรรวม teacher + students พร้อม avatar_url)
        cls = await ClassService.getClassroomDetails(widget.classId);
      }

      setState(() {
        _me = me;
        _isTeacher = isTeacher;
        _classroom = cls;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _openCreateAnnouncement() async {
    final ok = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateAnnouncementScreen(
          classId: widget.classId,
          className: _classroom?.name ?? widget.className ?? 'Class',
        ),
      ),
    );

    //  ถ้าโพสต์สำเร็จ แค่รีเฟรชฟีดพอ
    if (ok == true && mounted) {
      _streamKey.currentState?.refreshFeed();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('สร้างประกาศสำเร็จ')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _classroom?.name ?? widget.className ?? 'Classroom';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color.fromARGB(255, 28, 178, 248),
              ),
            )
          : _error
          ? const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'))
          : _buildBody(),
      floatingActionButton: _currentIndex == 1 && _isTeacher
          ? FloatingActionButton.extended(
              backgroundColor: Colors.blueAccent,
              icon: const Icon(color: Colors.white, Icons.add),
              label: const Text(
                style: TextStyle(color: Colors.white),
                'เพิ่มงาน',
              ),
              onPressed: () async {
                final ok = await Navigator.pushNamed(
                  context,
                  '/create-assignment',
                  arguments: widget.classId,
                );
                if (ok == true) setState(() {}); // รีเฟรชหลังเพิ่มงาน
              },
            )
          : null,

      //  Bottom Navigation Bar เหมือนเดิม
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: const Color.fromARGB(255, 39, 39, 39),
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            label: 'Stream',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            label: 'Classwork',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Report', // ✅ หน้ารายงานใหม่
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            label: 'People',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _StreamTab(
          key: _streamKey,
          classId: widget.classId,
          classroom: _classroom,
          isTeacher: _isTeacher,
          onCreateAnnouncement: _openCreateAnnouncement,
        );
      case 1:
        return _ClassworkTab(classId: widget.classId, isTeacher: _isTeacher);
      case 2:
        //  แท็บรายงานจริง
        return ClassReportTab(classId: widget.classId);
      case 3:
        return _PeopleTab(classroom: _classroom);
      default:
        return const SizedBox.shrink();
    }
  }
}

/// 🔹 STREAM TAB
class _StreamTab extends StatefulWidget {
  final String classId;
  final Classroom? classroom;
  final bool isTeacher;
  final VoidCallback onCreateAnnouncement;

  const _StreamTab({
    Key? key,
    required this.classId,
    required this.classroom,
    required this.isTeacher,
    required this.onCreateAnnouncement,
  }) : super(key: key);

  @override
  State<_StreamTab> createState() => _StreamTabState();
}

class _StreamTabState extends State<_StreamTab> {
  late Future<List<FeedItem>> _futureFeed;
  List<FeedItem> _lastFeed = const [];

  @override
  void initState() {
    super.initState();
    _futureFeed = FeedService.getClassFeed(widget.classId).then((list) {
      _lastFeed = list;
      return list;
    });
  }

  Future<void> _refresh({bool force = false}) async {
    setState(() {
      _futureFeed = FeedService.getClassFeed(widget.classId).then((list) {
        _lastFeed = list;
        return list;
      });
    });
  }

  void refreshFeed() => _refresh(force: true);

  void insertOptimisticSession(Map<String, dynamic> s) {
    final id = s['session_id']?.toString() ?? s['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final start = DateTime.tryParse(s['start_time']?.toString() ?? '');
    final end = DateTime.tryParse(
      s['end_time']?.toString() ?? s['expires_at']?.toString() ?? '',
    );

    final item = FeedItem(
      id: id,
      classId: widget.classId,
      type: FeedType.checkin,
      title: 'เช็คชื่อกำลังเปิดอยู่',
      postedAt: start ?? DateTime.now(),
      expiresAt: end,
      extra: {
        'session_id': id,
        'reverify_enabled': s['reverify_enabled'] == true,
        'radius': s['radius_meters'],
        'anchor_lat': s['anchor_lat'],
        'anchor_lon': s['anchor_lon'],
      },
    );

    setState(() {
      _lastFeed = [item, ..._lastFeed];
      _futureFeed = Future.value(_lastFeed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.classroom;
    return RefreshIndicator(
      onRefresh: () => _refresh(force: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (c != null)
            Card(
              color: getClassColor(c.name ?? 'Class'),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name ?? '—',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      style: TextStyle(
                        color: Colors.white
                      ),
                      'Code: ${c.code ?? '-'}'),
                    const SizedBox(height: 4),
                    Text(
                      style: const TextStyle(color: Colors.white70),
                      'Teacher: ${c.teacher?.username ?? c.teacher?.email ?? '-'}',
                    ),
                    if ((c.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(c.description!),
                    ],
                  ],
                ),
              ),
            ),
          if (widget.isTeacher) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: widget.onCreateAnnouncement,
              icon: const Icon(Icons.campaign),
              label: const Text('Create Announcement'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black38, // สีข้อความและไอคอน
                minimumSize: const Size.fromHeight(44),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blueAccent, // สีพื้นหลัง
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: () async {
                final created =
                    await showModalBottomSheet<Map<String, dynamic>?>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) =>
                          TeacherOpenCheckinSheet(classId: widget.classId),
                    );

                if (!mounted) return;

                if (created != null) {
                  await Future.delayed(const Duration(seconds: 4));
                  insertOptimisticSession(created);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('เปิดเช็คชื่อแล้ว')),
                  );
                  await _refresh(force: true);
                }
              },
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('ประกาศเช็คชื่อ'),
            ),
          ],
          const SizedBox(height: 16),
          Text('Announcements', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FutureBuilder<List<FeedItem>>(
            future: _futureFeed,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color.fromARGB(255, 28, 178, 248),
                    ),
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
              return FeedList(
                items: feed,
                isTeacher: widget.isTeacher,
                classId: widget.classId,
                onChanged: () => _refresh(force: true),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 🔹 CLASSWORK TAB (assignment)
class _ClassworkTab extends StatefulWidget {
  final String classId;
  final bool isTeacher;
  const _ClassworkTab({required this.classId, required this.isTeacher});

  @override
  State<_ClassworkTab> createState() => _ClassworkTabState();
}

class _ClassworkTabState extends State<_ClassworkTab> {
  late Future<List<FeedItem>> _futureAssignments;

  @override
  void initState() {
    super.initState();
    _futureAssignments = widget.isTeacher
        ? FeedService.getClassFeedForTeacherWithAssignments(widget.classId)
        : FeedService.getClassFeedForStudentWithAssignments(widget.classId);
  }

  Future<void> _refresh() async {
    setState(() {
      _futureAssignments = widget.isTeacher
          ? FeedService.getClassFeedForTeacherWithAssignments(widget.classId)
          : FeedService.getClassFeedForStudentWithAssignments(widget.classId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<FeedItem>>(
        future: _futureAssignments,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(
                color: Color.fromARGB(255, 28, 178, 248),
              ),
            );
          }
          if (snap.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snap.error}'));
          }

          final feed = snap.data ?? [];
          final assignments = feed
              .where((f) => (f.extra['kind'] ?? '') == 'assignment')
              .toList();

          if (assignments.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('ยังไม่มีงานในคลาสนี้'),
              ),
            );
          }

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: FeedList(
              items: assignments,
              isTeacher: widget.isTeacher,
              classId: widget.classId,
              onChanged: _refresh,
            ),
          );
        },
      ),
    );
  }
}

/// 🔹 REPORT TAB
class _ReportTab extends StatelessWidget {
  const _ReportTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Report — สถิติการเช็คชื่อ จะอยู่ที่นี่'),
      ),
    );
  }
}

/// 🔹 PEOPLE TAB (Teacher)
class _PeopleTab extends StatelessWidget {
  final Classroom? classroom;
  const _PeopleTab({required this.classroom});

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

  String _display(User u) => u.displayName;

  @override
  Widget build(BuildContext context) {
    final c = classroom;
    if (c == null) {
      return const Center(child: Text('ไม่มีข้อมูลสมาชิกในคลาส'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Teacher', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ListTile(
          leading: c.teacher != null
              ? _avatarFor(c.teacher!, radius: 22)
              : const CircleAvatar(child: Icon(Icons.person)),
          title: Text(c.teacher != null ? _display(c.teacher!) : '-'),
          subtitle: Text(c.teacher?.email ?? ''),
        ),
        const SizedBox(height: 12),
        Text(
          'Students (${c.students.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (c.students.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('ยังไม่มีนักเรียน'),
            ),
          ),
        ...c.students.map(
          (s) => ListTile(
            leading: _avatarFor(s),
            title: Text(_display(s)),
            subtitle: Text(s.email ?? ''),
          ),
        ),
      ],
    );
  }
}
