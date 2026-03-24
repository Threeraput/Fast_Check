import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  String? _message;
  bool _isLoading = false;

  Color? _messageColor;

  Future<void> _requestOtp() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      // --- แก้ไขตรงนี้: เปลี่ยนมาเรียก AuthService.requestOtp แทน ---
      await AuthService.requestOtp(_emailController.text);
      // ----------------------------------------------------------------

      setState(() {
        _message =
            'OTP for password reset sent to your email. Please check your inbox.';
        _messageColor = Colors.green; // สีข้อความสำเร็จ
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTP sent! Redirecting to reset password screen...'),
        ),
      );
      await Future.delayed(Duration(seconds: 2));
      // ส่ง email ไปยังหน้า reset password เพื่อให้รู้ว่ากำลังรีเซ็ตของอีเมลไหน
      Navigator.of(context).pushReplacementNamed(
        '/reset-password',
        arguments: _emailController.text,
      );
    } catch (e) {
      setState(() {
        _message = e.toString().replaceFirst('Exception: ', '');
        _messageColor = Colors.red; // สีข้อความผิดพลาด
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
    appBar: AppBar(title: Text('Forgot Password')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          padding: const EdgeInsets.all(24.0), // ระยะห่างด้านใน
          decoration: BoxDecoration(
            color: Colors.white, // สีพื้นหลังกล่อง
            borderRadius: BorderRadius.circular(16), // ความโค้ง
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4), // เงาด้านล่าง
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // ให้สูงเท่ากับเนื้อหา
            children: [
              Text(
                'Enter your email address to receive an OTP for password reset.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.email_outlined),
                  labelText: 'Your Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 20),
              _isLoading
                  ? CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _requestOtp,
                      child: Text(
                        'Request OTP',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _message!,
                    style: TextStyle(color: _messageColor),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
