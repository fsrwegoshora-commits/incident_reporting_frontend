import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:incident_reporting_frontend/screens/user/register_screen.dart';
import 'package:incident_reporting_frontend/screens/incident/report_incident_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/theme_provider.dart';
import '../../services/graphql_service.dart';
import '../../services/notifications_service.dart';
import '../../utils/auth_utils.dart';
import '../../utils/graphql_query.dart';
import '../../theme/app_theme.dart';
import '../admiin/admin_settings_screen.dart';
import '../agency/agency_management_screen.dart';
import '../department/department_management_screen.dart';
import '../incident/my_incidents_screen.dart';
import '../incident/officer_incidents_screen.dart';
import '../notification/notifications_screen.dart';
import '../user/user_management_screen.dart';
import '../station/police_station_management_screen.dart';
import 'improved_shift_card.dart';

// ============================================================================
// MODERN INCIDENT DASHBOARD - Complete Version
// ============================================================================

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  DateTime? _currentBackPressTime;

  // ============================================================================
  // STATE VARIABLES
  // ============================================================================

  // User Data
  String? _userRole;
  String? _userUid;
  String? _userName;
  String? _userPhone;
  String? _stationName;
  String? _stationUid;
  String? _badgeNumber;
  String? _rank;
  String? _officerUid;
  bool? _isOnDuty;
  Map<String, dynamic>? _currentShift;

  // Shifts Data
  List<Map<String, dynamic>> _officerShifts = [];
  bool _isLoadingShifts = false;

  Timer? _timer;
  Duration _remaining = Duration.zero;
  double _progress = 0.0;

  // Location & Nearby Stations
  Position? _currentPosition;
  String? _currentLocationName;
  List<Map<String, dynamic>> _nearbyStations = [];
  bool _isLoadingNearbyStations = false;
  double _maxDistance = 400.0;

  // UI State
  bool _isLoading = true;
  bool _balanceVisible = false;

  // Scaffold key for drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Animations
  late AnimationController _animationController;
  late AnimationController _stationsLoadingController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  NotificationsService? _notificationsService;
  Timer? _notificationRefreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notificationsService = Provider.of<NotificationsService>(context, listen: false);
      notificationsService.fetchNotifications();
      notificationsService.fetchUnreadCount();

      // Auto refresh every 30 seconds
      Timer.periodic(Duration(seconds: 30), (_) {
        if (mounted) {
          notificationsService.fetchUnreadCount();
        }
      });
    });
  }

  // void _toggleTheme() {
  //   final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  //   themeProvider.toggleTheme();
  //   setState(() {
  //     _isDarkMode = !_isDarkMode;
  //   });
  // }

  @override
  void dispose() {
    _animationController.dispose();
    _stationsLoadingController.dispose();

    // Clean up notifications
    _notificationRefreshTimer?.cancel();
    _notificationsService?.removeListener(_onNotificationsChanged);

    super.dispose();
  }

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _stationsLoadingController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _stationsLoadingController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  // ============================================================================
  // DATA LOADING
  // ============================================================================

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([_loadRole(), _loadUserProfile()]);
      if (_userRole == "POLICE_OFFICER" && _officerUid != null) {
        await _fetchOfficerShifts();
      }
    } catch (e) {
      _showSnackBar('Failed to load data: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRole() async {
    final role = await getUserRoleFromToken();
    setState(() => _userRole = role);
  }

  Future<void> _loadUserProfile() async {
    final gql = GraphQLService();
    final response = await gql.sendAuthenticatedQuery(meQuery, {});
    final user = response['data']?['me']?['data'];

    if (user != null) {
      setState(() {
        _userUid = user['uid'];
        _userName = user['name'];
        _userPhone = user['phoneNumber'];
        _userRole = user['role'];
        _stationName = user['stationName'];
        _stationUid = user['stationUid'];
        _badgeNumber = user['badgeNumber'];
        _rank = user['rank'];
        _isOnDuty = user['isOnDuty'];
        _currentShift = user['currentShift'];
        _officerUid = user['officerUid'];
        _userUid = user['uid'];
      });

      if (_stationUid == null && (_userRole == "STATION_ADMIN" || _userRole == "ROOT")) {
        final stationResponse = await gql.sendAuthenticatedQuery(getStationsByAdminQuery, {});
        final stations = stationResponse['data']?['getStationsByAdmin']?['data'];
        if (stations != null && stations.isNotEmpty) {
          setState(() {
            _stationUid = stations[0]['uid'];
            _stationName = stations[0]['name'] ?? _stationName;
          });
        }
      }
    }
  }

  Future<void> _fetchOfficerShifts() async {
    if (_officerUid == null) return;

    setState(() => _isLoadingShifts = true);
    try {
      final gql = GraphQLService();
      final response = await gql.sendAuthenticatedQuery(
        getShiftsByOfficerQuery,
        {
          'policeOfficerUid': _officerUid,
          'pageableParam': {
            'page': 0,
            'size': 10,
          },
        },
      );

      if (response.containsKey('errors')) return;

      final shifts = response['data']?['getShiftsByPoliceOfficer']?['data'] as List<dynamic>?;
      if (shifts != null) {
        setState(() => _officerShifts = shifts.cast<Map<String, dynamic>>());
      }
    } catch (e) {
      _showSnackBar('Failed to load shifts', isError: true);
    } finally {
      setState(() => _isLoadingShifts = false);
    }
  }

  // ============================================================================
  // NOTIFICATIONS
  // ============================================================================

  void _setupNotifications() {
    try {
      _notificationsService = Provider.of<NotificationsService>(context, listen: false);

      // Fetch initial notifications
      _notificationsService?.fetchNotifications();
      _notificationsService?.fetchUnreadCount();

      // Listen for notification updates
      _notificationsService?.addListener(_onNotificationsChanged);

      // Auto-refresh unread count every 30 seconds
      _notificationRefreshTimer = Timer.periodic(Duration(seconds: 30), (_) {
        if (mounted) {
          _notificationsService?.fetchUnreadCount();
        }
      });

      print("✅ Notifications setup complete");
    } catch (e) {
      print("❌ Error setting up notifications: $e");
    }
  }

  void _onNotificationsChanged() {
    print("🔔 Notifications updated - rebuilding");
    if (mounted) {
      setState(() {});
    }
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NotificationsScreen()),
    ).then((_) {
      // Refresh when coming back
      _notificationsService?.fetchNotifications();
      _notificationsService?.fetchUnreadCount();
    });
  }

  // ============================================================================
  // LOCATION & NEARBY STATIONS
  // ============================================================================

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Navigator.of(context).pop();
          _showSnackBar('Location permission required', isError: true);
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() => _currentPosition = position);

      await _getLocationName(position.latitude, position.longitude);
      await _fetchNearbyPoliceStations(position.latitude, position.longitude);
    } catch (e) {
      Navigator.of(context).pop();
      _showSnackBar('Failed to get location', isError: true);
    }
  }

  Future<void> _getLocationName(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        List<String> parts = [];

        if (place.street?.isNotEmpty == true) parts.add(place.street!);
        if (place.locality?.isNotEmpty == true) parts.add(place.locality!);

        setState(() {
          _currentLocationName = parts.isNotEmpty ? parts.join(', ') : 'Current Location';
        });
      }
    } catch (e) {
      setState(() => _currentLocationName = 'Current Location');
    }
  }

  Future<bool> _onWillPop() async {
    DateTime now = DateTime.now();

    // Check if this is the first time back button is pressed
    if (_currentBackPressTime == null ||
        now.difference(_currentBackPressTime!) > Duration(seconds: 2)) {

      _currentBackPressTime = now;

      // Show snackbar message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Press back again to exit app'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return false; // Don't exit
    }

    // If pressed twice within 2 seconds, exit app
    return true;
  }
  Future<void> _fetchNearbyPoliceStations(double latitude, double longitude) async {
    try {
      final gql = GraphQLService();
      final response = await gql.sendAuthenticatedQuery(
        getNearbyPoliceStationsQuery,
        {
          'latitude': latitude,
          'longitude': longitude,
          'maxDistance': _maxDistance,
        },
      );

      if (response.containsKey('errors')) {
        if (mounted) {
          setState(() {
            _isLoadingNearbyStations = false;
            _nearbyStations = [];
          });
        }
        _showSnackBar('Failed to load stations', isError: true);
        return;
      }

      final stations = response['data']?['getNearbyPoliceStations']?['data'] as List<dynamic>?;

      if (mounted) {
        setState(() {
          _nearbyStations = stations?.cast<Map<String, dynamic>>() ?? [];
          _isLoadingNearbyStations = false;
        });
      }

      print('✅ Loaded ${_nearbyStations.length} stations');

    } catch (e) {
      print('❌ Error loading stations: $e');
      if (mounted) {
        setState(() {
          _isLoadingNearbyStations = false;
          _nearbyStations = [];
        });
      }
      _showSnackBar('Error: $e', isError: true);
    }
  }

  // ============================================================================
  // NAVIGATION
  // ============================================================================

  void _navigateToReportIncident() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _buildNearbyStationsDialog(),
    );

    // Start loading location
    _getCurrentLocation();
  }

  void _selectStationForReport(Map<String, dynamic> station) {
    // Validate that we have position
    if (_currentPosition == null) {
      _showSnackBar('Location not available', isError: true);
      return;
    }
    // Close the station selection dialog
    Navigator.of(context).pop();

    // Navigate to Report Incident Screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportIncidentScreen(
          selectedStation: station,
          userPosition: _currentPosition!,
        ),
      ),
    ).then((_) {
      // Refresh dashboard when coming back
      _loadUserData();
    });
  }

  void _openUserManagement() {
    if (_userRole == "STATION_ADMIN" || _userRole == "ROOT") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => UserManagementScreen()));
    }
  }

  void _openPoliceStationManagement() {
    if (_userRole == "STATION_ADMIN" || _userRole == "ROOT") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PoliceStationManagementScreen()));
    }
  }

  void _openProfile() {
    _scaffoldKey.currentState?.openDrawer();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => RegisterScreen()),
    );
  }

  void _openStationIncidents() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => OfficerIncidentsScreen()));
  }

  void _openOfficerIncidents() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => OfficerIncidentsScreen()));
  }

  // ============================================================================
  // DELETE ACCOUNT - WEKA HAPA! 🎯
  // ============================================================================

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.errorRed.withOpacity(0.3),
                blurRadius: 30,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: AppTheme.errorRed,
                  size: 40,
                ),
              ),
              SizedBox(height: 20),

              Text(
                'Delete Account?',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'This action cannot be undone. All your data will be permanently deleted.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Color(0xFF8F9BB3),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),

              // Warning Points
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFFFFE69C)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWarningPoint('Your profile will be deleted'),
                    _buildWarningPoint('All your incidents will be removed'),
                    _buildWarningPoint('You cannot recover your account'),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Color(0xFFE4E9F2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1F36),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteAccount();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorRed,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Delete',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 3),
                SizedBox(height: 16),
                Text(
                  'Deleting account...',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1F36),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final gql = GraphQLService();
      final response = await gql.sendAuthenticatedQuery(deleteMyAccountMutation, {});

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      print('🔍 Delete Response: $response');

      // Check for GraphQL errors
      if (response.containsKey('errors')) {
        final errorMessage = response['errors'][0]['message'] ?? 'Failed to delete account';
        _showSnackBar(errorMessage, isError: true);
        return;
      }

      final deleteResult = response['data']?['deleteMyAccount'];

      if (deleteResult == null) {
        _showSnackBar('Invalid response from server', isError: true);
        return;
      }

      // 🔥 CHECK STATUS FIELD (not success field)
      final status = deleteResult['status'];
      final message = deleteResult['message'] ?? '';

      if (status == "Success") {
        print('✅ Account deleted successfully');

        // 🔥 CLEAR DATA IMMEDIATELY
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        print('✅ Local data cleared');

        // 🔥 NAVIGATE DIRECTLY - NO DIALOG
        _navigateToRegisterScreen();

      } else {
        _showSnackBar(message.isNotEmpty ? message : 'Failed to delete account', isError: true);
      }
    } catch (e) {
      print('❌ Delete Account Error: $e');

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      _showSnackBar('Error: ${e.toString()}', isError: true);
    }
  }

