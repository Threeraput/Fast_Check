import 'package:flutter/material.dart';
import 'package:frontend/models/classroom.dart';
import 'package:frontend/models/users.dart';
import 'package:frontend/screens/attendance/class_report_tab.dart';
import 'package:frontend/screens/classroom/classroom_home_screen.dart';
import 'package:frontend/screens/announcement/create_announcement_screen.dart';
import 'package:frontend/screens/attendance/teacher_open_checkin_sheet.dart';
import 'package:frontend/screens/classroom/chat_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/class_service.dart';
import 'package:frontend/services/feed_service.dart';
import 'package:frontend/widgets/feed_cards.dart';
import 'package:frontend/widgets/glass_card.dart';
import 'package:frontend/models/feed_item.dart';
import 'package:intl/intl.dart';
import 'package:frontend/utils/app_theme.dart';

// ใช้สำหรับ URL รูปโปรไฟล์
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
  final GlobalKey<_ClassworkTabState> _classworkKey =
      GlobalKey<_ClassworkTabState>();
  int _currentIndex = 0;
  bool _loading = true;
  bool _error = false;
  bool _isTeacher = false;
  bool _isSwapped = false; // 1. เพิ่มตัวแปรเช็คร่างจำแลง

  Classroom? _classroom;
  User? _me;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      // 2. อ่าน Role ปัจจุบันจาก Token โดยตรง ชัวร์ที่สุด!
      final currentRoles = await AuthService.getTokenRoles();
      final isSwapped = await AuthService.isCurrentlySwapped();

      final me = await AuthService.getCurrentUserFromLocal();
      // เช็คจาก currentRoles ที่เพิ่งแกะสดๆ ร้อนๆ แทน
      final isTeacher =
          currentRoles.contains('teacher') || currentRoles.contains('admin');

      Classroom? cls;
      if (isTeacher) {
        // ครูใช้รายละเอียดคลาส
        cls = await ClassService.getClassroomDetails(widget.classId);
      } else {
        // นักเรียนใช้ endpoint สมาชิกในคลาส เพื่อให้เห็นครูได้
        cls = await ClassService.getStudentClassroomDetails(widget.classId);
      }

      if (!mounted) return;
      setState(() {
        _me = me;
        _isTeacher = isTeacher;
        _isSwapped = isSwapped;
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

  Widget _buildSwappedBanner() {
    return Container(
      width: double.infinity,
      color: Colors.red.shade600,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '⚠️ คุณอยู่ในโหมดนักเรียน',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red.shade700,
            ),
            onPressed: () async {
              final success = await AuthService.switchRole('teacher');
              if (success && context.mounted) {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
            child: const Text('กลับสู่โหมดอาจารย์'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _classroom?.name ?? widget.className ?? 'Classroom';
    final classCode = _classroom?.code ?? '-';
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
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              'Class Code: $classCode',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : _error
          ? const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'))
          : Column(children: [Expanded(child: _buildBody())]),
      floatingActionButton: _currentIndex == 1 && _isTeacher
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
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
                if (ok == true) {
                  await _classworkKey.currentState?._refresh();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('สร้างงานสำเร็จ')),
                    );
                  }
                }
              },
            )
          : null,

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
          accent: const Color(0xFF2563EB),
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
                        ? const Color(0xFF2563EB).withValues(alpha: 0.15)
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
                                  ? AppColors.primary
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
                                    ? AppColors.primary
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
        return _StreamTab(
          key: _streamKey,
          classId: widget.classId,
          classroom: _classroom,
          isTeacher: _isTeacher,
          onCreateAnnouncement: _openCreateAnnouncement,
        );
      case 1:
        return _ClassworkTab(
          key: _classworkKey,
          classId: widget.classId,
          isTeacher: _isTeacher,
        );
      case 2:
        //  แท็บรายงานจริง
        return ClassReportTab(classId: widget.classId);
      case 3:
        return _PeopleTab(
          classroom: _classroom,
          onRefresh: _bootstrap,
          isTeacher: _isTeacher,
          currentUserId: _me?.userId,
        );
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

  Color get _roleTone => widget.isTeacher
      ? const Color(0xFF2563EB)
      : const Color(0xFF0EA5A4);

  String get _roleLabel => widget.isTeacher ? 'Teacher Stream' : 'Student Stream';

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
      _futureFeed = FeedService.getClassFeed(widget.classId, force: force).then(
        (list) {
          _lastFeed = list;
          return list;
        },
      );
    });
  }

  void refreshFeed() => _refresh(force: true);

  /// ซิงค์ข้อมูลแบบเงียบ (ไม่ trigger setState) - อัปเดต _lastFeed เท่านั้น
  void _syncFeedSilently() {
    FeedService.getClassFeed(widget.classId, force: true)
        .then((list) {
          if (!mounted) return;
          _lastFeed = list;
        })
        .catchError((_) {
          // ซิงค์ล้มเหลว ไม่ต้องทำอะไร
        });
  }

  void refreshFeedEventually({Duration delay = const Duration(seconds: 2)}) {
    Future.delayed(delay, () {
      if (!mounted) return;
      _syncFeedSilently(); // ใช้ sync เงียบแทน _refresh
    });
  }

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

  Widget _buildRoleDivider() {
    final tone = _roleTone;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [tone.withValues(alpha: 0.0), tone.withValues(alpha: 0.72)],
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: tone.withValues(alpha: 0.35)),
          ),
          child: Text(
            _roleLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: tone,
              letterSpacing: 0.25,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [tone.withValues(alpha: 0.72), tone.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    final tone = _roleTone;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
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
    final c = widget.classroom;
    return RefreshIndicator(
      onRefresh: () => _refresh(force: true),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildRoleDivider(),
          const SizedBox(height: 12),
          if (c != null)
            GlassCard(
              accent: getClassColor(c.name ?? 'Class'),
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
                          c.name ?? '—',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: const Color(0xFF0F2547),
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFBFD3FF)),
                          ),
                          child: Text(
                            'Code: ${c.code ?? '-'}',
                            style: const TextStyle(
                              color: Color(0xFF123A6D),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          style: const TextStyle(
                            color: Color(0xFF3D5A82),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          'Teacher: ${c.teacher?.username ?? c.teacher?.email ?? '-'}',
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
                              (c.description != null &&
                                      c.description!.isNotEmpty)
                                  ? c.description!
                                  : 'ยังไม่มีคำอธิบายสำหรับคลาสนี้',
                              style: const TextStyle(fontSize: 15),
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
          if (widget.isTeacher) ...[
            const SizedBox(height: 10),
            GlassCard(
              accent: const Color(0xFF2563EB),
              radius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              onTap: widget.onCreateAnnouncement,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.campaign_outlined, size: 18, color: Color(0xFF1D4ED8)),
                  const SizedBox(width: 8),
                  const Text(
                    'Create Announcement',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            GlassCard(
              accent: const Color(0xFF0EA5A4),
              radius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              onTap: () async {
                        final created =
                            await showModalBottomSheet<Map<String, dynamic>?>(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) =>
                                  TeacherOpenCheckinSheet(classId: widget.classId),
                            );

                        if (!mounted) return;

                        if (created != null) {
                          insertOptimisticSession(created);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('เปิดเช็คชื่อแล้ว')),
                          );
                          refreshFeedEventually();
                        }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_circle_outline, size: 18, color: Color(0xFF0F766E)),
                  const SizedBox(width: 8),
                  const Text(
                    'ประกาศเช็คชื่อ',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F766E)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _sectionTitle('Announcements'),
          const SizedBox(height: 6),
          FutureBuilder<List<FeedItem>>(
            future: _futureFeed,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
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
  const _ClassworkTab({
    super.key,
    required this.classId,
    required this.isTeacher,
  });

  @override
  State<_ClassworkTab> createState() => _ClassworkTabState();
}

class _ClassworkTabState extends State<_ClassworkTab> {
  late Future<List<FeedItem>> _futureAssignments;

  Color get _roleColor => widget.isTeacher
      ? const Color(0xFF2563EB)
      : const Color(0xFF0EA5A4);

  String get _roleLabel => widget.isTeacher
      ? 'Teacher Classwork'
      : 'Student Classwork';

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

  Widget _buildRoleDivider() {
    final color = _roleColor;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.0),
                  color.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Text(
            _roleLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
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
                  color.withValues(alpha: 0.72),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<FeedItem>>(
        future: _futureAssignments,
        builder: (context, snap) {
          final roleHeader = [
            _buildRoleDivider(),
            const SizedBox(height: 12),
          ];

          if (snap.connectionState != ConnectionState.done) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: [
                ...roleHeader,
                const SizedBox(height: 40),
                const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
              ],
            );
          }
          if (snap.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: [
                ...roleHeader,
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Text('เกิดข้อผิดพลาด: ${snap.error}'),
                ),
              ],
            );
          }

          final feed = snap.data ?? [];
          final assignments = feed
              .where((f) => (f.extra['kind'] ?? '') == 'assignment')
              .toList();

          if (assignments.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: [
                ...roleHeader,
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Icon(
                        widget.isTeacher
                            ? Icons.assignment_outlined
                            : Icons.assignment_late_outlined,
                        color: _roleColor,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.isTeacher
                            ? 'ยังไม่มีงานในคลาสนี้ กดปุ่ม เพิ่มงาน เพื่อสร้างงานแรก'
                            : 'ยังไม่มีงานที่ต้องส่งในคลาสนี้',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            children: [
              ...roleHeader,
              FeedList(
                items: assignments,
                isTeacher: widget.isTeacher,
                classId: widget.classId,
                onChanged: _refresh,
              ),
            ],
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
class _PeopleTab extends StatefulWidget {
  final Classroom? classroom;
  final VoidCallback? onRefresh;
  final bool isTeacher;
  final String? currentUserId;

  const _PeopleTab({
    required this.classroom,
    this.onRefresh,
    required this.isTeacher,
    this.currentUserId,
  });

  @override
  State<_PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<_PeopleTab> {
  static const Color _teacherTone = Color(0xFF2563EB);
  static const Color _studentTone = Color(0xFF0EA5A4);

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

  Widget _buildRoleDivider() {
    final tone = widget.isTeacher ? _teacherTone : _studentTone;
    final label = widget.isTeacher ? 'Teacher People View' : 'Student People View';
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  tone.withValues(alpha: 0.0),
                  tone.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: tone.withValues(alpha: 0.35)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: tone,
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
                  tone.withValues(alpha: 0.72),
                  tone.withValues(alpha: 0.0),
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

  Future<void> _removeStudent(User student) async {
    if (widget.classroom?.classId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบนักเรียน'),
        content: Text('ต้องการลบ ${student.displayName} ออกจากคลาสนี้หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ClassService.removeStudent(
        widget.classroom!.classId!,
        student.userId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ลบ ${student.displayName} สำเร็จ')),
        );
        // รีเฟรชข้อมูลคลาสโดยเรียก parent ให้ reload
        widget.onRefresh?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ลบนักเรียนไม่สำเร็จ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.classroom;
    if (c == null) {
      return const Center(child: Text('ไม่มีข้อมูลสมาชิกในคลาส'));
    }
    return ListView(
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
                c.teacher != null
                    ? _avatarFor(c.teacher!, radius: 22)
                    : const CircleAvatar(child: Icon(Icons.person)),
              ],
            ),
            title: Text(c.teacher != null ? _display(c.teacher!) : '-'),
            subtitle: Text(c.teacher?.email ?? ''),
            trailing: const Icon(Icons.school, size: 18, color: _teacherTone),
          ),
        ),
        const SizedBox(height: 10),
        _sectionTitle('Students (${c.students.length})', _studentTone),
        const SizedBox(height: 6),
        if (c.students.isEmpty)
          const GlassCard(
            accent: _studentTone,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('ยังไม่มีนักเรียน'),
            ),
          ),
        ...c.students.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GlassCard(
              accent: _studentTone,
              radius: 12,
              padding: const EdgeInsets.all(4),
              child: ListTile(
              contentPadding: const EdgeInsets.only(left: 0, right: 8),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 4, height: 40, color: _studentTone),
                  const SizedBox(width: 10),
                  _avatarFor(s),
                ],
              ),
              dense: true,
              title: Text(_display(s), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(s.email ?? '', style: const TextStyle(fontSize: 12)),
              trailing: widget.isTeacher
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                          tooltip: 'Chat student',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  classId: c.classId ?? '',
                                  otherUser: s,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          tooltip: 'ลบนักเรียน',
                          onPressed: () => _removeStudent(s),
                        ),
                      ],
                    )
                  : null,
            ),
            ),
          ),
        ),
      ],
    );
  }
}
