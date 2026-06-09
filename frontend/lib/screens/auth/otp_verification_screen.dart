// lib/screens/otp_verification_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

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
  String? _message;
  bool _isLoading = false;

  Color? _messageColor;

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
        if (_remaining.inSeconds > 0) {
          _remaining = _remaining - const Duration(seconds: 1);
        }
        if (_resendRemaining.inSeconds > 0) {
          _resendRemaining = _resendRemaining - const Duration(seconds: 1);
        }
        if (_remaining.inSeconds <= 0 && _resendRemaining.inSeconds <= 0) {
          _countdownTimer?.cancel();
        }
      });
    });
  }
  
  @override
  void dispose() {
    for (var ctrl in _controllers) ctrl.dispose();
    for (var node in _focusNodes) node.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  void _onOtpChanged(String value, int index) {
    if (value.isNotEmpty && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  String get _otp => _controllers.map((e) => e.text).join();

  Future<void> _verifyOtp() async {
    if (_controllers.any((c) => c.text.isEmpty)) {
      setState(() {
        _message = 'Please enter the 6-digit OTP.';
        _messageColor = Colors.redAccent;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      await AuthService.verifyOtp(widget.email, _otp);
      
      setState(() {
        _message = 'OTP verified successfully! Your account is now active.';
        _messageColor = Colors.green;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP verified! Redirecting to login...')),
      );
      _countdownTimer?.cancel();
      await Future.delayed(const Duration(seconds: 2));
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      setState(() {
        _message = e.toString().replaceFirst('Exception: ', '');
        _messageColor = Colors.redAccent;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _requestNewOtp() async {
    if (_resendRemaining.inSeconds > 0) return;

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      await AuthService.requestOtp(widget.email);

      setState(() {
        _message = 'New OTP has been sent to your email.';
        _messageColor = Colors.blueAccent;
        _remaining = Duration(minutes: _otpExpireMinutes);
        _resendRemaining = Duration(seconds: _resendCooldownSeconds);
      });
      
      _startTimer();
    } catch (e) {
      setState(() {
        _message = e.toString().replaceFirst('Exception: ', '');
        _messageColor = Colors.redAccent;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canResend = _resendRemaining.inSeconds <= 0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('FaceCheck'),
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _remaining.inSeconds > 0
                ? 'รหัสจะหมดอายุใน ${_formatDuration(_remaining)} (${_remaining.inMinutes + (_remaining.inSeconds%60>0?1:0)} นาที)'
                    : 'รหัสหมดอายุแล้ว กรุณาขอรหัสใหม่',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _remaining.inSeconds > 0 ? Colors.black54 : Colors.redAccent,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text('Enter the code sent to your inbox ${widget.email}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_otpLength, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: 43,
                    height: 52,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      maxLength: 1,
                      showCursor: false,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        counterText: '',
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.black54,
                            width: 2,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color.fromARGB(230, 20, 99, 247),
                            width: 2,
                          ),
                        ),
                        fillColor: const Color.fromARGB(255, 240, 240, 240),
                      ),
                      onChanged: (value) => _onOtpChanged(value, index),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 30),

              _isLoading
                  ? const CircularProgressIndicator(
                      color: Color.fromARGB(255, 28, 178, 248),
                      strokeWidth: 5,
                    )
                  : ElevatedButton(
                      onPressed: _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: const Color.fromARGB(
                          255,
                          28,
                          178,
                          248,
                        ),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Verify',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),

              const SizedBox(height: 12),
              TextButton(
                onPressed: (canResend && !_isLoading) ? _requestNewOtp : null,
                style: ButtonStyle(
                  overlayColor: WidgetStateProperty.all(
                    Colors.transparent,
                  ),
                ),
                child: Text(
                  canResend
                      ? "Didn't receive OTP? Request new"
                      : "Resend OTP in ${_resendRemaining.inSeconds}s",
                  style: TextStyle(
                    color: canResend ? Colors.blueAccent : Colors.grey,
                    fontWeight: canResend ? FontWeight.bold : FontWeight.normal,
                  ),
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
    );
  }
}
