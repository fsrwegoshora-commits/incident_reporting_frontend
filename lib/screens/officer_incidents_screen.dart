import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/graphql_service.dart';
import '../utils/graphql_query.dart';
import '../theme/app_theme.dart';
import 'incident_chat_screen.dart';
import 'incident_details_screen.dart';

class OfficerIncidentsScreen extends StatefulWidget {
  @override
  _OfficerIncidentsScreenState createState() => _OfficerIncidentsScreenState();
}

class _OfficerIncidentsScreenState extends State<OfficerIncidentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _allIncidents = [];
  List<Map<String, dynamic>> _myIncidents = [];
  List<Map<String, dynamic>> _stationIncidents = [];

  bool _isLoadingAll = true;
  bool _isLoadingMy = true;
  bool _isLoadingStation = true;

  String? _currentUserUid;
  String? _officerUid;
  String? _stationUid;
  String? _userRole;

  // Filters
  String? _statusFilter;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final gql = GraphQLService();
      final response = await gql.sendAuthenticatedQuery(meQuery, {});
      final user = response['data']?['me']?['data'];

      if (user != null) {
        setState(() {
          _currentUserUid = user['uid'];
          _officerUid = user['officerUid'];
          _stationUid = user['stationUid'];
          _userRole = user['role'];
        });

        await Future.wait([
          _loadAllIncidents(),
          _loadMyIncidents(),
          if (_userRole == 'STATION_ADMIN' || _userRole == 'ROOT')
            _loadStationIncidents(),
        ]);
      }
    } catch (e) {
      _showSnackBar('Failed to load data: $e', isError: true);
    }
  }

  Future<void> _loadAllIncidents({String? searchKey}) async {
    setState(() => _isLoadingAll = true);

    try {
      final gql = GraphQLService();

      final bool isStationAdmin = _userRole == 'STATION_ADMIN' || _userRole == 'ROOT';
      final String query = isStationAdmin ? getStationIncidentsQuery : getOfficerIncidentsQuery;
      final String dataKey = isStationAdmin ? 'getStationIncidents' : 'getOfficerIncidents';

      final response = await gql.sendAuthenticatedQuery(
        query,
        {
          'pageableParam': {
            'page': 0,
            'size': 50,
            'isActive': true,
            'searchParam': searchKey ?? '',
          },
          'status': _statusFilter,
        },
      );

      if (response.containsKey('errors')) {
        setState(() => _isLoadingAll = false);
        return;
      }

      final result = response['data']?[dataKey];
      if (result['status'] == 'Success') {
        final incidents = result['data'] as List<dynamic>? ?? [];
        setState(() {
          _allIncidents = incidents.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print('Error loading all incidents: $e');
    } finally {
      setState(() => _isLoadingAll = false);
    }
  }

  Future<void> _loadMyIncidents({String? searchKey}) async {
    setState(() => _isLoadingMy = true);

    try {
      final gql = GraphQLService();

      if (_userRole == 'STATION_ADMIN' || _userRole == 'ROOT') {
        // Tumia station incidents filtered na status IN_PROGRESS
        final response = await gql.sendAuthenticatedQuery(
          getStationIncidentsQuery,
          {
            'pageableParam': {
              'page': 0,
              'size': 50,
              'isActive': true,
              'searchParam': searchKey ?? '',
            },
            'status': 'IN_PROGRESS',
          },
        );

        if (response.containsKey('errors')) {
          setState(() => _isLoadingMy = false);
          return;
        }

        final result = response['data']?['getStationIncidents'];
        if (result['status'] == 'Success') {
          final incidents = result['data'] as List<dynamic>? ?? [];
          setState(() {
            _myIncidents = incidents.cast<Map<String, dynamic>>();
          });
        }
      } else {
        // Police Officer - tumia officer incidents
        final response = await gql.sendAuthenticatedQuery(
          getOfficerIncidentsQuery,
          {
            'pageableParam': {
              'page': 0,
              'size': 50,
              'isActive': true,
              'searchParam': searchKey ?? '',
            },
            'status': 'IN_PROGRESS',
          },
        );

        if (response.containsKey('errors')) {
          setState(() => _isLoadingMy = false);
          return;
        }

        final result = response['data']?['getOfficerIncidents'];
        if (result['status'] == 'Success') {
          final incidents = result['data'] as List<dynamic>? ?? [];
          setState(() {
            _myIncidents = incidents.cast<Map<String, dynamic>>();
          });
        }
      }
    } catch (e) {
      print('Error loading my incidents: $e');
    } finally {
      setState(() => _isLoadingMy = false);
    }
  }

  Future<void> _loadStationIncidents({String? searchKey}) async {
    if (_stationUid == null) {
      setState(() => _isLoadingStation = false);
      return;
    }

    setState(() => _isLoadingStation = true);

    try {
      final gql = GraphQLService();
      final response = await gql.sendAuthenticatedQuery(
        getStationIncidentsQuery,
        {
          'pageableParam': {
            'page': 0,
            'size': 50,
            'isActive': true,
            'searchParam': searchKey ?? '',
          },
          'status': _statusFilter,
        },
      );

      if (response.containsKey('errors')) {
        setState(() => _isLoadingStation = false);
        return;
      }

      final result = response['data']?['getStationIncidents'];
      if (result['status'] == 'Success') {
        final content = result['data'] as List<dynamic>? ?? [];
        setState(() {
          _stationIncidents = content.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print('Error loading station incidents: $e');
    } finally {
      setState(() => _isLoadingStation = false);
    }
  }

  void _applyFilters() {
    _loadAllIncidents(searchKey: _searchController.text);
    _loadMyIncidents(searchKey: _searchController.text);
    if (_userRole == 'STATION_ADMIN' || _userRole == 'ROOT') {
      _loadStationIncidents(searchKey: _searchController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildSearchBar(),
            _buildFilterChips(),
            _buildStatsCards(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _userRole == 'STATION_ADMIN' || _userRole == 'ROOT'
                    ? [
                  _buildIncidentsList(_myIncidents, _isLoadingMy, 'Active'),
                  _buildIncidentsList(_allIncidents, _isLoadingAll, 'All Station'),
                  _buildIncidentsList(_stationIncidents, _isLoadingStation, 'Overview'),
                ]
                    : [
                  _buildIncidentsList(_myIncidents, _isLoadingMy, 'Active'),
                  _buildIncidentsList(_allIncidents, _isLoadingAll, 'All Mine'),
                  _buildIncidentsList(_stationIncidents, _isLoadingStation, 'All'),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildQuickActionsFAB(),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Color(0xFF1A1F36)),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Incident Management',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1F36),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: Color(0xFF2E5BFF)),
            onPressed: _applyFilters,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.white,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFFE4E9F2)),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: Color(0xFF8F9BB3), size: 20),
            SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search incidents...',
                  border: InputBorder.none,
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Color(0xFF8F9BB3),
                  ),
                ),
                onChanged: (value) {
                  _applyFilters();
                },
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: Icon(Icons.clear_rounded, size: 18, color: Color(0xFF8F9BB3)),
                onPressed: () {
                  _searchController.clear();
                  _applyFilters();
                },
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', null),
            SizedBox(width: 8),
            _buildFilterChip('Pending', 'PENDING'),
            SizedBox(width: 8),
            _buildFilterChip('In Progress', 'IN_PROGRESS'),
            SizedBox(width: 8),
            _buildFilterChip('Resolved', 'RESOLVED'),
            SizedBox(width: 8),
            _buildFilterChip('Rejected', 'REJECTED'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String? status) {
    final isSelected = _statusFilter == status;
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isSelected ? Colors.white : Color(0xFF1A1F36),
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _statusFilter = selected ? status : null);
        _applyFilters();
      },
      backgroundColor: Color(0xFFF8F9FC),
      selectedColor: AppTheme.primaryBlue,
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildStatsCards() {
    final myActive = _myIncidents.length;
    final allCount = _allIncidents.length;
    final stationTotal = _stationIncidents.length;
    final pending = _allIncidents.where((i) => i['status'] == 'PENDING').length;
    final inProgress = _allIncidents.where((i) => i['status'] == 'IN_PROGRESS').length;
    final resolved = _allIncidents.where((i) => i['status'] == 'RESOLVED').length;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatCard(
              icon: Icons.assignment_rounded,
              label: 'Active',
              value: '$myActive',
              color: Color(0xFF2E5BFF),
            ),
            SizedBox(width: 12),
            _buildStatCard(
              icon: Icons.pending_outlined,
              label: 'Pending',
              value: '$pending',
              color: Color(0xFFFFB75E),
            ),
            SizedBox(width: 12),
            _buildStatCard(
              icon: Icons.pending_actions_rounded,
              label: 'In Progress',
              value: '$inProgress',
              color: Color(0xFF667EEA),
            ),
            SizedBox(width: 12),
            _buildStatCard(
              icon: Icons.check_circle_rounded,
              label: 'Resolved',
              value: '$resolved',
              color: AppTheme.successGreen,
            ),
            if (_userRole == 'STATION_ADMIN' || _userRole == 'ROOT') ...[
              SizedBox(width: 12),
              _buildStatCard(
                icon: Icons.location_city_rounded,
                label: 'Station',
                value: '$stationTotal',
                color: Color(0xFF9C27B0),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: 110,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE4E9F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1F36),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Color(0xFF8F9BB3),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final bool isStationAdmin = _userRole == 'STATION_ADMIN' || _userRole == 'ROOT';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE4E9F2)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Color(0xFF8F9BB3),
        labelStyle: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 13,
        ),
        tabs: isStationAdmin
            ? [
          Tab(text: 'Active'),
          Tab(text: 'All Station'),
          Tab(text: 'Overview'),
        ]
            : [
          Tab(text: 'Active'),
          Tab(text: 'All Mine'),
          Tab(text: 'All'),
        ],
      ),
    );
  }

  Widget _buildIncidentsList(
      List<Map<String, dynamic>> incidents,
      bool isLoading,
      String type,
      ) {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(0xFF2E5BFF)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading...',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Color(0xFF8F9BB3),
              ),
            ),
          ],
        ),
      );
    }

    if (incidents.isEmpty) {
      return _buildEmpty(type);
    }

    return RefreshIndicator(
      onRefresh: () async => _applyFilters(),
      child: ListView.builder(
        padding: EdgeInsets.all(20),
        itemCount: incidents.length,
        itemBuilder: (context, index) {
          return _buildIncidentCard(incidents[index]);
        },
      ),
    );
  }

  Widget _buildIncidentCard(Map<String, dynamic> incident) {
    final title = incident['title'] ?? 'Incident';
    final type = incident['type'] ?? 'OTHER';
    final location = incident['location'] ?? 'Unknown';
    final status = incident['status'] ?? 'PENDING';
    final reportedAt = incident['reportedAt'] ?? '';
    final reportedBy = incident['reportedBy'];
    final reporterName = reportedBy?['name'] ?? 'Unknown';

    final statusInfo = _getStatusInfo(status);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFE4E9F2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openIncidentDetails(incident),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getTypeColor(type).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getTypeIcon(type),
                        color: _getTypeColor(type),
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1F36),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            _formatType(type),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Color(0xFF8F9BB3),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusInfo['color'].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: statusInfo['color'].withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        statusInfo['label'],
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusInfo['color'],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFF8F9FC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 16, color: Color(0xFF8F9BB3)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reporterName,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1F36),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatDate(reportedAt),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Color(0xFF8F9BB3),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF8F9BB3)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        location,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Color(0xFF8F9BB3),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.chat_rounded,
                        label: 'Chat',
                        color: Color(0xFF2E5BFF),
                        onTap: () => _openChat(incident),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.info_outline,
                        label: 'Details',
                        color: Color(0xFF4ECDC4),
                        onTap: () => _openIncidentDetails(incident),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsFAB() {
    final pendingCount = _allIncidents.where((i) => i['status'] == 'PENDING').length;
    final inProgressCount = _allIncidents.where((i) => i['status'] == 'IN_PROGRESS').length;

    if (pendingCount == 0 && inProgressCount == 0) return SizedBox.shrink();

    return FloatingActionButton(
      onPressed: () => _showQuickActionsSheet(),
      backgroundColor: AppTheme.primaryBlue,
      child: Icon(Icons.flash_on_rounded, color: Colors.white),
    );
  }

  void _showQuickActionsSheet() {
    final pendingCount = _allIncidents.where((i) => i['status'] == 'PENDING').length;
    final inProgressCount = _allIncidents.where((i) => i['status'] == 'IN_PROGRESS').length;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.flash_on_rounded,
                    color: AppTheme.primaryBlue,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Text(
                  'Quick Actions',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1F36),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),

            _buildQuickActionTile(
              icon: Icons.play_arrow_rounded,
              title: 'Start Next Pending',
              subtitle: '$pendingCount pending incidents',
              color: Color(0xFFFFB75E),
              enabled: pendingCount > 0,
              onTap: () {
                Navigator.pop(context);
                final nextPending = _allIncidents.firstWhere(
                      (i) => i['status'] == 'PENDING',
                  orElse: () => {},
                );
                if (nextPending.isNotEmpty) {
                  _showStatusUpdateDialog(nextPending);
                }
              },
            ),

            _buildQuickActionTile(
              icon: Icons.done_all_rounded,
              title: 'Mark All Resolved',
              subtitle: '$inProgressCount in progress',
              color: AppTheme.successGreen,
              enabled: inProgressCount > 0,
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Bulk update coming soon');
              },
            ),

            _buildQuickActionTile(
              icon: Icons.assessment_rounded,
              title: 'Generate Report',
              subtitle: 'Export activity report',
              color: Color(0xFF667EEA),
              enabled: true,
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Report generation coming soon');
              },
            ),

            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
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
                  'Close',
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
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: enabled ? Color(0xFF1A1F36) : Color(0xFF8F9BB3),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: Color(0xFF8F9BB3),
        ),
      ),
      onTap: enabled ? onTap : null,
      enabled: enabled,
    );
  }

  void _showStatusUpdateDialog(Map<String, dynamic> incident) {
    final currentStatus = incident['status'] ?? 'PENDING';

    showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: EdgeInsets.all(24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
            Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF2E5BFF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.update_rounded,
              color: Color(0xFF2E5BFF),
              size: 40,
            ),
          ),
          SizedBox(height: 20),Text(
                    'Update Status',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1F36),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Current: ${_getStatusText(currentStatus)}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Color(0xFF8F9BB3),
                    ),
                  ),
                  SizedBox(height: 24),

                  if (currentStatus == 'PENDING')
                    _buildStatusOptionButton(
                      'IN_PROGRESS',
                      'Start Working',
                      Color(0xFF2E5BFF),
                      incident,
                    ),

                  if (currentStatus == 'IN_PROGRESS') ...[
                    _buildStatusOptionButton(
                      'RESOLVED',
                      'Mark Resolved',
                      AppTheme.successGreen,
                      incident,
                    ),
                    SizedBox(height: 12),
                    _buildStatusOptionButton(
                      'REJECTED',
                      'Reject',
                      AppTheme.errorRed,
                      incident,
                    ),
                  ],

                  SizedBox(height: 16),
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

  Widget _buildStatusOptionButton(
      String status,
      String label,
      Color color,
      Map<String, dynamic> incident,
      ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          _updateIncidentStatus(incident['uid'], status);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _updateIncidentStatus(String incidentUid, String newStatus) async {
    try {
      final gql = GraphQLService();
      final response = await gql.sendAuthenticatedQuery(
        updateIncidentMutation,
        {
          'incidentDto': {
            'uid': incidentUid,
            'status': newStatus,
          },
        },
      );

      if (response.containsKey('errors')) {
        _showSnackBar('Failed to update status', isError: true);
        return;
      }

      final result = response['data']?['updateIncident'];
      if (result['status'] == 'Success') {
        _showSnackBar('Status updated successfully');
        _applyFilters(); // Refresh all lists
      } else {
        _showSnackBar(result['message'] ?? 'Failed to update', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', isError: true);
    }
  }

  void _openChat(Map<String, dynamic> incident) {
    if (_currentUserUid == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IncidentChatScreen(
          incidentUid: incident['uid'],
          incidentTitle: incident['title'] ?? 'Incident',
          currentUserUid: _currentUserUid!,
        ),
      ),
    );
  }

  void _openIncidentDetails(Map<String, dynamic> incident) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IncidentDetailsScreen(
          incidentUid: incident['uid'],
        ),
      ),
    ).then((_) {
      _applyFilters(); // Refresh after returning
    });
  }

  Widget _buildEmpty(String type) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Color(0xFF2E5BFF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_outlined,
                size: 50,
                color: Color(0xFF2E5BFF),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'No $type Incidents',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1F36),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Incidents will appear here',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Color(0xFF8F9BB3),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return {'label': 'PENDING', 'color': Color(0xFFFFB75E)};
      case 'IN_PROGRESS':
        return {'label': 'ACTIVE', 'color': Color(0xFF2E5BFF)};
      case 'RESOLVED':
        return {'label': 'RESOLVED', 'color': AppTheme.successGreen};
      case 'REJECTED':
        return {'label': 'REJECTED', 'color': AppTheme.errorRed};
      default:
        return {'label': status, 'color': Color(0xFF8F9BB3)};
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'THEFT': return Icons.shopping_bag_outlined;
      case 'ASSAULT': return Icons.warning_rounded;
      case 'ROBBERY': return Icons.dangerous_rounded;
      case 'ACCIDENT': return Icons.car_crash_rounded;
      case 'FIRE': return Icons.local_fire_department_rounded;
      case 'DOMESTIC_VIOLENCE': return Icons.home_outlined;
      case 'FRAUD': return Icons.account_balance_outlined;
      case 'MISSING_PERSON': return Icons.person_search_rounded;
      default: return Icons.report_outlined;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'THEFT': return Color(0xFF4ECDC4);
      case 'ASSAULT': return Color(0xFFFF6B6B);
      case 'ROBBERY': return Color(0xFFFF5252);
      case 'ACCIDENT': return Color(0xFFFFB75E);
      case 'FIRE': return Color(0xFFFF5252);
      case 'DOMESTIC_VIOLENCE': return Color(0xFFE91E63);
      case 'FRAUD': return Color(0xFF9C27B0);
      case 'MISSING_PERSON': return Color(0xFF3F51B5);
      default: return Color(0xFF2E5BFF);
    }
  }

  String _formatType(String type) {
    return type
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateString;
    }
  }

  String _getStatusText(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING': return 'Pending';
      case 'IN_PROGRESS': return 'In Progress';
      case 'RESOLVED': return 'Resolved';
      case 'REJECTED': return 'Rejected';
      default: return status;
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

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
}