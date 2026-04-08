// lib/utils/image_utils.dart
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// ปรับทิศทางตาม EXIF + ย่อขนาด (ถ้าจำเป็น) + บีบอัดเป็น JPEG
/// แล้วคืน "พาธไฟล์ใหม่" ที่พร้อมใช้อัปโหลด
Future<String> normalizeAndSaveJpeg(
  String srcPath, {
  int maxWidth = 1600,
  int jpegQuality = 92,
}) async {
  // 1) อ่านไฟล์
  final bytes = await File(srcPath).readAsBytes();

  // 2) decode (รองรับ JPG/PNG/HEIC* ถ้าระบบรองรับ) → ได้ image object
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw Exception('อ่านภาพไม่สำเร็จหรือฟอร์แมตไม่รองรับ: $srcPath');
  }

  // 3) หมุนตาม EXIF ให้ "ภาพถูกหมุนจริง" (ไม่ใช่พึ่ง orientation tag)
  final baked = img.bakeOrientation(decoded);

  // 4) ย่อให้ไม่ใหญ่เกิน (ช่วยให้ face detector ทำงานง่ายและอัปโหลดเร็ว)
  img.Image finalImg = baked;
  if (baked.width > maxWidth) {
    finalImg = img.copyResize(
      baked,
      width: maxWidth,
      interpolation: img.Interpolation.cubic,
    );
  }

  // 5) เขียนเป็น JPEG (quality 92 กำลังดี)
  final outBytes = img.encodeJpg(finalImg, quality: jpegQuality);

  // 6) เก็บไฟล์ใหม่ใน temp directory
  final dir = await getTemporaryDirectory();
  final outPath = p.join(
    dir.path,
    'face_${DateTime.now().millisecondsSinceEpoch}.jpg',
  );
  final outFile = File(outPath);
  await outFile.writeAsBytes(outBytes, flush: true);

  return outPath;
}
