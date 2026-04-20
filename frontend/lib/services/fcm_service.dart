// lib/services/fcm_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import '../firebase_options.dart';
import 'auth_service.dart';
import 'package:frontend/config.dart';

// -----------------------------------------------------------------
//  1. หูทิพย์ (Background Handler) สำหรับแอบทำงานตอนแอปปิด/พับจอ
// -----------------------------------------------------------------
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // กฎเหล็ก: ต้องเปิด Firebase ก่อนเสมอเวลาทำงานเบื้องหลัง
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print("🔔 [FCM Background] ได้รับข้อความ: ${message.messageId}");

  // เช็คว่าใช่คำสั่งยามล่องหนจาก Backend เราหรือไม่
  if (message.data['type'] == 'SILENT_CHECK') {
    final sessionId = message.data['session_id'];
    print("📍 [SILENT PUSH] ยามล่องหนสั่งตรวจพิกัด! Session ID: $sessionId");

    try {
      // 1. แอบดึงพิกัด GPS ปัจจุบันของนักเรียน
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      print("🌍 ได้พิกัดมาแล้ว: ${position.latitude}, ${position.longitude}");

      // 2. ดึง Access Token ในเครื่องเพื่อยืนยันตัวตน
      final accessToken = await AuthService.getAccessToken();
      if (accessToken == null) {
        print(
          "⚠️ [SILENT CHECK] ไม่มี Token การ Login (แอปอาจจะล็อกเอาท์อยู่)",
        );
        return;
      }

      // 3. ยิง API รายงานพิกัดกลับไปให้ Backend (ยามล่องหน)
      // 🚨 หมายเหตุ: Backend ของคุณต้องมี API เส้นทางนี้นะครับ
      final url = Uri.parse('${AppConfig.baseUrl}/attendance/silent-check');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'session_id': sessionId,
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      );

      // 4. เช็คผลลัพธ์
      if (response.statusCode == 200) {
        print("✅ [SILENT CHECK] ส่งพิกัดรายงานยามล่องหนสำเร็จ!");
      } else {
        print(
          "❌ [SILENT CHECK] ส่งพิกัดพลาด: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("❌ [SILENT CHECK] เกิดข้อผิดพลาดเบื้องหลัง: $e");
    }
  }
}

// -----------------------------------------------------------------
//  2. Class สำหรับจัดการตั้งค่าและส่ง Token ตอนเปิดแอป
// -----------------------------------------------------------------
class FCMService {
  static Future<void> initialize() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 1. ขออนุญาตส่งแจ้งเตือน (สำคัญมากสำหรับ Android 13+ และ iOS)
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // 2. ลงทะเบียนฟังก์ชันหูทิพย์ให้ระบบรู้จัก
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 3. ดึง Token ประจำเครื่อง
    String? fcmToken = await messaging.getToken();
    print("🔑 [FCM TOKEN ของเครื่องนี้]: $fcmToken");

    // 4. ถ้าดึง Token ได้ ให้ส่งไปเก็บที่ Database ทันที
    if (fcmToken != null) {
      await _sendTokenToBackend(fcmToken);
    }
  }

  // ฟังก์ชันยิง API สำหรับส่ง Token ไปอัปเดตที่ Backend
  static Future<void> _sendTokenToBackend(String fcmToken) async {
    try {
      final accessToken = await AuthService.getAccessToken();
      if (accessToken == null) {
        print("⚠️ [FCM] ยังไม่ได้ Login เลยไม่ส่ง Token ให้ Backend");
        return;
      }

      final url = Uri.parse('${AppConfig.baseUrl}/users/fcm-token');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'fcm_token': fcmToken}),
      );

      if (response.statusCode == 200) {
        print("✅ [FCM] บันทึก Token ลง Database เรียบร้อย!");
      } else {
        print(
          "❌ [FCM] บันทึก Token พลาด: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("❌ [FCM] เชื่อมต่อ Backend ไม่ได้: $e");
    }
  }
}
