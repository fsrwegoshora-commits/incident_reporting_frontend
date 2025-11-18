import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:incident_reporting_frontend/services/websocket_notification_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/graphql_service.dart';
import 'services/notifications_service.dart';
import 'services/firebase_messaging_service.dart';
import 'utils/graphql_query.dart';
import 'screens/register_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/dashbord_screen.dart';
import 'screens/notifications_screen.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================================
  // INITIALIZE FIREBASE
  // ============================================================================
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase initialized successfully");
  } catch (e) {
    print("❌ Firebase initialization error: $e");
  }

  runApp(SmartIncidentApp());
}

class SmartIncidentApp extends StatefulWidget {
  @override
  _SmartIncidentAppState createState() => _SmartIncidentAppState();
}

class _SmartIncidentAppState extends State<SmartIncidentApp> {
  final gql = GraphQLService();
  late FirebaseMessagingService _firebaseMessagingService;
  late NotificationsService _notificationsService;
  late WebSocketNotificationsService _webSocketService; // ADDED
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  // ============================================================================
  // INITIALIZE ALL SERVICES
  // ============================================================================

  Future<void> _initializeServices() async {
    try {
      print("🚀 Initializing services...");

      // Initialize Notifications Service
      _notificationsService = NotificationsService();
      print("✅ Notifications Service initialized");

      // Initialize WebSocket Service
      _webSocketService = WebSocketNotificationsService();
      print("✅ WebSocket Service initialized");

      // Initialize Firebase Messaging Service
      _firebaseMessagingService = FirebaseMessagingService();
      print("✅ Firebase Messaging Service initialized");

      // Wait a moment for context to be ready
      await Future.delayed(Duration(milliseconds: 500));

      // Now initialize Firebase Messaging (after build is complete)
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          try {
            await _firebaseMessagingService.initialize(
              context,
              notificationsService: _notificationsService,
            );
            print("✅ Firebase Messaging fully initialized");

            // Set up callbacks
            _firebaseMessagingService.onMessageCallback = (RemoteMessage message) {
              print("🔔 Message received in main callback");
            };

            _firebaseMessagingService.onNotificationTapped = (screen, entityUid) {
              print("📍 Notification tapped - Screen: $screen, Entity: $entityUid");
            };

            setState(() => _isInitialized = true);
          } catch (e) {
            print("❌ Error initializing Firebase Messaging: $e");
            setState(() => _isInitialized = true);
          }
        }
      });
    } catch (e) {
      print("❌ Error in _initializeServices: $e");
      setState(() => _isInitialized = true);
    }
  }

  // ============================================================================
  // INITIALIZE WEBSOCKET AFTER LOGIN/TOKEN VALIDATION
  // ============================================================================

  Future<void> _initializeWebSocket(String userUid, String token) async {
    try {
      print("🔌 Initializing WebSocket for user: $userUid");

      await _webSocketService.connect(
          userUid,
          token,
          notificationsService: _notificationsService
      );

      // Set up WebSocket callbacks
      _webSocketService.onNotificationReceived = (NotificationModel notification) {
        print("🎯 WebSocket notification received: ${notification.title}");

        // This will automatically update the UI via NotificationsService
        _notificationsService.addNotification(notification);

        // Show snackbar or toast
        _showNewNotificationSnackbar(notification);
      };

      _webSocketService.onConnectionStatusChanged = (bool connected) {
        print(connected ? "✅ WebSocket connected" : "❌ WebSocket disconnected");
      };

      print("✅ WebSocket initialization complete");

    } catch (e) {
      print("❌ WebSocket initialization failed: $e");
    }
  }

  void _showNewNotificationSnackbar(NotificationModel notification) {
    // You can show a snackbar when new notification arrives
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔔 ${notification.title}'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // ============================================================================
  // TEST WEBSOCKET CONNECTION
  // ============================================================================

  void _testWebSocketConnection() async {
    final prefs = await SharedPreferences.getInstance();
    final userUid = prefs.getString('userUid');
    final token = prefs.getString('jwt_token');

    if (userUid != null && token != null) {
      print("🧪 Testing WebSocket connection...");
      _webSocketService.sendTestMessage();
    } else {
      print("❌ Cannot test WebSocket - user not logged in");
    }
  }

  // ============================================================================
  // TEST PUSH NOTIFICATION
  // ============================================================================

  void _testPushNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final userUid = prefs.getString('userUid');

    if (userUid == null) {
      print("❌ Cannot test push - user not logged in");
      return;
    }

    try {
      final response = await gql.sendAuthenticatedQuery('''
        mutation TestPushNotification {
          testPushNotification
        }
      ''', {});

      print("🧪 Push test response: $response");
    } catch (e) {
      print("❌ Push test failed: $e");
    }
  }

  Future<bool> _hasValidToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final userUid = prefs.getString('userUid');

      print('🔍 Checking token...');

      if (token == null || token.isEmpty) {
        print('❌ No token found');
        return false;
      }

      final response = await gql.sendQuery(
        validateTokenQuery,
        {"token": token},
      );

      print("📡 Validate token response: $response");

      final result = response['data']?['validateToken'];
      final isValid = result?['data'] == true;

      print(isValid ? '✅ Token valid' : '❌ Token invalid');

      // ✅ INITIALIZE WEBSOCKET IF TOKEN IS VALID
      if (isValid && userUid != null) {
        print("🚀 Initializing WebSocket after token validation...");
        _initializeWebSocket(userUid, token);
      }

      return isValid;
    } catch (e) {
      print("❌ Error validating token: $e");
      return false;
    }
  }

  @override
  void dispose() {
    _firebaseMessagingService.dispose();
    _webSocketService.disconnect(); // DISCONNECT WEBSOCKET
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<NotificationsService>(
          create: (_) => _notificationsService,
        ),
        // Add WebSocket service provider if needed
      ],
      child: MaterialApp(
        title: 'Smart Incident App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => SplashScreen(
            hasValidToken: _hasValidToken,
            testWebSocket: _testWebSocketConnection, // ADDED
            testPush: _testPushNotification, // ADDED
          ),
          '/register': (context) => RegisterScreen(),
          '/otp': (context) => OtpScreen(
            phoneNumber: ModalRoute.of(context)?.settings.arguments as String? ?? '',
          ),
          '/dashboard': (context) => DashboardScreen(),
          '/notifications': (context) => NotificationsScreen(),
        },
        onUnknownRoute: (settings) {
          print('⚠️ Unknown route: ${settings.name}');
          return MaterialPageRoute(
            builder: (context) => RegisterScreen(),
          );
        },
      ),
    );
  }
}

