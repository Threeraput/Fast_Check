import 'package:flutter/material.dart';
// 🚨 เปลี่ยน Path import ด้านล่างให้ตรงกับโปรเจกต์ของคุณด้วยนะครับ
import 'package:frontend/models/users.dart'; 
import 'package:frontend/models/admin.dart'; 
import 'package:frontend/services/admin_service.dart';

class AdminTrashScreen extends StatefulWidget {
  const AdminTrashScreen({super.key});

  @override
  State<AdminTrashScreen> createState() => _AdminTrashScreenState();
}

class _AdminTrashScreenState extends State<AdminTrashScreen> {
  AdminUsersPage? _page;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  // 🗑️ โหลดรายชื่อผู้ใช้ที่อยู่ในถังขยะ
  Future<void> _loadTrash() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await AdminService.listTrashUsers(limit: 100);
      if (!mounted) return;
      setState(() {
        _page = page;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ♻️ ฟังก์ชันกู้คืน User
  Future<void> _restore(User u) async {
    // 1. ถามยืนยันเพื่อป้องกันแอดมินมือลั่น
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการกู้คืน'),
        content: Text('ต้องการกู้คืนผู้ใช้ "${u.displayName}" กลับสู่ระบบใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('กู้คืน'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    // 2. ยิง API กู้คืน
    try {
      await AdminService.restoreUser(u.userId);
      if (!mounted) return;

      // 3. นำชื่อที่กู้คืนสำเร็จออกจากหน้าจอถังขยะทันที
      setState(() {
        if (_page != null) {
          _page = AdminUsersPage(
            total: (_page!.total - 1).clamp(0, 1 << 31),
            limit: _page!.limit,
            offset: _page!.offset,
            items: _page!.items.where((e) => e.userId != u.userId).toList(),
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กู้คืนผู้ใช้สำเร็จแล้ว'),
          backgroundColor: Colors.green, // สีเขียวให้รู้ว่าสำเร็จ
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('กู้คืนไม่สำเร็จ: $e'), 
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _page?.items ?? const <User>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('ถังขยะ'),
        backgroundColor: Colors.red.shade50, // สีแดงอ่อนๆ ให้รู้ว่าไม่ใช่หน้าปกติ
        foregroundColor: Colors.red.shade900,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('เกิดข้อผิดพลาด: $_error'))
              : items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline, size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'ถังขยะว่างเปล่า',
                            style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadTrash,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final u = items[i];
                          final rolesLabel = (u.roles).join(', ');
                          
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey.shade300,
                              child: const Icon(Icons.person_off, color: Colors.grey),
                            ),
                            title: Text(
                              u.displayName,
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough, // ลูกเล่น: ขีดฆ่าชื่อ
                                color: Colors.grey,
                              ),
                            ),
                            subtitle: Text('${u.email ?? '-'}  •  $rolesLabel'),
                            trailing: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade50,
                                foregroundColor: Colors.green.shade700,
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.restore, size: 18),
                              label: const Text('กู้คืน'),
                              onPressed: () => _restore(u),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}