// 🔥 SIMPLE NAVIGATION WITHOUT DIALOG
  void _navigateToRegisterScreen() {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => RegisterScreen()),
          (route) => false,
    );

    // Optional: Show success message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account deleted successfully'),
          backgroundColor: AppTheme.successGreen,
          duration: Duration(seconds: 3),
        ),
      );
    });
  }

  // ============================================================================
  // UI HELPERS
  // ============================================================================

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  String _getRoleDisplayName(String? role) {
    switch (role) {
      case "CITIZEN": return "Citizen";
      case "ROOT": return "Admin";
      case "POLICE_OFFICER": return "Officer";
      case "STATION_ADMIN": return "Admin";
      case "AGENCY_REP": return "Agency";
      default: return "User";
    }
  }

  Color _getStatusColor() {
    if (_userRole == "POLICE_OFFICER") {
      return _isOnDuty == true ? AppTheme.successGreen : AppTheme.errorRed;
    }
    return AppTheme.primaryBlue;
  }

  String _getStatusText() {
    if (_userRole == "POLICE_OFFICER") {
      return _isOnDuty == true ? "On Duty" : "Off Duty";
    }
    return "Active";
  }

  // ============================================================================
  // NOTIFICATION WIDGETS
  // ============================================================================

  Widget _buildNotificationsSummaryCard() {
    return Consumer<NotificationsService>(
      builder: (context, service, _) {
        // Only show if there are unread notifications
        if (service.unreadCount == 0) {
          return SizedBox.shrink();
        }

        // Get latest notifications
        final unreadNotifications = service.getUnreadNotifications().take(3).toList();

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF2E5BFF).withOpacity(0.95),
                Color(0xFF1E3A8A).withOpacity(0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF2E5BFF).withOpacity(0.2),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.notifications_active_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Notifications',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${service.unreadCount} unread',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // View all button
                  GestureDetector(
                    onTap: _openNotifications,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'View All',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (unreadNotifications.isNotEmpty) ...[
                SizedBox(height: 12),
                Container(
                  height: 1,
                  color: Colors.white.withOpacity(0.1),
                ),
                SizedBox(height: 12),
                ...unreadNotifications.map((notification) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            color: notification.getTypeColor(),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.title,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (notification.message != null)
                                Text(
                                  notification.message!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlertBanner() {
    return Consumer<NotificationsService>(
      builder: (context, service, _) {
        // Check for urgent notifications
        final urgentNotifications = service.notifications
            .where((n) =>
                n.type.toUpperCase().contains('INCIDENT') ||
                n.type.toUpperCase().contains('ASSIGNED'))
            .where((n) => !n.isRead)
            .toList();

        if (urgentNotifications.isEmpty) {
          return SizedBox.shrink();
        }

        return Container(
          margin: EdgeInsets.all(20),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFFFF6B6B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color(0xFFFF6B6B).withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFFFF6B6B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Urgent Notifications',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF6B6B),
                      ),
                    ),
                    Text(
                      'You have ${urgentNotifications.length} unread urgent notification${urgentNotifications.length > 1 ? 's' : ''}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Color(0xFFFF6B6B).withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _openNotifications,
                child: Text(
                  'View',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF6B6B),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentActivitySection() {
    return Consumer<NotificationsService>(
      builder: (context, service, _) {
        if (service.notifications.isEmpty) {
          return SizedBox.shrink();
        }

        final recentNotifications = service.notifications.take(5).toList();

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Activity',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1F36),
                ),
              ),
              SizedBox(height: 12),
              ...recentNotifications.map((notification) {
                return Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: notification.isRead ? Color(0xFFE8EBF0) : notification.getTypeColor().withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        notification.getTypeIcon(),
                        color: notification.getTypeColor(),
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.title,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1F36),
                              ),
                            ),
                            if (notification.message != null)
                              Text(
                                notification.message!,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Color(0xFF8F9BB3),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Color(0xFF2E5BFF),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
              SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _openNotifications,
                  child: Text(
                    'View All Activity',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E5BFF),
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

  Widget _buildQuickActionButtons() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1F36),
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _navigateToReportIncident,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.warning_rounded, color: Colors.white, size: 24),
                        SizedBox(height: 8),
                        Text(
                          'Report Incident',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _openNotifications,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF51CF66), Color(0xFF2B7A34)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.notifications_rounded, color: Colors.white, size: 24),
                        SizedBox(height: 8),
                        Text(
                          'Notifications',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // BUILD METHOD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoadingScreen();

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,

        drawer: Drawer(
          child: _buildProfileDrawer(),
        ),

        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadUserData,
            child: Stack(
              children: [
                SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        SizedBox(height: 280),

                        if (_userRole == "POLICE_OFFICER")
                          _buildShiftsSection()
                        else if (_userRole == "STATION_ADMIN" || _userRole == "ROOT")
                          _buildAdminSection()
                        else if (_userRole == "CITIZEN")
                            _buildCitizenContent(),

                        SizedBox(height: 150),
                      ],
                    ),
                  ),
                ),

                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      _buildHeader(),
                      _buildBalanceCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        bottomNavigationBar: _buildModernBottomNav(),
        floatingActionButton: _buildEmergencyButton(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  // ============================================================================
  // UI COMPONENTS - Header
  // ============================================================================

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Row(
        children: [
          // Profile Avatar
          GestureDetector(
            onTap: _openProfile,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryBlue, AppTheme.primaryBlue.withOpacity(0.7)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, color: Colors.white, size: 24),
            ),
          ),
          SizedBox(width: 12),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName?.split(' ').first ?? "User",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).textTheme.headlineMedium?.color,
                  ),
                ),
                if (_userRole == "POLICE_OFFICER" && _rank != null)
                  Text(
                    _getShortRankDisplay(_rank),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.successGreen,
                    ),
                  )
                else
                  Text(
                    _getRoleDisplayName(_userRole),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Color(0xFF8F9BB3),
                    ),
                  ),
              ],
            ),
          ),

          // Theme Toggle - FIXED!
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return GestureDetector(
                onTap: () {
                  themeProvider.toggleTheme(); // Hii pekee inatosha!
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Icon(
                    themeProvider.isDarkMode
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
              );
            },
          ),
          SizedBox(width: 12),

          // Status Indicator
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _getStatusColor(),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  _getStatusText(),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16),

          // Notification Icon + Badge - PERFECT!
          Consumer<NotificationsService>(
            builder: (context, service, child) {
              return Stack(
                children: [
                  GestureDetector(
                    onTap: _openNotifications,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.notifications_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                  ),
                  if (service.unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        constraints: BoxConstraints(minWidth: 18, minHeight: 18),
                        decoration: BoxDecoration(
                          color: Color(0xFFFF6B6B),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFFFF6B6B).withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          service.unreadCount > 99 ? '99+' : '${service.unreadCount}',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
  // ============================================================================
  // UI COMPONENTS - Balance Card
  // ============================================================================

  Widget _buildBalanceCard() {
    return Container(
      margin: EdgeInsets.fromLTRB(20, 0, 20, 24),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E5BFF),
            Color(0xFF1E3A8A),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF2E5BFF).withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.shield_rounded, color: Colors.white, size: 20),
              ),
              SizedBox(width: 10),
              Text(
                'Smart Incident',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text(
            'Active Incidents',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Text(
                _balanceVisible ? '7' : '•••',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(width: 12),
              GestureDetector(
                onTap: () => setState(() => _balanceVisible = !_balanceVisible),
                child: Icon(
                  _balanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: Colors.white.withOpacity(0.7),
                  size: 20,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            children: [
              _buildStatItem(Icons.check_circle_outline, 'Resolved', '5'),
              SizedBox(width: 24),
              _buildStatItem(Icons.pending_outlined, 'Pending', '2'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.7), size: 16),
        SizedBox(width: 6),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // UI COMPONENTS - Shifts Section
  // ============================================================================

  Widget _buildShiftsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Alert Banner for urgent notifications
        _buildAlertBanner(),

        // Notifications Summary Card
        _buildNotificationsSummaryCard(),

        // Shifts Header
        Container(
          margin: EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'My Shifts',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1F36),
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_officerShifts.length} total',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Shifts List
          if (_isLoadingShifts)
            _buildShiftsLoading()
          else if (_officerShifts.isEmpty)
            _buildNoShifts()
          else
            ..._officerShifts.take(3).map((shift) => _buildImprovedShiftCard(shift)).toList(),

          // Officer Incidents Card - ADD THIS SECTION
          SizedBox(height: 24),
          _buildOfficerIncidentsCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImprovedShiftCard(Map<String, dynamic> shift) {
    final shiftTime = shift['shiftTime'] ?? 'N/A';
    final shiftDutyType = shift['shiftDutyType'] ?? 'N/A';
    final shiftDate = shift['shiftDate'] ?? '';
    final startTime = shift['startTime'] ?? '06:00';
    final endTime = shift['endTime'] ?? '14:00';
    final isExcused = shift['isExcused'] ?? false;
    final isPunishment = shift['isPunishmentMode'] ?? false;

    final isCurrentShift = _currentShift != null && _currentShift!['uid'] == shift['uid'];
    final isOffShift = shiftTime.toUpperCase() == 'OFF';
    final isPastShift = _isShiftInPast(shiftDate);

    final statusInfo = _getShiftStatusInfo(
      isCurrentShift: isCurrentShift,
      isOffShift: isOffShift,
      isPastShift: isPastShift,
      isExcused: isExcused,
      isPunishment: isPunishment,
    );

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: statusInfo['bgColor'],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusInfo['borderColor'],
          width: statusInfo['isActive'] ? 2 : 1,
        ),
        boxShadow: statusInfo['isActive']
            ? [
          BoxShadow(
            color: statusInfo['accentColor'].withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ]
            : null,
      ),
      child: Stack(
        children: [
          if (statusInfo['isCompleted'])
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusInfo['accentColor'].withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        statusInfo['icon'],
                        color: statusInfo['accentColor'],
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  shiftTime,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: statusInfo['isCompleted']
                                        ? Color(0xFF1A1F36).withOpacity(0.5)
                                        : Color(0xFF1A1F36),
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusInfo['badgeColor'].withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: statusInfo['badgeColor'].withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  statusInfo['statusText'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: statusInfo['badgeColor'],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            _formatShiftDate(shiftDate),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: statusInfo['isCompleted']
                                  ? Color(0xFF8F9BB3).withOpacity(0.6)
                                  : Color(0xFF8F9BB3),
                            ),
                          ),
                          SizedBox(height: 6),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusInfo['accentColor'].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Duty: $shiftDutyType',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: statusInfo['accentColor'],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (!isOffShift && !isExcused) ...[
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusInfo['isCompleted']
                          ? Color(0xFFF8F9FC).withOpacity(0.5)
                          : Color(0xFFF8F9FC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: statusInfo['isCompleted']
                              ? Color(0xFF8F9BB3).withOpacity(0.5)
                              : Color(0xFF8F9BB3),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '$startTime - $endTime',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: statusInfo['isCompleted']
                                ? Color(0xFF1A1F36).withOpacity(0.5)
                                : Color(0xFF1A1F36),
                          ),
                        ),
                        Spacer(),
                        _buildDaysIndicator(shiftDate, statusInfo['isCompleted']),
                      ],
                    ),
                  ),
                ],

                if (isCurrentShift && _isOnDuty == true) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.successGreen, AppTheme.successGreen.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'ACTIVE - You are currently on duty',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getShiftStatusInfo({
    required bool isCurrentShift,
    required bool isOffShift,
    required bool isPastShift,
    required bool isExcused,
    required bool isPunishment,
  }) {
    if (isExcused) {
      return {
        'statusText': 'EXCUSED',
        'icon': Icons.event_busy_rounded,
        'accentColor': AppTheme.successGreen,
        'badgeColor': AppTheme.successGreen,
        'bgColor': Colors.white,
        'borderColor': AppTheme.successGreen.withOpacity(0.3),
        'isActive': false,
        'isCompleted': true,
      };
    }

    if (isOffShift) {
      if (isPastShift) {
        return {
          'statusText': 'DAY OFF',
          'icon': Icons.beach_access_rounded,
          'accentColor': Color(0xFF8F9BB3),
          'badgeColor': Color(0xFF8F9BB3),
          'bgColor': Colors.white,
          'borderColor': Color(0xFFE4E9F2),
          'isActive': false,
          'isCompleted': true,
        };
      } else {
        return {
          'statusText': 'OFF DAY',
          'icon': Icons.free_breakfast_rounded,
          'accentColor': Color(0xFF667EEA),
          'badgeColor': Color(0xFF667EEA),
          'bgColor': Color(0xFF667EEA).withOpacity(0.05),
          'borderColor': Color(0xFF667EEA).withOpacity(0.2),
          'isActive': false,
          'isCompleted': false,
        };
      }
    }

    if (isPunishment) {
      return {
        'statusText': isPastShift ? 'COMPLETED' : 'PUNISHMENT',
        'icon': Icons.warning_rounded,
        'accentColor': AppTheme.errorRed,
        'badgeColor': AppTheme.errorRed,
        'bgColor': isPastShift ? Colors.white : AppTheme.errorRed.withOpacity(0.05),
        'borderColor': AppTheme.errorRed.withOpacity(0.2),
        'isActive': false,
        'isCompleted': isPastShift,
      };
    }

    if (isCurrentShift && _isOnDuty == true) {
      return {
        'statusText': 'ACTIVE NOW',
        'icon': Icons.security_rounded,
        'accentColor': AppTheme.successGreen,
        'badgeColor': AppTheme.successGreen,
        'bgColor': AppTheme.successGreen.withOpacity(0.05),
        'borderColor': AppTheme.successGreen,
        'isActive': true,
        'isCompleted': false,
      };
    }

    if (isCurrentShift) {
      return {
        'statusText': 'TODAY',
        'icon': Icons.schedule_rounded,
        'accentColor': Color(0xFF2E5BFF),
        'badgeColor': Color(0xFF2E5BFF),
        'bgColor': Color(0xFF2E5BFF).withOpacity(0.05),
        'borderColor': Color(0xFF2E5BFF).withOpacity(0.3),
        'isActive': true,
        'isCompleted': false,
      };
    }

    if (isPastShift) {
      return {
        'statusText': 'COMPLETED',
        'icon': Icons.check_circle_rounded,
        'accentColor': AppTheme.successGreen,
        'badgeColor': AppTheme.successGreen,
        'bgColor': Colors.white,
        'borderColor': Color(0xFFE4E9F2),
        'isActive': false,
        'isCompleted': true,
      };
    }

    return {
      'statusText': 'UPCOMING',
      'icon': Icons.schedule_rounded,
      'accentColor': Color(0xFF2E5BFF),
      'badgeColor': Color(0xFF2E5BFF),
      'bgColor': Colors.white,
      'borderColor': Color(0xFFE4E9F2),
      'isActive': false,
      'isCompleted': false,
    };
  }

  Widget _buildDaysIndicator(String dateString, bool isCompleted) {
    try {
      final shiftDate = DateTime.parse(dateString);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final shiftDay = DateTime(shiftDate.year, shiftDate.month, shiftDate.day);
      final difference = shiftDay.difference(today).inDays;

      String text;
      Color color;

      if (difference == 0) {
        text = 'Today';
        color = AppTheme.successGreen;
      } else if (difference == 1) {
        text = 'Tomorrow';
        color = Color(0xFF2E5BFF);
      } else if (difference > 0) {
        text = 'In $difference days';
        color = Color(0xFF2E5BFF);
      } else {
        text = '${difference.abs()}d ago';
        color = Color(0xFF8F9BB3);
      }

      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isCompleted ? color.withOpacity(0.5) : color,
          ),
        ),
      );
    } catch (e) {
      return SizedBox.shrink();
    }
  }

  String _formatShiftDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final shiftDay = DateTime(date.year, date.month, date.day);

      if (shiftDay == today) {
        return 'Today • ${_formatDate(date)}';
      } else if (shiftDay == today.add(Duration(days: 1))) {
        return 'Tomorrow • ${_formatDate(date)}';
      } else if (shiftDay == today.subtract(Duration(days: 1))) {
        return 'Yesterday • ${_formatDate(date)}';
      } else {
        final dayName = _getDayName(date.weekday);
        return '$dayName • ${_formatDate(date)}';
      }
    } catch (e) {
      return dateString;
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _getDayName(int weekday) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  bool _isShiftInPast(String dateString) {
    try {
      final shiftDate = DateTime.parse(dateString);
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final shiftDay = DateTime(shiftDate.year, shiftDate.month, shiftDate.day);
      return shiftDay.isBefore(today);
    } catch (e) {
      return false;
    }
  }

  Widget _buildShiftsLoading() {
    return Container(
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildNoShifts() {
    return Container(
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.schedule_outlined, size: 48, color: Color(0xFF8F9BB3)),
          SizedBox(height: 12),
          Text(
            'No shifts assigned',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1F36),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // UI COMPONENTS - Admin Section
  // ============================================================================
  Widget _buildAdminSection() {
    // 🔴 ONLY SHOW FOR ROOT USERS
    final isRoot = _userRole == "ROOT";

    return Container(
      margin: EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Alert Banner for urgent notifications
          _buildAlertBanner(),

          // Notifications Summary Card
          _buildNotificationsSummaryCard(),

          // ====================================================================
          // ADMIN TOOLS HEADER
          // ====================================================================
          Text(
            'Admin Dashboard',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1F36),
            ),
          ),
          SizedBox(height: 16),

          // ====================================================================
          // ROOT ONLY - ORGANIZATION MANAGEMENT (Agency & Department)
          // ====================================================================
          if (isRoot)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Organization Management Section Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Color(0xFFFF6B6B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.domain_rounded,
                        color: Color(0xFFFF6B6B),
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Organization Setup',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1F36),
                      ),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFFFF6B6B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'ROOT ONLY',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF6B6B),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Agency & Department Management Cards (2 columns)
                Row(
                  children: [
                    Expanded(
                      child: _buildAdminCard(
                        icon: Icons.business_rounded,
                        title: 'Manage\nAgencies',
                        subtitle: 'Create & edit agencies',
                        color: Color(0xFF2E5BFF),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AgencyManagementScreen(),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildAdminCard(
                        icon: Icons.domain_rounded,
                        title: 'Manage\nDepartments',
                        subtitle: 'Create & organize departments',
                        color: Color(0xFF667EEA),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DepartmentManagementScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20),
              ],
            ),

          // ====================================================================
          // STATION ADMIN TOOLS (For all admins)
          // ====================================================================
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.admin_panel_settings_rounded,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Station Management',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1F36),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildAdminCard(
                icon: Icons.people_outline_rounded,
                title: 'Manage\nUsers',
                subtitle: 'Add & manage officers',
                color: Color(0xFF51CF66),
                onTap: _openUserManagement,
              ),
              _buildAdminCard(
                icon: Icons.location_city_outlined,
                title: 'Police\nStations',
                subtitle: 'Create & configure',
                color: Color(0xFFFFB75E),
                onTap: _openPoliceStationManagement,
              ),
              _buildAdminCard(
                icon: Icons.description_rounded,
                title: 'Station\nIncidents',
                subtitle: 'View all incidents',
                color: Color(0xFF4ECDC4),
                onTap: _openStationIncidents,
              ),
              _buildAdminCard(
                icon: Icons.analytics_rounded,
                title: 'Reports\n& Analytics',
                subtitle: 'Statistics & insights',
                color: Color(0xFF667EEA),
                onTap: () {
                  _showSnackBar('Reports feature coming soon');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCitizenContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Alert Banner for urgent notifications
        _buildAlertBanner(),

        // Notifications Summary Card
        _buildNotificationsSummaryCard(),

        // Recent Activity Section
        _buildRecentActivitySection(),

        // Quick Action Buttons
        _buildQuickActionButtons(),

        // Original content
        Container(
          margin: EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Reports',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1F36),
                ),
              ),
              SizedBox(height: 16),

              // Citizen Incidents Card
              _buildCitizenIncidentsCard(),

              SizedBox(height: 16),

              // Recent incidents list (optional)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.description_outlined, size: 48, color: Color(0xFF8F9BB3)),
                    SizedBox(height: 12),
                    Text(
                      'No reports yet',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1F36),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your incident reports will appear here',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Color(0xFF8F9BB3),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCitizenIncidentsCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => MyIncidentsScreen()));
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00B894), Color(0xFF00A085)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF00B894).withOpacity(0.3),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.list_alt_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Incident Reports',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'View all your reported incidents',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withOpacity(0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1F36),
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Color(0xFF8F9BB3),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  // ============================================================================
// OFFICER INCIDENTS CARD
// ============================================================================

  Widget _buildOfficerIncidentsCard() {
    return GestureDetector(
      onTap: _openOfficerIncidents,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A3A6F), Color(0xFF2E5BFF)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF2E5BFF).withOpacity(0.3),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.assignment_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Assigned Incidents',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'View and manage incidents assigned to you',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withOpacity(0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // UI COMPONENTS - Modern Bottom Navigation
  // ============================================================================

  Widget _buildModernBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).bottomNavigationBarTheme.backgroundColor
            ?? Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Color(0xFF2E5BFF).withOpacity(0.08),
            blurRadius: 32,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBottomNavIcon(
                icon: Icons.home_rounded,
                label: 'Home',
                onTap: () {},
              ),
              _buildBottomNavIcon(
                icon: Icons.description_rounded,
                label: 'Reports',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MyIncidentsScreen()),
                  );
                },
              ),
              SizedBox(width: 64),
              _buildBottomNavIcon(
                icon: Icons.forum_rounded,
                label: 'Chats',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MyIncidentsScreen()),
                  );
                },
              ),
              _buildBottomNavIcon(
                icon: Icons.emergency_outlined,
                label: 'Report',
                onTap: _navigateToReportIncident,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavIcon({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 64,
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: Theme.of(context).iconTheme.color,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // UI COMPONENTS - Emergency Button
  // ============================================================================

  Widget _buildEmergencyButton() {
    return Container(
      width: 65,
      height: 65,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF6B6B),
            Color(0xFFFF5252),
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFF5252).withOpacity(0.4),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: _showEmergencyDialog,
          child: Center(
            child: Icon(
              Icons.emergency_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).cardColor,
                  Theme.of(context).scaffoldBackgroundColor
                ]
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFFF5252).withOpacity(0.3),
                blurRadius: 30,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF5252)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.emergency_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              SizedBox(height: 20),

              Text(
                'EMERGENCY',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF5252),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Choose emergency action',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Color(0xFF8F9BB3),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),

              _buildEmergencyAction(
                icon: Icons.phone_rounded,
                title: 'Call 112',
                subtitle: 'Emergency hotline',
                color: Color(0xFFFF5252),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              SizedBox(height: 12),
              _buildEmergencyAction(
                icon: Icons.warning_rounded,
                title: 'Panic Alert',
                subtitle: 'Notify nearby stations',
                color: Color(0xFFFFB75E),
                onTap: () {},
              ),
              SizedBox(height: 12),
              _buildEmergencyAction(
                icon: Icons.location_on_rounded,
                title: 'Share Location',
                subtitle: 'Send your location',
                color: Color(0xFF4ECDC4),
                onTap: () {
                  Navigator.pop(context);
                },
              ),

              SizedBox(height: 20),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8F9BB3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1F36),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Color(0xFF8F9BB3),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // UI COMPONENTS - Nearby Stations Dialog
  // ============================================================================

// ============================================================================
// NEARBY STATIONS DIALOG (Enhanced)
// ============================================================================

  Widget _buildNearbyStationsDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: FutureBuilder<void>(
          future: _getCurrentLocation(),
          builder: (context, snapshot) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                _buildDialogHeader(),

                // Current Location Info
                if (_currentPosition != null)
                  _buildCurrentLocationCard(),

                // Stations List
                Flexible(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? _buildDialogLoading()
                      : _nearbyStations.isEmpty
                      ? _buildDialogEmpty()
                      : _buildDialogStationsList(),
                ),

                // Footer - Cancel button only (selection navigates directly)
                _buildDialogFooter(),
              ],
            );
          },
        ),
      ),
    );
  }

