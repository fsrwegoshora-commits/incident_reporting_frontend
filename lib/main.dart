import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:incident_reporting_frontend/providers/theme_provider.dart';
import 'package:incident_reporting_frontend/screens/dashbord_screen.dart';
import 'package:incident_reporting_frontend/screens/register_screen.dart';
import 'package:incident_reporting_frontend/screens/otp_screen.dart';
import 'package:incident_reporting_frontend/screens/notifications_screen.dart';
import 'package:incident_reporting_frontend/services/graphql_service.dart';
import 'package:incident_reporting_frontend/services/notifications_service.dart';
import 'package:incident_reporting_frontend/services/firebase_messaging_service.dart';
import 'package:incident_reporting_frontend/services/websocket_notification_service.dart';
import 'package:incident_reporting_frontend/services/config_service.dart';
import 'package:incident_reporting_frontend/utils/graphql_query.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // INITIALIZE CONFIG SERVICE FIRST (BEFORE FIREBASE)
  try {
    await ConfigService().init();
    print("✅ ConfigService initialized successfully");
  } catch (e) {
    print("❌ Error initializing ConfigService: $e");
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase initialized");
  } catch (e) {
    print("❌ Firebase initialization error: $e");
  }

  runApp(const SmartIncidentApp());
}

class SmartIncidentApp extends StatelessWidget {
  const SmartIncidentApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider(create: (_) => NotificationsService()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Smart Incident App',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const AuthWrapper(),
            routes: {
              '/dashboard': (context) => DashboardScreen(),
              '/register': (context) => RegisterScreen(),
              '/otp': (context) => OtpScreen(
                phoneNumber: ModalRoute.of(context)?.settings.arguments as String? ?? '',
              ),
              '/notifications': (context) => NotificationsScreen(),
            },
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final GraphQLService gql = GraphQLService();
  late FirebaseMessagingService _firebaseMessagingService;
  late WebSocketNotificationsService _webSocketService;
  bool _isChecking = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _firebaseMessagingService = FirebaseMessagingService();
    _webSocketService = WebSocketNotificationsService();
    _checkAuthAndInitialize();
  }

  Future<void> _checkAuthAndInitialize() async {
    try {
      final notificationsService = Provider.of<NotificationsService>(context, listen: false);

      // Initialize Firebase Messaging
      await _firebaseMessagingService.initialize(
        context,
        notificationsService: notificationsService,
      );

      // Check token validity
      final hasValidToken = await _validateToken();

      if (!mounted) return;

      if (hasValidToken) {
        // Fetch notifications once logged in
        await notificationsService.fetchNotifications();
        await notificationsService.fetchUnreadCount();

        // Get user credentials from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        var userUid = prefs.getString('userUid');
        final token = prefs.getString('jwt_token');

        print("🔍 userUid from prefs: $userUid");
        print("🔍 token exists: ${token != null}");
        print("🔍 Backend: ${ConfigService().displayAddress}");

        if (userUid == null) {
          print("⚠️ User UID not found, fetching from GraphQL...");
          try {
            const String meQuery = '''
              query {
                me {
                  data {
                    uid
                  }
                }
              }
            ''';

            final response = await gql.sendAuthenticatedQuery(meQuery, {});
            final user = response['data']?['me']?['data'];

            if (user != null && user['uid'] != null) {
              userUid = user['uid'];
              await prefs.setString('userUid', userUid!);
              print("✅ Saved user UID from GraphQL: $userUid");
            } else {
              print("❌ Could not get user UID from GraphQL response");
            }
          } catch (e) {
            print("❌ Error fetching user UID: $e");
          }
        } else {
          print("✅ User UID found: $userUid");
        }

        if (userUid != null && token != null) {
          await _webSocketService.connect(
            userUid,
            token,
            notificationsService: notificationsService,
          );
          print("✅ WebSocket connection initiated");
        } else {
          print("❌ Cannot connect WebSocket - missing userUid or token");
          print("   userUid: $userUid");
          print("   token: ${token != null ? 'exists' : 'null'}");
        }

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      } else {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/register');
        }
      }
    } catch (e) {
      print("❌ Auth initialization error: $e");
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<bool> _validateToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null || token.isEmpty) {
        print("❌ No token found");
        return false;
      }

      final response = await gql.sendQuery(validateTokenQuery, {"token": token}).timeout(
        const Duration(seconds: 8),
        onTimeout: () => {'data': {'validateToken': {'data': false}}},
      );

      final isValid = response['data']?['validateToken']?['data'] == true;
      return isValid;
    } catch (e) {
      print("❌ Token validation error: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E5BFF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10))
                ],
              ),
              child: const Icon(Icons.security_rounded, size: 50, color: Color(0xFF2E5BFF)),
            ),
            const SizedBox(height: 32),
            const Text(
              'Smart Incident',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              'Report. Track. Stay Safe.',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 60),
            if (_isChecking) ...[
              const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              const SizedBox(height: 20),
              const Text('Loading...', style: TextStyle(color: Colors.white70)),
            ] else if (_errorMessage != null) ...[
              const Icon(Icons.error_outline, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error: $_errorMessage',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isChecking = true;
                    _errorMessage = null;
                  });
                  _checkAuthAndInitialize();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF2E5BFF),
                ),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _firebaseMessagingService.dispose();
    super.dispose();
  }
}