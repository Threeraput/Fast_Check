import 'package:flutter/material.dart';
import 'package:frontend/models/users.dart';
import 'package:frontend/models/classroom.dart';
import 'package:frontend/screens/home/archived_classes_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/class_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'class_details_screen.dart';
import 'create_class_screen.dart';
import 'join_class_sheet.dart';
import '../student_class_view.dart';
import 'package:frontend/screens/profile/profile_screen.dart';
import 'package:frontend/services/user_service.dart';
import 'package:frontend/screens/admin/admin_dashboard_screen.dart';
import 'package:frontend/utils/app_theme.dart';
import 'dart:async'; // สำหรับใช้งาน Timer (Debounce)

// ใช้ API แอดมินสำหรับดึง/เพิ่ม/ลบคลาสทั้งหมดในระบบ
import 'package:frontend/services/admin_service.dart';

class ClassroomHomeScreen extends StatefulWidget {
  const ClassroomHomeScreen({super.key});

  @override
  State<ClassroomHomeScreen> createState() => _ClassroomHomeScreenState();
}

class _ClassroomHomeScreenState extends State<ClassroomHomeScreen> {
  User? _me;
  List<String> _tokenRoles = [];
  Future<List<Classroom>>? _futureTaught;
  Future<List<Classroom>>? _futureJoined;

  // แอดมิน: โหลด "คลาสทั้งหมดในระบบ"
  Future<List<_AdminClassItem>>? _futureAllClasses;

  // --------------------------------------------------
  // ตัวแปรสำหรับระบบค้นหา (เพิ่มใหม่)
  // --------------------------------------------------
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  bool get _isTeacher =>
      _tokenRoles.contains('teacher') || _tokenRoles.contains('admin');

  bool get _isAdmin => _tokenRoles.any((r) => r.toLowerCase() == 'admin');

  bool get _isStudent => _tokenRoles.contains('student');

  bool _isSwapped = false; // เพิ่มตรงนี้

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

