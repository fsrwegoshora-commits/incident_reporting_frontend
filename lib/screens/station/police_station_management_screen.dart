import 'package:flutter/material.dart';
import 'package:incident_reporting_frontend/screens/station/police_station_form.dart';
import 'package:incident_reporting_frontend/screens/police/police_officers_by_station_screen.dart';
import 'package:incident_reporting_frontend/screens/station/traffic_checkpoints_by_station_screen.dart';
import '../../services/graphql_service.dart';
import '../../utils/graphql_query.dart';
import '../../theme/app_theme.dart';
import '../shift/officer_shift_management_screen.dart';

class PoliceStationManagementScreen extends StatefulWidget {
  const PoliceStationManagementScreen({super.key});

  @override
  State<PoliceStationManagementScreen> createState() => _PoliceStationManagementScreenState();
}

class _PoliceStationManagementScreenState extends State<PoliceStationManagementScreen>
    with TickerProviderStateMixin {
  final gql = GraphQLService();
  late Future<Map<String, dynamic>> policeStationsResponse;
  late AnimationController _animationController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _fabAnimation;

  int _currentPage = 0;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.elasticOut),
    );

    policeStationsResponse = _fetchPoliceStations();
    _animationController.forward();
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fabAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchPoliceStations() async {
    setState(() => _isLoading = true);

    try {
      final variables = {
        "pageableParam": {
          "page": _currentPage,
          "size": _pageSize,
          "sortBy": "createdAt",
          "sortDirection": "DESC",
          "searchParam": _searchQuery.isEmpty ? null : _searchQuery,
          "isActive": true,
        }
      };
      print('Fetching police stations with variables: $variables');

      final response = await gql.sendAuthenticatedQuery(getPoliceStationsQueryMutation, variables);

      print('Police stations response: $response');

      if (response['errors'] != null) {
        final errorMessage = response['errors'][0]['message'] ?? 'Unknown error';
        _showModernSnackBar('Error fetching police stations: $errorMessage', isSuccess: false);
        return {
          'policeStations': [],
          'totalElements': 0,
          'totalPages': 0,
          'currentPage': _currentPage,
        };
      }

      final data = response['data']?['getPoliceStations'] ?? {};
      final policeStations = data['data'] ?? [];
      final totalPages = data['pages'] ?? 0;

      setState(() => _hasMore = _currentPage < totalPages - 1);

      return {
        'policeStations': List<Map<String, dynamic>>.from(policeStations),
        'totalElements': data['elements'] ?? 0,
        'totalPages': totalPages,
        'currentPage': _currentPage,
      };
    } catch (e) {
      print("Error fetching police stations: $e");
      _showModernSnackBar('Error fetching police stations: $e', isSuccess: false);
      return {
        'policeStations': [],
        'totalElements': 0,
        'totalPages': 0,
        'currentPage': _currentPage,
      };
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loadNextPage() {
    if (_hasMore && !_isLoading) {
      setState(() => _currentPage++);
      policeStationsResponse = _fetchPoliceStations();
    }
  }

  void _refreshList() {
    setState(() {
      _currentPage = 0;
      _hasMore = true;
      _searchQuery = '';
      _searchController.clear();
    });
    policeStationsResponse = _fetchPoliceStations();
    _animationController.reset();
    _animationController.forward();
  }

  void _deletePoliceStation(String uid) async {
    final confirm = await _showModernDialog();

    if (confirm == true) {
      try {
        final response = await gql.sendAuthenticatedMutation(deletePoliceStationMutation, {"uid": uid});
        final result = response['data']?['deletePoliceStation'];
        final message = result?['message'] ?? "Delete failed";
        final isSuccess = result?['status'] == 'Success';

        _showModernSnackBar(message, isSuccess: isSuccess);

        if (isSuccess) {
          _refreshList();
        }
      } catch (e) {
        _showModernSnackBar("Error deleting police station: $e", isSuccess: false);
      }
    }
  }

  Future<bool?> _showModernDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 800),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) => Transform.scale(
          scale: value,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
            content: Container(
              decoration: BoxDecoration(
                color: Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF2E5BFF).withOpacity(0.1),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFFF5252)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.warning_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Confirm Deletion',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1F36),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Are you sure you want to delete this police station? This action cannot be undone.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8F9BB3),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _ModernButton(
                          text: 'Cancel',
                          onPressed: () => Navigator.of(context).pop(false),
                          isOutlined: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ModernButton(
                          text: 'Delete',
                          onPressed: () => Navigator.of(context).pop(true),
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFFF5252)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showModernSnackBar(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          decoration: BoxDecoration(
            gradient: isSuccess
                ? LinearGradient(colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)])
                : LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF5252)]),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _showRegisterForm({Map<String, dynamic>? existingPoliceStation}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PoliceStationForm(
          existingPoliceStation: existingPoliceStation,
          onSubmit: () {
            Navigator.pop(context);
            _refreshList();
          },
        ),
      ),
    );
  }

  Widget _buildModernSearchBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF2E5BFF).withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _currentPage = 0;
            _hasMore = true;
            policeStationsResponse = _fetchPoliceStations();
          });
        },
        style: TextStyle(
          fontSize: 14,
          color: Color(0xFF1A1F36),
        ),
        decoration: InputDecoration(
          hintText: 'Search police station...',
          hintStyle: TextStyle(
            fontSize: 14,
            color: Color(0xFF8F9BB3),
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.search, color: Colors.white, size: 20),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, color: Color(0xFF8F9BB3)),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _currentPage = 0;
                _hasMore = true;
                policeStationsResponse = _fetchPoliceStations();
              });
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterPoliceStations(List<Map<String, dynamic>> policeStations) {
    if (_searchQuery.isEmpty) return policeStations;

    return policeStations.where((station) {
      final name = station['name']?.toString().toLowerCase() ?? '';
      final contact = station['contactInfo']?.toString().toLowerCase() ?? '';
      final address = station['policeStationLocation']?['label']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return name.contains(query) || contact.contains(query) || address.contains(query);
    }).toList();
  }

  String _normalizePhoneNumber(String contactInfo) {
    String cleaned = contactInfo.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('0')) {
      return '+255${cleaned.substring(1)}';
    } else if (cleaned.startsWith('+255')) {
      return cleaned;
    }
    return contactInfo;
  }

  Widget _buildPoliceStationCard(Map<String, dynamic> station, int index) {
    final stationName = station['name']?.toString() ?? 'Unknown Station';
    final contactInfo = _normalizePhoneNumber(station['contactInfo']?.toString() ?? '-');
    final locationLabel = station['policeStationLocation']?['label']?.toString() ?? 'Location not set';
    final stationUid = station['uid']?.toString() ?? '';

    Color getStationColor() {
      final name = stationName.toLowerCase();
      if (name.contains('headquarters') || name.contains('central')) {
        return Colors.purple[700] ?? Colors.purple;
      } else if (name.contains('district') || name.contains('regional')) {
        return Colors.indigo[700] ?? Colors.indigo;
      } else if (name.contains('traffic') || name.contains('highway')) {
        return Colors.orange[700] ?? Colors.orange;
      } else {
        return Color(0xFF2E5BFF);
      }
    }

    IconData getStationIcon() {
      final name = stationName.toLowerCase();
      if (name.contains('headquarters') || name.contains('central')) {
        return Icons.account_balance_rounded;
      } else if (name.contains('traffic') || name.contains('highway')) {
        return Icons.traffic_rounded;
      } else {
        return Icons.local_police_rounded;
      }
    }

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _slideAnimation.value),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            margin: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: 20,
              top: index == 0 ? 10 : 0,
            ),
            decoration: BoxDecoration(
              color: getStationColor().withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: getStationColor().withOpacity(0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _showRegisterForm(existingPoliceStation: station),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Hero(
                            tag: 'station_${station['uid'] ?? index}',
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    getStationColor().withOpacity(0.8),
                                    getStationColor(),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: getStationColor().withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                getStationIcon(),
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stationName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1F36),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: getStationColor().withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: getStationColor().withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.business_rounded,
                                        size: 14,
                                        color: getStationColor(),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _getStationType(stationName),
                                        style: TextStyle(
                                          color: getStationColor(),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildStationInfoRow(
                                  Icons.phone_rounded,
                                  'Contact',
                                  contactInfo,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: _buildStationInfoRow(
                                  Icons.location_on_rounded,
                                  'Location',
                                  locationLabel,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildStationInfoRow(
                            Icons.pin_rounded,
                            'Station ID',
                            stationUid.isNotEmpty ? stationUid.substring(0, 8).toUpperCase() : 'N/A',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Action Buttons - Updated with Traffic Checkpoints
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStationActionButton(
                            icon: Icons.edit_rounded,
                            label: 'Edit',
                            color: getStationColor(),
                            onPressed: () => _showRegisterForm(existingPoliceStation: station),
                          ),
                          _buildStationActionButton(
                            icon: Icons.people_rounded,
                            label: 'Officers',
                            color: Color(0xFF4ECDC4),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PoliceOfficersByStationScreen(
                                    stationUid: stationUid,
                                    stationName: stationName,
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildStationActionButton(
                            icon: Icons.traffic_rounded,
                            label: 'Checkpoints',
                            color: Color(0xFFFF9800),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TrafficCheckpointsByStationScreen(
                                    stationUid: stationUid,
                                    stationName: stationName,
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildStationActionButton(
                            icon: Icons.schedule_rounded,
                            label: 'Shifts',
                            color: Color(0xFFFFB75E),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OfficerShiftManagementScreen(
                                    stationUid: stationUid,
                                    stationName: stationName,
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildStationActionButton(
                            icon: Icons.delete_outline_rounded,
                            label: 'Delete',
                            color: Color(0xFFFF6B6B),
                            onPressed: () => _confirmDeleteStation(station),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStationInfoRow(
      IconData icon,
      String label,
      String value, {
        int maxLines = 1,
        Color? textColor,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Color(0xFF2E5BFF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: Color(0xFF2E5BFF),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8F9BB3),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor ?? Color(0xFF1A1F36),
                  fontWeight: FontWeight.w600,
                ),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStationActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: IconButton(
            icon: Icon(icon, size: 20),
            color: color,
            onPressed: onPressed,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _getStationType(String stationName) {
    final name = stationName.toLowerCase();
    if (name.contains('headquarters') || name.contains('central')) {
      return 'HEADQUARTERS';
    } else if (name.contains('district')) {
      return 'DISTRICT';
    } else if (name.contains('regional')) {
      return 'REGIONAL';
    } else if (name.contains('traffic')) {
      return 'TRAFFIC';
    } else {
      return 'STATION';
    }
  }

  void _confirmDeleteStation(Map<String, dynamic> station) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Station'),
        content: Text(
          'Are you sure you want to delete "${station['name'] ?? 'this station'}"?\n\n'
              'This action cannot be undone and will affect all officers assigned to this station.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePoliceStation(station['uid']);
            },
            style: TextButton.styleFrom(
              foregroundColor: Color(0xFFFF6B6B),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Center(
        child: _isLoading
            ? Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1A1F36),
                ),
              ),
            ],
          ),
        )
            : _ModernButton(
          text: 'Load More',
          onPressed: _loadNextPage,
          icon: Icons.expand_more,
        ),
      ),
    );
  }

  Widget _buildStatsCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_police,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Police Stations',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data['totalElements'] ?? 0}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
                ),
              ),
              child: FlexibleSpaceBar(
                title: Text(
                  'Police Station Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                centerTitle: false,
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _refreshList,
                  tooltip: 'Refresh',
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildModernSearchBar(),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: FutureBuilder<Map<String, dynamic>>(
              future: policeStationsResponse,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _currentPage == 0) {
                  return Container(
                    height: 300,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Loading police stations...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1F36),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Color(0xFFF8F9FC),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF2E5BFF).withOpacity(0.1),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFFF6B6B), Color(0xFFFF5252)],
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Failed to load police stations',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1F36),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          snapshot.error.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFFF6B6B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        _ModernButton(
                          text: 'Try Again',
                          onPressed: _refreshList,
                          icon: Icons.refresh,
                        ),
                      ],
                    ),
                  );
                } else if (snapshot.hasData) {
                  final data = snapshot.data!;
                  final allStations = data['policeStations'] as List<Map<String, dynamic>>;
                  final filteredStations = _filterPoliceStations(allStations);

                  if (allStations.isEmpty) {
                    return Container(
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Color(0xFFF8F9FC),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF2E5BFF).withOpacity(0.1),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.local_police_outlined,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No police stations found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1F36),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Click the (+) button to add the first police station',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8F9BB3),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      _buildStatsCard(data),
                      const SizedBox(height: 20),
                      if (filteredStations.isEmpty && _searchQuery.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Color(0xFFF8F9FC),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF2E5BFF).withOpacity(0.1),
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 60,
                                color: Color(0xFF8F9BB3),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No results found',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1F36),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Try using a different search term',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF8F9BB3),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else
                        ...filteredStations.asMap().entries.map((entry) {
                          return _buildPoliceStationCard(entry.value, entry.key);
                        }).toList(),
                      if (_hasMore && _searchQuery.isEmpty) _buildLoadMoreButton(),
                      const SizedBox(height: 100),
                    ],
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF2E5BFF).withOpacity(0.3),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () => _showRegisterForm(),
            backgroundColor: Colors.transparent,
            elevation: 0,
            icon: const Icon(Icons.add_location, color: Colors.white),
            label: Text(
              'Register Police Station',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isOutlined;
  final LinearGradient? gradient;

  const _ModernButton({
    required this.text,
    required this.onPressed,
    this.icon,
    this.isOutlined = false,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Color(0xFFE4E9F2), width: 2),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Color(0xFF1A1F36), size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
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
    }

    return Container(
      decoration: BoxDecoration(
        gradient: gradient ??
            LinearGradient(
              colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
            ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF2E5BFF).withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(text,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}