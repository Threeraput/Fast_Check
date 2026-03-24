import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:frontend/models/users.dart';
import 'package:frontend/models/classroom.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/class_service.dart';
import 'class_details_screen.dart';
import 'create_class_screen.dart';
import 'join_class_sheet.dart';
import 'student_class_view.dart';
import '../screens/camera_screen.dart';
import '../services/face_service.dart';
import 'package:frontend/screens/profile_screen.dart';
import 'package:frontend/services/user_service.dart';
import 'package:frontend/screens/admin_dashboard_screen.dart';

// ✅ ใช้ API แอดมินสำหรับดึง/เพิ่ม/ลบคลาสทั้งหมดในระบบ
import 'package:frontend/services/admin_service.dart';

class ClassroomHomeScreen extends StatefulWidget {
  const ClassroomHomeScreen({super.key});

  @override
  State<ClassroomHomeScreen> createState() => _ClassroomHomeScreenState();
}

class _ClassroomHomeScreenState extends State<ClassroomHomeScreen> {
  User? _me;
  Future<List<Classroom>>? _futureTaught;
  Future<List<Classroom>>? _futureJoined;

  // ✅ แอดมิน: โหลด "คลาสทั้งหมดในระบบ"
  Future<List<_AdminClassItem>>? _futureAllClasses;

  bool get _isTeacher =>
      _me?.roles.contains('teacher') == true ||
      _me?.roles.contains('admin') == true;

  bool get _isAdmin =>
      _me?.roles.any((r) => r.toLowerCase() == 'admin') == true;

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  void _setupFutures() {
    if (_isAdmin) {
      _futureAllClasses = _fetchAllClassesForAdmin();
      _futureTaught = null;
      _futureJoined = null;
      return;
    }
    if (_isTeacher) {
      _futureTaught = ClassService.getTaughtClasses();
      _futureJoined = null;
    } else {
      _futureJoined = ClassService.getJoinedClasses();
      _futureTaught = null;
    }
  }

  Future<void> _loadMe() async {
    final cached = await AuthService.getCurrentUserFromLocal();
    setState(() {
      _me = cached;
      _setupFutures();
    });

    try {
      final fresh = await UserService.fetchMe();
      if (!mounted) return;
      setState(() {
        _me = fresh;
        _setupFutures();
      });
    } catch (_) {}
  }

