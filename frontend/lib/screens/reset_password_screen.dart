import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  _ResetPasswordScreenState createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final int _otpLength = 6;
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late List<TextEditingController> _otpControllers;

  String? _message;
  Color? _messageColor;
  bool _isLoading = false;
  String? _passwordError;

  // ✅ สถานะตรวจสอบรหัสผ่าน
  bool hasUppercase = false;
  bool hasLowercase = false;
  bool hasNumber = false;
  bool hasSpecialChar = false;
  bool hasMinLength = false;
  bool _showPasswordChecklist = true; // แสดงทันที
  bool _expandChecklist = false;

  @override
  void initState() {
    super.initState();
    _otpControllers = List.generate(_otpLength, (_) => TextEditingController());

    // ✅ ตรวจสอบรหัสผ่านขณะพิมพ์
    _newPasswordController.addListener(() {
      _checkPasswordStatus(_newPasswordController.text);
      if (_passwordError != null) {
        setState(() => _passwordError = null);
      }
    });
  }

  @override
  void dispose() {
    for (var c in _otpControllers) {
      c.dispose();
    }
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ✅ รวมค่า OTP ทั้งหมด
  String get _otp => _otpControllers.map((e) => e.text).join();

  /// ✅ ตรวจสอบแต่ละเงื่อนไขของรหัสผ่าน
  void _checkPasswordStatus(String password) {
    setState(() {
      hasUppercase = password.contains(RegExp(r'[A-Z]'));
      hasLowercase = password.contains(RegExp(r'[a-z]'));
      hasNumber = password.contains(RegExp(r'\d'));
      hasSpecialChar = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
      hasMinLength = password.length >= 8;
    });
  }

  /// ✅ ตรวจสอบรหัสผ่านว่าผ่านทุกข้อหรือไม่
  bool _isPasswordSecure(String password) {
    return hasUppercase &&
        hasLowercase &&
        hasNumber &&
        hasSpecialChar &&
        hasMinLength;
  }

  Future<void> _resetPassword() async {
    bool isValid = true;
    String password = _newPasswordController.text;
    String confirmPassword = _confirmPasswordController.text;

    if (_otpControllers.any((c) => c.text.isEmpty)) {
      setState(() {
        _message = 'Please enter the 6-digit OTP.';
        _messageColor = Colors.red;
      });
      return;
    }

    if (password.isEmpty) {
      setState(() => _passwordError = 'Enter your password');
      isValid = false;
    } else if (!_isPasswordSecure(password)) {
      setState(
        () => _passwordError = 'Password does not meet all requirements.',
      );
      isValid = false;
    }

    if (password != confirmPassword) {
      setState(() {
        _message = 'Passwords do not match.';
        _messageColor = Colors.red;
      });
      isValid = false;
    }

    if (!isValid) return;

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      await AuthService.resetPassword(
        widget.email,
        _otp,
        _newPasswordController.text,
      );

      setState(() {
        _message =
            'Password reset successfully! You can now login with your new password.';
        _messageColor = Colors.green;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset! Redirecting to login...'),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      setState(() {
        _message = e.toString().replaceFirst('Exception: ', '');
        _messageColor = Colors.red;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// ✅ Widget แสดง checklist เงื่อนไขรหัสผ่าน
  Widget _buildPasswordChecklist() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCheckItem('At least 8 characters', hasMinLength),
        _buildCheckItem('At least one uppercase letter (A-Z)', hasUppercase),
        _buildCheckItem('At least one lowercase letter (a-z)', hasLowercase),
        _buildCheckItem('At least one number (0-9)', hasNumber),
        _buildCheckItem(
          'At least one special character (!@#\$%^&*)',
          hasSpecialChar,
        ),
      ],
    );
  }

  Widget _buildCheckItem(String text, bool isPassed) {
    return Row(
      children: [
        Icon(
          isPassed ? Icons.check_circle : Icons.cancel,
          color: isPassed ? Colors.green : Colors.red,
          size: 18,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: isPassed ? Colors.green[700] : Colors.red[700],
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  /// ✅ ช่องกรอก OTP แบบแยกช่อง
  Widget _buildOtpFields() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(_otpLength, (index) {
        return SizedBox(
          width: 48,
          child: TextField(
            controller: _otpControllers[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            maxLength: 1,
            decoration: InputDecoration(
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color.fromARGB(230, 20, 99, 247),
                  width: 2,
                ),
              ),
            ),
            onChanged: (value) {
              if (value.isNotEmpty && index < _otpLength - 1) {
                FocusScope.of(context).nextFocus();
              } else if (value.isEmpty && index > 0) {
                FocusScope.of(context).previousFocus();
              }
            },
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Reset Password'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              Icon(
                Icons.lock_reset_rounded,
                size: 70,
                color: Colors.blueAccent.shade200,
              ),
              const SizedBox(height: 16),

              Text(
                'Reset your password',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter the OTP sent to\n${widget.email}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 28),

              // 🔹 กล่องกรอก OTP แบบช่อง ๆ
              _buildOtpFields(),

              const SizedBox(height: 28),

              // 🔹 กรอกรหัสผ่านใหม่
              TextFormField(
                controller: _newPasswordController,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  errorText: _passwordError,
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: Colors.blueAccent,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                obscureText: true,
                onTap: () {
                  setState(() {
                    _showPasswordChecklist = true;
                  });
                },
                onChanged: _checkPasswordStatus,
              ),
              const SizedBox(height: 8),

              // ✅ เงื่อนไขรหัสผ่าน
              if (_showPasswordChecklist)
                GestureDetector(
                  onTap: () {
                    setState(() => _expandChecklist = !_expandChecklist);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'รหัสผ่านต้องปลอดภัย (แตะเพื่อดูรายละเอียด)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: _buildPasswordChecklist(),
                        crossFadeState: _expandChecklist
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 250),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // 🔹 ยืนยันรหัสผ่านใหม่
              TextField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: const Icon(
                    Icons.verified_user_outlined,
                    color: Colors.blueAccent,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                obscureText: true,
              ),

              const SizedBox(height: 28),

              // 🔹 ปุ่มรีเซ็ตรหัสผ่าน
              _isLoading
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blueAccent,
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _resetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: const Text(
                          'Reset Password',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

              const SizedBox(height: 20),

              // 🔹 แสดงข้อความแจ้งเตือน (สำเร็จ / ผิดพลาด)
              if (_message != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _messageColor?.withOpacity(0.1) ?? Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _messageColor ?? Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
