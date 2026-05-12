// lib/screens/student_checkin_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/location_helper.dart';
import '../../services/attendance_service.dart';

class StudentCheckinScreen extends StatefulWidget {
  final String classId;
  const StudentCheckinScreen({super.key, required this.classId});

  @override
  State<StudentCheckinScreen> createState() => _StudentCheckinScreenState();
}

class _StudentCheckinScreenState extends State<StudentCheckinScreen> {
  late Future<void> _init;
  String? _sessionId;
  bool _busy = false;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _init = _bootstrap();
  }

  Future<void> _bootstrap() async {
    final sessions = await AttendanceService.getActiveSessions();
    final matched = sessions.firstWhere((m) {
      final cid = (m['class_id']?.toString()) ??
          (m['classId']?.toString()) ??
          ((m['class'] is Map)
              ? (m['class']['id']?.toString() ?? m['class']['class_id']?.toString())
              : null);
      return cid == widget.classId;
    }, orElse: () => {});

    _sessionId = matched['session_id']?.toString() ?? matched['id']?.toString();
    if (_sessionId == null) {
      throw Exception('ยังไม่มีประกาศเช็คชื่อสำหรับคลาสนี้');
    }
  }

  String _friendlyCheckinError(dynamic e) {
    if (e is ApiException) {
      final msg = e.message.toLowerCase();
      final code = e.statusCode;

      if (code == 403 || msg.contains('location check failed') || msg.contains('อยู่นอก')) {
        return 'คุณอยู่นอกพื้นที่ที่อาจารย์กำหนดไว้สำหรับการเช็คชื่อ';
      }
      if (code == 400 && (msg.contains('no face') || msg.contains('not found'))) {
        return 'ไม่พบใบหน้าในภาพ กรุณาถ่ายใหม่ให้เห็นใบหน้าชัดเจน';
      }
      if (code == 400 && msg.contains('exactly one face')) {
        return 'กรุณาถ่ายภาพที่มีใบหน้าเพียง 1 คนเท่านั้น';
      }
      if (code == 409) {
        return 'คุณได้ทำการเช็คชื่อในคาบเรียนนี้ไปเรียบร้อยแล้ว';
      }
      if (code == 401) {
        return 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่อีกครั้ง';
      }
      if (code == 500) {
        return 'ระบบเซิร์ฟเวอร์ขัดข้องชั่วคราว กรุณาลองใหม่อีกครั้ง';
      }
      return e.message;
    }
    
    final errStr = e.toString().toLowerCase();
    if (errStr.contains('timeout')) return 'การเชื่อมต่อล่าช้าเกินไป กรุณาตรวจสอบอินเทอร์เน็ต';
    if (errStr.contains('permission denied')) return 'กรุณาอนุญาตให้แอปเข้าถึงตำแหน่ง (GPS) เพื่อเช็คชื่อ';
    
    return e.toString().replaceFirst('Exception: ', '');
  }

  Future<Map<String, dynamic>?> _openVerifyFace() async {
    final res = await Navigator.pushNamed(context, '/verify-face');
    if (!mounted) return null;
    if (res == null) return null;
    if (res is Map<String, dynamic>) return res;
    if (res is String) return {"verified": true, "imagePath": res};
    if (res == true || res == 'success') return {"verified": true};
    return null;
  }

  Future<void> _checkIn() async {
    if (_busy) return;
    if (_sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยังไม่มีประกาศเช็คชื่อสำหรับคลาสนี้')),
      );
      return;
    }

    setState(() {
      _busy = true;
      _statusText = 'กำลังเตรียมความพร้อม...';
    });

    try {
      setState(() => _statusText = 'กำลังตรวจสอบใบหน้า...');
      final face = await _openVerifyFace();
      if (face == null) {
        setState(() => _busy = false);
        return;
      }

      final verified = (face['verified'] == true);
      final imagePath = (face['imagePath'] ?? face['path'])?.toString();

      if (!verified) throw Exception('ตรวจสอบใบหน้าไม่สำเร็จ กรุณาลองใหม่');
      if (imagePath == null) throw Exception('ไม่พบข้อมูลรูปภาพใบหน้า');

      setState(() => _statusText = 'กำลังค้นหาพิกัด GPS...');
      final pos = await LocationHelper.getCurrentPositionOrThrow();

      setState(() => _statusText = 'กำลังบันทึกการเช็คชื่อ...');
      await AttendanceService.checkIn(
        sessionId: _sessionId!,
        imagePath: imagePath,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('เช็คชื่อสำเร็จเรียบร้อยแล้ว'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = _friendlyCheckinError(e);

      if (e.statusCode == 403 || msg.contains('นอกพื้นที่')) {
        await _showOutOfRangeDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = _friendlyCheckinError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showOutOfRangeDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.location_off, size: 64, color: Colors.red),
        title: const Text('อยู่นอกพื้นที่เช็คชื่อ', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('คุณอยู่ห่างจากห้องเรียนเกินไป', textAlign: TextAlign.center),
            SizedBox(height: 12),
            Text(
              '💡 คำแนะนำ: กรุณาเข้าใกล้ห้องเรียนมากขึ้น และตรวจสอบว่าเปิด GPS ความแม่นยำสูงแล้ว',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () => Navigator.pop(context),
              child: const Text('ตกลง'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('เช็คชื่อเข้าเรียน', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder(
        future: _init,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('เกิดข้อผิดพลาด: ${_friendlyCheckinError(snap.error)}', textAlign: TextAlign.center),
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildInfoCard(
                  Icons.verified_user_outlined,
                  'ยืนยันตัวตน',
                  'แอปจะเปิดกล้องเพื่อตรวจสอบใบหน้าของคุณ',
                  Colors.blue,
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  Icons.location_on_outlined,
                  'ตรวจสอบพิกัด',
                  'คุณต้องอยู่ภายในระยะที่อาจารย์กำหนด',
                  Colors.green,
                ),
                const SizedBox(height: 16),
                _buildWarningCard(),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    onPressed: _busy ? null : _checkIn,
                    icon: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Icon(Icons.check_circle_outline, size: 24),
                    label: Text(
                      _busy ? _statusText : 'เริ่มการเช็คชื่อ',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String subtitle, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      ),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[100]!),
      ),
      child: Row(
        children: [
          Icon(Icons.tips_and_updates_outlined, color: Colors.orange[800]),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'ห้ามมีบุคคลอื่นอยู่ในเฟรมขณะสแกนหน้า เพื่อความถูกต้องของระบบ',
              style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
