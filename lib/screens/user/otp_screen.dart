// lib/screens/auth/otp_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/graphql_service.dart';
import '../../utils/graphql_query.dart';
import '../../theme/app_theme.dart';
import '../dashbord/dashbord_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  const OtpScreen({required this.phoneNumber});

  @override
  _OtpScreenState createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with TickerProviderStateMixin {
  final List<TextEditingController> _otpControllers =
  List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  final gql = GraphQLService();
  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 0;
  int _resendAttempts = 0;
  int _maxResendAttempts = 3;
  int _cooldownPeriod = 300;
  int _cooldownCountdown = 0;
  bool _isInCooldown = false;
  Timer? _resendTimer;
  Timer? _cooldownTimer;

  late AnimationController _animationController;
  late AnimationController _shakeController;
  late AnimationController _pulseController;
  late AnimationController _successController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _successScale;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadResendState();
    _startResendCountdown();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _shakeController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _successController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 8.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _successScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
  }

  Future<void> _loadResendState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _resendAttempts = prefs.getInt('resend_attempts') ?? 0;
      final lastResendTime = prefs.getInt('last_resend_time') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      if (_resendAttempts >= _maxResendAttempts) {
        final elapsed = currentTime - lastResendTime;
        if (elapsed < _cooldownPeriod) {
          _isInCooldown = true;
          _cooldownCountdown = _cooldownPeriod - elapsed;
          _startCooldownCountdown();
        } else {
          _resendAttempts = 0;
          _isInCooldown = false;
          prefs.remove('resend_attempts');
          prefs.remove('last_resend_time');
        }
      }
    });
  }

  Future<void> _saveResendState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('resend_attempts', _resendAttempts);
    await prefs.setInt(
        'last_resend_time', DateTime.now().millisecondsSinceEpoch ~/ 1000);
  }

  void _startResendCountdown() {
    setState(() => _resendCountdown = 120);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) {
          timer.cancel();
        }
      });
    });
  }

  void _startCooldownCountdown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownCountdown--;
        if (_cooldownCountdown <= 0) {
          _isInCooldown = false;
          _resendAttempts = 0;
          _saveResendState();
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _cooldownTimer?.cancel();
    _animationController.dispose();
    _shakeController.dispose();
    _pulseController.dispose();
    _successController.dispose();
    _otpControllers.forEach((controller) => controller.dispose());
    _focusNodes.forEach((node) => node.dispose());
    super.dispose();
  }

  String get _otpCode {
    return _otpControllers.map((controller) => controller.text).join();
  }

  void _onOtpChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    if (_otpCode.length == 6 && !_isLoading) {
      _verifyOtp();
    }
  }

  void _clearOtpFields() {
    for (int i = 0; i < _otpControllers.length; i++) {
      _otpControllers[i].clear();
    }
    FocusScope.of(context).unfocus();
    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  void _shakeOtpFields() {
    _shakeController.reset();
    _shakeController.forward();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCode.trim();
    if (otp.length != 6) {
      _showErrorSnackBar("Please enter complete 6-digit OTP");
      _shakeOtpFields();
      return;
    }

    setState(() => _isLoading = true);

    try {
      print("🔐 Verifying OTP: $otp for ${widget.phoneNumber}");

      final response = await gql.sendMutation(verifyOtpMutation, {
        "phone": widget.phoneNumber,
        "code": otp,
      });

      print("📋 Verify response: $response");

      if (!mounted) return;

      final result = response['data']?['verifyOtp'];
      final token = result?['data'];
      final message = result?['message'];

      if (token != null && token.toString().startsWith("eyJ")) {
        _successController.forward();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("jwt_token", token.toString());
        await prefs.remove('resend_attempts');
        await prefs.remove('last_resend_time');

        _showSuccessSnackBar(message ?? "OTP verified successfully");

        await Future.delayed(Duration(milliseconds: 1500));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => DashboardScreen(),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: Duration(milliseconds: 500),
            ),
          );
        }
      } else {
        final error = response['errors']?[0]?['message'] ??
            message ??
            "Failed to verify OTP";
        _showErrorSnackBar(error);
        _shakeOtpFields();
        _clearOtpFields();
      }
    } catch (e) {
      if (!mounted) return;

      print("❌ Verify error: $e");

      final errorMessage = e.toString().contains("Network")
          ? "Network error, please try again"
          : "Error: $e";
      _showErrorSnackBar(errorMessage);
      _shakeOtpFields();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    // Check all blocking conditions
    if (_resendCountdown > 0 || _isResending || _isInCooldown) {
      if (_resendCountdown > 0) {
        _showInfoSnackBar("Please wait before requesting new OTP");
      }
      return;
    }

    // Check max attempts
    if (_resendAttempts >= _maxResendAttempts) {
      setState(() {
        _isInCooldown = true;
        _cooldownCountdown = _cooldownPeriod;
      });
      _startCooldownCountdown();
      _showErrorSnackBar(
          "Maximum resend attempts reached. Please wait ${_formatTime(_cooldownCountdown)} before trying again."
      );
      await _saveResendState();
      return;
    }

    // Start resending
    setState(() => _isResending = true);

    try {
      print("🔄 Resending OTP to: ${widget.phoneNumber}");

      final response = await gql.sendMutation(requestOtpMutation, {
        "phone": widget.phoneNumber,
      });

      print("📡 Resend response: $response");

      if (!mounted) return;

      // Check for GraphQL errors first
      if (response['errors'] != null && response['errors'].isNotEmpty) {
        final error = response['errors'][0]['message'] ?? "Failed to resend OTP";
        _showErrorSnackBar(error);
        return;
      }

      // Check data
      final data = response['data'];
      if (data == null) {
        _showErrorSnackBar("No response from server");
        return;
      }

      final result = data['requestOtp'];
      if (result == null) {
        _showErrorSnackBar("Invalid response format");
        return;
      }

      // Check success conditions (adapt to your API response)
      final success = result['success'] ??
          result['status'] == 'success' ||
              result['status'] == 'Success' ||
              result['message']?.toLowerCase().contains('sent') == true;
      final message = result['message'] ?? "OTP sent successfully";

      if (success) {
        // Update state
        setState(() {
          _resendAttempts++;
          _resendCountdown = 120; // 2 minutes
        });

        // Save state and start countdown
        await _saveResendState();
        _startResendCountdown();

        // Show success and clear fields
        _showSuccessSnackBar(message);
        _clearOtpFields();

        // Optional: Play success animation
        _successController.reset();
        _successController.forward();

      } else {
        // Handle failure
        final errorMsg = message.contains("already")
            ? "OTP already sent. Please check your messages."
            : message.contains("wait")
            ? "Please wait before requesting new code"
            : message;

        _showErrorSnackBar(errorMsg);
      }
    } catch (e) {
      if (!mounted) return;

      print("❌ Resend error: $e");

      // More specific error messages
      String errorMessage;
      if (e.toString().contains("SocketException") ||
          e.toString().contains("Connection failed")) {
        errorMessage = "No internet connection. Please check your network.";
      } else if (e.toString().contains("Timeout")) {
        errorMessage = "Request timeout. Please try again.";
      } else if (e.toString().contains("FormatException")) {
        errorMessage = "Invalid response from server.";
      } else {
        errorMessage = "Failed to resend OTP. Please try again.";
      }

      _showErrorSnackBar(errorMessage);

    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Icon(
                Icons.check,
                color: AppTheme.successGreen,
                size: 16,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 3),
        elevation: 8,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Icon(
                Icons.close,
                color: AppTheme.errorRed,
                size: 16,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 4),
        elevation: 8,
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Icon(
                Icons.info,
                color: AppTheme.infoBlue,
                size: 16,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.infoBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 2),
        elevation: 8,
      ),
    );
  }

  Widget _buildBackButton() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryBlue.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon Container with gradient
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryBlue.withOpacity(0.15),
                        AppTheme.primaryBlue.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryBlue,
                            AppTheme.primaryBlue.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withOpacity(0.3),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 32),

                // Title
                Text(
                  "Verify Your Account",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryBlue,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 12),

                // Description
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF6B7280),
                        height: 1.6,
                      ),
                      children: [
                        TextSpan(
                          text: "We've sent a 6-digit code to\n",
                        ),
                        TextSpan(
                          text: widget.phoneNumber,
                          style: TextStyle(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOtpFields() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            (_shakeAnimation.value *
                ((_shakeController.value * 4).floor() % 2 == 0 ? 1 : -1)),
            0,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final isFocused = _focusNodes[index].hasFocus;
                      final hasValue = _otpControllers[index].text.isNotEmpty;

                      return Transform.scale(
                        scale: isFocused ? _pulseAnimation.value : 1.0,
                        child: Container(
                          width: 52,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: (isFocused || hasValue)
                                    ? AppTheme.primaryBlue.withOpacity(0.15)
                                    : Colors.black.withOpacity(0.05),
                                blurRadius: isFocused ? 16 : 8,
                                offset: Offset(0, isFocused ? 8 : 2),
                                spreadRadius: isFocused ? 2 : 0,
                              ),
                            ],
                            border: Border.all(
                              color: hasValue
                                  ? AppTheme.primaryBlue
                                  : isFocused
                                  ? AppTheme.primaryBlue.withOpacity(0.6)
                                  : Color(0xFFE5E7EB),
                              width: hasValue ? 2.5 : isFocused ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: TextField(
                              controller: _otpControllers[index],
                              focusNode: _focusNodes[index],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryBlue,
                                letterSpacing: 2,
                              ),
                              keyboardType: TextInputType.number,
                              maxLength: 1,
                              decoration: InputDecoration(
                                counterText: "",
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (value) => _onOtpChanged(value, index),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
              SizedBox(height: 32),

              // Loading State
              if (_isLoading)
                Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withOpacity(0.15),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Verifying OTP...",
                      style: TextStyle(
                        color: AppTheme.primaryBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVerifyButton() {
    final isComplete = _otpCode.length == 6;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: isComplete && !_isLoading ? _pulseAnimation.value : 1.0,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: isComplete && !_isLoading
                  ? [
                BoxShadow(
                  color: AppTheme.primaryBlue.withOpacity(0.35),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                  spreadRadius: 2,
                ),
              ]
                  : [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: (_isLoading || !isComplete) ? null : _verifyOtp,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: isComplete && !_isLoading
                        ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryBlue,
                        AppTheme.primaryBlue.withOpacity(0.85),
                      ],
                    )
                        : LinearGradient(
                      colors: [
                        Color(0xFFE5E7EB),
                        Color(0xFFD1D5DB),
                      ],
                    ),
                  ),
                  child: Center(
                    child: _isLoading
                        ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          color: isComplete
                              ? Colors.white
                              : Color(0xFF9CA3AF),
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Text(
                          "Verify OTP",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isComplete
                                ? Colors.white
                                : Color(0xFF9CA3AF),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResendSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          if (_resendCountdown > 0)
            _buildCountdownCard()
          else if (_isInCooldown)
            _buildCooldownCard()
          else
            _buildResendButton(),
          SizedBox(height: 20),
          Divider(
            color: Color(0xFFE5E7EB),
            height: 1,
            thickness: 1,
          ),
          SizedBox(height: 16),
          _buildChangePhoneButton(),
        ],
      ),
    );
  }

  Widget _buildCountdownCard() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.infoBlue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.infoBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.hourglass_bottom_rounded,
              color: AppTheme.infoBlue,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Resend available in",
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  _formatTime(_resendCountdown),
                  style: TextStyle(
                    color: AppTheme.infoBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Courier',
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.infoBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "Waiting",
              style: TextStyle(
                color: AppTheme.infoBlue,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCooldownCard() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.errorRed.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.errorRed.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.lock_clock_rounded,
              color: AppTheme.errorRed,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Too many attempts",
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Retry in ${_formatTime(_cooldownCountdown)}",
                  style: TextStyle(
                    color: AppTheme.errorRed,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResendButton() {
    return Column(
      children: [
        if (_resendAttempts > 0)
          Container(
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_rounded,
                  color: AppTheme.primaryBlue,
                  size: 14,
                ),
                SizedBox(width: 6),
                Text(
                  "Attempts: $_resendAttempts/$_maxResendAttempts",
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryBlue.withOpacity(0.3),
              width: 1.5,
            ),
            color: AppTheme.primaryBlue.withOpacity(0.04),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _isResending ? null : _resendOtp,
              borderRadius: BorderRadius.circular(12),
              child: Center(
                child: _isResending
                    ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      "Sending...",
                      style: TextStyle(
                        color: AppTheme.primaryBlue,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
                    : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Resend OTP",
                      style: TextStyle(
                        color: AppTheme.primaryBlue,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChangePhoneButton() {
    return TextButton(
      onPressed: () => Navigator.pop(context),
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.edit_rounded,
            color: Color(0xFF6B7280),
            size: 18,
          ),
          SizedBox(width: 8),
          Text(
            "Change phone number",
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 4),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: Color(0xFF6B7280),
            size: 12,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAFAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with back button
              Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _buildBackButton(),
              ),
              SizedBox(height: 24),

              // Main content
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildHeader(),
                    SizedBox(height: 48),
                    _buildOtpFields(),
                    SizedBox(height: 40),
                    _buildVerifyButton(),
                    SizedBox(height: 40),
                    _buildResendSection(),
                    SizedBox(height: 30),
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