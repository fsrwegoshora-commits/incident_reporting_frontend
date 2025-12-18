import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/graphql_service.dart';
import '../../utils/graphql_query.dart';
import '../../enum/enum.dart';

class CheckpointShiftsScreen extends StatefulWidget {
  final String checkpointUid;
  final String checkpointName;
  final String stationName;

  const CheckpointShiftsScreen({
    required this.checkpointUid,
    required this.checkpointName,
    required this.stationName,
    super.key,
  });

  @override
  State<CheckpointShiftsScreen> createState() => _CheckpointShiftsScreenState();
}

class _CheckpointShiftsScreenState extends State<CheckpointShiftsScreen>
    with TickerProviderStateMixin {
  final gql = GraphQLService();
  late Future<Map<String, dynamic>> shiftsResponse;
  late AnimationController _animationController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _fabAnimation;

  int _currentPage = 0;
  final int _pageSize = 15;
  bool _hasMore = true;
  bool _isLoading = false;
  String _searchQuery = '';
  String _filterDutyType = '';
  final TextEditingController _searchController = TextEditingController();

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

    shiftsResponse = _fetchShifts();
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

  String _calculateShiftStatus(Map<String, dynamic> shift) {
    final now = DateTime.now();
    final shiftDateStr = shift['shiftDate'] ?? DateTime.now().toIso8601String().split('T')[0];
    final shiftDate = DateTime.parse(shiftDateStr);
    final startTimeStr = shift['startTime'] ?? '06:00';
    final endTimeStr = shift['endTime'] ?? '14:00';
    final isExcused = shift['isExcused'] ?? false;
    final shiftDutyType = shift['shiftDutyType'] ?? ShiftDutyTypeEnum.STATION_DUTY;

    final startTime = DateFormat.Hm().parse(startTimeStr);
    final endTime = DateFormat.Hm().parse(endTimeStr);

    final shiftStart = DateTime(
      shiftDate.year,
      shiftDate.month,
      shiftDate.day,
      startTime.hour,
      startTime.minute,
    );
    final shiftEnd = DateTime(
      shiftDate.year,
      shiftDate.month,
      shiftDate.day,
      endTime.hour,
      endTime.minute,
    ).add(Duration(days: endTime.hour < startTime.hour ? 1 : 0));

    if (shiftDutyType == ShiftDutyTypeEnum.OFF) {
      return 'OFF';
    }

    if (isExcused) {
      return 'EXCUSED';
    }

    if (now.isAfter(shiftEnd)) {
      return 'COMPLETED';
    } else if (now.isAfter(shiftStart) && now.isBefore(shiftEnd)) {
      final remainingMinutes = shiftEnd.difference(now).inMinutes;
      final hours = remainingMinutes ~/ 60;
      final minutes = remainingMinutes % 60;
      return hours > 0
          ? 'ONGOING ($hours:${minutes.toString().padLeft(2, '0')})'
          : 'ONGOING (${minutes}m)';
    } else {
      return 'SCHEDULED';
    }
  }

  Color _getStatusColor(String status) {
    if (status.contains('OFF')) {
      return Color(0xFF9E9E9E);
    } else if (status.contains('COMPLETED')) {
      return Color(0xFF10B981);
    } else if (status.contains('ONGOING')) {
      return Color(0xFF2E5BFF);
    } else if (status.contains('EXCUSED')) {
      return Color(0xFFFFA726);
    } else {
      return Color(0xFFFFB75E);
    }
  }

  Future<Map<String, dynamic>> _fetchShifts() async {
    setState(() => _isLoading = true);

    try {
      final response = await gql.sendAuthenticatedQuery(
        getPoliceOfficerShiftsByCheckpointQuery,
        {
          "pageableParam": {
            "page": _currentPage,
            "size": _pageSize,
            "sortBy": "shiftDate",
            "sortDirection": "DESC",
          },
          "checkpointUid": widget.checkpointUid,
        },
      );

      if (response['errors'] != null) {
        throw Exception(response['errors'][0]['message']);
      }

      final data = response['data']?['getPoliceOfficerShiftsByCheckpoint'] ?? {};
      final shifts = data['data'] ?? [];
      final totalPages = data['pages'] ?? 0;

      setState(() => _hasMore = _currentPage < totalPages - 1);

      return {
        'shifts': List<Map<String, dynamic>>.from(shifts),
        'totalElements': data['elements'] ?? 0,
        'totalPages': totalPages,
        'currentPage': _currentPage,
      };
    } catch (e) {
      print("Error fetching shifts: $e");
      _showModernSnackBar('Error fetching shifts: $e', isSuccess: false);
      return {
        'shifts': [],
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
      shiftsResponse = _fetchShifts();
    }
  }

  void _refreshList() {
    setState(() {
      _currentPage = 0;
      _hasMore = true;
      _searchQuery = '';
      _filterDutyType = '';
      _searchController.clear();
    });
    shiftsResponse = _fetchShifts();
    _animationController.reset();
    _animationController.forward();
  }

  void _showModernSnackBar(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          decoration: BoxDecoration(
            gradient: isSuccess
                ? LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
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
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.zero,
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
            color: Color(0xFFFF9800).withOpacity(0.1),
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
          });
        },
        style: TextStyle(
          fontSize: 14,
          color: Color(0xFF1A1F36),
        ),
        decoration: InputDecoration(
          hintText: 'Search officer name, badge...',
          hintStyle: TextStyle(
            fontSize: 14,
            color: Color(0xFF8F9BB3),
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF9800), Color(0xFFFF6B35)],
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

  Widget _buildDutyTypeFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', '', null),
            ...ShiftDutyTypeEnum.values.map((dutyType) {
              return _buildFilterChip(
                ShiftDutyTypeEnum.getLabel(dutyType),
                dutyType,
                ShiftDutyTypeEnum.getColor(dutyType),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, Color? color) {
    final isSelected = _filterDutyType == value;

    return GestureDetector(
      onTap: () => setState(() => _filterDutyType = value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? (color ?? Color(0xFFFF9800)) : Colors.white,
          border: Border.all(
            color: color ?? Color(0xFFFF9800),
            width: isSelected ? 0 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: (color ?? Color(0xFFFF9800)).withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 2),
            )
          ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : (color ?? Color(0xFFFF9800)),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterShifts(List<Map<String, dynamic>> shifts) {
    if (_searchQuery.isEmpty && _filterDutyType.isEmpty) return shifts;

    return shifts.where((shift) {
      // Apply duty type filter
      if (_filterDutyType.isNotEmpty) {
        final shiftDutyType = shift['shiftDutyType']?.toString() ?? '';
        if (shiftDutyType != _filterDutyType) {
          return false;
        }
      }

      // Apply search query
      if (_searchQuery.isNotEmpty) {
        final officerName = shift['officer']?['userAccount']?['name']?.toString().toLowerCase() ?? '';
        final badgeNumber = shift['officer']?['badgeNumber']?.toString().toLowerCase() ?? '';
        final shiftDate = shift['shiftDate']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();

        return officerName.contains(query) ||
            badgeNumber.contains(query) ||
            shiftDate.contains(query);
      }

      return true;
    }).toList();
  }

  Widget _buildShiftCard(Map<String, dynamic> shift, int index) {
    final officerName = shift['officer']?['userAccount']?['name']?.toString() ?? 'Unknown Officer';
    final badgeNumber = shift['officer']?['badgeNumber']?.toString() ?? 'N/A';
    final phoneNumber = shift['officer']?['userAccount']?['phoneNumber']?.toString() ?? '-';
    final shiftDate = shift['shiftDate']?.toString() ?? 'N/A';
    final startTime = shift['startTime']?.toString() ?? '06:00';
    final endTime = shift['endTime']?.toString() ?? '14:00';
    final shiftTime = shift['shiftTime'] ?? ShiftTimeEnum.MORNING;
    final dutyDescription = shift['dutyDescription']?.toString() ?? 'No description';
    final isPunishmentMode = shift['isPunishmentMode'] ?? false;
    final isExcused = shift['isExcused'] ?? false;
    final shiftStatus = _calculateShiftStatus(shift);
    final statusColor = _getStatusColor(shiftStatus);

    Color getCardColor() {
      if (isPunishmentMode) {
        return Color(0xFFFFCDD2).withOpacity(0.08);
      } else if (isExcused) {
        return Color(0xFFFFECB3).withOpacity(0.08);
      } else {
        return statusColor.withOpacity(0.08);
      }
    }

    LinearGradient getIconGradient() {
      if (isPunishmentMode) {
        return LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF5252)]);
      } else if (isExcused) {
        return LinearGradient(colors: [Color(0xFFFFA726), Color(0xFFFF9800)]);
      } else {
        return LinearGradient(colors: [statusColor.withOpacity(0.8), statusColor]);
      }
    }

    IconData getStatusIcon() {
      if (isPunishmentMode) return Icons.warning_rounded;
      if (isExcused) return Icons.event_busy_rounded;
      if (shiftStatus.contains('COMPLETED')) return Icons.check_circle_rounded;
      if (shiftStatus.contains('ONGOING')) return Icons.play_circle_rounded;
      return Icons.schedule_rounded;
    }

    return FadeTransition(
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
            color: getCardColor(),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: statusColor.withOpacity(0.2),
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
              onTap: () => _showShiftDetails(shift),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Header: Officer Info
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: getIconGradient(),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            getStatusIcon(),
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                officerName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1F36),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: statusColor.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      badgeNumber,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isPunishmentMode)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Color(0xFFFF6B6B).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'PUNISHMENT',
                                        style: TextStyle(
                                          color: Color(0xFFFF6B6B),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  if (isExcused)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Color(0xFFFFA726).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'EXCUSED',
                                        style: TextStyle(
                                          color: Color(0xFFFFA726),
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

                    // Shift Details Grid
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.2,
                      ),
                      children: [
                        _buildGridInfo(
                          Icons.calendar_today_rounded,
                          'Date',
                          shiftDate,
                        ),
                        _buildGridInfo(
                          Icons.access_time_rounded,
                          'Time',
                          '$startTime - $endTime',
                        ),
                        _buildGridInfo(
                          Icons.phone_rounded,
                          'Phone',
                          phoneNumber,
                        ),
                        _buildGridInfo(
                          Icons.info_rounded,
                          'Status',
                          shiftStatus,
                          color: statusColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Description
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Duty Details',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8F9BB3),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dutyDescription,
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1A1F36),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
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
  }

  Widget _buildGridInfo(
      IconData icon,
      String label,
      String value, {
        Color? color,
      }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: color ?? Color(0xFFFF9800),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF8F9BB3),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color ?? Color(0xFF1A1F36),
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showShiftDetails(Map<String, dynamic> shift) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Color(0xFFF8F9FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
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
                      child: const Icon(
                        Icons.schedule_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shift Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1F36),
                            ),
                          ),
                          Text(
                            shift['officer']?['userAccount']?['name'] ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFFFF9800),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Details
                ..._buildDetailItems(shift),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFF9800),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDetailItems(Map<String, dynamic> shift) {
    final items = [
      ('Officer Badge', shift['officer']?['badgeNumber']?.toString() ?? 'N/A', Icons.badge_rounded),
      ('Officer Phone', shift['officer']?['userAccount']?['phoneNumber']?.toString() ?? '-', Icons.phone_rounded),
      ('Shift Date', shift['shiftDate']?.toString() ?? 'N/A', Icons.calendar_today_rounded),
      ('Start Time', shift['startTime']?.toString() ?? 'N/A', Icons.schedule_rounded),
      ('End Time', shift['endTime']?.toString() ?? 'N/A', Icons.schedule_rounded),
      ('Shift Time', ShiftTimeEnum.getLabel(shift['shiftTime'] ?? ShiftTimeEnum.MORNING), Icons.access_time_rounded),
      ('Duty Type', ShiftDutyTypeEnum.getLabel(shift['shiftDutyType'] ?? ''), Icons.work_rounded),
      ('Status', _calculateShiftStatus(shift), Icons.info_rounded),
      ('Duty Description', shift['dutyDescription']?.toString() ?? 'No description', Icons.description_rounded),
    ];

    return items.map((item) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(0xFFFF9800).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.$3,
                    size: 18,
                    color: Color(0xFFFF9800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$1,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8F9BB3),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$2,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1A1F36),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
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
                    colors: [Color(0xFFFF9800), Color(0xFFFF6B35)],
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
                'Loading shifts...',
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
    final allShifts = data['shifts'] as List<Map<String, dynamic>>;
    final filteredShifts = _filterShifts(allShifts);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF9800), Color(0xFFFF6B35)],
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
              Icons.people_rounded,
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
                  'Officers on Duty',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${filteredShifts.length}',
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
            expandedHeight: 140,
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
                      'Checkpoint Shifts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      widget.checkpointName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      widget.stationName,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.7),
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
                const SizedBox(height: 12),
                _buildDutyTypeFilter(),
                const SizedBox(height: 12),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: FutureBuilder<Map<String, dynamic>>(
              future: shiftsResponse,
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
                            'Loading shifts...',
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
                          'Failed to load shifts',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1F36),
                          ),
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
                  final allShifts = data['shifts'] as List<Map<String, dynamic>>;
                  final filteredShifts = _filterShifts(allShifts);

                  if (allShifts.isEmpty) {
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
                              Icons.schedule_outlined,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No shifts assigned',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1F36),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No officers are currently assigned to this checkpoint',
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
                      if (filteredShifts.isEmpty && (_searchQuery.isNotEmpty || _filterDutyType.isNotEmpty))
                        Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Color(0xFFF8F9FC),
                            borderRadius: BorderRadius.circular(20),
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
                                'No shifts match your search',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1F36),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...filteredShifts.asMap().entries.map((entry) {
                          return _buildShiftCard(entry.value, entry.key);
                        }).toList(),
                      if (_hasMore && _searchQuery.isEmpty && _filterDutyType.isEmpty)
                        _buildLoadMoreButton(),
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
    );
  }
}

class _ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;

  const _ModernButton({
    required this.text,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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