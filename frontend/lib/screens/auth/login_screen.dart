// lib/screens/auth/login_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/face_service.dart';
import '../../services/fcm_service.dart';
import '../../utils/app_theme.dart';

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
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { _isLoading = true; _message = null; });
    try {
      final token = await AuthService.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      if (token != null) {
        try {
          await FCMService.sendTokenAfterLogin().timeout(const Duration(seconds: 2));
        } on TimeoutException {
          debugPrint('FCM token sync timeout after login');
        } catch (e) {
          debugPrint('FCM token sync failed after login: $e');
        }

        final user = await AuthService.getCurrentUserFromLocal();
        if (user != null) {
          final roles = user.roles ?? [];
          final isStudent = roles.any(
            (role) => role.toString().trim().toLowerCase() == 'student',
          );

          if (isStudent) {
            final hasFace = await FaceService.checkHasFace(user.userId);
            if (hasFace) {
              Navigator.pushReplacementNamed(context, '/home');
            } else {
              final consent = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Face Registration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  content: const Text(
                    'You have not registered your face yet.\nWould you like to register now?',
                    style: TextStyle(fontSize: 13),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Later', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Register now', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              );
              if (consent == true) {
                Navigator.pushReplacementNamed(context, '/upload-face');
              } else {
                Navigator.pushReplacementNamed(context, '/home');
              }
            }
          } else {
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          setState(() { _message = 'Unable to read user data.'; });
        }
      } else {
        setState(() { _message = 'Login failed.'; });
      }
    } catch (e) {
      setState(() { _message = e.toString().replaceFirst('Exception: ', ''); });
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(24),
                            bottomRight: Radius.circular(24),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 260,
                            child: Image.asset(
                              'assets/images/Image1.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(24),
                                bottomRight: Radius.circular(24),
                              ),
                              gradient: AppGradients.imageHeroOverlay,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 22,
                          bottom: 24,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fast Check',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Face Attendance Platform',
                                style: TextStyle(
                                  color: Color(0xFFE2E8F0),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Transform.translate(
                      offset: const Offset(0, -18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A0F172A),
                                blurRadius: 18,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.verified_user, color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Sign in to your account',
                                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _usernameController,
                                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                decoration: appInput(label: 'Email or Username', icon: Icons.person_outline),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                decoration: appInput(
                                  label: 'Password',
                                  icon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                      size: 17,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => Navigator.of(context).pushNamed('/forgot-password'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                                  ),
                                  child: const Text('Forgot password?', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              _isLoading
                                  ? const Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                      ),
                                    )
                                  : FilledButton(onPressed: _login, child: const Text('Sign In')),
                              if (_message != null) ...[
                                const SizedBox(height: 10),
                                _AuthBanner(_message!),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account?", style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        TextButton(
                          onPressed: () => Navigator.of(context).pushNamed('/register'),
                          child: const Text('Sign up', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
              },
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

// Shared banner used across auth screens
class _AuthBanner extends StatelessWidget {
  final String message;
  final bool isSuccess;
  const _AuthBanner(this.message, {this.isSuccess = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isSuccess ? AppColors.successLight : AppColors.errorLight,
        border: Border.all(
          color: isSuccess ? AppColors.success.withOpacity(0.4) : AppColors.error.withOpacity(0.35),
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Text(
        message,
        style: TextStyle(color: isSuccess ? AppColors.success : AppColors.error, fontSize: 12),
      ),
    );
  }
}
