import 'package:flutter/material.dart';
import 'package:frontend/screens/admin/admin_trash_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/models/users.dart';
import 'package:frontend/models/admin.dart';
import 'package:frontend/services/admin_service.dart';
// ใช้สำหรับ URL รูปโปรไฟล์จริง
import 'package:frontend/services/user_service.dart';
import 'package:frontend/utils/app_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _guarding = true;
  String? _guardErr;

  // Users tab state
  final _searchCtrl = TextEditingController();
  String _role = 'all'; // all|admin|teacher|student
  bool _loadingUsers = true;
  String? _usersErr;
  AdminUsersPage? _page;

  // Reports tab state
  bool _loadingReport = true;
  String? _reportErr;
  SystemSummary? _summary;

  // Approvals tab state (ใช้ของเดิม)
  List<User> _pendingTeachers = [];
  bool _loadingPending = true;
  String? _pendingErr;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _guardAndLoad();
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // helper แสดงรูปโปรไฟล์จริง ถ้าไม่มีใช้ตัวอักษรแรกแทน
  CircleAvatar _avatarFor(User u, {double radius = 20}) {
    final abs = UserService.absoluteAvatarUrl(u.avatarUrl);
    if (abs != null && abs.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(abs));
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

  Future<void> _guardAndLoad() async {
    setState(() {
      _guarding = true;
      _guardErr = null;
    });
    try {
      final tokenRoles = await AuthService.getTokenRoles();
      final isAdmin = tokenRoles.any((r) => r.toLowerCase() == 'admin');
      if (!isAdmin) {
        _guardErr = 'เฉพาะผู้ดูแลระบบเท่านั้น';
        if (mounted) Navigator.pop(context);
        return;
      }
      await Future.wait([
        _loadUsers(reset: true),
        _loadSummary(),
        _loadPending(),
      ]);
    } catch (e) {
      _guardErr = e.toString();
    } finally {
      if (mounted) {
        setState(() => _guarding = false);
      }
    }
  }

  // ===== Users Tab =====
  Future<void> _loadUsers({bool reset = false}) async {
    setState(() {
      _loadingUsers = true;
      _usersErr = null;
      if (reset) _page = null;
    });
    try {
      final nextOffset = reset
          ? 0
          : (_page?.offset ?? 0) + (_page?.items.length ?? 0);
      final roleParam = _role == 'all' ? null : _role;
      final res = await AdminService.listUsers(
        q: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        role: roleParam,
        limit: 50,
        offset: nextOffset,
      );
      setState(() {
        if (reset || _page == null) {
          _page = res;
        } else {
          _page = AdminUsersPage(
            total: res.total,
            limit: res.limit,
            offset: res.offset,
            items: [..._page!.items, ...res.items],
          );
        }
      });
    } catch (e) {
      _usersErr = e.toString();
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _deleteUser(User u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ย้ายผู้ใช้ลงถังขยะ'), // ✏️ เปลี่ยนข้อความ
        content: Text('ต้องการย้ายผู้ใช้ "${u.displayName}" ลงถังขยะใช่หรือไม่?\n(คุณสามารถกู้คืนได้ในภายหลัง)'), // ✏️ อธิบายเพิ่มว่ากู้คืนได้
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ย้ายลงถังขยะ'), // ✏️ เปลี่ยนข้อความปุ่ม
          ),
        ],
      ),
    );
    if (ok != true) return;
    
    try {
      // 🚀 ยิง API ไปลบ (ซึ่งหลังบ้านเราแก้ให้มันจับลงถังขยะแล้ว)
      await AdminService.deleteUser(u.userId);
      if (!mounted) return;
      
      setState(() {
        _page = _page == null
            ? null
            : AdminUsersPage(
                total: (_page!.total - 1).clamp(0, 1 << 31),
                limit: _page!.limit,
                offset: _page!.offset,
                // ตัดรายชื่อคนที่โดนลบออกจากหน้าจอ
                items: _page!.items.where((e) => e.userId != u.userId).toList(),
              );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ย้ายผู้ใช้ลงถังขยะเรียบร้อยแล้ว')), // ✏️ เปลี่ยนข้อความแจ้งเตือน
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  Widget _usersTab() {
    final items = _page?.items ?? const <User>[];
    final canLoadMore = (_page != null) && (items.length < _page!.total);
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              const SizedBox(width: 8),
              // ตัวกรอง (อยู่ฝั่งซ้าย)
              DropdownButton<String>(
                value: _role,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                  DropdownMenuItem(value: 'student', child: Text('Student')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _role = v);
                  _loadUsers(reset: true);
                },
              ),
              
              // 🌟 เพิ่ม Spacer() เพื่อดันปุ่มถังขยะไปชิดขวาสุด
              const Spacer(), 

              // 🌟 ปุ่มทางเข้าหน้าถังขยะ (อยู่ฝั่งขวา)
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.red),
                tooltip: 'ดูถังขยะ',
                onPressed: () async {
                  // กดแล้วให้ Navigate ไปที่หน้า AdminTrashScreen
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminTrashScreen(), // อย่าลืม import ไฟล์หน้านี้มาด้วยนะครับ
                    ),
                  );
                  // พอกด Back กลับมาจากหน้าถังขยะ (อาจจะมีการกู้คืน User) ให้รีเฟรชหน้าผู้ใช้ใหม่
                  _loadUsers(reset: true); 
                },
              ),
              const SizedBox(width: 8), // เว้นระยะขอบขวานิดนึงให้สวยงาม
            ],
          ),
        ),
        
        if (_loadingUsers)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_usersErr != null)
          Expanded(child: Center(child: Text('เกิดข้อผิดพลาด: $_usersErr')))
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadUsers(reset: true),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length + (canLoadMore ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  if (canLoadMore && i == items.length) {
                    return TextButton(
                      onPressed: () => _loadUsers(reset: false),
                      child: const Text('โหลดเพิ่ม'),
                    );
                  }
                  final u = items[i];
                  final rolesLabel = (u.roles).join(', ');
                  return ListTile(
                    leading: _avatarFor(u, radius: 20), // ✅ ใช้รูปจริง
                    title: Text(u.displayName),
                    subtitle: Text('${u.email ?? '-'}  •  $rolesLabel'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: AppColors.error),
                      onPressed: () => _deleteUser(u),
                      tooltip: 'ย้ายลงถังขยะ', // ✏️ เปลี่ยน tooltip ให้ชัดเจน
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  // ===== Reports Tab =====
  Future<void> _loadSummary() async {
    setState(() {
      _loadingReport = true;
      _reportErr = null;
    });
    try {
      final s = await AdminService.getSystemSummary();
      setState(() => _summary = s);
    } catch (e) {
      _reportErr = e.toString();
    } finally {
      if (mounted) setState(() => _loadingReport = false);
    }
  }

  Widget _metricCard({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
    required String badge,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 16),
            child: child,
          ),
        );
      },
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.24),
                          color.withValues(alpha: 0.10),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 9,
                        color: color,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reportsTab() {
    if (_loadingReport) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reportErr != null) {
      return Center(child: Text('เกิดข้อผิดพลาด: $_reportErr'));
    }
    final s = _summary;
    if (s == null) {
      return const Center(child: Text('ไม่พบข้อมูลรายงาน'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            _metricCard(
              title: 'ผู้ใช้ทั้งหมด',
              value: s.totalUsers,
              icon: Icons.groups_2_outlined,
              color: const Color(0xFF06B6D4),
              badge: 'ALL',
            ),
            _metricCard(
              title: 'Admins',
              value: s.totalAdmins,
              icon: Icons.admin_panel_settings_outlined,
              color: const Color(0xFF8B5CF6),
              badge: 'CORE',
            ),
            _metricCard(
              title: 'Teachers',
              value: s.totalTeachers,
              icon: Icons.school_outlined,
              color: const Color(0xFF3B82F6),
              badge: 'PRO',
            ),
            _metricCard(
              title: 'Students',
              value: s.totalStudents,
              icon: Icons.badge_outlined,
              color: const Color(0xFF14B8A6),
              badge: 'UNI',
            ),
            _metricCard(
              title: 'คลาสทั้งหมด',
              value: s.totalClasses,
              icon: Icons.class_outlined,
              color: const Color(0xFF0EA5E9),
              badge: 'ROOM',
            ),
            _metricCard(
              title: 'เช็คชื่อทั้งหมด',
              value: s.totalAttendances,
              icon: Icons.fact_check_outlined,
              color: const Color(0xFF6366F1),
              badge: 'LIVE',
            ),
          ],
        ),
      ],
    );
  }

  // ===== Approvals Tab (เหมือนเดิม) =====
  Future<void> _loadPending() async {
    setState(() {
      _loadingPending = true;
      _pendingErr = null;
    });
    try {
      _pendingTeachers = await AuthService.getPendingTeachers();
    } catch (e) {
      _pendingErr = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loadingPending = false);
    }
  }

  Future<void> _approveTeacher(String userId) async {
    try {
      await AuthService.approveTeacher(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('อนุมัติอาจารย์สำเร็จ')));
      _loadPending();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Widget _approvalsTab() {
    if (_loadingPending) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pendingErr != null) {
      return Center(child: Text(_pendingErr!));
    }
    if (_pendingTeachers.isEmpty) {
      return const Center(child: Text('ไม่มี Teacher ที่รอการอนุมัติ'));
    }
    return RefreshIndicator(
      onRefresh: _loadPending,
      child: ListView.builder(
        itemCount: _pendingTeachers.length,
        itemBuilder: (context, index) {
          final user = _pendingTeachers[index];
          return ListTile(
            leading: _avatarFor(user, radius: 20), // ใช้รูปจริง
            title: Text(user.displayName),
            subtitle: Text('อีเมล: ${user.email ?? '-'}'),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () => _approveTeacher(user.userId),
              child: const Text(
                'อนุมัติ',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_guarding) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_guardErr != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Dashboard')),
        body: Center(child: Text(_guardErr!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          overlayColor: WidgetStateProperty.all(
            Colors.transparent,
          ), // ปิดสี overlay ตอนกด
          tabs: const [
            Tab(
              icon: Icon(Icons.group, color: Colors.black),
              text: 'Users',
            ),
            Tab(
              icon: Icon(Icons.how_to_reg_outlined, color: Colors.black),
              text: 'Approvals',
            ),
            Tab(
              icon: Icon(Icons.analytics_outlined, color: Colors.black),
              text: 'Reports',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_usersTab(), _approvalsTab(), _reportsTab()],
      ),
    );
  }
}