// ============================================================================
// DIALOG COMPONENTS
// ============================================================================

  Widget _buildDialogHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Icon(Icons.location_city_rounded, color: Colors.white, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nearby Stations',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Select station to report incident',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentLocationCard() {
    return Container(
      margin: EdgeInsets.all(20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.successGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.my_location_rounded,
              color: AppTheme.successGreen,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Location',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1F36),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  _currentLocationName ?? 'Loading...',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Color(0xFF8F9BB3),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.successGreen,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  'Active',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogStationsList() {
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shrinkWrap: true,
      itemCount: _nearbyStations.length,
      separatorBuilder: (_, __) => SizedBox(height: 12),
      itemBuilder: (context, index) {
        final station = _nearbyStations[index];
        final name = station['name'] ?? 'Unknown Station';
        final distance = station['temporaryDistance'] ?? 0.0;
        final contact = station['contactInfo'] ?? 'N/A';
        final address = station['address'] ?? '';

        return InkWell(
          onTap: () => _selectStationForReport(station),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFF8F9FC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFFE4E9F2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Color(0xFF2E5BFF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.local_police_rounded,
                        color: Color(0xFF2E5BFF),
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1F36),
                            ),
                          ),
                          if (address.isNotEmpty)
                            Text(
                              address,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Color(0xFF8F9BB3),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: AppTheme.successGreen,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${distance.toStringAsFixed(1)}km',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.successGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.phone_rounded,
                        size: 14,
                        color: Color(0xFF2E5BFF),
                      ),
                      SizedBox(width: 8),
                      Text(
                        contact,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1F36),
                        ),
                      ),
                      Spacer(),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: Color(0xFF2E5BFF),
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

  Widget _buildDialogFooter() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE4E9F2)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Color(0xFFE4E9F2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1F36),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogLoading() {
    return Container(
      padding: EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Color(0xFF2E5BFF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(Color(0xFF2E5BFF)),
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Finding nearby stations...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1F36),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please wait',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Color(0xFF8F9BB3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogEmpty() {
    return Container(
      padding: EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Color(0xFFE4E9F2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 40,
              color: Color(0xFF8F9BB3),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'No Stations Found',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1F36),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'No police stations within ${_maxDistance.toInt()}km radius',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Color(0xFF8F9BB3),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          OutlinedButton(
            onPressed: () {
              setState(() => _maxDistance = _maxDistance + 50);
              _fetchNearbyPoliceStations(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              );
            },
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              side: BorderSide(color: Color(0xFF2E5BFF)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Search Wider Area',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E5BFF),
              ),
            ),
          ),
        ],
      ),
    );
  }

