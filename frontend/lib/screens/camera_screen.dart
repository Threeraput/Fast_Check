// lib/screens/camera_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../utils/image_utils.dart';
import '../services/face_service.dart';
import '../services/face_service.dart' show ApiException;
import 'classroom_home_screen.dart';

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;
  final bool isVerificationMode; // true = verify-face, false = upload-face
  final void Function(String path)? onImageCaptured;

  const CameraScreen({
    super.key,
    required this.camera,
    this.isVerificationMode = false,
    this.onImageCaptured,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  late Future<void> _initializeControllerFuture;
  bool _isProcessing = false;
  bool _isCapturing = false;

  bool _consentGiven = false;
  bool _askedConsent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _initializeControllerFuture = _controller!
        .initialize()
        .then((_) async {
          if (!mounted) return;
          await _controller?.setFlashMode(FlashMode.off);
        })
        .catchError((e) {
          _showResultDialog('เปิดกล้องไม่สำเร็จ: $e', Colors.red);
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    final c = _controller;
    _controller = null;
    c?.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (controller.value.isStreamingImages) {
        controller.stopImageStream().catchError((_) {});
      }
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _controller = CameraController(
        widget.camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _initializeControllerFuture = _controller!
          .initialize()
          .then((_) async {
            if (!mounted) return;
            await _controller?.setFlashMode(FlashMode.off);
            setState(() {});
          })
          .catchError((e) {
            _showResultDialog('เปิดกล้องใหม่ไม่สำเร็จ: $e', Colors.red);
          });
      setState(() {});
    }
  }

  Future<void> _askForConsent() async {
    if (_askedConsent) return;
    _askedConsent = true;

    // โหมด verify ไม่ต้องถาม consent
     if (widget.isVerificationMode || widget.onImageCaptured != null) {
      setState(() => _consentGiven = true);
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,

      builder: (_) { // แบบ responsive เเล้ว
        // ขนาดหน้าจอ
        final screenWidth = MediaQuery.of(context).size.width;

        // ปรับขนาดตัวอักษรตามหน้าจอ
        double titleFontSize =
            screenWidth * 0.045; // ประมาณ 4.5% ของความกว้างหน้าจอ
        double contentFontSize = screenWidth * 0.04; // ประมาณ 4%
        double buttonFontSize = screenWidth * 0.04;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'ขออนุญาตเก็บข้อมูลใบหน้า',
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: contentFontSize,
                color: Colors.black87,
              ),
              children: const [
                TextSpan(
                  text:
                      'ระบบจะเก็บข้อมูลใบหน้าของคุณเพื่อใช้ในการยืนยันตัวตน\n',
                ),
                TextSpan(text: 'ในการเช็คชื่อในอนาคต\n\n'),
                TextSpan(text: 'คุณ '),
                TextSpan(
                  text: 'ยินยอม',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                TextSpan(text: ' ให้ระบบบันทึกข้อมูลนี้หรือไม่?'),
              ],
            ),
            textAlign: TextAlign.start,
          ),
          actions: [
            TextButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all<Color>(
                  Colors.grey[300]!,
                ),
                padding: MaterialStateProperty.all<EdgeInsets>(
                  EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.05,
                    vertical: screenWidth * 0.025,
                  ),
                ),
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'ไม่ยินยอม',
                style: TextStyle(fontSize: buttonFontSize, color: Colors.white),
              ),
            ),
            FilledButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all<Color>(
                  Colors.blueAccent,
                ),
                padding: MaterialStateProperty.all<EdgeInsets>(
                  EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.05,
                    vertical: screenWidth * 0.025,
                  ),
                ),
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'ยินยอม',
                style: TextStyle(fontSize: buttonFontSize, color: Colors.white),
              ),
            ),
          ],
          // กำหนดความกว้างของ Dialog แบบ responsive
          insetPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
        );
      },
    );

    if (result == true) {
      setState(() => _consentGiven = true);
    } else {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ClassroomHomeScreen()),
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Future.microtask(() => _askForConsent());
  }

  void _popVerifyResult(dynamic result) {
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

Future<void> _captureAndProcess() async {
    // ต้องให้ consent ก่อน ยกเว้น verify-mode หรือ re-verify (มี onImageCaptured)
    if (!_consentGiven &&
        !widget.isVerificationMode &&
        widget.onImageCaptured == null)
      return;

    final controller = _controller;
    if (_isProcessing || _isCapturing) return;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      setState(() => _isCapturing = true);
      await _initializeControllerFuture;

      final XFile file = await controller.takePicture();
      final normalizedPath = await normalizeAndSaveJpeg(
        file.path,
        maxWidth: 1600,
        jpegQuality: 92,
      );

      setState(() => _isProcessing = true);

      //  โหมด re-verify → คืน path กลับ (ไม่ upload/verify ในหน้านี้)
      if (widget.onImageCaptured != null) {
        widget.onImageCaptured!(normalizedPath);
        return;
      }

      //  โหมด verify
      if (widget.isVerificationMode) {
        final success = await FaceService.verifyFace(normalizedPath);
        if (!mounted) return;

        if (success) {
          _popVerifyResult({'verified': true, 'imagePath': normalizedPath});
        } else {
          _popVerifyResult({'verified': false});
        }
      }
      //  โหมด enroll (เพิ่มใบหน้า)
      else {
        await FaceService.uploadFace(normalizedPath);
        if (!mounted) return;
        _showResultDialog('อัปโหลดใบหน้าสำเร็จ', Colors.green);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (widget.isVerificationMode) {
        _popVerifyResult({'verified': false, 'error': e.message});
      } else {
        _showResultDialog(e.message, Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      if (widget.isVerificationMode) {
        _popVerifyResult({'verified': false, 'error': e.toString()});
      } else {
        _showResultDialog('เกิดข้อผิดพลาด: $e', Colors.red);
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _isCapturing = false;
      });
    }
  }


  void _showResultDialog(String message, Color color) {
    // ใช้เฉพาะโหมด upload-face เพื่อกลับหน้า home
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(message, style: TextStyle(color: color)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ClassroomHomeScreen()),
              );
            },
            child: const Text(
              style: TextStyle(color: Colors.black54),
              'OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

      final String appBarTitle = widget.onImageCaptured != null
        ? 'ยืนยันตัวตนซ้ำ (Re-verify)'
        : (widget.isVerificationMode
              ? 'ยืนยันตัวตนด้วยใบหน้า'
              : 'เพิ่มรูปภาพใบหน้า');

    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle),
        backgroundColor: Colors.transparent, // ✅ โปร่งใส
        elevation: 0, // ✅ ตัดเงาออก
        foregroundColor: Colors.black, // ✅ เปลี่ยนสีไอคอนเป็นดำ
      ),
      body: controller == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!_consentGiven && !widget.isVerificationMode) {
                  return const Center(
                    child: Text(
                      'กรุณายืนยันการเก็บข้อมูลใบหน้าก่อนเริ่มการถ่ายภาพ...',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                return Stack(
                  children: [
                    // กล้องเต็มจอ
                    SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: controller.value.previewSize!.height,
                          height: controller.value.previewSize!.width,
                          child: CameraPreview(controller),
                        ),
                      ),
                    ),

                    // ปุ่มข้าม (เฉพาะอำนวยความสะดวก)
                    if (!widget.isVerificationMode)
                      Positioned(
                        top: 40,
                        right: 16,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black54,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ClassroomHomeScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'ข้าม',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    // ปุ่มถ่ายภาพ
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: FloatingActionButton(
                          backgroundColor: Colors.blueAccent, 
                          onPressed: (_isProcessing || _isCapturing)
                              ? null
                              : _captureAndProcess,
                          child: _isProcessing
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Icon(
                                Icons.camera_alt, 
                                color: Colors.black54,
                                ),
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