  Future<void> _refresh() async {
    setState(() {
      _setupFutures();
    });
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const CreateClassScreen()));
    if (created == true) {
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('สร้างคลาสสำเร็จ')));
      }
    }
  }

  Future<void> _openJoin() async {
    final joined = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const JoinClassSheet(),
    );
    if (joined == true) {
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('เข้าร่วมคลาสสำเร็จ')));
      }
    }
  }

  Future<void> _openProfile() async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    if (changed == true) {
      await _loadMe();
    }
  }

  Future<void> _openAdmin() async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('เฉพาะผู้ดูแลระบบเท่านั้น')));
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
  }

  // =========================
  // ✅ ADMIN: โหลดคลาสทั้งหมดในระบบ
  // =========================
  Future<List<_AdminClassItem>> _fetchAllClassesForAdmin() async {
    final page = await AdminService.listClasses(limit: 200, offset: 0);
    final items = (page['items'] as List<dynamic>? ?? []);
    return items.map((e) {
      final m = e as Map<String, dynamic>;
      final teacher = (m['teacher'] as Map<String, dynamic>?) ?? {};
      return _AdminClassItem(
        classId: (m['class_id'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        code: (m['code'] ?? '').toString(),
        studentCount: (m['student_count'] ?? 0) as int,
        teacherName:
            (teacher['username'] ??
                    teacher['full_name'] ??
                    teacher['email'] ??
                    '-')
                .toString(),
      );
    }).toList();
  }

  // =========================
  // ✅ ADMIN: เพิ่มคลาสใหม่ (ชื่อ + teacher_id)
  // =========================
  Future<void> _adminCreateClass() async {
    final nameCtrl = TextEditingController();
    final teacherIdCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เพิ่มคลาส (แอดมิน)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'ชื่อคลาส',
                prefixIcon: Icon(Icons.class_),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: teacherIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Teacher ID (UUID)',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              style: TextStyle(color: Colors.grey),
              'ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.blueAccent),
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.pop(ctx, true),
            label: const Text('เพิ่ม'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final name = nameCtrl.text.trim();
      final teacherId = teacherIdCtrl.text.trim();
      if (name.isEmpty || teacherId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรอกชื่อคลาสและ Teacher ID ให้ครบ')),
        );
        return;
      }
      try {
        await AdminService.createClass(name: name, teacherId: teacherId);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('เพิ่มคลาสสำเร็จ')));
        _refresh();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เพิ่มคลาสไม่สำเร็จ: $e')));
      }
    }
  }

  // =========================
  // ✅ ADMIN: ลบคลาส
  // =========================
  Future<void> _adminDeleteClass(String classId, String className) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการลบคลาส'),
        content: Text('ต้องการลบ "$className" ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await AdminService.deleteClass(classId);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ลบคลาสสำเร็จ')));
        _refresh();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ลบคลาสไม่สำเร็จ: $e')));
      }
    }
  }

  Drawer _buildDrawer() {
    final me = _me;

    if (me == null) {
      return const Drawer(
        child: Center(
          child: CircularProgressIndicator(
            color: Color.fromARGB(255, 28, 178, 248),
          ),
        ),
      );
    }

    final isStudent = me.roles.any((r) => r.toLowerCase() == 'student');
    final avatarAbs = UserService.absoluteAvatarUrl(me.avatarUrl);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(me.displayName),
              accountEmail: Text(me.email ?? ''),
              currentAccountPicture: GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  await _openProfile();
                },
                child: CircleAvatar(
                  backgroundColor: Colors.deepOrangeAccent,
                  backgroundImage: avatarAbs != null
                      ? NetworkImage(avatarAbs)
                      : null,
                  child: avatarAbs == null
                      ? Text(
                          (me.username.isNotEmpty ? me.username[0] : '?')
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blueAccent, Colors.lightBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.class_, color: Colors.blueAccent),
                    title: Text(
                      _isAdmin
                          ? 'คลาสทั้งหมด (แอดมิน)'
                          : (_isTeacher ? 'คลาสที่สอน' : 'คลาสที่เรียน'),
                    ),
                    onTap: () => Navigator.pop(context),
                  ),
                  if (_isAdmin) ...[
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Text(
                        'ADMIN',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.admin_panel_settings,
                        color: Colors.deepOrange,
                      ),
                      title: const Text('Admin Dashboard'),
                      onTap: () async {
                        Navigator.pop(context);
                        await _openAdmin();
                      },
                    ),
                  ],
                  const Divider(),

                  if (_isTeacher && !_isAdmin)
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline),
                      title: const Text('สร้างคลาสใหม่'),
                      onTap: () {
                        Navigator.pop(context);
                        _openCreate();
                      },
                    ),

                  if (!_isTeacher && !_isAdmin)
                    ListTile(
                      leading: const Icon(Icons.group_add),
                      title: const Text('เข้าร่วมคลาส'),
                      onTap: () {
                        Navigator.pop(context);
                        _openJoin();
                      },
                    ),

                  if (isStudent) ...[
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.face_retouching_natural),
                      title: const Text('เพิ่มใบหน้า'),
                      onTap: () async {
                        Navigator.pushReplacementNamed(context, '/upload-face');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_forever),
                      title: const Text('ลบใบหน้า'),
                      onTap: () async {
                        Navigator.pop(context);
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('ยืนยันการลบข้อมูลใบหน้า'),
                            content: const Text(
                              'การกระทำนี้ไม่สามารถกู้คืนได้',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text(
                                  style: TextStyle(color: Colors.grey),
                                  'ยกเลิก'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('ลบ'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          try {
                            await FaceService.deleteFace();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('ลบข้อมูลใบหน้าสำเร็จ'),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('ลบข้อมูลใบหน้าไม่สำเร็จ: $e'),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),

            const Divider(),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: ListTile(
                leading: const Icon(Icons.logout),
                title: const Text(
                  'ออกจากระบบ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text(
                        'ยืนยันการออกจากระบบ'),
                      content: const Text(
                        'คุณต้องเข้าสู่ระบบอีกครั้งเพื่อใช้งานต่อ',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text(
                          style: TextStyle(color: Colors.grey),
                            'ยกเลิก'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('ออกจากระบบ'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await AuthService.logout();
                    if (context.mounted) {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/login', (route) => false);
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    final avatarAbs = me != null
        ? UserService.absoluteAvatarUrl(me.avatarUrl)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isAdmin ? 'All Classes (Admin)' : 'Classroom'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _openProfile,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: (avatarAbs != null)
                    ? NetworkImage(avatarAbs)
                    : null,
                child: (avatarAbs == null)
                    ? Icon(Icons.person, color: Colors.grey.shade700)
                    : null,
              ),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      // ✅ แอดมิน: มีปุ่มเพิ่มคลาสเท่านั้น
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: _adminCreateClass,
              backgroundColor: Colors.blueAccent,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'เพิ่มคลาส',
                style: TextStyle(color: Colors.white),
              ),
            )
          : FloatingActionButton(
              onPressed: _isTeacher ? _openCreate : _openJoin,
              tooltip: _isTeacher ? 'สร้างคลาสใหม่' : 'เข้าร่วมคลาส',
              backgroundColor: Colors.blueAccent,
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: me == null
          ? const Center(
              child: CircularProgressIndicator(
                color: Color.fromARGB(255, 28, 178, 248),
              ),
            )
          : _isAdmin
          ? _AdminClasses(
              futureAll: _futureAllClasses,
              onDelete: _adminDeleteClass,
              onRefresh: _refresh,
            )
          : (_isTeacher
                ? _TeacherClasses(
                    futureTaught: _futureTaught,
                    onRefresh: _refresh,
                  )
                : _StudentClasses(
                    futureJoined: _futureJoined,
                    onRefresh: _refresh,
                  )),
    );
  }
}

class _TeacherClasses extends StatelessWidget {
  final Future<List<Classroom>>? futureTaught;
  final Future<void> Function() onRefresh;
  const _TeacherClasses({required this.futureTaught, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Classroom>>(
      future: futureTaught,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color.fromARGB(255, 28, 178, 248),
            ),
          );
        }
        if (snap.hasError) {
          return Center(child: Text('เกิดข้อผิดพลาด: ${snap.error}'));
        }
        final data = snap.data ?? [];
        if (data.isEmpty) {
          return const _EmptyState(
            title: 'ยังไม่มีคลาสที่คุณสอน',
            subtitle: 'กดปุ่ม + เพื่อสร้างคลาสใหม่',
          );
        }
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: data.length,
            itemBuilder: (_, i) =>
                _ClassCard(c: data[i], isTeacher: true, onRefresh: onRefresh),
          ),
        );
      },
    );
  }
}

