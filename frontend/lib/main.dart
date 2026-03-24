// lib/main.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:frontend/screens/assignment_detail_screen.dart';
import 'package:frontend/screens/classroom_home_screen.dart';
import 'package:frontend/screens/create_assignment_screen.dart';
import 'package:frontend/screens/edit_announcement_screen.dart';
import 'package:frontend/screens/verify_face_route.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/camera_screen.dart';

List<CameraDescription> cameras = const [];

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Camera init error: ${e.code} - ${e.description}');
    cameras = const [];
  }
}

Future<void> main() async {
  await _bootstrap();
  final accessToken = await AuthService.getAccessToken();
  runApp(MyApp(initialRoute: accessToken != null ? '/home' : '/login'));
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  CameraDescription? _pickFrontOrAny() {
    if (cameras.isEmpty) return null;
    // พยายามเลือกกล้องหน้า ถ้าไม่มีใช้ตัวแรกแทน
    final front = cameras.where(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    return front.isNotEmpty ? front.first : cameras.first;
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/login':
        return MaterialPageRoute(builder: (_) => LoginScreen());
      case '/register':
        return MaterialPageRoute(builder: (_) => RegisterScreen());
      case '/home':
        // เปลี่ยนให้ /home ไปที่ ClassroomHomeScreen แทน HomeScreen
        return MaterialPageRoute(builder: (_) => const ClassroomHomeScreen());
      case '/verify-otp':
        {
          final email = settings.arguments as String?;
          return MaterialPageRoute(
            builder: (_) => email == null
                ? LoginScreen()
                : OtpVerificationScreen(email: email),
          );
        }
      case '/forgot-password':
        return MaterialPageRoute(builder: (_) => ForgotPasswordScreen());
      case '/reset-password':
        {
          final email = settings.arguments as String?;
          return MaterialPageRoute(
            builder: (_) => email == null
                ? ForgotPasswordScreen()
                : ResetPasswordScreen(email: email),
          );
        }
      case '/admin-dashboard':
        return MaterialPageRoute(builder: (_) => const AdminDashboardScreen());

      //  กล้องสำหรับอัปโหลด/ตรวจสอบใบหน้า
      case '/upload-face':
      case '/verify-face':
        {
          final cam = _pickFrontOrAny();
          if (cam == null) {
            // กรณีไม่มีอุปกรณ์กล้อง
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Camera')),
                body: const Center(
                  child: Text(
                    'ไม่พบอุปกรณ์กล้อง กรุณาทดสอบบนเครื่องจริงหรือเปิดสิทธิ์กล้อง',
                  ),
                ),
              ),
            );
          }
          final isVerification = settings.name == '/verify-face';
          return MaterialPageRoute(
            builder: (_) =>
                CameraScreen(camera: cam, isVerificationMode: isVerification),
          );
        }

      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Attendance App',
      theme: ThemeData(
        textSelectionTheme: TextSelectionThemeData(
          selectionHandleColor: Colors.blue, // สีจุดจับ
          selectionColor: Colors.blue.shade200, // สีพื้นหลังตอนเลือกข้อความ
          cursorColor: Color.fromARGB(209, 35, 35, 35), // สีเคอร์เซอร์
        ),
        inputDecorationTheme: InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color.fromARGB(212, 134, 134, 134), // สีกรอบเวลาพิมพ์
              width: 2,
            ),
          ),
          floatingLabelStyle: const TextStyle(
            color: Color.fromARGB(255, 134, 134, 134), // สี label ตอนโฟกัส
            fontWeight: FontWeight.bold,
          ),
        ),
        primarySwatch: Colors.blue,
      ),
      initialRoute: initialRoute,
      onGenerateRoute: _onGenerateRoute,
      routes: {
        //  verify-face สำหรับตรวจยืนยัน
        '/verify-face': (context) => const VerifyFaceRoute(),

        //  reverify-face สำหรับสุ่มตรวจซ้ำกลางคาบ
        '/reverify-face': (context) =>
            const VerifyFaceRoute(isReverifyMode: true),

        //  เพิ่มเส้นทางสร้างงานใหม่ (อยู่ใน routes เดียวกัน)
        '/create-assignment': (context) {
          final classId = ModalRoute.of(context)!.settings.arguments as String;
          return CreateAssignmentScreen(classId: classId);
        },

        '/assignment-detail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return AssignmentDetailScreen(
            assignmentId: args['assignmentId'],
            title: args['title'] ?? 'Assignment',
            classId: args['classId'],
          );
        },
        '/edit-announcement': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          final ann = args['announcement'];
          return EditAnnouncementScreen(
            announcementId: ann['announcement_id'],
            title: ann['title'],
            body: ann['body'],
          );
        },
      },
    );
  }
}
