import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/graphql_service.dart';
import '../utils/graphql_query.dart';
import '../theme/app_theme.dart';
import 'incident_chat_screen.dart';

class IncidentDetailsScreen extends StatefulWidget {
  final String incidentUid;

  const IncidentDetailsScreen({
    Key? key,
    required this.incidentUid,
  }) : super(key: key);

  @override
  _IncidentDetailsScreenState createState() => _IncidentDetailsScreenState();
}

class _IncidentDetailsScreenState extends State<IncidentDetailsScreen> {
  Map<String, dynamic>? _incident;
  bool _isLoading = true;
  String? _currentUserUid;
  String? _userRole;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _loadIncidentDetails();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final gql = GraphQLService();
      final response = await gql.sendAuthenticatedQuery(meQuery, {});
      final user = response['data']?['me']?['data'];

      if (user != null && mounted) {
        setState(() {
          _currentUserUid = user['uid'];
          _userRole = user['role'];
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadIncidentDetails() async {
    setState(() => _isLoading = true);

    try {
      final gql = GraphQLService();
      final response = await gql.sendAuthenticatedQuery(
        getIncidentQuery,
        {'uid': widget.incidentUid},
      );

      if (response.containsKey('errors')) {
        _showSnackBar('Failed to load incident details', isError: true);
        return;
      }

      final result = response['data']?['getIncident'];
      if (result['status'] == 'Success' && mounted) {
        setState(() {
          _incident = result['data'];
        });
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Color(0xFF1A1F36)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Color(0xFF2E5BFF)),
          ),
        ),
      );
    }

    if (_incident == null) {
      return Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Color(0xFF1A1F36)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(
            'Incident not found',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Color(0xFF8F9BB3),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeaderCard(),
            _buildDetailsSection(),
            _buildReporterSection(),
            _buildOfficerSection(),
            _buildLocationSection(),
            _buildMediaSection(),
            SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _buildActionButtons(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Color(0xFF1A1F36)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Incident Details',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1F36),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: Color(0xFF2E5BFF)),
          onPressed: _loadIncidentDetails,
        ),
      ],
    );
  }