// ============================================================================
// UI COMPONENTS - Profile Drawer (COMPLETE WITH DELETE ACCOUNT)
// ============================================================================

  Widget _buildProfileDrawer() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ========================================================================
            // HEADER SECTION (FIXED - Not scrollable)
            // ========================================================================
            Container(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Profile Avatar
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(Icons.person, color: Colors.white, size: 32),
                  ),
                  SizedBox(height: 14),

                  // User Name
                  Text(
                    _userName ?? "User",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6),

                  // Role/Rank Display
                  if (_userRole == "POLICE_OFFICER" && _rank != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getShortRankDisplay(_rank),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else
                    Text(
                      _getRoleDisplayName(_userRole),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                ],
              ),
            ),

            // ========================================================================
            // SCROLLABLE CONTENT SECTION
            // ========================================================================
            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==================================================================
                    // PERSONAL INFORMATION CARD
                    // ==================================================================
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Color(0xFFF8F9FC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Color(0xFFE4E9F2), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline_rounded,
                                color: Color(0xFF2E5BFF),
                                size: 16,
                              ),
                              SizedBox(width: 7),
                              Text(
                                'Personal Information',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1F36),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),

                          _buildProfileInfoRow(
                            Icons.phone_rounded,
                            "Phone Number",
                            _userPhone ?? "N/A",
                          ),

                          if (_userRole == "POLICE_OFFICER") ...[
                            if (_rank != null)
                              _buildProfileInfoRow(
                                Icons.military_tech_rounded,
                                "Rank",
                                _getFullRankDisplay(_rank),
                                valueColor: AppTheme.successGreen,
                              ),
                            if (_badgeNumber != null)
                              _buildProfileInfoRow(
                                Icons.badge_rounded,
                                "Badge Number",
                                _badgeNumber!,
                                valueColor: Color(0xFF2E5BFF),
                              ),
                          ],

                          if (_stationName != null)
                            _buildProfileInfoRow(
                              Icons.location_on_rounded,
                              "Assigned Station",
                              _stationName!,
                            ),
                        ],
                      ),
                    ),

                    SizedBox(height: 14),

                    // ==================================================================
                    // ADMIN TOOLS (Only for Admins)
                    // ==================================================================
                    if (_userRole == "STATION_ADMIN" || _userRole == "ROOT") ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Color(0xFFF8F9FC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Color(0xFFE4E9F2), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.admin_panel_settings_rounded,
                                  color: AppTheme.errorRed,
                                  size: 16,
                                ),
                                SizedBox(width: 7),
                                Text(
                                  'Admin Tools',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1F36),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),

                            _buildProfileActionTile(
                              Icons.people_outline_rounded,
                              "Manage Users",
                              _openUserManagement,
                            ),
                            _buildProfileActionTile(
                              Icons.location_city_outlined,
                              "Police Stations",
                              _openPoliceStationManagement,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 14),
                    ],// 🎯 ADD THIS TO YOUR EXISTING DASHBOARD CLASS
