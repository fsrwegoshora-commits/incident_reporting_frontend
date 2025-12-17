// lib/screens/otp_screen.dart
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
  int _cooldownPeriod = 300; // 5 minutes in seconds
  int _cooldownCountdown = 0;
  bool _isInCooldown = false;
  Timer? _resendTimer;
  Timer? _cooldownTimer;

  late AnimationController _animationController;
  late AnimationController _shakeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _shakeAnimation;

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
      duration: Duration(milliseconds: 500),
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
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
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
    setState(() => _resendCountdown = 120); // 2 minutes
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
    _otpControllers.forEach((controller) => controller.clear());
    _focusNodes[0].requestFocus();
  }

  void _shakeOtpFields() {
    _shakeController.reset();
    _shakeController.forward();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCode.trim();
    if (otp.length != 6) {
      _showErrorSnackBar("Please enter complete OTP code");
      _shakeOtpFields();
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await gql.sendMutation(verifyOtpMutation, {
        "phone": widget.phoneNumber,
        "code": otp,
      });
      print("📡 Verify OTP response: $response");
      final result = response['data']?['verifyOtp'];
      final token = result?['data'];
      final message = result?['message'];
      if (token != null && token.toString().startsWith("eyJ")) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("jwt_token", token.toString());
        await prefs.remove('resend_attempts');
        await prefs.remove('last_resend_time');
        _showSuccessSnackBar(message ?? "OTP verified successfully");
        await Future.delayed(Duration(milliseconds: 1000));
        Navigator.pushReplacementNamed(context, '/dashboard'); // Changed to pushNamed
      } else {
        final error = response['errors']?[0]?['message'] ?? message ?? "Failed to verify OTP";
        _showErrorSnackBar(error);
        _clearOtpFields();
        _shakeOtpFields();
      }
    } catch (e) {
      final errorMessage = e.toString().contains("Network")
          ? "Network error, please try again"
          : "Error: $e";
      _showErrorSnackBar(errorMessage);
      _shakeOtpFields();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0 || _isResending || _isInCooldown) {
      return;
    }

    if (_resendAttempts >= _maxResendAttempts) {
      setState(() {
        _isInCooldown = true;
        _cooldownCountdown = _cooldownPeriod;
      });
      _startCooldownCountdown();
      _showErrorSnackBar("Maximum resend attempts reached. Please wait.");
      await _saveResendState();
      return;
    }

    setState(() => _isResending = true);

    try {
      final response = await gql.sendMutation(requestOtpMutation, {
        "phone": widget.phoneNumber,
      });

      print("📡 Resend OTP response: $response");

      final result = response['data']?['requestOtp'];
      final success = result?['status'] == 'Success';
      final message = result?['message'];

      if (success) {
        setState(() {
          _resendAttempts++;
          _resendCountdown = 120;
        });
        await _saveResendState();
        _startResendCountdown();
        _showSuccessSnackBar(message ?? "OTP code resent successfully");
        _clearOtpFields();
      } else {
        _showErrorSnackBar(message ?? "Failed to resend OTP");
      }
    } catch (e) {
      _showErrorSnackBar("Failed to resend OTP. Please try again.");
    } finally {
      setState(() => _isResending = false);
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
            Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            SizedBox(width: AppTheme.spaceS),
            Expanded(
              child: Text(
                message,
                style: AppTheme.bodyMedium.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.buttonRadius),
        margin: EdgeInsets.all(AppTheme.spaceM),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: AppTheme.spaceS),
            Expanded(
              child: Text(
                message,
                style: AppTheme.bodyMedium.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.buttonRadius),
        margin: EdgeInsets.all(AppTheme.spaceM),
        duration: Duration(seconds: 3),
      ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(AppTheme.spaceM),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: AppTheme.mediumRadius,
                    boxShadow: [AppTheme.cardShadow],
                  ),
                  child: Icon(
                    Icons.security,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                SizedBox(height: AppTheme.spaceL),
                Text(
                  "Verify OTP",
                  style: AppTheme.headlineMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                SizedBox(height: AppTheme.spaceS),
                RichText(
                  text: TextSpan(
                    style: AppTheme.bodyLarge,
                    children: [
                      TextSpan(
                        text: "Enter the 6-digit code sent to ",
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      TextSpan(
                        text: widget.phoneNumber,
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
              0),
          child: Container(
            padding: EdgeInsets.all(AppTheme.spaceL),
            decoration: AppTheme.primaryCardDecoration,
            child: Column(
              children: [
                Text(
                  "Enter Verification Code",
                  style: AppTheme.titleMedium.copyWith(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AppTheme.spaceL),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    return Container(
                      width: 45,
                      height: 55,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: AppTheme.smallRadius,
                        border: Border.all(
                          color: _otpControllers[index].text.isNotEmpty
                              ? AppTheme.primaryBlue
                              : AppTheme.borderColor,
                          width: _otpControllers[index].text.isNotEmpty ? 2 : 1,
                        ),
                        boxShadow: [AppTheme.lightShadow],
                      ),
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        style: AppTheme.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
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
                    );
                  }),
                ),
                SizedBox(height: AppTheme.spaceL),
                if (_isLoading)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryBlue,
                          ),
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: AppTheme.spaceS),
                      Text(
                        "Verifying...",
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerifyButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: _isLoading || _otpCode.length != 6
          ? BoxDecoration(
        color: AppTheme.borderColor,
        borderRadius: AppTheme.buttonRadius,
      )
          : AppTheme.primaryButtonDecoration,
      child: ElevatedButton(
        onPressed: (_isLoading || _otpCode.length != 6) ? null : _verifyOtp,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.buttonRadius,
          ),
        ),
        child: _isLoading
            ? SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            strokeWidth: 2,
          ),
        )
            : Text(
          "Verify OTP",
          style: AppTheme.buttonTextLarge.copyWith(
            color: _otpCode.length == 6
                ? Colors.white
                : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildResendSection() {
    return Column(
      children: [
        if (_resendCountdown > 0)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spaceM,
              vertical: AppTheme.spaceS,
            ),
            decoration: BoxDecoration(
              color: AppTheme.infoBlue.withOpacity(0.2),
              borderRadius: AppTheme.buttonRadius,
              border: Border.all(
                color: AppTheme.infoBlue,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.access_time,
                  color: AppTheme.infoBlue,
                  size: 20,
                ),
                SizedBox(width: AppTheme.spaceS),
                Text(
                  "Resend available in ${_formatTime(_resendCountdown)}",
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.infoBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else if (_isInCooldown)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spaceM,
              vertical: AppTheme.spaceS,
            ),
            decoration: BoxDecoration(
              color: AppTheme.errorRed.withOpacity(0.2),
              borderRadius: AppTheme.buttonRadius,
              border: Border.all(
                color: AppTheme.errorRed,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_clock,
                      color: AppTheme.errorRed,
                      size: 20,
                    ),
                    SizedBox(width: AppTheme.spaceS),
                    Text(
                      "Try again in ${_formatTime(_cooldownCountdown)}",
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.errorRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spaceXS),
                Text(
                  "Maximum resend attempts reached",
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.errorRed,
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              if (_resendAttempts > 0)
                Text(
                  "Resend attempts: $_resendAttempts/$_maxResendAttempts",
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              SizedBox(height: AppTheme.spaceS),
              TextButton(
                onPressed: _isResending ? null : _resendOtp,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceL,
                    vertical: AppTheme.spaceS,
                  ),
                  backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.buttonRadius,
                  ),
                ),
                child: _isResending
                    ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryBlue,
                        ),
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: AppTheme.spaceS),
                    Text(
                      "Resending...",
                      style: AppTheme.labelLarge.copyWith(
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                )
                    : Text(
                  "Resend OTP Code",
                  style: AppTheme.labelLarge.copyWith(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        SizedBox(height: AppTheme.spaceS),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            "Change Phone Number",
            style: AppTheme.labelMedium.copyWith(
              color: AppTheme.textSecondary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppTheme.spaceL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              SizedBox(height: AppTheme.spaceXL),
              _buildOtpFields(),
              SizedBox(height: AppTheme.spaceL),
              _buildVerifyButton(),
              SizedBox(height: AppTheme.spaceL),
              Center(child: _buildResendSection()),
              SizedBox(height: AppTheme.spaceL),
            ],
          ),
        ),
      ),
    );
  }
}