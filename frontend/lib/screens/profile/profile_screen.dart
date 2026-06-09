import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:frontend/models/users.dart';
import 'package:frontend/services/user_service.dart';
import 'package:frontend/services/face_service.dart'; // เพิ่ม import นี้
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _me;
  Map<String, dynamic>? _faceSample; // เพิ่มตัวแปรเก็บข้อมูลใบหน้า
  bool _loading = true;
  bool _saving = false;

  // โหมดแก้ไข: ปิดอยู่โดยค่าเริ่มต้น
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
    setState(() {
      _loading = true;
    });
    try {
      final fresh = await UserService.fetchMe(); // โหลดล่าสุด (มี avatar_url)
      _applyUser(fresh);
      
      // เพิ่ม: โหลดข้อมูลใบหน้าถ้าเป็นนักเรียน
      if (_hasRole('student')) {
        final face = await FaceService.getMyFaceSample();
        setState(() {
          _faceSample = face;
        });
      }

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('โหลดโปรไฟล์ไม่สำเร็จ: $e')));
      }
    }
  }

  void _applyUser(User u) {
    _me = u;
    _usernameCtrl.text = u.username;
    _firstNameCtrl.text = u.firstName ?? '';
    _lastNameCtrl.text = u.lastName ?? '';
  }

  void _toggleEdit() {
    setState(() => _editing = true);
  }

  void _cancelEdit() {
    if (_me != null) _applyUser(_me!);
    setState(() => _editing = false);
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_me == null || !_editing) return; // อนุญาตเมื่ออยู่ในโหมดแก้ไข
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (res == null || res.files.isEmpty) return;

      final path = res.files.single.path;
      if (path == null) return;

      setState(() => _saving = true);
      final updatedUser = await UserService.uploadAvatar(File(path));
      setState(() {
        _applyUser(updatedUser);
        _saving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปโหลดรูปโปรไฟล์สำเร็จ')),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('อัปโหลดรูปไม่สำเร็จ: $e')));
      }
    }
  }

  Future<void> _deleteAvatar() async {
    if (_me == null || !_editing) return; // อนุญาตเมื่ออยู่ในโหมดแก้ไข
    try {
      setState(() => _saving = true);
      final updatedUser = await UserService.deleteAvatar();
      setState(() {
        _applyUser(updatedUser);
        _saving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ลบรูปโปรไฟล์สำเร็จ')));
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ลบรูปไม่สำเร็จ: $e')));
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_me == null) return;
    try {
      setState(() => _saving = true);
      // ไม่อัปเดตรหัสนักเรียน/อาจารย์ในหน้าโปรไฟล์
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('บันทึกโปรไฟล์สำเร็จ')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
      }
    }
  }

  // ===== Helpers =====
  bool _hasRole(String role) => _me?.roles.contains(role) ?? false;
  String? _nz(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

  @override
  Widget build(BuildContext context) {
    final me = _me;

    return Scaffold(
      backgroundColor: Colors.grey[50], // พื้นหลังสีเทาอ่อนให้ดูสะอาด
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        title: const Text('โปรไฟล์ของฉัน', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_editing) ...[
            IconButton(
              onPressed: _saving ? null : _saveProfile,
              icon: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, color: Colors.white),
            ),
            IconButton(
              onPressed: _saving ? null : _cancelEdit,
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ] else
            IconButton(
              tooltip: 'แก้ไขโปรไฟล์',
              icon: const Icon(Icons.edit_note),
              onPressed: _toggleEdit,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : me == null
              ? const Center(child: Text('ไม่พบข้อมูลผู้ใช้'))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // ===== Header ส่วนบน =====
                      _buildHeader(me),

                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ===== ข้อมูลส่วนตัว =====
                            _buildSectionTitle('ข้อมูลส่วนตัว'),
                            _buildInfoCard([
                              _buildInfoTile(Icons.email_outlined, 'อีเมล', me.email ?? '-', isReadOnly: true),
                              _buildEditableTile(Icons.person_outline, 'ชื่อผู้ใช้', _usernameCtrl),
                              _buildEditableTile(Icons.badge_outlined, 'ชื่อจริง', _firstNameCtrl),
                              _buildEditableTile(Icons.badge_outlined, 'นามสกุล', _lastNameCtrl),
                            ]),

                            const SizedBox(height: 20),

                            // ===== ข้อมูลการเรียน/การทำงาน =====
                            _buildSectionTitle('ข้อมูลตัวตนในระบบ'),
                            _buildInfoCard([
                              if (_hasRole('teacher') && _nz(me.teacherId) != null)
                                _buildInfoTile(Icons.school_outlined, 'รหัสอาจารย์', me.teacherId!, isReadOnly: true),
                              if (_hasRole('student') && _nz(me.studentId) != null)
                                _buildInfoTile(Icons.badge, 'รหัสนักเรียน', me.studentId!, isReadOnly: true),
                              _buildInfoTile(Icons.verified_user_outlined, 'บทบาท', me.roles.join(', ').toUpperCase(), isReadOnly: true),
                            ]),

                            const SizedBox(height: 20),

                            // ===== ส่วนแสดงใบหน้า =====
                            if (_hasRole('student')) ...[
                              _buildSectionTitle('ใบหน้าที่ลงทะเบียนไว้'),
                              _buildFaceCard(),
                            ],
                            
                            const SizedBox(height: 32),
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
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.blueAccent,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 54,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blueGrey[50],
                  backgroundImage: imgUrl != null ? NetworkImage(imgUrl) : null,
                  child: imgUrl == null
                      ? Text(me.username[0].toUpperCase(), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold))
                      : null,
                ),
              ),
              if (_editing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 18,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, size: 18, color: Colors.blueAccent),
                      onPressed: _pickAndUploadAvatar,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${me.firstName ?? ''} ${me.lastName ?? ''}'.trim().isNotEmpty 
              ? '${me.firstName} ${me.lastName}' 
              : me.username,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              me.roles.first.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[700], letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value, {bool isReadOnly = false}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 20, color: Colors.blueAccent),
      ),
      title: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)),
    );
  }

  Widget _buildEditableTile(IconData icon, String label, TextEditingController controller) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _editing ? Colors.orange[50] : Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: _editing ? Colors.orange : Colors.blueAccent),
      ),
      title: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      subtitle: _editing
          ? TextField(
              controller: controller,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8), border: InputBorder.none),
            )
          : Text(controller.text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildFaceCard() {
    if (_faceSample == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.face_retouching_off, size: 20, color: Colors.grey[400]),
          ),
          title: const Text('ยังไม่ได้ลงทะเบียนใบหน้า', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
      );
    }

    final imageUrl = UserService.absoluteAvatarUrl(_faceSample!['image_url']) ?? '';
    final dateStr = DateFormat('dd MMM yyyy HH:mm').format(DateTime.parse(_faceSample!['created_at']));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
      child: ListTile(
        onTap: () => _showFacePreview(imageUrl, dateStr), // กดเพื่อขยาย
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.face, size: 20, color: Colors.green),
        ),
        title: const Text('ใบหน้าที่ลงทะเบียนไว้', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text('ลงทะเบียนเมื่อ: $dateStr', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: const Icon(Icons.open_in_full, size: 18, color: Colors.grey),
      ),
    );
  }

  void _showFacePreview(String imageUrl, String dateStr) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.grey[100],
                    child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withOpacity(0.5),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text('ใบหน้ายืนยันตัวตน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('บันทึกเมื่อ: $dateStr', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ปิด'),
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
