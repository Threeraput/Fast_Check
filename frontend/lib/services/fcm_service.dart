// lib/services/fcm_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../firebase_options.dart';
import 'auth_service.dart';
import 'package:frontend/config.dart';

// -----------------------------------------------------------------
//  1. หูทิพย์ (Background Handler)
// -----------------------------------------------------------------
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print("🔔 [FCM Background] ได้รับข้อความ: ${message.messageId}");

  if (message.data['type'] == 'SILENT_CHECK') {
    print(
      "📍 [SILENT PUSH] ยามล่องหนสั่งตรวจพิกัด! Session ID: ${message.data['session_id']}",
    );
    // TODO: ดึงพิกัด GPS และยิง API กลับ Backend
  }
}

// -----------------------------------------------------------------
//  2. Class สำหรับจัดการ Notification ต่างๆ
// -----------------------------------------------------------------
class FCMService {
  static Future<void> initialize() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 1. ขออนุญาตแจ้งเตือน (เผื่ออนาคตอยากส่งแจ้งเตือนแบบมีเสียง)
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // 2. FirebaseMessaging
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 3. ดึง Token ประจำเครื่อง
    String? fcmToken = await messaging.getToken(); 
    print("🔑 [FCM TOKEN ของเครื่องนี้]: $fcmToken");

    if (fcmToken != null) {
      await _sendTokenToBackend(fcmToken);
    }
  }

  static Future<void> _sendTokenToBackend(String fcmToken) async {
    try {
      // 1. ดึง Access Token (JWT) ของคนที่ล็อกอินอยู่
      final accessToken = await AuthService.getAccessToken();
      if (accessToken == null) {
        print("⚠️ [FCM] ยังไม่ได้ Login เลยไม่ส่ง Token ให้ Backend");
        return;
      }

      // 2. ใช้ AppConfig.baseUrl แบบเดียวกับ auth_service.dart
      final url = Uri.parse('${AppConfig.baseUrl}/users/fcm-token');

      // 3. ยิง API พร้อมแนบ Token
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'fcm_token': fcmToken}),
      );

      // 4. เช็คผลลัพธ์
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
