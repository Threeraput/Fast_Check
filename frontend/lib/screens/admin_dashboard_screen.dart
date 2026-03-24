import 'package:flutter/material.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/models/users.dart';
import 'package:frontend/models/admin.dart';
import 'package:frontend/services/admin_service.dart';
// ✅ ใช้สำหรับ URL รูปโปรไฟล์จริง
import 'package:frontend/services/user_service.dart';

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
  DateTime? _start;
  DateTime? _end;

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

  // ✅ helper แสดงรูปโปรไฟล์จริง ถ้าไม่มีใช้ตัวอักษรแรกแทน
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
      final me = await AuthService.getCurrentUserFromLocal();
      final isAdmin = me?.roles.any((r) => r.toLowerCase() == 'admin') == true;
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
        title: const Text('ยืนยันการลบผู้ใช้'),
        content: Text('ต้องการลบผู้ใช้ "${u.displayName}" ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AdminService.deleteUser(u.userId);
      if (!mounted) return;
      setState(() {
        _page = _page == null
            ? null
            : AdminUsersPage(
                total: (_page!.total - 1).clamp(0, 1 << 31),
                limit: _page!.limit,
                offset: _page!.offset,
                items: _page!.items.where((e) => e.userId != u.userId).toList(),
              );
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ลบผู้ใช้สำเร็จ')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ลบไม่สำเร็จ: $e')));
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
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _deleteUser(u),
                      tooltip: 'ลบผู้ใช้',
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
      final s = await AdminService.getSystemSummary(start: _start, end: _end);
      setState(() => _summary = s);
    } catch (e) {
      _reportErr = e.toString();
    } finally {
      if (mounted) setState(() => _loadingReport = false);
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 1, 1, 1);
    final last = DateTime(now.year + 1, 12, 31);
    final range = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDateRange: (_start != null && _end != null)
          ? DateTimeRange(start: _start!, end: _end!)
          : null,
    );
    if (range != null) {
      setState(() {
        _start = DateTime(range.start.year, range.start.month, range.start.day);
        _end = DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
          23,
          59,
          59,
        );
      });
      _loadSummary();
    }
  }

  Widget _metricCard(String title, int value, {Color? color}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color ?? Colors.blueAccent,
              ),
            ),
          ],
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
        Row(
          children: [
            // Expanded(
            //   child: OutlinedButton.icon(
            //     onPressed: _pickRange,
            //     icon: const Icon(Icons.event),
            //     label: Text(
            //       (_start != null && _end != null)
            //           ? '${_start!.toLocal().toString().substring(0, 10)} - ${_end!.toLocal().toString().substring(0, 10)}'
            //           : 'เลือกช่วงเวลา',
            //     ),
            //   ),
            // ),
            // const SizedBox(width: 8),
            // TextButton(
            //   onPressed: () {
            //     setState(() {
            //       _start = null;
            //       _end = null;
            //     });
            //     _loadSummary();
            //   },
            //   child: const Text('ล้างช่วงเวลา'),
            // ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _metricCard('ผู้ใช้ทั้งหมด', s.totalUsers),
            _metricCard('Admins', s.totalAdmins),
            _metricCard('Teachers', s.totalTeachers),
            _metricCard('Students', s.totalStudents),
            _metricCard('คลาสทั้งหมด', s.totalClasses, color: Colors.teal),
            _metricCard(
              'เช็คชื่อทั้งหมด',
              s.totalAttendances,
              color: Colors.indigo,
            ),
            // _metricCard(
            //   'เช็คชื่อในช่วงเวลา',
            //   s.totalAttendancesInRange,
            //   color: Colors.purple,
            // ),
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
            leading: _avatarFor(user, radius: 20), // ✅ ใช้รูปจริง
            title: Text(user.displayName),
            subtitle: Text('อีเมล: ${user.email ?? '-'}'),
            trailing: ElevatedButton(
              onPressed: () => _approveTeacher(user.userId),
              child: const Text('อนุมัติ'),
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
          tabs: const [
            Tab(icon: Icon(Icons.group), text: 'Users'),
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Reports'),
            Tab(icon: Icon(Icons.how_to_reg_outlined), text: 'Approvals'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_usersTab(), _reportsTab(), _approvalsTab()],
      ),
    );
  }
}
 