// Add this method and update the drawer building

// ============================================================================
// UPDATE THE _buildProfileDrawer() METHOD - ADD THIS AFTER ADMIN TOOLS SECTION
// ============================================================================

// IN THE _buildProfileDrawer() METHOD, AFTER THE ADMIN TOOLS SECTION, ADD:

            if (_userRole == "ROOT") ...[
          SizedBox(height: 14),

        // ====================================================================
        // ROOT ONLY - ADMIN SETTINGS
        // ====================================================================
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E5BFF).withOpacity(0.1), Color(0xFF667EEA).withOpacity(0.1)],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Color(0xFF2E5BFF).withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF2E5BFF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ROOT ADMINISTRATOR',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2E5BFF),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Full system access',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: Color(0xFF2E5BFF).withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              // Root admin action buttons
              _buildProfileActionTile(
                Icons.domain_rounded,
                "Manage Agencies",
                    () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AgencyManagementScreen(),
                    ),
                  );
                },
              ),
              SizedBox(height: 8),
              _buildProfileActionTile(
                Icons.business_rounded,
                "Manage Departments",
                    () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DepartmentManagementScreen(),
                    ),
                  );
                },
              ),
              SizedBox(height: 8),
              _buildProfileActionTile(
                Icons.settings_rounded,
                "Admin Settings",
                    () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminSettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        ],

                    // ==================================================================
                    // LOGOUT BUTTON
                    // ==================================================================
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _logout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.errorRed,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.logout_rounded, size: 16, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Logout',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).cardColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ==================================================================
                    // DELETE ACCOUNT (Only for CITIZEN)
                    // ==================================================================
                    if (_userRole == "CITIZEN") ...[
                      SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton(
                          onPressed: _showDeleteAccountDialog,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppTheme.errorRed, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.delete_forever_rounded,
                                size: 17,
                                color: AppTheme.errorRed,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Delete Account',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.errorRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 6),
                      Center(
                        child: Text(
                          'This action cannot be undone',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Color(0xFF8F9BB3),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],

                    SizedBox(height: 16), // Bottom padding
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// ============================================================================
// PROFILE DRAWER - HELPER WIDGETS
// ============================================================================

  Widget _buildProfileInfoRow(
      IconData icon,
      String label,
      String value, {
        Color? valueColor,
      }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Container
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Color(0xFF2E5BFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 14,
              color: Color(0xFF2E5BFF),
            ),
          ),
          SizedBox(width: 12),

          // Label and Value
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Color(0xFF8F9BB3),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? Color(0xFF1A1F36),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileActionTile(
      IconData icon,
      String title,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: () {
        Navigator.pop(context); // Close drawer first
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: Color(0xFF8F9BB3),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1F36),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Color(0xFF8F9BB3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningPoint(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 6,
            color: Color(0xFF856404),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Color(0xFF856404),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // RANK DISPLAY HELPERS
  // ============================================================================

  String _getFullRankDisplay(String? rankAbbreviation) {
    if (rankAbbreviation == null) return "Officer";

    switch (rankAbbreviation.toUpperCase()) {
      case "PC":
        return "Police Constable (PC)";
      case "CPC":
        return "Corporal Police Constable (CPC)";
      case "SPC":
        return "Senior Police Constable (SPC)";
      case "SGT":
      case "PS":
        return "Police Sergeant (SGT)";
      case "SSGT":
      case "SPS":
        return "Senior Police Sergeant (SSGT)";
      case "CSGT":
      case "CPS":
        return "Corporal Police Sergeant (CSGT)";
      case "IP":
      case "INS":
        return "Inspector of Police (IP)";
      case "AIP":
      case "AINS":
        return "Assistant Inspector of Police (AIP)";
      case "ASP":
        return "Assistant Superintendent (ASP)";
      case "DSP":
        return "Deputy Superintendent (DSP)";
      case "SP":
        return "Superintendent (SP)";
      case "SSP":
        return "Senior Superintendent (SSP)";
      case "CSP":
        return "Chief Superintendent (CSP)";
      case "ACP":
        return "Assistant Commissioner (ACP)";
      case "DCP":
        return "Deputy Commissioner (DCP)";
      case "CP":
        return "Commissioner (CP)";
      case "IGP":
        return "Inspector General (IGP)";
      default:
        return rankAbbreviation;
    }
  }

  String _getShortRankDisplay(String? rankAbbreviation) {
    if (rankAbbreviation == null) return "Officer";

    switch (rankAbbreviation.toUpperCase()) {
      case "PC": return "Police Constable";
      case "CPC": return "Corporal Constable";
      case "SPC": return "Senior Constable";
      case "SGT":
      case "PS": return "Sergeant";
      case "SSGT":
      case "SPS": return "Senior Sergeant";
      case "IP":
      case "INS": return "Inspector";
      case "AIP":
      case "AINS": return "Asst. Inspector";
      case "ASP": return "Asst. Superintendent";
      case "DSP": return "Deputy Superintendent";
      case "SP": return "Superintendent";
      case "ACP": return "Asst. Commissioner";
      case "DCP": return "Deputy Commissioner";
      case "CP": return "Commissioner";
      case "IGP": return "Inspector General";
      default: return rankAbbreviation;
    }
  }

  // ============================================================================
  // UI COMPONENTS - Loading Screen
  // ============================================================================

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
                ),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
            SizedBox(height: 24),
            Text(
              "Loading...",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}