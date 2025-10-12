// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/graphql_service.dart';
import '../utils/graphql_query.dart';
import '../theme/app_theme.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final gql = GraphQLService();

  bool _isLoading = false;
  bool _isRegisterMode = true;

  late AnimationController _animationController;
  late AnimationController _switchAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _switchAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _switchAnimationController = AnimationController(
      duration: AppTheme.normalAnimation,
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

    _switchAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _switchAnimationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _switchAnimationController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    _switchAnimationController.reset();
    _switchAnimationController.forward();
    setState(() => _isRegisterMode = !_isRegisterMode);

    // Clear form when switching modes
    if (!_isRegisterMode) {
      _nameController.clear();
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final phone = _phoneController.text.trim();
      final formattedPhone = phone.startsWith('+')
          ? phone
          : "+255${phone.replaceFirst(RegExp(r'^0+'), '')}";

      if (_isRegisterMode) {
        if (_nameController.text.trim().isEmpty) {
          _showErrorSnackBar("Full name is required");
          setState(() => _isLoading = false);
          return;
        }

        final registerResponse = await gql.sendMutation(registerMutation, {
          "phone": formattedPhone,
          "name": _nameController.text.trim(),
        });

        print("📡 Register response: $registerResponse");

        final registerResult = registerResponse['data']?['userRegistration'];
        if (registerResult == null) {
          print("⚠️ Registration failed: No userRegistration data");
          _showErrorSnackBar("Registration failed: No data received");
          return;
        }

        final registerSuccess = registerResult['status'] == 'Success';
        if (!registerSuccess) {
          final message = registerResult['message'] ?? "Registration failed";
          print("⚠️ Registration failed: $message");
          _showErrorSnackBar(message);
          return;
        }

        _showSuccessSnackBar("Registration successful! Requesting OTP...");
        await Future.delayed(Duration(milliseconds: 1000));
      }

      final otpResponse = await gql.sendMutation(requestOtpMutation, {
        "phone": formattedPhone,
      });

      print("📡 OTP response: $otpResponse");

      final otpResult = otpResponse['data']?['requestOtp'];
      if (otpResult == null) {
        print("⚠️ Failed to get OTP: No requestOtp data");
        _showErrorSnackBar("Failed to request OTP: No data received");
        return;
      }

      final otpMessage = otpResult['message'];
      final otpData = otpResult['data'];

      if (otpMessage == 'Success' && otpData != null) {
        print("📲 OTP generated: $otpData (Message: $otpMessage)");
        _showSuccessSnackBar("OTP sent to $formattedPhone");

        await Future.delayed(Duration(milliseconds: 800));

        Navigator.pushNamed(context, '/otp', arguments: formattedPhone); // Changed to pushNamed
      } else {
        final errorMessage = otpResponse['errors']?[0]?['message'] ??
            otpMessage ??
            "Unknown error";
        print("⚠️ Failed to get OTP: $errorMessage");

        if (errorMessage.toLowerCase().contains("user does not exist")) {
          _showErrorSnackBar(
            "Phone number not registered. Please register first.",
            action: SnackBarAction(
              label: "Register",
              textColor: Colors.white,
              onPressed: () {
                setState(() => _isRegisterMode = true);
                _toggleMode();
              },
            ),
          );
        } else {
          _showErrorSnackBar("Failed to request OTP: $errorMessage");
        }
      }
    } catch (e, stackTrace) {
      print("❌ Error: $e");
      print("📋 Stack trace: $stackTrace");

      String errorMessage = "Error: $e";
      if (e.toString().contains("Network")) {
        errorMessage = "Network error, please try again";
      }
      _showErrorSnackBar(errorMessage);
    } finally {
      setState(() => _isLoading = false);
    }
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

  void _showErrorSnackBar(String message, {SnackBarAction? action}) {
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
        duration: Duration(seconds: 4),
        action: action,
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
                    gradient: _isRegisterMode
                        ? AppTheme.successGradient
                        : AppTheme.primaryGradient,
                    borderRadius: AppTheme.mediumRadius,
                    boxShadow: [AppTheme.cardShadow],
                  ),
                  child: Icon(
                    _isRegisterMode ? Icons.person_add : Icons.login,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                SizedBox(height: AppTheme.spaceL),
                Text(
                  _isRegisterMode ? "Create Account" : "Welcome Back",
                  style: AppTheme.headlineMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                SizedBox(height: AppTheme.spaceS),
                Text(
                  _isRegisterMode
                      ? "Enter your details to create a new account"
                      : "Enter your phone number to receive OTP",
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeToggle() {
    return AnimatedBuilder(
      animation: _switchAnimation,
      builder: (context, child) {
        return Container(
          margin: EdgeInsets.symmetric(vertical: AppTheme.spaceL),
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.surfaceGrey,
            borderRadius: AppTheme.pillRadius,
            border: Border.all(color: AppTheme.borderColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (!_isRegisterMode) _toggleMode();
                  },
                  child: AnimatedContainer(
                    duration: AppTheme.normalAnimation,
                    padding: EdgeInsets.symmetric(vertical: AppTheme.spaceS),
                    decoration: BoxDecoration(
                      gradient: _isRegisterMode ? AppTheme.primaryGradient : null,
                      borderRadius: AppTheme.pillRadius,
                      boxShadow: _isRegisterMode ? [AppTheme.lightShadow] : null,
                    ),
                    child: Text(
                      "Register",
                      textAlign: TextAlign.center,
                      style: AppTheme.labelLarge.copyWith(
                        color: _isRegisterMode
                            ? Colors.white
                            : AppTheme.textSecondary,
                        fontWeight: _isRegisterMode
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_isRegisterMode) _toggleMode();
                  },
                  child: AnimatedContainer(
                    duration: AppTheme.normalAnimation,
                    padding: EdgeInsets.symmetric(vertical: AppTheme.spaceS),
                    decoration: BoxDecoration(
                      gradient: !_isRegisterMode ? AppTheme.primaryGradient : null,
                      borderRadius: AppTheme.pillRadius,
                      boxShadow: !_isRegisterMode ? [AppTheme.lightShadow] : null,
                    ),
                    child: Text(
                      "Sign In",
                      textAlign: TextAlign.center,
                      style: AppTheme.labelLarge.copyWith(
                        color: !_isRegisterMode
                            ? Colors.white
                            : AppTheme.textSecondary,
                        fontWeight: !_isRegisterMode
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildForm() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spaceL),
      decoration: AppTheme.primaryCardDecoration,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isRegisterMode ? "Registration Details" : "Login Information",
              style: AppTheme.titleMedium.copyWith(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppTheme.spaceL),

            // Name field (only in register mode)
            AnimatedContainer(
              duration: AppTheme.normalAnimation,
              height: _isRegisterMode ? null : 0,
              child: AnimatedOpacity(
                opacity: _isRegisterMode ? 1.0 : 0.0,
                duration: AppTheme.normalAnimation,
                child: _isRegisterMode ? Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: AppTheme.getInputDecoration(
                        labelText: "Full Name",
                        hintText: "Enter your full name",
                        prefixIcon: Icons.person_outline,
                      ),
                      style: AppTheme.bodyLarge,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value?.isEmpty == true) return "Full name is required";
                        if (value!.length < 2) return "Name must be at least 2 characters";
                        return null;
                      },
                    ),
                    SizedBox(height: AppTheme.spaceM),
                  ],
                ) : SizedBox.shrink(),
              ),
            ),

            // Phone number field
            TextFormField(
              controller: _phoneController,
              decoration: AppTheme.getInputDecoration(
                labelText: "Phone Number",
                hintText: "Enter your phone number",
                prefixIcon: Icons.phone_outlined,
              ),
              style: AppTheme.bodyLarge,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(13),
              ],
              validator: (value) {
                if (value?.isEmpty == true) return "Phone number is required";

                // Remove any non-digit characters for validation
                final cleanPhone = value!.replaceAll(RegExp(r'\D'), '');

                if (cleanPhone.length < 9) {
                  return "Phone number is too short";
                }
                if (cleanPhone.length > 13) {
                  return "Phone number is too long";
                }

                // Check if it starts with valid Tanzanian prefixes
                if (cleanPhone.startsWith('0') && cleanPhone.length == 10) {
                  return null; // Valid local format
                }
                if (cleanPhone.startsWith('255') && cleanPhone.length == 12) {
                  return null; // Valid international format
                }
                if (cleanPhone.length >= 9 && cleanPhone.length <= 10) {
                  return null; // Assume valid
                }

                return "Invalid phone number format";
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: _isLoading
          ? BoxDecoration(
        color: AppTheme.borderColor,
        borderRadius: AppTheme.buttonRadius,
      )
          : (_isRegisterMode
          ? AppTheme.successButtonDecoration
          : AppTheme.primaryButtonDecoration),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.buttonRadius,
          ),
        ),
        child: _isLoading
            ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: AppTheme.spaceS),
            Text(
              _isRegisterMode ? "Creating Account..." : "Sending OTP...",
              style: AppTheme.buttonTextMedium,
            ),
          ],
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isRegisterMode ? Icons.person_add : Icons.send,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: AppTheme.spaceS),
            Text(
              _isRegisterMode ? "Create Account" : "Request OTP",
              style: AppTheme.buttonTextLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(AppTheme.spaceM),
          decoration: BoxDecoration(
            color: AppTheme.infoBlue.withOpacity(0.1),
            borderRadius: AppTheme.buttonRadius,
            border: Border.all(
              color: AppTheme.infoBlue.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppTheme.infoBlue,
                size: 20,
              ),
              SizedBox(width: AppTheme.spaceS),
              Expanded(
                child: Text(
                  _isRegisterMode
                      ? "By creating an account, you agree to our terms and conditions"
                      : "We'll send a 6-digit verification code to your phone number",
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.infoBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppTheme.spaceM),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isRegisterMode
                  ? "Already have an account? "
                  : "Don't have an account? ",
              style: AppTheme.bodyMedium,
            ),
            TextButton(
              onPressed: _toggleMode,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceS),
              ),
              child: Text(
                _isRegisterMode ? "Sign In" : "Register",
                style: AppTheme.labelLarge.copyWith(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
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
      backgroundColor: AppTheme.surfaceWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppTheme.spaceL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildModeToggle(),
              _buildForm(),
              SizedBox(height: AppTheme.spaceL),
              _buildSubmitButton(),
              SizedBox(height: AppTheme.spaceL),
              _buildFooter(),
              SizedBox(height: AppTheme.spaceL),
            ],
          ),
        ),
      ),
    );
  }
}