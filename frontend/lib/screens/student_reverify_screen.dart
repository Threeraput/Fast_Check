// lib/screens/student_reverify_screen.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../utils/image_utils.dart';
import '../utils/location_helper.dart';
import '../services/attendance_service.dart';

class StudentReverifyScreen extends StatefulWidget {
  final String sessionId; // ต้องส่ง session ที่กำลังเปิดอยู่ของคลาสนี้
  const StudentReverifyScreen({super.key, required this.sessionId});

  @override
  State<StudentReverifyScreen> createState() => _StudentReverifyScreenState();
}

class _StudentReverifyScreenState extends State<StudentReverifyScreen> {
  CameraController? _controller;
  late Future<void> _init;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _init = _bootstrap();
  }

  Future<void> _bootstrap() async {
    final cams = await availableCameras();
    _controller = CameraController(
      cams.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _controller!.initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _doReverify() async {
    if (_busy) return;
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    setState(() => _busy = true);
    try {
      // ถ่ายรูป + normalize
      final shot = await c.takePicture();
      final normalized = await normalizeAndSaveJpeg(
        shot.path,
        maxWidth: 1600,
        jpegQuality: 92,
      );

      // GPS
      final pos = await LocationHelper.getCurrentPositionOrThrow();

      // call API
      await AttendanceService.reVerify(
        sessionId: widget.sessionId,
        imagePath: normalized,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ยืนยันตัวตนซ้ำสำเร็จ')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ยืนยันตัวตนซ้ำ (กลางคาบ)'),
        backgroundColor: Colors.transparent, // ✅ โปร่งใส
        elevation: 0, // ✅ ตัดเงาออก
        foregroundColor: Colors.white, // ✅ เปลี่ยนสีไอคอนเป็นดำ
      ),
      body: FutureBuilder(
        future: _init,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(snap.error.toString()));
          }
          return Stack(
            children: [
              CameraPreview(_controller!),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: FloatingActionButton.extended(
                    onPressed: _busy ? null : _doReverify,
                    icon: const Icon(Icons.verified),
                    label: Text(_busy ? 'กำลังยืนยัน...' : 'ยืนยันตอนนี้'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