  Widget _buildHeaderCard() {
    final title = _incident!['title'] ?? 'Incident';
    final type = _incident!['type'] ?? 'OTHER';
    final status = _incident!['status'] ?? 'PENDING';
    final reportedAt = _incident!['reportedAt'] ?? '';

    final statusInfo = _getStatusInfo(status);

    return Container(
      margin: EdgeInsets.all(20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusInfo['color'], statusInfo['color'].withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusInfo['color'].withOpacity(0.3),
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
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getTypeIcon(type),
                  color: Colors.white,
                  size: 28,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatType(type),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time_rounded, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Reported ${_formatDate(reportedAt)}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
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

  Widget _buildDetailsSection() {
    final description = _incident!['description'] ?? 'No description';
    final status = _incident!['status'] ?? 'PENDING';
    final isLiveCall = _incident!['is '] ?? false;

    final statusInfo = _getStatusInfo(status);

    return Container(
      margin: EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Details',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1F36),
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusInfo['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusInfo['color'].withOpacity(0.3)),
                ),
                child: Text(
                  statusInfo['label'],
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusInfo['color'],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            description,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Color(0xFF1A1F36),
              height: 1.6,
            ),
          ),
          if (isLiveCall) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFFF5252).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Color(0xFFFF5252).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone_in_talk_rounded, size: 18, color: Color(0xFFFF5252)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Reporter requested live call assistance',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF5252),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReporterSection() {
    final reportedBy = _incident!['reportedBy'];
    if (reportedBy == null) return SizedBox.shrink();

    final name = reportedBy['name'] ?? 'Unknown';
    final phone = reportedBy['phoneNumber'] ?? '';

    return Container(
      margin: EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reported By',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1F36),
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF2E5BFF).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: Color(0xFF2E5BFF),
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1F36),
                      ),
                    ),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Color(0xFF8F9BB3),
                        ),
                      ),
                  ],
                ),
              ),
              if (phone.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.phone_rounded, color: AppTheme.successGreen),
                  onPressed: () => _makePhoneCall(phone),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfficerSection() {
    final assignedOfficer = _incident!['assignedOfficer'];
    final assignedStation = _incident!['assignedStation'];

    return Container(
      margin: EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assignment',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1F36),
            ),
          ),
          SizedBox(height: 16),

          if (assignedOfficer != null) ...[
            _buildInfoRow(
              icon: Icons.badge_rounded,
              label: 'Assigned Officer',
              value: assignedOfficer['userAccount']?['name'] ?? 'Unknown',
              valueColor: AppTheme.successGreen,
            ),
            SizedBox(height: 12),
            if (assignedOfficer['code'] != null)
              _buildInfoRow(
                icon: Icons.military_tech_rounded,
                label: 'Rank',
                value: assignedOfficer['code'],
              ),
          ] else
            _buildInfoRow(
              icon: Icons.badge_outlined,
              label: 'Officer',
              value: 'Not assigned yet',
              valueColor: Color(0xFFFFB75E),
            ),

          if (assignedStation != null) ...[
            SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.location_city_rounded,
              label: 'Station',
              value: assignedStation['name'] ?? 'Unknown',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    final location = _incident!['location'] ?? 'Unknown';
    final latitude = _incident!['latitude'];
    final longitude = _incident!['longitude'];

    return Container(
      margin: EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1F36),
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.location_on_rounded, color: Color(0xFFFF5252), size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  location,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Color(0xFF1A1F36),
                  ),
                ),
              ),
            ],
          ),
          if (latitude != null && longitude != null) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.gps_fixed_rounded, size: 16, color: Color(0xFF8F9BB3)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Color(0xFF8F9BB3),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.map_rounded, color: Color(0xFF2E5BFF)),
                    onPressed: () => _openMap(latitude, longitude),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMediaSection() {
    final imageUrl = _incident!['imageUrl'];
    final audioUrl = _incident!['audioUrl'];
    final videoUrl = _incident!['videoUrl'];

    if (imageUrl == null && audioUrl == null && videoUrl == null) {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Media Attachments',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1F36),
            ),
          ),
          SizedBox(height: 16),
          if (imageUrl != null)
            _buildMediaItem(Icons.image_rounded, 'Image', imageUrl, Color(0xFF4ECDC4)),
          if (audioUrl != null)
            _buildMediaItem(Icons.audiotrack_rounded, 'Audio', audioUrl, Color(0xFFFFB75E)),
          if (videoUrl != null)
            _buildMediaItem(Icons.videocam_rounded, 'Video', videoUrl, Color(0xFFFF6B6B)),
        ],
      ),
    );
  }

  Widget _buildMediaItem(IconData icon, String label, String url, Color color) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1F36),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.open_in_new_rounded, color: color),
            onPressed: () => _openUrl(url),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Color(0xFF8F9BB3)),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Color(0xFF8F9BB3),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Color(0xFF1A1F36),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (_userRole != 'POLICE_OFFICER' &&
        _userRole != 'STATION_ADMIN' &&
        _userRole != 'ROOT') {
      return SizedBox.shrink();
    }

    final status = _incident!['status'];

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _openChat(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4ECDC4),
                  padding: EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Chat',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (status != 'RESOLVED' && status != 'REJECTED') ...[
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _showStatusUpdateDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2E5BFF),
                    padding: EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Update',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showStatusUpdateDialog() {
    final currentStatus = _incident!['status'];

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
              SizedBox(height: 20),
              Text(
                'Update Status',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1F36),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Change incident status',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Color(0xFF8F9BB3),
                ),
              ),
              SizedBox(height: 24),

              if (currentStatus == 'PENDING')
                _buildStatusButton('IN_PROGRESS', 'Start Working', Color(0xFF2E5BFF)),

              if (currentStatus == 'IN_PROGRESS') ...[
                _buildStatusButton('RESOLVED', 'Mark Resolved', AppTheme.successGreen),
                SizedBox(height: 12),
                _buildStatusButton('REJECTED', 'Reject', AppTheme.errorRed),
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

  Widget _buildStatusButton(String status, String label, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          _updateStatus(status);
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

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdatingStatus = true);

    try {
      final gql = GraphQLService();
      final response = await gql.sendAuthenticatedQuery(
        updateIncidentMutation,
        {
          'incidentDto': {
            'uid': widget.incidentUid,
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
        await _loadIncidentDetails();
      } else {
        _showSnackBar(result['message'] ?? 'Failed to update', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  void _openChat() {
    if (_currentUserUid == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IncidentChatScreen(
          incidentUid: widget.incidentUid,
          incidentTitle: _incident!['title'] ?? 'Incident',
          currentUserUid: _currentUserUid!,
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('Cannot make phone call', isError: true);
    }
  }

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('Cannot open map', isError: true);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('Cannot open URL', isError: true);
    }
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return {'label': 'PENDING', 'color': Color(0xFFFFB75E)};
      case 'IN_PROGRESS':
        return {'label': 'IN PROGRESS', 'color': Color(0xFF2E5BFF)};
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

  String _formatType(String type) {
    return type
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join('');
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes} minutes ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours} hours ago';
      } else if (difference.inDays == 1) {
        return 'yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        final day = date.day.toString().padLeft(2, '0');
        final month = date.month.toString().padLeft(2, '0');
        final year = date.year;
        return '$day/$month/$year';
      }
    } catch (e) {
      return dateString;
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