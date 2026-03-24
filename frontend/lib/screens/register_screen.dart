import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/users.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();

  String? _selectedRole;
  String? _message;
  bool _isLoading = false;

  final List<String> _roles = ['student', 'teacher'];

  // สำหรับจัดการ error ข้อความแดง
  String? _usernameError;
  String? _passwordError;
  String? _firstNameError;
  String? _lastNameError;
  String? _emailError;

  // ✅ สถานะตรวจสอบรหัสผ่าน
  bool hasUppercase = false;
  bool hasLowercase = false;
  bool hasNumber = false;
  bool hasSpecialChar = false;
  bool hasMinLength = false;
  bool _showPasswordChecklist = false;
  bool _expandChecklist = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = _roles.first;

    // เคลียร์ error เมื่อพิมพ์ใหม่
    _usernameController.addListener(() {
      if (_usernameError != null) setState(() => _usernameError = null);
    });
    _passwordController.addListener(() {
      if (_passwordError != null) setState(() => _passwordError = null);
      _checkPasswordStatus(_passwordController.text);
    });
    _firstNameController.addListener(() {
      if (_firstNameError != null) setState(() => _firstNameError = null);
    });
    _lastNameController.addListener(() {
      if (_lastNameError != null) setState(() => _lastNameError = null);
    });
    _emailController.addListener(() {
      if (_emailError != null) setState(() => _emailError = null);
    });
  }

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

  Future<void> _register() async {
    bool isValid = true;
    String password = _passwordController.text;

    if (_usernameController.text.isEmpty) {
      setState(() => _usernameError = 'Enter your username');
      isValid = false;
    }

    if (password.isEmpty) {
      setState(() => _passwordError = 'Enter your password');
      isValid = false;
    } else if (!_isPasswordSecure(password)) {
      setState(() => _passwordError = 'Password does not meet all requirements.');
      isValid = false;
    }

    if (_firstNameController.text.isEmpty) {
      setState(() => _firstNameError = 'Enter your First Name');
      isValid = false;
    }
    if (_lastNameController.text.isEmpty) {
      setState(() => _lastNameError = 'Enter your Last Name');
      isValid = false;
    }
    if (_emailController.text.isEmpty) {
      setState(() => _emailError = 'Enter your Email');
      isValid = false;
    }

    if (_selectedRole == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select your Role')));
      isValid = false;
    }

    if (!isValid) return;

    setState(() {
      _isLoading = true;
      _message = null;
    });

    final userData = {
      'username': _usernameController.text,
      'password': password,
      'first_name': _firstNameController.text,
      'last_name': _lastNameController.text,
      'email': _emailController.text,
      'role': _selectedRole,
    };

    try {
      User newUser = await AuthService.register(userData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your account has been created! Check your email to activate it.',
          ),
        ),
      );
      Navigator.of(
        context,
      ).pushReplacementNamed('/verify-otp', arguments: newUser.email);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                errorText: _usernameError,
                prefixIcon: const Icon(
                  Icons.person_outline,
                  color: Colors.blueAccent,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                errorText: _passwordError,
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: Colors.blueAccent,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),

            // ✅ ข้อความเตือนสั้น ๆ
            if (_showPasswordChecklist)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _expandChecklist = !_expandChecklist; // กดเพื่อขยาย/ย่อ
                  });
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
                    // ✅ Checklist ขยายออกเมื่อกด
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(), // ย่อ
                      secondChild: _buildPasswordChecklist(), // ขยาย
                      crossFadeState: _expandChecklist
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _firstNameController,
              decoration: InputDecoration(
                labelText: 'First Name',
                errorText: _firstNameError,
                prefixIcon: const Icon(
                  Icons.badge_outlined,
                  color: Colors.blueAccent,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: 'Last Name',
                errorText: _lastNameError,
                prefixIcon: const Icon(
                  Icons.badge_outlined,
                  color: Colors.blueAccent,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                errorText: _emailError,
                prefixIcon: const Icon(
                  Icons.email_outlined,
                  color: Colors.blueAccent,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField2<String>(
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              hint: const Text(
                'Select Your Role',
                style: TextStyle(fontSize: 14),
              ),

              items: _roles.map((role) {
                IconData roleIcon;
                switch (role) {
                  case 'student':
                    roleIcon = Icons.person_outline;
                    break;
                  case 'teacher':
                    roleIcon = Icons.school_outlined;
                    break;
                  default:
                    roleIcon = Icons.group;
                }
                return DropdownMenuItem<String>(
                  value: role,
                  child: Row(
                    children: [
                      Icon(roleIcon, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Text(role, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedRole = value!);
              },
              validator: (value) =>
                  value == null ? 'Please select your Role.' : null,
              dropdownStyleData: DropdownStyleData(
                maxHeight: 300,
                width: 380,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blueAccent,
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showPasswordChecklist = true; // แสดง checklist
                      });
                      _register(); // เรียกฟังก์ชันสมัคร
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color.fromARGB(185, 64, 195, 255),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text(
                      'Register',
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
            TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/login');
              },
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(Colors.black),
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                overlayColor: WidgetStateProperty.all(Colors.transparent),
              ),
              child: const Text('Already have an account? Login here'),
            ),
          ],
        ),
      ),
    );
  }
}
