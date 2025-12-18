import 'package:flutter/material.dart';
import '../../services/graphql_service.dart';
import '../../utils/graphql_query.dart';
import '../../theme/app_theme.dart';
import 'register_traffic_checkpoint_tab.dart';

class TrafficCheckpointManagementScreen extends StatefulWidget {
  @override
  _TrafficCheckpointManagementScreenState createState() => _TrafficCheckpointManagementScreenState();
}

class _TrafficCheckpointManagementScreenState extends State<TrafficCheckpointManagementScreen>
    with TickerProviderStateMixin {
  final gql = GraphQLService();
  List<Map<String, dynamic>> _checkpoints = [];
  bool _isLoading = true;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Animation controllers
  late AnimationController _animationController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _fabAnimation;

  // Pagination
  int _currentPage = 0;
  final int _pageSize = 20;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();

    // Initialize animations
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

    _fetchCheckpoints();
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

  Future<void> _fetchCheckpoints() async {
    setState(() => _isLoading = true);
    try {
      final response = await gql.sendAuthenticatedQuery(getTrafficCheckpointsQuery, {
        "pageableParam": {
          "page": _currentPage,
          "size": _pageSize,
          "sortBy": "name",
          "sortDirection": "ASC",
          "isActive": true,
        }
      });

      if (response['errors'] != null) {
        throw Exception(response['errors'][0]['message']);
      }

      final data = response['data']?['getTrafficCheckpoints'] ?? {};
      final checkpoints = data['data'] ?? [];
      final totalPages = data['pages'] ?? 0;

      setState(() {
        if (_currentPage == 0) {
          _checkpoints = List<Map<String, dynamic>>.from(checkpoints);
        } else {
          _checkpoints.addAll(List<Map<String, dynamic>>.from(checkpoints));
        }
        _hasMore = _currentPage < totalPages - 1;
        _isLoading = false;
      });
    } catch (e) {
      _showErrorSnackBar("Error loading checkpoints: $e");
      setState(() => _isLoading = false);
    }
  }

  void _loadNextPage() {
    if (_hasMore && !_isLoading) {
      setState(() => _currentPage++);
      _fetchCheckpoints();
    }
  }

  void _refreshList() {
    setState(() {
      _currentPage = 0;
      _hasMore = true;
      _searchQuery = '';
      _searchController.clear();
    });
    _fetchCheckpoints();
    _animationController.reset();
    _animationController.forward();
  }

  Future<void> _deleteCheckpoint(String uid) async {
    final confirm = await _showModernDialog();

    if (confirm == true) {
      try {
        final response = await gql.sendAuthenticatedMutation(deleteTrafficCheckpointMutation, {"uid": uid});

        if (response['errors'] != null) {
          throw Exception(response['errors'][0]['message']);
        }

        final result = response['data']?['deleteTrafficCheckpoint'];
        final message = result?['message'] ?? "Delete failed";
        final isSuccess = result?['status'] == true || message.toLowerCase().contains('success');

        _showModernSnackBar(
          message,
          isSuccess: isSuccess,
        );

        if (isSuccess) {
          _refreshList();
        }
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
                    'Are you sure you want to delete this traffic checkpoint? This action cannot be undone.',
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
            gradient: isSuccess
                ? LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
                : LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
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

  void _showErrorSnackBar(String message) {
    _showModernSnackBar(message, isSuccess: false);
  }

  void _showSuccessSnackBar(String message) {
    _showModernSnackBar(message, isSuccess: true);
  }

  void _openRegisterCheckpoint({Map<String, dynamic>? existingCheckpoint}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.cardRadius),
        child: RegisterTrafficCheckpointTab(
          existingCheckpoint: existingCheckpoint,
          onSubmit: _refreshList,
        ),
      ),
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
        onChanged: (value) => setState(() => _searchQuery = value),
        style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search checkpoint...',
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

  List<Map<String, dynamic>> _filterCheckpoints(List<Map<String, dynamic>> checkpoints) {
    if (_searchQuery.isEmpty) return checkpoints;

    return checkpoints.where((checkpoint) {
      final name = checkpoint['name']?.toString().toLowerCase() ?? '';
      final contactPhone = checkpoint['contactPhone']?.toString().toLowerCase() ?? '';
      final address = checkpoint['location']?['address']?.toString().toLowerCase() ?? '';
      final station = checkpoint['parentStation']?['name']?.toString().toLowerCase() ?? '';
      final supervisor = checkpoint['supervisingOfficer']?['userAccount']?['name']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return name.contains(query) ||
          contactPhone.contains(query) ||
          address.contains(query) ||
          station.contains(query) ||
          supervisor.contains(query);
    }).toList();
  }

  Widget _buildCheckpointCard(Map<String, dynamic> checkpoint, int index) {
    return AnimatedBuilder(
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
            decoration: AppTheme.elevatedCardDecoration.copyWith(
              borderRadius: AppTheme.largeRadius,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: AppTheme.largeRadius,
                onTap: () => _openRegisterCheckpoint(existingCheckpoint: checkpoint),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceM),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: AppTheme.cardRadius,
                          boxShadow: [AppTheme.cardShadow],
                        ),
                        child: const Icon(
                          Icons.traffic,
                          color: AppTheme.cardWhite,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              checkpoint['name'] ?? 'Unknown',
                              style: AppTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    checkpoint['contactPhone'] ?? 'N/A',
                                    style: AppTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    checkpoint['location']?['address'] ?? 'N/A',
                                    style: AppTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    checkpoint['supervisingOfficer']?['userAccount']?['name'] ?? 'N/A',
                                    style: AppTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceM),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.errorRed.withOpacity(0.1),
                          borderRadius: AppTheme.smallRadius,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: AppTheme.errorRed,
                          onPressed: () => _deleteCheckpoint(checkpoint['uid']),
                          tooltip: 'Delete checkpoint',
                        ),
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

  Widget _buildStatsCard() {
    final filteredCheckpoints = _filterCheckpoints(_checkpoints);

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
              Icons.traffic,
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
                  'Total Checkpoints',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.cardWhite.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${filteredCheckpoints.length}',
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
    final filteredCheckpoints = _filterCheckpoints(_checkpoints);

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
                  'Traffic Checkpoint Management',
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
            child: _isLoading && _currentPage == 0
                ? Container(
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
                      'Loading checkpoints...',
                      style: AppTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            )
                : Column(
              children: [
                _buildStatsCard(),
                const SizedBox(height: AppTheme.spaceM),
                if (filteredCheckpoints.isEmpty && _searchQuery.isEmpty)
                  Container(
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
                            Icons.traffic_outlined,
                            color: AppTheme.cardWhite,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceL),
                        Text(
                          'No checkpoints found',
                          style: AppTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTheme.spaceM),
                        Text(
                          'Click the (+) button to add the first traffic checkpoint',
                          style: AppTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else if (filteredCheckpoints.isEmpty && _searchQuery.isNotEmpty)
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
                  ...filteredCheckpoints.asMap().entries.map((entry) {
                    return _buildCheckpointCard(entry.value, entry.key);
                  }).toList(),
                if (_hasMore && _searchQuery.isEmpty) _buildLoadMoreButton(),
                const SizedBox(height: 100), // FAB space
              ],
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
            onPressed: () => _openRegisterCheckpoint(),
            backgroundColor: Colors.transparent,
            elevation: 0,
            icon: const Icon(Icons.add_location, color: AppTheme.cardWhite),
            label: Text(
              'Add Checkpoint',
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