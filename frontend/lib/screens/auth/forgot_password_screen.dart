// lib/screens/auth/forgot_password_screen.dart
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  String? _message;
  bool _isLoading = false;
  bool _isSuccess = false;

  @override
  void dispose() { _emailController.dispose(); super.dispose(); }

  Future<void> _requestOtp() async {
    setState(() { _isLoading = true; _message = null; });
    try {
      await AuthService.requestOtp(_emailController.text.trim());
      setState(() { _message = 'OTP sent! Check your email.'; _isSuccess = true; });
      await Future.delayed(const Duration(seconds: 2));
      Navigator.of(context).pushReplacementNamed('/reset-password', arguments: _emailController.text.trim());
    } catch (e) {
      setState(() { _message = e.toString().replaceFirst('Exception: ', ''); _isSuccess = false; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
                    'Forgot password',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enter your email to receive a reset OTP.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                          decoration: appInput(label: 'Email', icon: Icons.email_outlined),
                        ),
                        const SizedBox(height: 14),
                        _isLoading
                            ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
                            : FilledButton(onPressed: _requestOtp, child: const Text('Send OTP')),
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
        ],
      ),
    );
  }

  Widget _bgOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
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
