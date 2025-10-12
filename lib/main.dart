import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/graphql_service.dart';
import 'utils/graphql_query.dart';
import 'screens/register_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/dashbord_screen.dart';

void main() {
  runApp(SmartIncidentApp());
}

class SmartIncidentApp extends StatelessWidget {
  final gql = GraphQLService();

  Future<bool> _hasValidToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      print('🔍 Checking token...'); // Debug

      if (token == null || token.isEmpty) {
        print('❌ No token found'); // Debug
        return false;
      }

      final response = await gql.sendQuery(
        validateTokenQuery,
        {"token": token},
      );

      print("📡 Validate token response: $response"); // Debug

      final result = response['data']?['validateToken'];
      final isValid = result?['data'] == true;

      print(isValid ? '✅ Token valid' : '❌ Token invalid'); // Debug

      return isValid;
    } catch (e) {
      print("❌ Error validating token: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Incident App',
      debugShowCheckedModeBanner: false, // Remove debug banner
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),

      // Initial Route
      initialRoute: '/',

      // Named Routes
      routes: {
        '/': (context) => SplashScreen(hasValidToken: _hasValidToken),
        '/register': (context) => RegisterScreen(),
        '/otp': (context) => OtpScreen(
          phoneNumber: ModalRoute.of(context)?.settings.arguments as String? ?? '',
        ),
        '/dashboard': (context) => DashboardScreen(),
      },

      // Fallback route handler
      onUnknownRoute: (settings) {
        print('⚠️ Unknown route: ${settings.name}');
        return MaterialPageRoute(
          builder: (context) => RegisterScreen(),
        );
      },
    );
  }
}

// ============================================================================
// SPLASH SCREEN - Better UX while checking token
// ============================================================================

class SplashScreen extends StatefulWidget {
  final Future<bool> Function() hasValidToken;

  const SplashScreen({Key? key, required this.hasValidToken}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Add small delay for better UX
    await Future.delayed(Duration(milliseconds: 500));

    try {
      final isValid = await widget.hasValidToken();

      if (!mounted) return;

      if (isValid) {
        print('🚀 Navigating to Dashboard...');
        Navigator.of(context).pushReplacementNamed('/dashboard');
      } else {
        print('🚀 Navigating to Register...');
        Navigator.of(context).pushReplacementNamed('/register');
      }
    } catch (e) {
      print('❌ Auth check error: $e');

      if (!mounted) return;

      // On error, go to register
      Navigator.of(context).pushReplacementNamed('/register');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF2E5BFF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo/Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.shield_rounded,
                size: 50,
                color: Color(0xFF2E5BFF),
              ),
            ),
            SizedBox(height: 30),

            // App Name
            Text(
              'Smart Incident',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),

            // Tagline
            Text(
              'Report. Track. Stay Safe.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            SizedBox(height: 50),

            // Loading Indicator
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}