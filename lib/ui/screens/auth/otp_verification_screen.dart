import 'dart:async';
import 'package:fireout/services/auth_service.dart';
import 'package:fireout/ui/screens/login/widgets/textfield.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

class OTPVerificationScreen extends StatefulWidget {
  const OTPVerificationScreen({super.key});

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  String tempUserId = '';
  String phoneNumber = '';
  DateTime? _expiresAt;
  bool isLoading = false;
  bool canResend = false;
  bool _otpConfirmed = false;
  String? errorMessage;
  Timer? _timer;
  Timer? _expiryTimer;
  int _countdown = 60;
  int _expirySecondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        tempUserId = (args['tempUserId'] as String?) ?? '';
        phoneNumber = (args['phone'] as String?) ?? '';
        _expiresAt = _parseExpiresAt(args['expiresAt']);
      } else if (args is String) {
        phoneNumber = args;
      }

      if (tempUserId.isEmpty) {
        setState(() {
          errorMessage = 'Invalid verification session. Please sign up again.';
        });
        return;
      }

      _startCountdown();
      _startExpiryTimer();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _expiryTimer?.cancel();
    _otpController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  DateTime? _parseExpiresAt(dynamic raw) {
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw)?.toLocal();
    }
    return null;
  }

  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    _recomputeExpiryRemaining();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _recomputeExpiryRemaining();
      if (_expirySecondsRemaining <= 0) {
        timer.cancel();
      }
    });
  }

  void _recomputeExpiryRemaining() {
    if (_expiresAt == null) {
      if (_expirySecondsRemaining != 0) {
        setState(() => _expirySecondsRemaining = 0);
      }
      return;
    }
    final remaining = _expiresAt!.difference(DateTime.now()).inSeconds;
    final clamped = remaining < 0 ? 0 : remaining;
    if (clamped != _expirySecondsRemaining) {
      setState(() => _expirySecondsRemaining = clamped);
    }
  }

  String _formatMinutesSeconds(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  bool get _isOtpExpired => _expiresAt != null && _expirySecondsRemaining <= 0;

  void _startCountdown() {
    setState(() {
      _countdown = 60;
      canResend = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        setState(() {
          canResend = true;
        });
        timer.cancel();
      }
    });
  }

  void _handleConfirmOtp() {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() {
        errorMessage = 'Please enter the 6-digit verification code';
      });
      return;
    }
    if (_isOtpExpired) {
      setState(() {
        errorMessage = 'Code expired. Tap Resend to get a new one.';
      });
      return;
    }
    setState(() {
      errorMessage = null;
      _otpConfirmed = true;
    });
  }

  Future<void> _handleVerification() async {
    final otp = _otpController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (otp.length != 6) {
      setState(() {
        _otpConfirmed = false;
        errorMessage = 'Please enter the 6-digit verification code';
      });
      return;
    }

    if (username.isEmpty) {
      setState(() {
        errorMessage = 'Username is required';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        errorMessage = 'Password must be at least 6 characters';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        errorMessage = 'Passwords do not match';
      });
      return;
    }

    if (tempUserId.isEmpty) {
      setState(() {
        errorMessage = 'Invalid verification session. Please sign up again.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final result = await _authService.verifyOTP(tempUserId, otp, username, password);

    setState(() {
      isLoading = false;
    });

    if (result != null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/main');
      }
    } else {
      final error = await _authService.getVerificationErrorMessage(
        tempUserId,
        otp,
        username,
        password,
      );
      setState(() {
        errorMessage = error ?? 'Invalid OTP. Please try again.';
      });
    }
  }

  Future<void> _handleResendOTP() async {
    if (tempUserId.isEmpty) {
      setState(() {
        errorMessage = 'Invalid verification session. Please sign up again.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final result = await _authService.resendOTP(tempUserId);

    setState(() {
      isLoading = false;
    });

    if (result != null) {
      setState(() {
        _expiresAt = _parseExpiresAt(result['expiresAt']);
        _otpController.clear();
        _otpConfirmed = false;
      });
      _startCountdown();
      _startExpiryTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      setState(() {
        errorMessage = 'Failed to resend OTP. Please try again.';
      });
    }
  }

  String _formatPhoneNumber(String phone) {
    if (phone.startsWith('+63')) {
      return phone.replaceFirst('+63', '0');
    }
    return phone;
  }

  Widget _buildBody() {
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          child: Image.asset('assets/images/login_shade.png'),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 50, right: 35),
              child: SizedBox(
                width: 300,
                height: 300,
                child: Image.asset('assets/images/fireout3_logo.png'),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 20, right: 20, top: 50),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Verify Your Phone',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Enter the 6-digit code sent to\n${_formatPhoneNumber(phoneNumber)}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_expiresAt != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _isOtpExpired
                          ? 'Code expired. Tap Resend to get a new one.'
                          : 'Code expires in ${_formatMinutesSeconds(_expirySecondsRemaining)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: _isOtpExpired
                            ? Colors.redAccent
                            : (_expirySecondsRemaining < 60
                                ? Colors.orangeAccent
                                : Colors.white70),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 30),
                  Pinput(
                    controller: _otpController,
                    length: 6,
                    onChanged: (_) {
                      if (_otpConfirmed) {
                        setState(() {
                          _otpConfirmed = false;
                        });
                      }
                    },
                    defaultPinTheme: PinTheme(
                      width: 50,
                      height: 50,
                      textStyle: const TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white70),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    focusedPinTheme: PinTheme(
                      width: 50,
                      height: 50,
                      textStyle: const TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    submittedPinTheme: PinTheme(
                      width: 50,
                      height: 50,
                      textStyle: const TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_otpConfirmed) ...[
                    const Text(
                      'Complete Your Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Username',
                      controller: _usernameController,
                      inputType: TextInputType.text,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Password',
                      controller: _passwordController,
                      inputType: TextInputType.visiblePassword,
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Confirm Password',
                      controller: _confirmPasswordController,
                      inputType: TextInputType.visiblePassword,
                      obscureText: true,
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (isLoading || _isOtpExpired)
                          ? null
                          : (_otpConfirmed ? _handleVerification : _handleConfirmOtp),
                      child: isLoading
                          ? const CircularProgressIndicator()
                          : Text(_otpConfirmed ? 'Create Account' : 'Verify Code'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (canResend)
                    TextButton(
                      onPressed: isLoading ? null : _handleResendOTP,
                      child: const Text(
                        'Resend OTP',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  else
                    Text(
                      'Resend OTP in $_countdown seconds',
                      style: const TextStyle(color: Colors.white54),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: _buildBody(),
        ),
      ),
    );
  }
}