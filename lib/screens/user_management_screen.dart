import 'package:flutter/material.dart';
import 'package:incident_reporting_frontend/screens/register_special_user_tab.dart';
import '../services/graphql_service.dart';
import '../utils/graphql_query.dart';
import '../theme/app_theme.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> with TickerProviderStateMixin {
  final gql = GraphQLService();
  late Future<Map<String, dynamic>> usersResponse;
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

    _animationController = AnimationController(
      duration: AppTheme.normalAnimation,
      vsync: this,
    );

    _fabAnimationController = AnimationController(
      duration: AppTheme.fastAnimation,
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

    usersResponse = _fetchUsers();
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

  Future<Map<String, dynamic>> _fetchUsers() async {
    setState(() => _isLoading = true);

    try {
      final response = await gql.sendAuthenticatedQuery(getUsersQuery, {
        "pageableParam": {
          "page": _currentPage,
          "size": _pageSize,
          "sortBy": "createdAt",
          "sortDirection": "DESC",
          "searchParam": _searchQuery.isEmpty ? null : _searchQuery,
          "isActive": true,
        }
      });

      print("📡 GetUsers response: $response");

      final data = response['data']?['getUsers'] ?? {};
      final users = data['data'] ?? [];
      final totalPages = data['pages'] ?? 0;

      setState(() => _hasMore = _currentPage < totalPages - 1);

      return {
        'users': List<Map<String, dynamic>>.from(users),
        'totalElements': data['elements'] ?? 0,
        'totalPages': totalPages,
        'currentPage': _currentPage,
      };
    } catch (e) {
      print("Error fetching users: $e");
      rethrow;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loadNextPage() {
    if (_hasMore && !_isLoading) {
      setState(() => _currentPage++);
      usersResponse = _fetchUsers();
    }
  }

  void _refreshList() {
    setState(() {
      _currentPage = 0;
      _hasMore = true;
    });
    usersResponse = _fetchUsers();
    _animationController.reset();
    _animationController.forward();
  }

  void _deleteUser(String uid) async {
    final confirm = await _showModernDialog();

    if (confirm == true) {
      try {
        final response = await gql.sendAuthenticatedMutation(deleteUserMutation, {"uid": uid});
        final result = response['data']?['deleteUser'];
        final message = result?['message'] ?? "Delete failed";

        _showModernSnackBar(
          message.contains("success") ? "Successfully deleted" : message,
          isSuccess: message.contains("success"),
        );

        _refreshList();
      } catch (e) {
        _showModernSnackBar("Error: $e", isSuccess: false);
      }
    }
  }

  Future<bool?> _showModernDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => TweenAnimationBuilder<double>(
        duration: AppTheme.normalAnimation,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) => Transform.scale(
          scale: value,
          child: AlertDialog(
            backgroundColor: AppTheme.cardWhite,
            shape: RoundedRectangleBorder(borderRadius: AppTheme.largeRadius),
            elevation: 0,
            content: Container(
              decoration: AppTheme.elevatedCardDecoration,
              padding: const EdgeInsets.all(AppTheme.spaceL),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: AppTheme.errorGradient,
                      borderRadius: AppTheme.pillRadius,
                    ),
                    child: const Icon(
                      Icons.warning_rounded,
                      color: AppTheme.cardWhite,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceL),
                  Text(
                    'Confirm Deletion',
                    style: AppTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spaceM),
                  Text(
                    'Are you sure you want to delete this user? This action cannot be undone.',
                    style: AppTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spaceXL),
                  Row(
                    children: [
                      Expanded(
                        child: _ModernButton(
                          text: 'Cancel',
                          onPressed: () => Navigator.of(context).pop(false),
                          isOutlined: true,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceM),
                      Expanded(
                        child: _ModernButton(
                          text: 'Delete',
                          onPressed: () => Navigator.of(context).pop(true),
                          gradient: AppTheme.errorGradient,
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
            gradient: isSuccess ? AppTheme.successGradient : AppTheme.errorGradient,
            borderRadius: AppTheme.cardRadius,
          ),
          padding: const EdgeInsets.all(AppTheme.spaceM),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.cardWhite.withOpacity(0.2),
                  borderRadius: AppTheme.smallRadius,
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  color: AppTheme.cardWhite,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spaceM),
              Expanded(
                child: Text(
                  message,
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.cardWhite),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppTheme.spaceM),
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: AppTheme.cardRadius),
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _showRegisterForm({Map<String, dynamic>? existingUser}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: AppTheme.normalAnimation,
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionBuilder: (context, animation1, animation2, child) {
        return Transform.scale(
          scale: animation1.value,
          child: Opacity(
            opacity: animation1.value,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(AppTheme.spaceL),
              child: Container(
                decoration: AppTheme.elevatedCardDecoration.copyWith(
                  borderRadius: AppTheme.largeRadius,
                ),
                child: ClipRRect(
                  borderRadius: AppTheme.largeRadius,
                  child: SizedBox(
                    height: 600,
                    child: Column(
                      children: [
                        Container(
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: AppTheme.spaceM),
                              Icon(
                                existingUser != null ? Icons.edit : Icons.person_add,
                                color: AppTheme.cardWhite,
                              ),
                              const SizedBox(width: AppTheme.spaceM),
                              Expanded(
                                child: Text(
                                  existingUser != null ? 'Edit User' : 'Register Special User',
                                  style: AppTheme.titleMedium.copyWith(
                                    color: AppTheme.cardWhite,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: AppTheme.cardWhite),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(AppTheme.spaceL),
                            child: RegisterSpecialUserTab(
                              existingUser: existingUser,
                              onSubmit: () {
                                Navigator.pop(context);
                                _refreshList();
                              },
                            ),
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
      margin: const EdgeInsets.all(AppTheme.spaceM),
      decoration: AppTheme.primaryCardDecoration.copyWith(
        borderRadius: AppTheme.pillRadius,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() => _searchQuery = value);
          _refreshList(); // Refresh on search
        },
        style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search user...',
          hintStyle: AppTheme.bodyMedium.copyWith(
            color: AppTheme.textSecondary.withOpacity(0.7),
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: AppTheme.pillRadius,
            ),
            child: const Icon(Icons.search, color: AppTheme.cardWhite, size: 20),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
              _refreshList();
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceM,
            vertical: AppTheme.spaceM,
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterUsers(List<Map<String, dynamic>> users) {
    if (_searchQuery.isEmpty) return users;

    return users.where((user) {
      final name = user['name']?.toString().toLowerCase() ?? '';
      final phone = user['phoneNumber']?.toString().toLowerCase() ?? '';
      final role = user['role']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return name.contains(query) || phone.contains(query) || role.contains(query);
    }).toList();
  }

  String _normalizePhoneNumber(String phoneNumber) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('0')) {
      return '+255${cleaned.substring(1)}';
    } else if (cleaned.startsWith('+255')) {
      return cleaned;
    }
    return phoneNumber;
  }

  Widget _buildUserCard(Map<String, dynamic> user, int index) {
    final userName = user['name']?.toString() ?? 'Unknown User';
    final phoneNumber = _normalizePhoneNumber(user['phoneNumber']?.toString() ?? '-');
    final stationName = user['station']?['name']?.toString() ?? 'No Station';
    final userRole = user['role']?.toString() ?? 'N/A';
    final roleDisplayName = userRole.replaceAll('_', ' ');

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: 120.0,
        maxWidth: MediaQuery.of(context).size.width - 32,
      ),
      child: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: EdgeInsets.only(
                left: AppTheme.spaceM,
                right: AppTheme.spaceM,
                bottom: AppTheme.spaceM,
                top: index == 0 ? AppTheme.spaceS : 0,
              ),
              decoration: BoxDecoration(
                color: _getRoleColor(userRole).withOpacity(0.08),
                borderRadius: AppTheme.largeRadius,
                border: Border.all(
                  color: _getRoleColor(userRole).withOpacity(0.2),
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
                  borderRadius: AppTheme.largeRadius,
                  onTap: () => _showRegisterForm(existingUser: user),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spaceM),
                    child: Column(
                      children: [
                        // Header Row with Hero Icon and User Info
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Hero Icon Container
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _getRoleColor(userRole).withOpacity(0.8),
                                    _getRoleColor(userRole),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: _getRoleColor(userRole).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _getUserIcon(userRole),
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spaceM),

                            // User Info Column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // User Name Row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          userName,
                                          style: AppTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),

                                  // Role Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _getRoleColor(userRole).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _getRoleColor(userRole).withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      roleDisplayName,
                                      style: TextStyle(
                                        color: _getRoleColor(userRole),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppTheme.spaceM),

                        // User Details Grid
                        Column(
                          children: [
                            // First Row: Phone and Station
                            Row(
                              children: [
                                Expanded(
                                  child: _buildUserInfoRow(
                                    Icons.phone_rounded,
                                    'Phone',
                                    phoneNumber,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spaceM),
                                Expanded(
                                  child: _buildUserInfoRow(
                                    Icons.local_police_rounded,
                                    'Station',
                                    stationName,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: AppTheme.spaceM),

                        // Action Buttons Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildActionButton(
                              icon: Icons.edit_rounded,
                              label: 'Edit',
                              color: _getRoleColor(userRole),
                              onPressed: () => _showRegisterForm(existingUser: user),
                            ),
                            _buildActionButton(
                              icon: Icons.info_outline_rounded,
                              label: 'Details',
                              color: AppTheme.primaryBlue ?? Colors.blue,
                              onPressed: () => _showUserDetails(user),
                            ),
                            _buildActionButton(
                              icon: Icons.delete_outline_rounded,
                              label: 'Delete',
                              color: AppTheme.errorRed ?? Colors.red,
                              onPressed: () => _deleteUser(user['uid']),
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

// Helper method to build user info rows
  Widget _buildUserInfoRow(
      IconData icon,
      String label,
      String value, {
        int maxLines = 1,
        Color? textColor,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: AppTheme.textSecondary?.withOpacity(0.7) ?? Colors.grey[600],
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary?.withOpacity(0.7) ?? Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: textColor ?? (AppTheme.textPrimary ?? Colors.black87),
                  fontWeight: FontWeight.w500,
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

// Helper method to build action buttons
  Widget _buildActionButton({
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
        ),
      ],
    );
  }

// Helper method for user details dialog
  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('User Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${user['name'] ?? 'N/A'}'),
            Text('Phone: ${_normalizePhoneNumber(user['phoneNumber'] ?? '-')}'),
            Text('Role: ${user['role']?.replaceAll('_', ' ') ?? 'N/A'}'),
            Text('Station: ${user['station']?['name'] ?? 'No Station'}'),
            Text('User ID: ${user['uid']?.substring(0, 8) ?? 'N/A'}'),
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

// Keep existing helper methods for colors and icons
  LinearGradient _getUserGradient(String? role) {
    switch (role?.toUpperCase()) {
      case 'POLICE_OFFICER':
        return AppTheme.primaryGradient;
      case 'STATION_ADMIN':
        return AppTheme.warningGradient;
      case 'AGENCY_REP':
        return AppTheme.successGradient;
      default:
        return AppTheme.primaryGradient;
    }
  }

  IconData _getUserIcon(String? role) {
    switch (role?.toUpperCase()) {
      case 'POLICE_OFFICER':
        return Icons.local_police_rounded;
      case 'STATION_ADMIN':
        return Icons.admin_panel_settings_rounded;
      case 'AGENCY_REP':
        return Icons.person_rounded;
      default:
        return Icons.account_circle_rounded;
    }
  }

  Color _getRoleColor(String? role) {
    switch (role?.toUpperCase()) {
      case 'POLICE_OFFICER':
        return AppTheme.primaryBlue ?? Colors.blue;
      case 'STATION_ADMIN':
        return AppTheme.warningAmber ?? Colors.amber;
      case 'AGENCY_REP':
        return AppTheme.successGreen ?? Colors.green;
      default:
        return AppTheme.textSecondary ?? Colors.grey;
    }
  }

  Widget _buildLoadMoreButton() {
    return Container(
      margin: const EdgeInsets.all(AppTheme.spaceL),
      child: Center(
        child: _isLoading
            ? Container(
          padding: const EdgeInsets.all(AppTheme.spaceL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: AppTheme.pillRadius,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cardWhite),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceM),
              Text(
                'Loading...',
                style: AppTheme.bodySmall,
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
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceM),
      padding: const EdgeInsets.all(AppTheme.spaceL),
      decoration: AppTheme.primaryCardDecoration.copyWith(
        gradient: AppTheme.primaryGradient,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceM),
            decoration: BoxDecoration(
              color: AppTheme.cardWhite.withOpacity(0.2),
              borderRadius: AppTheme.cardRadius,
            ),
            child: const Icon(
              Icons.group,
              color: AppTheme.cardWhite,
              size: 32,
            ),
          ),
          const SizedBox(width: AppTheme.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Users',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.cardWhite.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data['totalElements'] ?? 0}',
                  style: AppTheme.headlineMedium.copyWith(
                    color: AppTheme.cardWhite,
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
      backgroundColor: AppTheme.surfaceWhite,
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
                gradient: AppTheme.primaryGradient,
              ),
              child: FlexibleSpaceBar(
                title: Text(
                  'User Management',
                  style: AppTheme.titleLarge.copyWith(
                    color: AppTheme.cardWhite,
                  ),
                ),
                centerTitle: false,
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: AppTheme.spaceM),
                decoration: BoxDecoration(
                  color: AppTheme.cardWhite.withOpacity(0.2),
                  borderRadius: AppTheme.smallRadius,
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: AppTheme.cardWhite),
                  onPressed: _refreshList,
                  tooltip: 'Refresh',
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: AppTheme.spaceM),
                _buildModernSearchBar(),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: FutureBuilder<Map<String, dynamic>>(
              future: usersResponse,
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
                              gradient: AppTheme.primaryGradient,
                              borderRadius: AppTheme.pillRadius,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cardWhite),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTheme.spaceL),
                          Text(
                            'Loading users...',
                            style: AppTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Container(
                    margin: const EdgeInsets.all(AppTheme.spaceL),
                    padding: const EdgeInsets.all(AppTheme.spaceXL),
                    decoration: AppTheme.elevatedCardDecoration,
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: AppTheme.errorGradient,
                            borderRadius: AppTheme.pillRadius,
                          ),
                          child: const Icon(
                            Icons.error_outline,
                            color: AppTheme.cardWhite,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceL),
                        Text(
                          'Failed to load users',
                          style: AppTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTheme.spaceM),
                        Text(
                          snapshot.error.toString(),
                          style: AppTheme.bodySmall.copyWith(color: AppTheme.errorRed),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTheme.spaceL),
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
                  final allUsers = data['users'] as List<Map<String, dynamic>>;
                  final filteredUsers = _filterUsers(allUsers);

                  if (allUsers.isEmpty) {
                    return Container(
                      margin: const EdgeInsets.all(AppTheme.spaceL),
                      padding: const EdgeInsets.all(AppTheme.spaceXL),
                      decoration: AppTheme.elevatedCardDecoration,
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: AppTheme.pillRadius,
                            ),
                            child: const Icon(
                              Icons.group_off,
                              color: AppTheme.cardWhite,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spaceL),
                          Text(
                            'No users found',
                            style: AppTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppTheme.spaceM),
                          Text(
                            'Click the (+) button to add the first user',
                            style: AppTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      _buildStatsCard(data),
                      const SizedBox(height: AppTheme.spaceM),
                      if (filteredUsers.isEmpty && _searchQuery.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.all(AppTheme.spaceL),
                          padding: const EdgeInsets.all(AppTheme.spaceXL),
                          decoration: AppTheme.elevatedCardDecoration,
                          child: Column(
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 60,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(height: AppTheme.spaceL),
                              Text(
                                'No results found',
                                style: AppTheme.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppTheme.spaceM),
                              Text(
                                'Try using a different search term',
                                style: AppTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else
                        ...filteredUsers.asMap().entries.map((entry) {
                          return _buildUserCard(entry.value, entry.key);
                        }).toList(),
                      if (_hasMore && _searchQuery.isEmpty) _buildLoadMoreButton(),
                      const SizedBox(height: 100), // FAB space
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
            gradient: AppTheme.acceptGradient,
            borderRadius: AppTheme.pillRadius,
            boxShadow: [AppTheme.elevatedShadow],
          ),
          child: FloatingActionButton.extended(
            onPressed: () => _showRegisterForm(),
            backgroundColor: Colors.transparent,
            elevation: 0,
            icon: const Icon(Icons.person_add, color: AppTheme.cardWhite),
            label: Text(
              'Register User',
              style: AppTheme.buttonTextMedium,
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
          borderRadius: AppTheme.buttonRadius,
          border: Border.all(color: AppTheme.borderColor, width: 2),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppTheme.buttonRadius,
            onTap: onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceL,
                vertical: AppTheme.spaceM,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: AppTheme.textPrimary, size: 20),
                    const SizedBox(width: AppTheme.spaceS),
                  ],
                  Text(
                    text,
                    style: AppTheme.buttonTextMedium.copyWith(
                      color: AppTheme.textPrimary,
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
        gradient: gradient ?? AppTheme.primaryGradient,
        borderRadius: AppTheme.buttonRadius,
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppTheme.buttonRadius,
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceL,
              vertical: AppTheme.spaceM,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: AppTheme.cardWhite, size: 20),
                  const SizedBox(width: AppTheme.spaceS),
                ],
                Text(text, style: AppTheme.buttonTextMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}