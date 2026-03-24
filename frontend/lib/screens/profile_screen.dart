import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:frontend/models/users.dart';
import 'package:frontend/services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _me;
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
      appBar: AppBar(
        title: const Text('โปรไฟล์ของฉัน'),
        actions: [
          if (_editing) ...[
            TextButton(
              onPressed: _saving ? null : _saveProfile,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('บันทึก'),
            ),
            TextButton(
              onPressed: _saving ? null : _cancelEdit,
              child: const Text('ยกเลิก'),
            ),
          ] else
            IconButton(
              tooltip: 'แก้ไข',
              icon: const Icon(Icons.edit),
              onPressed: _toggleEdit,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : me == null
          ? const Center(child: Text('ไม่พบข้อมูลผู้ใช้'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ===== Avatar =====
                  Builder(
                    builder: (context) {
                      final imgUrl = UserService.absoluteAvatarUrl(
                        me.avatarUrl,
                      );
                      return Column(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.blueGrey.shade100,
                            backgroundImage: imgUrl != null
                                ? NetworkImage(imgUrl)
                                : null,
                            child: imgUrl == null
                                ? Text(
                                    me.username.isNotEmpty
                                        ? me.username[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 36,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: (!_editing || _saving)
                                    ? null
                                    : _pickAndUploadAvatar,
                                icon: const Icon(Icons.photo),
                                label: const Text('เปลี่ยนรูป'),
                              ),
                              const SizedBox(width: 8),
                              if (_nz(me.avatarUrl) != null)
                                TextButton.icon(
                                  onPressed: (!_editing || _saving)
                                      ? null
                                      : _deleteAvatar,
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    'ลบรูป',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // ===== Email (read-only) =====
                  TextFormField(
                    initialValue: me.email ?? '',
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'อีเมล (แก้ไขไม่ได้)',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ===== Username =====
                  TextField(
                    controller: _usernameCtrl,
                    enabled: _editing && !_saving,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อผู้ใช้',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ===== First / Last name =====
                  TextField(
                    controller: _firstNameCtrl,
                    enabled: _editing && !_saving,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อจริง',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _lastNameCtrl,
                    enabled: _editing && !_saving,
                    decoration: const InputDecoration(
                      labelText: 'นามสกุล',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ===== แสดงรหัสตามบทบาท (read-only) =====
                  if (_hasRole('teacher') && _nz(me.teacherId) != null) ...[
                    TextFormField(
                      initialValue: me.teacherId!,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'รหัสอาจารย์ (Teacher ID)',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_hasRole('student') && _nz(me.studentId) != null) ...[
                    TextFormField(
                      initialValue: me.studentId!,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'รหัสนักเรียน (Student ID)',
                        prefixIcon: Icon(Icons.badge),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // หมายเหตุ: ไม่เปิดให้แก้ studentId/teacherId ที่หน้าจอนี้
                ],
              ),
            ),
    );
  }
}
