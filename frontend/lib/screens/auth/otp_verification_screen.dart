// lib/screens/auth/otp_verification_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  const OtpVerificationScreen({super.key, required this.email});
  @override
  _OtpVerificationScreenState createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final int _otpLength = 6;
  final int _otpExpireMinutes = 5;
  final int _resendCooldownSeconds = 60;
  late Duration _remaining;
  late Duration _resendRemaining;
  Timer? _countdownTimer;
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  bool _isUpdatingOtpFields = false;
  String? _message;
  bool _isLoading = false;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _otpLength; i++) {
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
    }
    _remaining = Duration(minutes: _otpExpireMinutes);
    _resendRemaining = Duration(seconds: _resendCooldownSeconds);
    _startTimer();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_remaining.inSeconds > 0) _remaining = _remaining - const Duration(seconds: 1);
        if (_resendRemaining.inSeconds > 0) _resendRemaining = _resendRemaining - const Duration(seconds: 1);
        if (_remaining.inSeconds <= 0 && _resendRemaining.inSeconds <= 0) _countdownTimer?.cancel();
      });
    });
  }

  @override
  void dispose() {
    for (var c in _controllers) c.dispose();
    for (var n in _focusNodes) n.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  void _onOtpChanged(String value, int index) {
    if (_isUpdatingOtpFields) return;

    final digits = value.replaceAll(RegExp(r'\D'), '');

    _isUpdatingOtpFields = true;
    try {
      if (digits.isEmpty) {
        _controllers[index].clear();
        return;
      }

      if (digits.length == 1) {
        _controllers[index].text = digits;
        _controllers[index].selection = const TextSelection.collapsed(offset: 1);
        if (index < _otpLength - 1) {
          _focusNodes[index + 1].requestFocus();
        } else {
          _focusNodes[index].unfocus();
        }
        return;
      }

      // Handle multi-digit paste by spreading digits across the remaining fields.
      var cursor = index;
      for (final ch in digits.split('')) {
        if (cursor >= _otpLength) break;
        _controllers[cursor].text = ch;
        _controllers[cursor].selection = const TextSelection.collapsed(offset: 1);
        cursor++;
      }

      if (cursor < _otpLength) {
        _focusNodes[cursor].requestFocus();
      } else {
        _focusNodes[_otpLength - 1].unfocus();
      }
    } finally {
      _isUpdatingOtpFields = false;
    }
  }

  KeyEventResult _onOtpKeyEvent(KeyEvent event, int index) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].selection = TextSelection.collapsed(
        offset: _controllers[index - 1].text.length,
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String get _otp => _controllers.map((e) => e.text).join();

  Future<void> _verifyOtp() async {
    if (_controllers.any((c) => c.text.isEmpty)) {
      setState(() { _message = 'Please enter all 6 digits.'; _isSuccess = false; });
      return;
    }
    setState(() { _isLoading = true; _message = null; });
    try {
      await AuthService.verifyOtp(widget.email, _otp);
      setState(() { _message = 'OTP verified! Your account is now active.'; _isSuccess = true; });
      _countdownTimer?.cancel();
      await Future.delayed(const Duration(seconds: 2));
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      setState(() { _message = e.toString().replaceFirst('Exception: ', ''); _isSuccess = false; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _requestNewOtp() async {
    if (_resendRemaining.inSeconds > 0) return;
    setState(() { _isLoading = true; _message = null; });
    try {
      await AuthService.requestOtp(widget.email);
      setState(() {
        _message = 'New OTP has been sent to your email.';
        _isSuccess = true;
        _remaining = Duration(minutes: _otpExpireMinutes);
        _resendRemaining = Duration(seconds: _resendCooldownSeconds);
      });
      _startTimer();
    } catch (e) {
      setState(() { _message = e.toString().replaceFirst('Exception: ', ''); _isSuccess = false; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _resendRemaining.inSeconds <= 0;
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
                'Verify your email',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter the 6-digit code sent to ${widget.email}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                _remaining.inSeconds > 0
                    ? 'Expires in ${_fmt(_remaining)}'
                    : 'Code expired — request a new one',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _remaining.inSeconds > 0 ? AppColors.textSecondary : AppColors.error,
                ),
              ),
              const SizedBox(height: 24),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // OTP input boxes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_otpLength, (i) {
                        return SizedBox(
                          width: 44,
                          child: Focus(
                            onKeyEvent: (_, event) => _onOtpKeyEvent(event, i),
                            child: TextField(
                              controller: _controllers[i],
                              focusNode: _focusNodes[i],
                              maxLength: 6,
                              showCursor: false,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              textInputAction: i == _otpLength - 1 ? TextInputAction.done : TextInputAction.next,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                                filled: true,
                                fillColor: AppColors.surfaceAlt,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                              ),
                              onChanged: (v) => _onOtpChanged(v, i),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    _isLoading
                        ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
                        : FilledButton(onPressed: _verifyOtp, child: const Text('Verify')),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: (canResend && !_isLoading) ? _requestNewOtp : null,
                      child: Text(
                        canResend ? "Resend OTP" : "Resend in ${_resendRemaining.inSeconds}s",
                        style: TextStyle(
                          fontSize: 13,
                          color: canResend ? AppColors.primary : AppColors.textHint,
                        ),
                      ),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 6),
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
