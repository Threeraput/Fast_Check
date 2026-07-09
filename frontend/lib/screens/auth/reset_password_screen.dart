// lib/screens/auth/reset_password_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';

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
  late List<FocusNode> _otpFocusNodes;
  bool _isUpdatingOtpFields = false;

  String? _message;
  bool _isSuccess = false;
  bool _isLoading = false;
  String? _passwordError;
  bool _isPasswordVisible = false;
  bool _isConfirmVisible = false;

  bool hasUppercase = false;
  bool hasLowercase = false;
  bool hasNumber = false;
  bool hasSpecialChar = false;
  bool hasMinLength = false;

  @override
  void initState() {
    super.initState();
    _otpControllers = List.generate(_otpLength, (_) => TextEditingController());
    _otpFocusNodes = List.generate(_otpLength, (_) => FocusNode());
    _newPasswordController.addListener(() {
      _checkPasswordStatus(_newPasswordController.text);
      if (_passwordError != null) setState(() => _passwordError = null);
    });
  }

  @override
  void dispose() {
    for (var c in _otpControllers) c.dispose();
    for (var n in _otpFocusNodes) n.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String get _otp => _otpControllers.map((e) => e.text).join();

  void _onOtpChanged(String value, int index) {
    if (_isUpdatingOtpFields) return;

    final digits = value.replaceAll(RegExp(r'\D'), '');

    _isUpdatingOtpFields = true;
    try {
      if (digits.isEmpty) {
        _otpControllers[index].clear();
        return;
      }

      if (digits.length == 1) {
        _otpControllers[index].text = digits;
        _otpControllers[index].selection = const TextSelection.collapsed(offset: 1);
        if (index < _otpLength - 1) {
          _otpFocusNodes[index + 1].requestFocus();
        } else {
          _otpFocusNodes[index].unfocus();
        }
        return;
      }

      // Handle multi-digit paste by filling from the current index onward.
      var cursor = index;
      for (final ch in digits.split('')) {
        if (cursor >= _otpLength) break;
        _otpControllers[cursor].text = ch;
        _otpControllers[cursor].selection = const TextSelection.collapsed(offset: 1);
        cursor++;
      }

      if (cursor < _otpLength) {
        _otpFocusNodes[cursor].requestFocus();
      } else {
        _otpFocusNodes[_otpLength - 1].unfocus();
      }
    } finally {
      _isUpdatingOtpFields = false;
    }
  }

  KeyEventResult _onOtpKeyEvent(KeyEvent event, int index) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _otpControllers[index].text.isEmpty &&
        index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
      _otpControllers[index - 1].selection = TextSelection.collapsed(
        offset: _otpControllers[index - 1].text.length,
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _checkPasswordStatus(String password) {
    setState(() {
      hasUppercase = password.contains(RegExp(r'[A-Z]'));
      hasLowercase = password.contains(RegExp(r'[a-z]'));
      hasNumber = password.contains(RegExp(r'\d'));
      hasSpecialChar = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
      hasMinLength = password.length >= 8;
    });
  }

  bool _isPasswordSecure(String password) {
    return hasUppercase && hasLowercase && hasNumber && hasSpecialChar && hasMinLength;
  }

  Future<void> _resetPassword() async {
    final password = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (_otpControllers.any((c) => c.text.isEmpty)) {
      setState(() { _message = 'Please enter the 6-digit OTP.'; _isSuccess = false; });
      return;
    }
    if (password.isEmpty) {
      setState(() => _passwordError = 'Enter your password');
      return;
    }
    if (!_isPasswordSecure(password)) {
      setState(() => _passwordError = 'Password does not meet all requirements.');
      return;
    }
    if (password != confirmPassword) {
      setState(() { _message = 'Passwords do not match.'; _isSuccess = false; });
      return;
    }

    setState(() { _isLoading = true; _message = null; });
    try {
      await AuthService.resetPassword(widget.email, _otp, password);
      setState(() { _message = 'Password reset successfully.'; _isSuccess = true; });
      await Future.delayed(const Duration(seconds: 2));
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      setState(() { _message = e.toString().replaceFirst('Exception: ', ''); _isSuccess = false; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Widget _checkItem(String text, bool ok) {
    return Row(
      children: [
        Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: ok ? AppColors.success : AppColors.textHint),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, color: ok ? AppColors.success : AppColors.textSecondary)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),
              const Text(
                'Reset password',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter the OTP and choose a new password.',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('OTP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_otpLength, (index) {
                        return SizedBox(
                          width: 44,
                          child: Focus(
                            onKeyEvent: (_, event) => _onOtpKeyEvent(event, index),
                            child: TextField(
                              controller: _otpControllers[index],
                              focusNode: _otpFocusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 6,
                              textInputAction: index == _otpLength - 1 ? TextInputAction.done : TextInputAction.next,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: AppColors.surfaceAlt,
                                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onChanged: (v) => _onOtpChanged(v, index),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: !_isPasswordVisible,
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      decoration: appInput(
                        label: 'New password',
                        icon: Icons.lock_outline,
                        errorText: _passwordError,
                        suffixIcon: IconButton(
                          icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, size: 17, color: AppColors.textSecondary),
                          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: !_isConfirmVisible,
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      decoration: appInput(
                        label: 'Confirm password',
                        icon: Icons.lock_reset,
                        suffixIcon: IconButton(
                          icon: Icon(_isConfirmVisible ? Icons.visibility : Icons.visibility_off, size: 17, color: AppColors.textSecondary),
                          onPressed: () => setState(() => _isConfirmVisible = !_isConfirmVisible),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Password requirements', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    _checkItem('8+ characters', hasMinLength),
                    _checkItem('Uppercase letter', hasUppercase),
                    _checkItem('Lowercase letter', hasLowercase),
                    _checkItem('Number', hasNumber),
                    _checkItem('Special character', hasSpecialChar),
                    const SizedBox(height: 14),
                    _isLoading
                        ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
                        : FilledButton(onPressed: _resetPassword, child: const Text('Reset password')),
                    if (_message != null) ...[
                      const SizedBox(height: 10),
                      _Banner(_message!, isSuccess: _isSuccess),
                    ],
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

class _Banner extends StatelessWidget {
  final String message; final bool isSuccess;
  const _Banner(this.message, {this.isSuccess = false});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: isSuccess ? AppColors.successLight : AppColors.errorLight,
      border: Border.all(color: isSuccess ? AppColors.success.withOpacity(0.4) : AppColors.error.withOpacity(0.35)),
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
    ),
    child: Text(message, style: TextStyle(color: isSuccess ? AppColors.success : AppColors.error, fontSize: 12)),
  );
}
