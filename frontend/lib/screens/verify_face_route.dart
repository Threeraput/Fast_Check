// lib/screens/verify_face_route.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'camera_screen.dart';

class VerifyFaceRoute extends StatefulWidget {
  /// true = ใช้สำหรับ re-verify (สุ่มตรวจซ้ำ) → ถ่ายแล้วคืนรูปให้หน้าเดิม
  final bool isReverifyMode;
  const VerifyFaceRoute({super.key, this.isReverifyMode = false});

  @override
  State<VerifyFaceRoute> createState() => _VerifyFaceRouteState();
}

class _VerifyFaceRouteState extends State<VerifyFaceRoute> {
  CameraDescription? _camera;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() => _error = 'ไม่พบกล้องบนอุปกรณ์');
        return;
      }
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      setState(() => _camera = front);
    } catch (e) {
      setState(() => _error = 'เปิดกล้องไม่สำเร็จ: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ยืนยันตัวตนด้วยใบหน้า')),
        body: Center(child: Text(_error!)),
      );
    }
    if (_camera == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isReverify = widget.isReverifyMode;

    // re-verify: ไม่ทำ verify/enroll ในกล้อง แต่คืน path กลับ
    return CameraScreen(
      camera: _camera!,
      isVerificationMode: !isReverify, // re-verify => false
      onImageCaptured: isReverify
          ? (String path) => Navigator.pop(context, path)
          : null,
    );
  }
}
