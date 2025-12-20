import 'package:flutter/material.dart';
import '../../services/graphql_service.dart';
import '../../utils/graphql_query.dart';
import '../../theme/app_theme.dart';
import '../shift/checkpoint_shifts_screen.dart';
import 'register_traffic_checkpoint_tab.dart';

class TrafficCheckpointsByStationScreen extends StatefulWidget {
  final String stationUid;
  final String stationName;

  const TrafficCheckpointsByStationScreen({
    required this.stationUid,
    required this.stationName,
    super.key,
  });

  @override
  State<TrafficCheckpointsByStationScreen> createState() => _TrafficCheckpointsByStationScreenState();
}

class _TrafficCheckpointsByStationScreenState extends State<TrafficCheckpointsByStationScreen>
    with TickerProviderStateMixin {
  final gql = GraphQLService();
  late Future<Map<String, dynamic>> checkpointsResponse;
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

    checkpointsResponse = _fetchCheckpoints();
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

  Future<Map<String, dynamic>> _fetchCheckpoints() async {
    setState(() => _isLoading = true);

    try {
      final variables = {
        "pageableParam": {
          "page": _currentPage,
          "size": _pageSize,
          "sortBy": "name",
          "sortDirection": "ASC",
          "searchParam": _searchQuery.isEmpty ? null : _searchQuery,
        },
        "stationUid": widget.stationUid,
      };

      print('Fetching checkpoints for station ${widget.stationUid} with variables: $variables');

      final response = await gql.sendAuthenticatedQuery(
        getTrafficCheckpointsByPoliceStationQuery,
        variables,
      );

      print('Checkpoints response: $response');

      if (response['errors'] != null) {
        final errorMessage = response['errors'][0]['message'] ?? 'Unknown error';
        _showModernSnackBar('Error fetching checkpoints: $errorMessage', isSuccess: false);
        return {
          'checkpoints': [],
          'totalElements': 0,
          'totalPages': 0,
          'currentPage': _currentPage,
        };
      }

      final data = response['data']?['getTrafficCheckpointsByPoliceStation'] ?? {};
      final checkpoints = data['data'] ?? [];
      final totalPages = data['pages'] ?? 0;

      setState(() => _hasMore = _currentPage < totalPages - 1);

      return {
        'checkpoints': List<Map<String, dynamic>>.from(checkpoints),
        'totalElements': data['elements'] ?? 0,
        'totalPages': totalPages,
        'currentPage': _currentPage,
      };
    } catch (e) {
      print("Error fetching checkpoints: $e");
      _showModernSnackBar('Error fetching checkpoints: $e', isSuccess: false);
      return {
        'checkpoints': [],
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
      checkpointsResponse = _fetchCheckpoints();
    }
  }

  void _refreshList() {
    setState(() {
      _currentPage = 0;
      _hasMore = true;
      _searchQuery = '';
      _searchController.clear();
    });
    checkpointsResponse = _fetchCheckpoints();
    _animationController.reset();
    _animationController.forward();
  }

  Future<void> _deleteCheckpoint(String uid) async {
    final confirm = await _showModernDialog();

    if (confirm == true) {
      try {
        final response =
        await gql.sendAuthenticatedMutation(deleteTrafficCheckpointMutation, {"uid": uid});
        final result = response['data']?['deleteTrafficCheckpoint'];
        final message = result?['message'] ?? "Delete failed";
        final isSuccess = result?['status'] == 'Success';

        _showModernSnackBar(message, isSuccess: isSuccess);

        if (isSuccess) {
          _refreshList();
        }
      } catch (e) {
        _showModernSnackBar("Error deleting checkpoint: $e", isSuccess: false);
      }
    }
  }

  // ✅ TOGGLE CHECKPOINT ACTIVATION/DEACTIVATION
  Future<void> _toggleCheckpointStatus(Map<String, dynamic> checkpoint) async {
    final checkpointUid = checkpoint['uid']?.toString() ?? '';
    final checkpointName = checkpoint['name'] ?? 'Unknown';
    final currentStatus = checkpoint['active'] ?? true;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          currentStatus ? 'Deactivate Checkpoint?' : 'Activate Checkpoint?',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Text(
          currentStatus
              ? 'Are you sure you want to deactivate "$checkpointName"?'
              : 'Are you sure you want to activate "$checkpointName"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentStatus ? Colors.red : Colors.green,
            ),
            child: Text(
              currentStatus ? 'Deactivate' : 'Activate',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await gql.sendAuthenticatedMutation(
        activateOrDeactivateCheckpointMutation,
        {"checkpointUid": checkpointUid},
      );

      print("📡 Response: $response");

      if (response['errors'] != null) {
        throw Exception(response['errors'][0]['message']);
      }

      final result = response['data']?['activateOrDeactivateCheckpoint'];
      final isSuccess = result?['status'] == 'Success' || result?['status'] == true;

      if (isSuccess) {
        final newStatus = result?['data']?['active'] ?? !currentStatus;
        final message = newStatus ? 'Checkpoint activated ✅' : 'Checkpoint deactivated ⚠️';

        _showModernSnackBar(message, isSuccess: true);

        // Refresh list to update UI
        _refreshList();
      } else {
        _showModernSnackBar(result?['message'] ?? "Failed to toggle checkpoint status", isSuccess: false);
      }
    } catch (e) {
      print("❌ Error: $e");
      _showModernSnackBar("Error: $e", isSuccess: false);
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
                    'Are you sure you want to delete this traffic checkpoint? This action cannot be undone.',
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

  void _showRegisterForm({Map<String, dynamic>? existingCheckpoint}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: RegisterTrafficCheckpointTab(
          existingCheckpoint: existingCheckpoint,
          preSelectedStationUid: widget.stationUid,
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
            checkpointsResponse = _fetchCheckpoints();
          });
        },
        style: TextStyle(
          fontSize: 14,
          color: Color(0xFF1A1F36),
        ),
        decoration: InputDecoration(
          hintText: 'Search checkpoint...',
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
                checkpointsResponse = _fetchCheckpoints();
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

  List<Map<String, dynamic>> _filterCheckpoints(List<Map<String, dynamic>> checkpoints) {
    if (_searchQuery.isEmpty) return checkpoints;

    return checkpoints.where((checkpoint) {
      final name = checkpoint['name']?.toString().toLowerCase() ?? '';
      final contactPhone = checkpoint['contactPhone']?.toString().toLowerCase() ?? '';
      final address = checkpoint['location']?['address']?.toString().toLowerCase() ?? '';
      final supervisor = checkpoint['supervisingOfficer']?['userAccount']?['name']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return name.contains(query) ||
          contactPhone.contains(query) ||
          address.contains(query) ||
          supervisor.contains(query);
    }).toList();
  }

  Widget _buildCheckpointCard(Map<String, dynamic> checkpoint, int index) {
    final checkpointName = checkpoint['name']?.toString() ?? 'Unknown Checkpoint';
    final contactPhone = checkpoint['contactPhone']?.toString() ?? '-';
    final address = checkpoint['location']?['address']?.toString() ?? 'Location not set';
    final supervisorName = checkpoint['supervisingOfficer']?['userAccount']?['name']?.toString() ?? 'Unassigned';
    final coverageRadius = checkpoint['coverageRadiusKm']?.toString() ?? '0';
    final checkpointUid = checkpoint['uid']?.toString() ?? '';
    final isActive = checkpoint['active'] ?? true;

    final opacity = isActive ? 1.0 : 0.5;
    final isDisabled = !isActive;

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _slideAnimation.value),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Opacity(
            opacity: opacity,
            child: Container(
              margin: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: 20,
                top: index == 0 ? 10 : 0,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? Color(0xFFFF9800).withOpacity(0.06)
                    : Color(0xFF999999).withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? Color(0xFFFF9800).withOpacity(0.15)
                      : Color(0xFF999999).withOpacity(0.15),
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
                  onTap: isDisabled ? null : () => _showRegisterForm(existingCheckpoint: checkpoint),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // ✅ TOP ROW: Icon + Name + Status Toggle Button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Hero(
                              tag: 'checkpoint_${checkpoint['uid'] ?? index}',
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isActive
                                        ? [
                                      Color(0xFFFF9800).withOpacity(0.8),
                                      Color(0xFFFF9800),
                                    ]
                                        : [
                                      Color(0xFF999999).withOpacity(0.8),
                                      Color(0xFF999999),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isActive ? Color(0xFFFF9800) : Color(0xFF999999)).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.traffic,
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
                                    checkpointName,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1F36),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? Color(0xFF10B981).withOpacity(0.1)
                                          : Color(0xFFFF6B6B).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isActive ? Icons.circle : Icons.circle_outlined,
                                          size: 8,
                                          color: isActive ? Color(0xFF10B981) : Color(0xFFFF6B6B),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isActive ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            color: isActive
                                                ? Color(0xFF10B981)
                                                : Color(0xFFFF6B6B),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _toggleCheckpointStatus(checkpoint),
                                  splashColor: isActive ? Color(0xFF10B981).withOpacity(0.2) : Color(0xFFFF6B6B).withOpacity(0.2),
                                  highlightColor: isActive ? Color(0xFF10B981).withOpacity(0.1) : Color(0xFFFF6B6B).withOpacity(0.1),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: isActive
                                          ? LinearGradient(
                                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                          : LinearGradient(
                                        colors: [Color(0xFFFF6B6B), Color(0xFFFF5252)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isActive ? Color(0xFF10B981).withOpacity(0.3) : Color(0xFFFF6B6B).withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          isActive ? 'Deactivate' : 'Activate',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // ✅ CHECKPOINT INFO ROWS
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCheckpointInfoRow(
                                    Icons.phone_rounded,
                                    'Contact',
                                    contactPhone,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: _buildCheckpointInfoRow(
                                    Icons.radio,
                                    'Coverage',
                                    '${coverageRadius} km',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildCheckpointInfoRow(
                              Icons.location_on_rounded,
                              'Address',
                              address,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 12),
                            _buildCheckpointInfoRow(
                              Icons.person_rounded,
                              'Supervisor',
                              supervisorName,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // ✅ ACTION BUTTONS - Only 4 (Edit, Shifts, Map, Delete)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildCheckpointActionButton(
                              icon: Icons.edit_rounded,
                              label: 'Edit',
                              color: Color(0xFF2E5BFF),
                              onPressed: isDisabled ? null : () =>
                                  _showRegisterForm(existingCheckpoint: checkpoint),
                            ),
                            _buildCheckpointActionButton(
                              icon: Icons.schedule_rounded,
                              label: 'Shifts',
                              color: Color(0xFFFF9800),
                              onPressed: isDisabled ? null : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CheckpointShiftsScreen(
                                      checkpointUid: checkpointUid,
                                      checkpointName: checkpointName,
                                      stationName: widget.stationName,
                                    ),
                                  ),
                                );
                              },
                            ),
                            _buildCheckpointActionButton(
                              icon: Icons.map_rounded,
                              label: 'Map',
                              color: Color(0xFF4ECDC4),
                              onPressed: isDisabled ? null : () {
                                _showModernSnackBar(
                                  'Map view coming soon',
                                  isSuccess: true,
                                );
                              },
                            ),
                            _buildCheckpointActionButton(
                              icon: Icons.delete_outline_rounded,
                              label: 'Delete',
                              color: Color(0xFFFF6B6B),
                              onPressed: isDisabled ? null : () => _deleteCheckpoint(checkpointUid),
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
      ),
    );
  }
  void _showCheckpointDetails(Map<String, dynamic> checkpoint) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          checkpoint['name'] ?? 'Checkpoint Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1F36),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Contact Phone', checkpoint['contactPhone'] ?? 'N/A'),
              _buildDetailRow('Coverage Radius', '${checkpoint['coverageRadiusKm'] ?? '0'} km'),
              _buildDetailRow(
                'Latitude',
                (checkpoint['location']?['latitude'] ?? 'N/A').toString(),
              ),
              _buildDetailRow(
                'Longitude',
                (checkpoint['location']?['longitude'] ?? 'N/A').toString(),
              ),
              _buildDetailRow(
                'Address',
                checkpoint['location']?['address'] ?? 'N/A',
              ),
              _buildDetailRow(
                'Supervisor',
                checkpoint['supervisingOfficer']?['userAccount']?['name'] ?? 'Unassigned',
              ),
              _buildDetailRow(
                'Department',
                checkpoint['department']?['name'] ?? 'N/A',
              ),
              _buildDetailRow(
                'Status',
                checkpoint['active'] == true ? 'Active' : 'Inactive',
                color: checkpoint['active'] == true ? Color(0xFF10B981) : Color(0xFFFF6B6B),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: Color(0xFF2E5BFF)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color ?? Color(0xFF1A1F36),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckpointInfoRow(
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
            color: Color(0xFFFF9800).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: Color(0xFFFF9800),
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

  Widget _buildCheckpointActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    final isDisabled = onPressed == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDisabled
                ? Colors.grey.withOpacity(0.1)
                : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDisabled
                  ? Colors.grey.withOpacity(0.2)
                  : color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: IconButton(
            icon: Icon(icon, size: 20),
            color: isDisabled ? Colors.grey : color,
            onPressed: onPressed,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDisabled ? Colors.grey : color,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
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
            Color(0xFFFF9800),
            Color(0xFFFF6B35),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFF9800).withOpacity(0.3),
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
              Icons.traffic,
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
                  'Total Checkpoints',
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
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF9800), Color(0xFFFF6B35)],
                ),
              ),
              child: FlexibleSpaceBar(
                title: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Traffic Checkpoints',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      widget.stationName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
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
              future: checkpointsResponse,
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
                                colors: [Color(0xFFFF9800), Color(0xFFFF6B35)],
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
                            'Loading checkpoints...',
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
                          'Failed to load checkpoints',
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
                  final allCheckpoints =
                  data['checkpoints'] as List<Map<String, dynamic>>;
                  final filteredCheckpoints = _filterCheckpoints(allCheckpoints);

                  if (allCheckpoints.isEmpty) {
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
                                colors: [Color(0xFFFF9800), Color(0xFFFF6B35)],
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.traffic_outlined,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No checkpoints found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1F36),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Click the (+) button to add the first traffic checkpoint',
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
                      if (filteredCheckpoints.isEmpty && _searchQuery.isNotEmpty)
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
                        ...filteredCheckpoints.asMap().entries.map((entry) {
                          return _buildCheckpointCard(entry.value, entry.key);
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
              colors: [Color(0xFFFF9800), Color(0xFFFF6B35)],
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFFF9800).withOpacity(0.3),
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
              'Add Checkpoint',
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
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}