class _StudentClasses extends StatelessWidget {
  final Future<List<Classroom>>? futureJoined;
  final Future<void> Function() onRefresh;
  const _StudentClasses({required this.futureJoined, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Classroom>>(
      future: futureJoined,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color.fromARGB(255, 28, 178, 248),
            ),
          );
        }
        if (snap.hasError) {
          return Center(child: Text('เกิดข้อผิดพลาด: ${snap.error}'));
        }
        final data = snap.data ?? [];
        if (data.isEmpty) {
          return const _EmptyState(
            title: 'ยังไม่มีคลาสที่เข้าร่วม',
            subtitle: 'กด “เข้าร่วม” แล้วกรอกรหัสจากอาจารย์',
          );
        }
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: data.length,
            itemBuilder: (_, i) =>
                _ClassCard(c: data[i], isTeacher: false, onRefresh: onRefresh),
          ),
        );
      },
    );
  }
}

class _AdminClasses extends StatelessWidget {
  final Future<List<_AdminClassItem>>? futureAll;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String classId, String className) onDelete;
  const _AdminClasses({
    required this.futureAll,
    required this.onRefresh,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_AdminClassItem>>(
      future: futureAll,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color.fromARGB(255, 28, 178, 248),
            ),
          );
        }
        if (snap.hasError) {
          return Center(child: Text('เกิดข้อผิดพลาด: ${snap.error}'));
        }
        final data = snap.data ?? const <_AdminClassItem>[];
        if (data.isEmpty) {
          return const _EmptyState(
            title: 'ยังไม่มีคลาสในระบบ',
            subtitle: 'กดปุ่ม “เพิ่มคลาส” ที่มุมขวาล่าง',
          );
        }

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: data.length,
            itemBuilder: (_, i) {
              final it = data[i];
              final color = getClassColor(it.name);
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
                color: color,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  title: Text(
                    it.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Teacher: ${it.teacherName}  •  Students: ${it.studentCount}',
                    style: TextStyle(color: Colors.white.withOpacity(0.92)),
                  ),
                  // ✅ แอดมิน: มีปุ่มลบเท่านั้น
                  trailing: IconButton(
                    tooltip: 'ลบคลาส',
                    onPressed: () => onDelete(it.classId, it.name),
                    icon: const Icon(Icons.delete, color: Colors.white),
                  ),
                  // ❌ ไม่พาเข้า class details สำหรับแอดมินในหน้านี้
                  onTap: null,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? extra;
  const _EmptyState({required this.title, required this.subtitle, this.extra});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.class_, size: 64, color: Colors.blueAccent),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
            if (extra != null) ...[const SizedBox(height: 16), extra!],
          ],
        ),
      ),
    );
  }
}

