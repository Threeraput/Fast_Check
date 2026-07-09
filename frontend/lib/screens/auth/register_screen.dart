import 'package:flutter/material.dart';
import 'package:frontend/utils/app_theme.dart';
import '../../services/auth_service.dart';
import '../../models/users.dart';
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
  bool _isPasswordVisible = false; // 👈 เพิ่มสถานะการมองเห็นรหัสผ่าน

  final List<String> _roles = ['student', 'teacher'];

  // สำหรับจัดการ error ข้อความแดง
  String? _usernameError;
  String? _passwordError;
  String? _firstNameError;
  String? _lastNameError;
  String? _emailError;

  // สถานะตรวจสอบรหัสผ่าน
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

  /// ตรวจสอบแต่ละเงื่อนไขของรหัสผ่าน
  void _checkPasswordStatus(String password) {
    setState(() {
      hasUppercase = password.contains(RegExp(r'[A-Z]'));
      hasLowercase = password.contains(RegExp(r'[a-z]'));
      hasNumber = password.contains(RegExp(r'\d'));
      hasSpecialChar = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
      hasMinLength = password.length >= 8;
    });
  }

  /// ตรวจสอบรหัสผ่านว่าผ่านทุกข้อหรือไม่
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

  /// Widget แสดง checklist เงื่อนไขรหัสผ่าน
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
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppGradients.authBackground,
            ),
          ),
          Positioned(
            top: -80,
            right: -40,
            child: _bgOrb(const Color(0x1A2F80ED), 210),
          ),
          Positioned(
            bottom: -120,
            left: -70,
            child: _bgOrb(const Color(0x14225DB0), 250),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE6ECF4), width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x140F172A),
                          blurRadius: 28,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Account',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                    fontSize: 28,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Fill in your information to get started.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF64748B),
                                    fontSize: 15,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            _buildModernTextField(
                              controller: _usernameController,
                              labelText: 'Username',
                              errorText: _usernameError,
                              icon: Icons.person_outline,
                            ),
                            const SizedBox(height: 12),
                            _buildModernTextField(
                              controller: _passwordController,
                              labelText: 'Password',
                              errorText: _passwordError,
                              icon: Icons.lock_outline,
                              obscureText: !_isPasswordVisible,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: const Color(0xFF64748B),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_showPasswordChecklist)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _expandChecklist = !_expandChecklist;
                                  });
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Password requirements (tap to view)',
                                      style: TextStyle(
                                        fontSize: 13,
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
                                      duration: const Duration(milliseconds: 200),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            _buildModernTextField(
                              controller: _firstNameController,
                              labelText: 'First Name',
                              errorText: _firstNameError,
                              icon: Icons.badge_outlined,
                            ),
                            const SizedBox(height: 12),
                            _buildModernTextField(
                              controller: _lastNameController,
                              labelText: 'Last Name',
                              errorText: _lastNameError,
                              icon: Icons.badge_outlined,
                            ),
                            const SizedBox(height: 12),
                            _buildModernTextField(
                              controller: _emailController,
                              labelText: 'Email',
                              errorText: _emailError,
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField2<String>(
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Role',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                                filled: true,
                                fillColor: const Color(0xFFFFFFFF),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: AppColors.primary,
                                    width: 1.8,
                                  ),
                                ),
                              ),
                              hint: const Text(
                                'Select Your Role',
                                style: TextStyle(fontSize: 15),
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
                                      Icon(roleIcon, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Text(role, style: const TextStyle(fontSize: 17)),
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
                            const SizedBox(height: 14),
                            _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                    ),
                                  )
                                : FilledButton(
                                    onPressed: () {
                                      setState(() {
                                        _showPasswordChecklist = true;
                                      });
                                      _register();
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      minimumSize: const Size(double.infinity, 44),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    child: const Text('Register'),
                                  ),
                            if (_message != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(11),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF1F2),
                                    border: Border.all(
                                      color: const Color(0xFFFECACA),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _message!,
                                    style: const TextStyle(
                                      color: Color(0xFFB42318),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 6),
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.of(context).pushNamed('/login');
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  textStyle: const TextStyle(fontSize: 15),
                                ),
                                child: const Text('Already have an account? Login'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    String? errorText,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontSize: 16,
        color: Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        labelText: labelText,
        errorText: errorText,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffixIcon,
        labelStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
      ),
    );
  }

  Widget _bgOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
