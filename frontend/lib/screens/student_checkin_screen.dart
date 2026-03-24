// lib/screens/student_checkin_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/location_helper.dart';
import '../services/attendance_service.dart';

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

  @override
  void initState() {
    super.initState();
    _init = _bootstrap();
  }

  Future<void> _bootstrap() async {
    // 1) หา session ที่ active ของคลาสนี้ (รองรับหลาย schema)
    final sessions = await AttendanceService.getActiveSessions();
    final matched = sessions.firstWhere((m) {
      final cid =
          (m['class_id']?.toString()) ??
          (m['classId']?.toString()) ??
          ((m['class'] is Map)
              ? (m['class']['id']?.toString() ??
                    m['class']['class_id']?.toString())
              : null);
      return cid == widget.classId;
    }, orElse: () => {});

    _sessionId = matched['session_id']?.toString() ?? matched['id']?.toString();
    if (_sessionId == null) {
      throw Exception('ยังไม่มีประกาศเช็คชื่อสำหรับคลาสนี้');
    }
  }

  /// เปิดหน้า /verify-face แล้วคาดหวังผลลัพธ์กลับมา
  /// รองรับ:
  /// - Map: {"verified": true, "imagePath": "/path/to/selfie.jpg", "score": 0.87}
  /// - String: "/path/to/selfie.jpg" (ถือว่า verified = true)
  /// - true / 'success' (แต่ควรส่ง path มาด้วยเพื่ออัปโหลดใน check-in)
  Future<Map<String, dynamic>?> _openVerifyFace() async {
    final res = await Navigator.pushNamed(context, '/verify-face');
    if (!mounted) return null;

    if (res == null) return null;

    if (res is Map<String, dynamic>) {
      return res;
    }

    if (res is String) {
      return {"verified": true, "imagePath": res};
    }

    if (res == true || res == 'success') {
      // กรณีหน้า verify-face ทำ upload เองทั้งหมดและฝั่ง Check-in ไม่ต้องใช้รูป
      // แต่โปรเจกต์นี้คาดหวังส่งรูปใน check-in ด้วย ดังนั้น return null จะให้แจ้งเตือนผู้ใช้
      return {"verified": true};
    }

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

    setState(() => _busy = true);
    try {
      // 1) ไปหน้า verify-face
      final face = await _openVerifyFace();
      if (face == null) throw Exception('ยกเลิกการตรวจสอบใบหน้า');

      final verified = (face['verified'] == true);
      final imagePath = (face['imagePath'] ?? face['path'])?.toString();

      if (!verified) {
        throw Exception('ตรวจสอบใบหน้าไม่สำเร็จ กรุณาลองใหม่');
      }
      if (imagePath == null || imagePath.isEmpty) {
        // ถ้าหน้า /verify-face ไม่ส่ง path รูปกลับมา แต่คุณยังต้องอัปโหลดรูปใน check-in → แจ้งผู้ใช้
        throw Exception(
          'ไม่พบไฟล์รูปจาก /verify-face (imagePath). กรุณาแก้ให้ route ส่ง imagePath กลับมา',
        );
      }

      // (ออปชัน) ใช้ค่าความมั่นใจขั้นต่ำ ถ้า /verify-face ส่ง score มา
      final score = (face['score'] is num)
          ? (face['score'] as num).toDouble()
          : null;
      if (score != null && score < 0.6) {
        throw Exception(
          'ความมั่นใจต่ำเกินไป (${(score * 100).toStringAsFixed(0)}%) กรุณาลองถ่ายใหม่',
        );
      }

      // 2) GPS
      final pos = await LocationHelper.getCurrentPositionOrThrow();

      // 3) ส่งเช็คชื่อ (อัปโหลดรูป + พิกัด)
      await AttendanceService.checkIn(
        sessionId: _sessionId!,
        imagePath: imagePath,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('เช็คชื่อสำเร็จ')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      final msg = e.toString().replaceFirst('Exception: ', '');
      print('🧩 [StudentCheckinScreen] error: $msg');

      // ✅ ตรวจว่ามีคำว่า 403 หรือข้อความที่เกี่ยวกับรัศมี
      if (msg.contains('403') ||
          msg.contains('นอกระยะ') ||
          msg.contains('รัศมี')) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              'อยู่นอกรัศมีที่กำหนด',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'คุณอยู่นอกพื้นที่ที่อาจารย์กำหนดไว้สำหรับการเช็คชื่อ\n'
              'กรุณาเข้าใกล้พื้นที่ที่กำหนดและลองใหม่อีกครั้ง',
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.blueAccent
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  style: TextStyle(
                    color: Colors.white
                  ),
                  'ตกลง'),
              ),
            ],
          ),
        );
      } else {
        // 🧩 Error อื่น ๆ แสดง SnackBar ตามปกติ
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เช็คชื่อด้วยใบหน้า')),
      body: FutureBuilder(
        future: _init,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(snap.error.toString()));
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.verified_user),
                    title: const Text('ยืนยันตัวตนด้วยใบหน้า'),
                    subtitle: const Text(
                      'ระบบจะพาคุณไปยังหน้าตรวจสอบใบหน้า (/verify-face)',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.my_location),
                    title: const Text('ใช้ตำแหน่งปัจจุบัน'),
                    subtitle: const Text(
                      'ต้องเปิด Location เพื่อยืนยันการเช็คชื่อ',
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: _busy ? null : _checkIn,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle),
                    label: Text(
                      _busy ? 'กำลังเช็คชื่อ...' : 'เช็คชื่อเดี๋ยวนี้',
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
}