Color getClassColor(String? className, {int shade = 400}) {
  if (className == null || className.isEmpty) return Colors.grey.shade400;
  final baseColor =
      Colors.primaries[className.hashCode % Colors.primaries.length];

  switch (shade) {
    case 100:
      return baseColor.shade100;
    case 200:
      return baseColor.shade200;
    case 300:
      return baseColor.shade300;
    case 400:
      return baseColor.shade400;
    case 500:
      return baseColor.shade500;
    default:
      return baseColor.shade400;
  }
}

// การ์ดสำหรับครู/นักเรียน (ไม่ใช้กับแอดมิน)
class _ClassCard extends StatelessWidget {
  final Classroom c;
  final bool isTeacher;
  final Future<void> Function()? onRefresh;
  const _ClassCard({required this.c, required this.isTeacher, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final color = getClassColor(c.name);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      color: color,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (isTeacher) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClassDetailsScreen(classId: c.classId!),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StudentClassView(
                  classId: c.classId ?? '',
                  className: c.name ?? '(no name)',
                  teacherName: c.teacher?.username ?? c.teacher?.email ?? '-',
                ),
              ),
            );
          }
        },
        child: Stack(
          children: [
            Positioned(
              top: 4,
              right: 4,
              child: PopupMenuButton<String>(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) async {
                  if (value == 'edit') {
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateClassScreen(editing: c),
                      ),
                    );
                    if (updated == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('แก้ไขคลาสสำเร็จ')),
                      );
                      onRefresh?.call();
                    }
                  } else if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text(
                          'ออกจากคลาส',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        content: const Text(
                          'ต้องการลบคลาสนี้ใช่หรือไม่?',
                          style: TextStyle(fontSize: 15),
                        ),
                        actionsAlignment: MainAxisAlignment.center,
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('ยกเลิก'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('ลบ'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await ClassService.deleteClassroom(c.classId!);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ลบคลาสสำเร็จ')),
                          );
                          onRefresh?.call();
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('ลบไม่สำเร็จ: $e')),
                        );
                      }
                    }
                  } else if (value == 'leave') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('ออกจากคลาส'),
                        content: const Text('ต้องการออกจากคลาสนี้ใช่หรือไม่?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text(
                              'ยกเลิก',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('ออกจากคลาส'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await ClassService.leaveClassroom(c.classId!);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ออกจากคลาสสำเร็จ')),
                          );
                          onRefresh?.call();
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('ออกจากคลาสไม่สำเร็จ: $e')),
                        );
                      }
                    }
                  }
                },
                itemBuilder: (_) => isTeacher
                    ? const [
                        PopupMenuItem(value: 'edit', child: Text('แก้ไขคลาส')),
                        PopupMenuDivider(height: 2),
                        PopupMenuItem(value: 'delete', child: Text('ลบคลาส')),
                      ]
                    : [
                        const PopupMenuItem(
                          value: 'leave',
                          height: 28,
                          child: Text(
                            'ออกจากคลาส',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name ?? '(ไม่มีชื่อคลาส)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.teacher?.username ?? c.teacher?.email ?? '',
                    style: TextStyle(color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminClassItem {
  final String classId;
  final String name;
  final String code;
  final int studentCount;
  final String teacherName;

  _AdminClassItem({
    required this.classId,
    required this.name,
    required this.code,
    required this.studentCount,
    required this.teacherName,
  });
}
