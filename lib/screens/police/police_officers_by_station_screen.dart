import 'package:flutter/material.dart';
import '../../services/graphql_service.dart';
import '../../utils/graphql_query.dart';
import '../../theme/app_theme.dart';
import 'register_police_officer_tab.dart';

class PoliceOfficersByStationScreen extends StatefulWidget {
  final String stationUid;
  final String stationName;

  const PoliceOfficersByStationScreen({
    super.key,
    required this.stationUid,
    required this.stationName,
  });

  @override
  State<PoliceOfficersByStationScreen> createState() => _PoliceOfficersByStationScreenState();
}

class _PoliceOfficersByStationScreenState extends State<PoliceOfficersByStationScreen>
    with TickerProviderStateMixin {
  final gql = GraphQLService();
  late Future<Map<String, dynamic>> policeOfficersResponse;
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

  final List<Map<String, String>> _ranks = [
    {"value": "PC", "label": "Police Constable (PC)"},
    {"value": "CPL", "label": "Corporal (CPL)"},
    {"value": "SGT", "label": "Sergeant (SGT)"},
    {"value": "S_SGT", "label": "Senior Sergeant (S/SGT)"},
    {"value": "SM", "label": "Staff Sergeant (SM)"},
    {"value": "A_ISP", "label": "Assistant Inspector (A/ISP)"},
    {"value": "ISP", "label": "Inspector (ISP)"},
  ];

  @override
  void initState() {
    super.initState();

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

    policeOfficersResponse = _fetchPoliceOfficers();
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

  Future<Map<String, dynamic>> _fetchPoliceOfficers() async {
    setState(() => _isLoading = true);

    try {
      final response = await gql.sendAuthenticatedQuery(getPoliceOfficersByStationQuery, {
        "pageableParam": {
          "page": _currentPage,
          "size": _pageSize,
          "sortBy": "userAccount.name",
          "sortDirection": "ASC",
          "isActive": true,
        },
        "policeStationUid": widget.stationUid,
      });

      final data = response['data']?['getPoliceOfficersByStation'] ?? {};
      final policeOfficers = data['data'] ?? [];
      final totalPages = data['pages'] ?? 0;

      setState(() => _hasMore = _currentPage < totalPages - 1);

      return {
        'policeOfficers': List<Map<String, dynamic>>.from(policeOfficers),
        'totalElements': data['elements'] ?? 0,
        'totalPages': totalPages,
        'currentPage': _currentPage,
      };
    } catch (e) {
      print("Error fetching police officers: $e");
      rethrow;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loadNextPage() {
    if (_hasMore && !_isLoading) {
      setState(() => _currentPage++);
      policeOfficersResponse = _fetchPoliceOfficers();
    }
  }

  void _refreshList() {
    setState(() {
      _currentPage = 0;
      _hasMore = true;
      _searchQuery = '';
      _searchController.clear();
    });
    policeOfficersResponse = _fetchPoliceOfficers();
    _animationController.reset();
    _animationController.forward();
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

  void _showRegisterForm({Map<String, dynamic>? existingOfficer}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 800),
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionBuilder: (context, animation1, animation2, child) {
        return Transform.scale(
          scale: animation1.value,
          child: Opacity(
            opacity: animation1.value,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(20),
              child: Container(
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 600,
                    child: Column(
                      children: [
                        Container(
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
                            ),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 20),
                              Icon(
                                existingOfficer != null ? Icons.edit : Icons.person_add,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Text(
                                  existingOfficer != null ? 'Edit Police Officer' : 'Register Police Officer',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: RegisterPoliceOfficerTab(
                            existingOfficer: existingOfficer,
                            preSelectedStationUid: widget.stationUid,
                            onSubmit: () {
                              Navigator.pop(context);
                              _refreshList();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
        onChanged: (value) => setState(() => _searchQuery = value),
        style: TextStyle(
          fontSize: 14,
          color: Color(0xFF1A1F36),
        ),
        decoration: InputDecoration(
          hintText: 'Search police officer...',
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
              setState(() => _searchQuery = '');
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

  List<Map<String, dynamic>> _filterPoliceOfficers(List<Map<String, dynamic>> policeOfficers) {
    if (_searchQuery.isEmpty) return policeOfficers;

    return policeOfficers.where((officer) {
      final name = officer['userAccount']?['name']?.toString().toLowerCase() ?? '';
      final badgeNumber = officer['badgeNumber']?.toString().toLowerCase() ?? '';
      final code = officer['code']?.toString().toLowerCase() ?? '';
      final rankLabel = _ranks.firstWhere(
            (rank) => rank['value'] == officer['code'],
        orElse: () => {'label': ''},
      )['label']?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return name.contains(query) || badgeNumber.contains(query) || code.contains(query) || rankLabel.contains(query);
    }).toList();
  }

  String _normalizePhoneNumber(String? phoneNumber) {
    if (phoneNumber == null) return '-';
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('0')) {
      return '+255${cleaned.substring(1)}';
    } else if (cleaned.startsWith('+255')) {
      return cleaned;
    }
    return phoneNumber;
  }

  String _getRankLabel(String? code) {
    return _ranks.firstWhere(
          (rank) => rank['value'] == code,
      orElse: () => {'label': code ?? 'N/A'},
    )['label']!;
  }

  Widget _buildPoliceOfficerCard(Map<String, dynamic> officer, int index) {
    final officerName = officer['userAccount']?['name']?.toString() ?? 'Unknown Officer';
    final badgeNumber = officer['badgeNumber']?.toString() ?? 'N/A';
    final rankLabel = _getRankLabel(officer['code']);
    final phoneNumber = _normalizePhoneNumber(officer['userAccount']?['phoneNumber']);
    final stationName = officer['station']?['name']?.toString() ?? 'N/A';

    Color getRankColor() {
      final code = officer['code']?.toString().toLowerCase() ?? '';
      if (code.contains('inspector') || code.contains('superintendent') || code.contains('commander')) {
        return Colors.amber[700] ?? Colors.amber;
      } else if (code.contains('sergeant') || code.contains('corporal')) {
        return Colors.green[700] ?? Colors.green;
      } else if (code.contains('constable')) {
        return Color(0xFF2E5BFF);
      } else {
        return Color(0xFF2E5BFF);
      }
    }

    LinearGradient getHeroGradient() {
      final rankColor = getRankColor();
      return LinearGradient(
        colors: [
          rankColor.withOpacity(0.8),
          rankColor,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: 120.0,
        maxWidth: MediaQuery.of(context).size.width - 32,
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Transform.translate(
          offset: Offset(0, _slideAnimation.value * (index + 1)),
          child: Container(
            margin: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: 20,
              top: index == 0 ? 10 : 0,
            ),
            decoration: BoxDecoration(
              color: getRankColor().withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: getRankColor().withOpacity(0.2),
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
                onTap: () => _showRegisterForm(existingOfficer: officer),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: getHeroGradient(),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: getRankColor().withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        officerName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1A1F36),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: getRankColor().withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: getRankColor().withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        rankLabel,
                                        style: TextStyle(
                                          color: getRankColor(),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
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
                                child: _buildOfficerInfoRow(
                                  Icons.badge_rounded,
                                  'Badge',
                                  badgeNumber,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: _buildOfficerInfoRow(
                                  Icons.phone_rounded,
                                  'Phone',
                                  phoneNumber,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildOfficerInfoRow(
                            Icons.local_police_rounded,
                            'Station',
                            stationName,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildOfficerActionButton(
                            icon: Icons.edit_rounded,
                            label: 'Edit',
                            color: Color(0xFF2E5BFF),
                            onPressed: () => _showRegisterForm(existingOfficer: officer),
                          ),
                          _buildOfficerActionButton(
                            icon: Icons.schedule_rounded,
                            label: 'Shifts',
                            color: Color(0xFFFFB75E),
                            onPressed: () => _viewOfficerShifts(officer),
                          ),
                          _buildOfficerActionButton(
                            icon: Icons.info_outline_rounded,
                            label: 'Details',
                            color: Color(0xFF4ECDC4),
                            onPressed: () => _showOfficerDetails(officer),
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

  Widget _buildOfficerInfoRow(
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

  Widget _buildOfficerActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: IconButton(
            icon: Icon(icon, size: 22),
            color: color,
            onPressed: onPressed,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _viewOfficerShifts(Map<String, dynamic> officer) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing shifts for ${officer['userAccount']?['name'] ?? 'officer'}'),
        backgroundColor: Color(0xFF2E5BFF),
      ),
    );
  }

  void _showOfficerDetails(Map<String, dynamic> officer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Officer Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${officer['userAccount']?['name'] ?? 'N/A'}'),
            Text('Badge: ${officer['badgeNumber'] ?? 'N/A'}'),
            Text('Rank: ${_getRankLabel(officer['code'])}'),
            Text('Phone: ${_normalizePhoneNumber(officer['userAccount']?['phoneNumber'])}'),
            Text('Station: ${officer['station']?['name'] ?? 'N/A'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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
          colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
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
              Icons.people,
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
                  'Total Police Officers',
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
                  'Officers at ${widget.stationName}',
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
              future: policeOfficersResponse,
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
                            'Loading police officers...',
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
                          'Failed to load police officers',
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
                  final allOfficers = data['policeOfficers'] as List<Map<String, dynamic>>;
                  final filteredOfficers = _filterPoliceOfficers(allOfficers);

                  if (allOfficers.isEmpty) {
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
                              Icons.people_outline,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No police officers found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1F36),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Click the (+) button to add the first police officer',
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
                      if (filteredOfficers.isEmpty && _searchQuery.isNotEmpty)
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
                        ...filteredOfficers.asMap().entries.map((entry) {
                          return _buildPoliceOfficerCard(entry.value, entry.key);
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
            icon: const Icon(Icons.person_add, color: Colors.white),
            label: Text(
              'Register Police Officer',
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
        gradient: gradient ?? LinearGradient(
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
                Text(text, style: TextStyle(
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