// ============================================================================
// ENHANCED SPLASH SCREEN WITH DEBUG OPTIONS
// ============================================================================

class SplashScreen extends StatefulWidget {
  final Future<bool> Function() hasValidToken;
  final VoidCallback? testWebSocket; // ADDED
  final VoidCallback? testPush; // ADDED

  const SplashScreen({
    Key? key,
    required this.hasValidToken,
    this.testWebSocket,
    this.testPush,
  }) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusMessage = 'Loading...';
  bool _showDebugOptions = false; // ADDED

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      // Wait for services to initialize (see _initializeServices in main)
      await Future.delayed(Duration(milliseconds: 1500));

      if (!mounted) return;

      setState(() => _statusMessage = 'Verifying authentication...');

      // Wait a bit more to ensure Firebase Messaging is ready
      await Future.delayed(Duration(milliseconds: 500));

      if (!mounted) return;

      final isValid = await widget.hasValidToken();

      if (!mounted) return;

      if (isValid) {
        print('🚀 Navigating to Dashboard...');
        // Fetch initial notifications when user logs in
        final notificationsService = Provider.of<NotificationsService>(context, listen: false);
        await notificationsService.fetchNotifications();

        Navigator.of(context).pushReplacementNamed('/dashboard');
      } else {
        print('🚀 Navigating to Register...');
        Navigator.of(context).pushReplacementNamed('/register');
      }
    } catch (e) {
      print('❌ Auth check error: $e');

      if (!mounted) return;

      setState(() {
        _statusMessage = 'Error. Tap to retry...';
        _showDebugOptions = true; // Show debug options on error
      });
    }
  }

  void _retryAuth() {
    setState(() {
      _statusMessage = 'Retrying...';
      _showDebugOptions = false;
    });
    _checkAuthAndNavigate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF2E5BFF),
      body: GestureDetector(
        onTap: _retryAuth, // Allow tap to retry
        child: Center(
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
              SizedBox(height: 20),

              // Status Message
              Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),

              // ============================================================================
              // DEBUG OPTIONS (Visible only when showDebugOptions is true)
              // ============================================================================
              if (_showDebugOptions) ...[
                SizedBox(height: 30),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Debug Options',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: widget.testWebSocket,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                            child: Text(
                              'Test WebSocket',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: widget.testPush,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: Text(
                              'Test Push',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),

      // ============================================================================
      // FLOATING DEBUG BUTTON (Always visible for testing)
      // ============================================================================
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _showDebugOptions = !_showDebugOptions;
          });
        },
        mini: true,
        backgroundColor: Colors.red,
        child: Icon(Icons.bug_report),
        tooltip: 'Debug Options',
      ),
    );
  }
}