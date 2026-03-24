// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/face_service.dart';
import "classroom_home_screen.dart";
import 'camera_screen.dart';
import 'package:frontend/main.dart' show cameras;


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _message;
  bool _isLoading = false;

 Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final token = await AuthService.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      if (token != null) {
        final user = await AuthService.getCurrentUserFromLocal();

        if (user != null) {
          final roles = user.roles ?? [];

          //  ถ้าเป็นนักเรียน
          if (roles.contains('student')) {
            final hasFace = await FaceService.checkHasFace(user.userId);

            if (hasFace) {
              // 👩‍🎓 มีใบหน้าแล้ว → ไปหน้า classroom
              Navigator.pushReplacementNamed(context, '/home');
            } else {
              // 👩‍🎓 ยังไม่มีใบหน้า → ไปหน้า classroom เหมือนกัน
              // แต่ถามก่อนว่าต้องการลงทะเบียนไหม
              final consent = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text(
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    'ยืนยันการบันทึกภาพใบหน้า'),
                  content: const Text(
                    'คุณยังไม่ได้ลงทะเบียนใบหน้าในระบบ\n'
                    'ต้องการลงทะเบียนตอนนี้หรือไม่?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14) ,
                        'ภายหลัง'),
                    ),
                    FilledButton(
                      style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('ลงทะเบียนตอนนี้'),
                    ),
                  ],
                ),
              );

              if (consent == true) {
                //  ยินยอม → ไปหน้า upload face
                Navigator.pushReplacementNamed(context, '/upload-face');
              } else {
                //  ข้าม → ไปหน้า classroom
                Navigator.pushReplacementNamed(context, '/home');
              }
            }
          } else {
            //  Teacher/Admin → ไปหน้า classroom
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          setState(() {
            _message = 'ไม่สามารถอ่านข้อมูลผู้ใช้ได้';
          });
        }
      } else {
        setState(() {
          _message = 'เข้าสู่ระบบไม่สำเร็จ';
        });
      }
    } catch (e) {
      setState(() {
        _message = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false, // ปิดเว้นขอบบน เพื่อให้รูปติดขอบบนได้
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //  รูปภาพชิดขอบบนเต็มหน้าจอ
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                child: Image.asset(
                  'assets/images/Image1.png',
                  width: double.infinity,
                  height: 320,
                  fit: BoxFit.cover,
                ),
              ),

              const SizedBox(height: 24),

              //  ส่วนฟอร์ม ค่อยใส่ Padding แยก
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.email_outlined),
                        labelText: 'Your Email',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _passwordController,
                      
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline),
                        labelText: 'Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      obscureText: true,
                    ),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed('/forgot-password');
                        },
                        style: ButtonStyle(
                          foregroundColor: WidgetStateProperty.all(
                            Colors.black,
                          ),
                          textStyle: WidgetStateProperty.all(
                            const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          overlayColor: WidgetStateProperty.all(
                            Colors.transparent,
                          ),
                        ),
                        child: const Text('Forgot password?'),
                      ),
                    ),

                    _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color.fromARGB(255, 28, 178, 248),
                              strokeWidth: 5,
                            ),
                          )
                        : ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(
                                185,
                                64,
                                195,
                                255,
                              ),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: const Size(double.infinity, 48),
                            ),
                            child: const Text(
                              'Login',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),

                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          _message!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),

                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed('/register');
                        },
                        style: ButtonStyle(
                          foregroundColor: WidgetStateProperty.all(
                            Colors.black,
                          ),
                          textStyle: WidgetStateProperty.all(
                            const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          overlayColor: WidgetStateProperty.all(
                            Colors.transparent,
                          ),
                        ),
                        child: const Text(
                          "Don't have an account? Register here",
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}           