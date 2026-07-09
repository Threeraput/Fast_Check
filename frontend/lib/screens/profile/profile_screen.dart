// lib/screens/profile/profile_screen.dart
import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:frontend/models/users.dart';
import 'package:frontend/services/user_service.dart';
import 'package:frontend/services/face_service.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _me;
  Map<String, dynamic>? _faceSample;
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;

  final _usernameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMe() async {
    setState(() => _loading = true);
    try {
      final fresh = await UserService.fetchMe();
      _applyUser(fresh);
      if (_hasRole('student')) {
        final face = await FaceService.getMyFaceSample();
        _faceSample = face;
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('โหลดโปรไฟล์ไม่สำเร็จ: $e')));
    }
  }

  void _applyUser(User u) {
    _me = u;
    _usernameCtrl.text = u.username;
    _firstNameCtrl.text = u.firstName ?? '';
    _lastNameCtrl.text = u.lastName ?? '';
  }

  void _toggleEdit() => setState(() => _editing = true);
  void _cancelEdit() { if (_me != null) _applyUser(_me!); setState(() => _editing = false); }

  Future<void> _pickAndUploadAvatar() async {
    if (_me == null || !_editing) return;
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
      if (res == null || res.files.isEmpty || res.files.single.path == null) return;
      setState(() => _saving = true);
      final updatedUser = await UserService.uploadAvatar(File(res.files.single.path!));
      setState(() { _applyUser(updatedUser); _saving = false; });
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('อัปโหลดรูปไม่สำเร็จ: $e')));
    }
  }

  Future<void> _deleteAvatar() async {
    if (_me == null || !_editing) return;
    try {
      setState(() => _saving = true);
      final updatedUser = await UserService.deleteAvatar();
      setState(() { _applyUser(updatedUser); _saving = false; });
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ลบรูปไม่สำเร็จ: $e')));
    }
  }

  Future<void> _saveProfile() async {
    if (_me == null) return;
    try {
      setState(() => _saving = true);
      final updated = await UserService.updateUser(
        userId: _me!.userId,
        username: _usernameCtrl.text,
        firstName: _firstNameCtrl.text,
        lastName: _lastNameCtrl.text,
      );
      setState(() {
        _applyUser(updated);
        _saving = false;
        _editing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกโปรไฟล์สำเร็จ')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
    }
  }

  bool _hasRole(String role) => _me?.roles.contains(role) ?? false;
  String? _nz(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

  @override
  Widget build(BuildContext context) {
    final me = _me;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('โปรไฟล์ของฉัน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          if (_editing) ...[
            IconButton(onPressed: _saving ? null : _saveProfile, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check)),
            IconButton(onPressed: _saving ? null : _cancelEdit, icon: const Icon(Icons.close)),
          ] else
            IconButton(tooltip: 'แก้ไขโปรไฟล์', icon: const Icon(Icons.edit_note), onPressed: _toggleEdit),
        ],
      ),
      body: _loading
          ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
          : me == null
              ? const Center(child: Text('ไม่พบข้อมูลผู้ใช้', style: TextStyle(fontSize: 13)))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildHeader(me),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AppSectionTitle('ข้อมูลส่วนตัว'),
                            _GlassCard(
                              padding: const EdgeInsets.symmetric(vertical: 0),
                              child: Column(
                                children: [
                                  _buildInfoTile(Icons.email_outlined, 'อีเมล', me.email ?? '-', readOnly: true),
                                  Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
                                  _buildEditableTile(Icons.person_outline, 'ชื่อผู้ใช้', _usernameCtrl),
                                  Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
                                  _buildEditableTile(Icons.badge_outlined, 'ชื่อจริง', _firstNameCtrl),
                                  Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
                                  _buildEditableTile(Icons.badge_outlined, 'นามสกุล', _lastNameCtrl),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const AppSectionTitle('ข้อมูลตัวตนในระบบ'),
                            _GlassCard(
                              padding: const EdgeInsets.symmetric(vertical: 0),
                              child: Column(
                                children: [
                                  if (_hasRole('teacher') && _nz(me.teacherId) != null) ...[
                                    _buildInfoTile(Icons.school_outlined, 'รหัสอาจารย์', me.teacherId!, readOnly: true),
                                    Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
                                  ],
                                  if (_hasRole('student') && _nz(me.studentId) != null) ...[
                                    _buildInfoTile(Icons.badge, 'รหัสนักเรียน', me.studentId!, readOnly: true),
                                    Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
                                  ],
                                  _buildInfoTile(Icons.verified_user_outlined, 'บทบาท', me.roles.join(', ').toUpperCase(), readOnly: true),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_hasRole('student')) ...[
                              const AppSectionTitle('ใบหน้าที่ลงทะเบียนไว้'),
                              _buildFaceCard(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader(User me) {
    final imgUrl = UserService.absoluteAvatarUrl(me.avatarUrl);
    final displayName = '${me.firstName ?? ''} ${me.lastName ?? ''}'.trim().isNotEmpty
        ? '${me.firstName ?? ''} ${me.lastName ?? ''}'.trim()
        : me.username;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color.fromARGB(255, 37, 235, 232), Color.fromARGB(255, 224, 56, 182)]),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: AppColors.surfaceAlt,
                  backgroundImage: imgUrl != null ? NetworkImage(imgUrl) : null,
                  child: imgUrl == null ? Text(me.username[0].toUpperCase(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)) : null,
                ),
              ),
              if (_editing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.camera_alt, size: 16, color: AppColors.primary),
                      onPressed: _pickAndUploadAvatar,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          AppBadge(me.roles.first.toUpperCase(), color: Colors.white.withOpacity(0.18), textColor: Colors.white),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value, {bool readOnly = false}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
      title: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      subtitle: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      dense: true,
    );
  }

  Widget _buildEditableTile(IconData icon, String label, TextEditingController controller) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: _editing ? AppColors.warningLight : AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: _editing ? AppColors.warning : AppColors.primary),
      ),
      title: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      subtitle: _editing
          ? TextField(
              controller: controller,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8), border: InputBorder.none),
            )
          : Text(controller.text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      dense: true,
    );
  }

  Widget _buildFaceCard() {
    if (_faceSample == null) {
      return _GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 0),
        child: ListTile(
          leading: const Icon(Icons.face_retouching_natural, color: AppColors.primary),
          title: const Text('ยังไม่มีข้อมูลใบหน้า', style: TextStyle(fontSize: 13)),
          subtitle: const Text('ถ้าต้องการเปลี่ยนใบหน้า ให้ไปที่เมนูใน Drawer', style: TextStyle(fontSize: 12)),
          dense: true,
        ),
      );
    }
    return _GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.face, color: AppColors.primary),
            title: const Text('มีข้อมูลใบหน้าแล้ว', style: TextStyle(fontSize: 13)),
            subtitle: Text('อัปเดตล่าสุด: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}', style: const TextStyle(fontSize: 12)),
            dense: true,
          ),
          if (_editing) ...[
            Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextButton(onPressed: _deleteAvatar, child: const Text('ลบรูปโปรไฟล์')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.35),
                Colors.white.withValues(alpha: 0.2),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}