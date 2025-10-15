import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/graphql_service.dart';
import '../utils/graphql_query.dart';
import '../theme/app_theme.dart';
import 'incident_chat_screen.dart';

class MyIncidentsScreen extends StatefulWidget {
  @override
  _MyIncidentsScreenState createState() => _MyIncidentsScreenState();
}

class _MyIncidentsScreenState extends State<MyIncidentsScreen> {
  List<Map<String, dynamic>> _incidents = [];
  bool _isLoading = true;
  String? _currentUserUid;

  @override
  void initState() {
    super.initState();
    _loadUserIncidents();
  }

  Future<void> _loadUserIncidents() async {
    setState(() => _isLoading = true);

    try {
      final gql = GraphQLService();

      // Get current user UID first
      final meResponse = await gql.sendAuthenticatedQuery(meQuery, {});
      _currentUserUid = meResponse['data']?['me']?['data']?['uid'];

      // Load incidents
      final response = await gql.sendAuthenticatedQuery(
        getMyIncidentsQuery,
        {
          'pageableParam': {
            'page': 0,
            'size': 20,
            'isActive': true,
          },
        },
      );

      if (response.containsKey('errors')) {
        _showSnackBar('Failed to load incidents', isError: true);
        return;
      }

      final result = response['data']?['getMyIncidents'];
      if (result['status'] == 'Success') {
        // Fixed: 'data' is the list directly, not under 'content'
        var rawContent = result['data'];
        if (rawContent is List) {
          setState(() {
            _incidents = rawContent.cast<Map<String, dynamic>>();
          });
        } else {
          _incidents = []; // Fallback
        }

        // Optional: Log pagination for debug
        print('Total elements: ${result['elements']}');
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', isError: true);
      print('Exception details: $e'); // For debug
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF1A1F36)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Reports',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1F36),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: Color(0xFF2E5BFF)),
            onPressed: _loadUserIncidents,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoading()
          : _incidents.isEmpty
          ? _buildEmpty()
          : _buildIncidentsList(),
    );
  }

  Widget _buildIncidentsList() {
    return RefreshIndicator(
      onRefresh: _loadUserIncidents,
      child: ListView.builder(
        padding: EdgeInsets.all(20),
        itemCount: _incidents.length,
        itemBuilder: (context, index) {
          return _buildIncidentCard(_incidents[index]);
        },
      ),
    );
  }

  Widget _buildIncidentCard(Map<String, dynamic> incident) {
    final title = incident['title'] ?? 'Incident';
    final type = incident['type'] ?? 'OTHER';
    final location = incident['location'] ?? 'Unknown location';
    final status = incident['status'] ?? 'PENDING';
    final reportedAt = incident['reportedAt'] ?? '';
    final stationName = incident['assignedStation']?['name'] ?? 'N/A';

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
          onTap: () => _openIncidentChat(incident),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
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
                          Text(
                            _formatType(type),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Color(0xFF8F9BB3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusInfo['color'].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusInfo['color'].withOpacity(0.3)),
                      ),
                      child: Text(
                        statusInfo['label'],
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusInfo['color'],
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // Location
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

                SizedBox(height: 8),

                // Station & Date
                Row(
                  children: [
                    Icon(Icons.local_police_outlined, size: 14, color: Color(0xFF8F9BB3)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        stationName,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Color(0xFF8F9BB3),
                        ),
                        maxLines: 1,
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

                SizedBox(height: 12),

                // Chat Button
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF2E5BFF).withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_rounded, size: 16, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Open Chat & Send Media',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Spacer(),
                      Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openIncidentChat(Map<String, dynamic> incident) {
    if (_currentUserUid == null) {
      _showSnackBar('User not found', isError: true);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IncidentChatScreen(
          incidentUid: incident['uid'],
          incidentTitle: incident['title'] ?? 'Incident',
          currentUserUid: _currentUserUid!,
        ),
      ),
    ).then((_) {
      // Refresh after returning from chat
      _loadUserIncidents();
    });
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
    return type.replaceAll('_', ' ').toLowerCase().split(' ').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
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

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(Color(0xFF2E5BFF)),
          ),
          SizedBox(height: 16),
          Text(
            'Loading reports...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Color(0xFF8F9BB3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Color(0xFF2E5BFF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.description_outlined,
              size: 50,
              color: Color(0xFF2E5BFF),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'No Reports Yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1F36),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your incident reports will appear here',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Color(0xFF8F9BB3),
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.add_circle_outline, size: 20),
            label: Text('Report Incident'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2E5BFF),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
}