  // --------------------------------------------------
  // ฟังก์ชันหน่วงเวลาค้นหา (เพิ่มใหม่)
  // --------------------------------------------------
  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = value;
      });
      _refresh(); // สั่งรีเฟรชเพื่อโหลดข้อมูลใหม่
    });
  }
  // --------------------------------------------------

  Future<void> _loadMe() async {
    final cached = await AuthService.getCurrentUserFromLocal();
    final roles = await AuthService.getTokenRoles();
    final isSwapped = await AuthService.isCurrentlySwapped(); // เพิ่ม

    setState(() {
      _me = cached;
      _tokenRoles = roles;
      _isSwapped = isSwapped;
      _setupFutures();
    });

    try {
      final fresh = await UserService.fetchMe();
      if (!mounted) return;
      setState(() {
        _me = fresh;
        _tokenRoles = roles;
        _isSwapped = isSwapped;
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
  // ADMIN: โหลดคลาสทั้งหมดในระบบ
  // =========================
  Future<List<_AdminClassItem>> _fetchAllClassesForAdmin() async {
    final fetchLimit = _searchQuery.trim().isEmpty ? 5 : 200;
    // เพิ่ม q: _searchQuery ตรงนี้
    final page = await AdminService.listClasses(
      q: _searchQuery,
      isArchived: false, // เฉพาะคลาสที่ยังไม่เก็บ
      limit: fetchLimit,
      offset: 0,
    );
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
  // ADMIN: เพิ่มคลาสใหม่ (ชื่อ + teacher_id)
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
            child: const Text(style: TextStyle(color: Colors.grey), 'ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
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
  // ADMIN: เก็บคลาส
  // =========================
  Future<void> _adminArchiveClass(String classId, String className) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการเก็บคลาส'),
        content: Text('ต้องการเก็บ "$className" ไว้ในคลังใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('เก็บ'),
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
        ).showSnackBar(const SnackBar(content: Text('จัดเก็บคลาสสำเร็จ')));
        _refresh();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เก็บคลาสไม่สำเร็จ: $e')));
      }
    }
  }

  Drawer _buildDrawer() {
    final me = _me;
    if (me == null) {
      return const Drawer(
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final avatarAbs = UserService.absoluteAvatarUrl(me.avatarUrl);

    Widget sectionLabel(String text) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      );
    }

    Future<void> openArchived() async {
      Navigator.pop(context);
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ArchivedClassesScreen()),
      );
    }

    Future<void> doLogout() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ยืนยันการออกจากระบบ'),
          content: const Text('คุณต้องเข้าสู่ระบบอีกครั้งเพื่อใช้งานต่อ'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ออกจากระบบ'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await AuthService.logout();
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      }
    }

    Widget menuTile({
      required IconData icon,
      required String title,
      Color iconColor = AppColors.primary,
      Color? textColor,
      Future<void> Function()? onTap,
      EdgeInsetsGeometry margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    }) {
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.80),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: ListTile(
          dense: true,
          leading: Icon(icon, color: iconColor, size: 20),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor ?? AppColors.textPrimary,
            ),
          ),
          onTap: onTap == null ? null : () async => onTap(),
        ),
      );
    }

    return Drawer(
      child: Container(
        decoration: const BoxDecoration(gradient: AppGradients.classroomBackground),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.86),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 3)),
                  ],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        await _openProfile();
                      },
                      child: CircleAvatar(
                        radius: 23,
                        backgroundColor: AppColors.primaryLight,
                        backgroundImage: avatarAbs != null ? NetworkImage(avatarAbs) : null,
                        child: avatarAbs == null
                            ? Text(
                                (me.username.isNotEmpty ? me.username[0] : '?').toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            me.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            me.email ?? '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 5),
                          AppBadge(
                            _isAdmin ? 'ADMIN' : (_isTeacher ? 'TEACHER' : 'STUDENT'),
                            color: AppColors.primaryLight,
                            textColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [
                    menuTile(
                      icon: Icons.class_,
                      title: _isAdmin
                          ? 'คลาสทั้งหมด (แอดมิน)'
                          : (_isTeacher ? 'คลาสที่สอน' : 'คลาสที่เรียน'),
                      onTap: () async => Navigator.pop(context),
                    ),
                    if (_isAdmin) ...[
                      sectionLabel('ADMIN'),
                      menuTile(
                        icon: Icons.admin_panel_settings,
                        iconColor: AppColors.warning,
                        title: 'Admin Dashboard',
                        onTap: () async {
                          Navigator.pop(context);
                          await _openAdmin();
                        },
                      ),
                      menuTile(
                        icon: Icons.archive_outlined,
                        iconColor: AppColors.textSecondary,
                        title: 'ชั้นเรียนที่เก็บ',
                        onTap: openArchived,
                      ),
                    ],
                    if (_isTeacher && !_isAdmin) ...[
                      sectionLabel('CLASSROOM'),
                      menuTile(
                        icon: Icons.add_circle_outline,
                        title: 'สร้างคลาสใหม่',
                        onTap: () async {
                          Navigator.pop(context);
                          await _openCreate();
                        },
                      ),
                      menuTile(
                        icon: Icons.inbox_outlined,
                        iconColor: AppColors.textSecondary,
                        title: 'ชั้นเรียนที่เก็บ',
                        onTap: openArchived,
                      ),
                      menuTile(
                        icon: Icons.swap_horiz,
                        iconColor: AppColors.primary,
                        title: 'ใช้งานในมุมมองนักเรียน',
                        onTap: () async {
                          Navigator.pop(context);
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(color: AppColors.primary),
                            ),
                          );
                          final success = await AuthService.switchRole('student');
                          if (context.mounted) Navigator.pop(context);
                          if (success && context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const ClassroomHomeScreen()),
                              (route) => false,
                            );
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('สลับร่างไม่สำเร็จ'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                    if (!_isTeacher && !_isAdmin) ...[
                      sectionLabel('STUDENT'),
                      menuTile(
                        icon: Icons.group_add,
                        title: 'เข้าร่วมคลาส',
                        onTap: () async {
                          Navigator.pop(context);
                          await _openJoin();
                        },
                      ),
                    ],
                    if (_isSwapped)
                      menuTile(
                        icon: Icons.swap_horiz,
                        iconColor: AppColors.error,
                        textColor: AppColors.error,
                        title: 'กลับสู่โหมดอาจารย์',
                        onTap: () async {
                          Navigator.pop(context);
                          final success = await AuthService.switchRole('teacher');
                          if (success && context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const ClassroomHomeScreen()),
                              (route) => false,
                            );
                          }
                        },
                      ),
                    if (_isStudent)
                      menuTile(
                        icon: Icons.face_retouching_natural,
                        title: 'ลงทะเบียน/เปลี่ยนใบหน้า',
                        onTap: () async {
                          Navigator.pop(context);
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(color: AppColors.primary),
                            ),
                          );
                          try {
                            final prefs = await SharedPreferences.getInstance();
                            final token = prefs.getString('accessToken') ?? '';
                            final result = await UserService.checkCanChangeFace(token);
                            if (context.mounted) Navigator.pop(context);
                            if (result['can_change_face'] == true) {
                              if (context.mounted) {
                                Navigator.pushNamed(context, '/upload-face');
                              }
                            } else if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    result['message'] ?? 'ไม่สามารถเปลี่ยนใบหน้าได้ในขณะนี้',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: AppColors.error,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) Navigator.pop(context);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('เกิดข้อผิดพลาด: $e'),
                                  backgroundColor: AppColors.warning,
                                ),
                              );
                            }
                          }
                        },
                      ),
                  ],
                ),
              ),
              const Divider(),
              menuTile(
                icon: Icons.logout,
                iconColor: AppColors.error,
                textColor: AppColors.error,
                title: 'ออกจากระบบ',
                margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                onTap: doLogout,
              ),
            ],
          ),
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isAdmin ? 'All Classes' : 'Classroom',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: AppColors.primaryDark,
              ),
            ),
            Text(
              _isAdmin
                  ? 'Admin overview'
                  : (_isTeacher ? 'Teaching workspace' : 'Learning workspace'),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _openProfile,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: (avatarAbs != null)
                    ? NetworkImage(avatarAbs)
                    : null,
                child: (avatarAbs == null)
                    ? const Icon(Icons.person, color: AppColors.primary)
                    : null,
              ),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      // แอดมิน: มีปุ่มเพิ่มคลาสเท่านั้น
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: _adminCreateClass,
              backgroundColor: AppColors.primary,
              elevation: 0,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'เพิ่มคลาส',
                style: TextStyle(color: Colors.white),
              ),
            )
          : FloatingActionButton(
              onPressed: _isTeacher ? _openCreate : _openJoin,
              tooltip: _isTeacher ? 'สร้างคลาสใหม่' : 'เข้าร่วมคลาส',
              backgroundColor: AppColors.primary,
              elevation: 0,
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.classroomBackground,
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -90,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF67A8FF).withOpacity(0.20),
                ),
              ),
            ),
            Positioned(
              top: 170,
              left: -90,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4F8EF7).withOpacity(0.14),
                ),
              ),
            ),
            Positioned(
              bottom: -130,
              right: -60,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF7A93FF).withOpacity(0.18),
                ),
              ),
            ),
            me == null
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  )
                : _isAdmin
                // --- ส่วนที่เปลี่ยนสำหรับหน้า Admin ---
                ? Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: Colors.white.withOpacity(0.72),
                            border: Border.all(
                              color: const Color(0xFF95B1DF),
                              width: 1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14243B63),
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _searchCtrl,
                                  onChanged: _onSearchChanged,
                                  decoration: InputDecoration(
                                    hintText: 'ค้นหาชื่อคลาส',
                                    hintStyle: const TextStyle(
                                      color: Color(0xFF6B7FA8),
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      color: Color(0xFF325DAB),
                                    ),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.clear,
                                              color: Color(0xFF325DAB),
                                            ),
                                            onPressed: () {
                                              _searchCtrl.clear();
                                              _onSearchChanged('');
                                            },
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: const Color(0xFFFFFFFF),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF9EB8E7),
                                        width: 1,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF9EB8E7),
                                        width: 1,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: AppColors.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _searchQuery.trim().isEmpty
                                        ? 'คลาสล่าสุด'
                                        : 'ผลการค้นหาสำหรับ "$_searchQuery"',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF213A63),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _AdminClasses(
                          futureAll: _futureAllClasses,
                          onArchive: _adminArchiveClass,
                          onRefresh: _refresh,
                        ),
                      ),
                    ],
                  )
                // ---------------------------------
                : (_isTeacher
                      ? _TeacherClasses(
                          futureTaught: _futureTaught,
                          onRefresh: _refresh,
                        )
                      : _StudentClasses(
                          futureJoined: _futureJoined,
                          onRefresh: _refresh,
                        )),
          ],
        ),
      ),
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
  final Future<void> Function(String classId, String className) onArchive;
  const _AdminClasses({
    required this.futureAll,
    required this.onRefresh,
    required this.onArchive,
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
                  side: BorderSide(color: color.withOpacity(0.35), width: 1),
                ),
                elevation: 3,
                shadowColor: const Color(0x1A2F4A78),
                color: Colors.white.withOpacity(0.94),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.30),
                    child: Icon(
                      Icons.class_,
                      color: Color.alphaBlend(const Color(0x33000000), color),
                    ),
                  ),
                  title: Text(
                    it.name,
                    style: const TextStyle(
                      color: Color(0xFF1C2C47),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Teacher: ${it.teacherName}  •  Students: ${it.studentCount}',
                    style: const TextStyle(color: Color(0xFF334155)),
                  ),
                  // แอดมิน: มีปุ่มเก็บคลาสเท่านั้น
                  trailing: IconButton(
                    tooltip: 'เก็บคลาส',
                    onPressed: () => onArchive(it.classId, it.name),
                    icon: const Icon(
                      Icons.archive_outlined,
                      color: Color(0xFF415A84),
                    ),
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
            const Icon(Icons.class_, size: 64, color: AppColors.primary),
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
    final deepColor = Color.alphaBlend(const Color(0x22000000), color);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 6,
      shadowColor: const Color(0x24243B63),
      margin: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
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
                  description: c.description,
                ),
              ),
            );
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      deepColor.withOpacity(0.95),
                      deepColor.withOpacity(0.78),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.06),
                      Colors.black.withOpacity(0.18),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: PopupMenuButton<String>(
                constraints: const BoxConstraints(
                  minWidth: 90, // ปรับให้แคบลง
                  maxWidth: 120, // ไม่ให้กว้างเกินนี้
                ),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_vert, color: Colors.white),
                ),
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
                          'เก็บคลาส',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        content: const Text(
                          'ต้องการเก็บคลาสนี้ใช่หรือไม่?',
                          style: TextStyle(fontSize: 15),
                        ),
                        actionsAlignment: MainAxisAlignment.center,
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
                              backgroundColor: AppColors.primary,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('เก็บ'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await ClassService.deleteClassroom(c.classId!);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('จัดเก็บคลาสสำเร็จ')),
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
                              backgroundColor: AppColors.error,
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
                        PopupMenuItem(
                          value: 'edit',
                          height: 28,
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('แก้ไข'),
                        ),
                        PopupMenuDivider(height: 2),
                        PopupMenuItem(
                          value: 'delete',
                          height: 28,
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('เก็บ'),
                        ),
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
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: Colors.white.withOpacity(0.90),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          c.teacher?.username ?? c.teacher?.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.92),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isTeacher ? 'Teacher Class' : 'Joined Class',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
