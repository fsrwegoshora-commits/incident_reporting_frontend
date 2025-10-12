import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/graphql_service.dart';
import '../utils/graphql_query.dart';
import '../theme/app_theme.dart';
import './officer_shift_form.dart';

class OfficerShiftManagementScreen extends StatefulWidget {
        final String stationUid;
        final String stationName;

        const OfficerShiftManagementScreen({
                super.key,
                required this.stationUid,
                required this.stationName,
        });

        @override
        State<OfficerShiftManagementScreen> createState() => _OfficerShiftManagementScreenState();
}

class _OfficerShiftManagementScreenState extends State<OfficerShiftManagementScreen>
    with TickerProviderStateMixin {
        final gql = GraphQLService();
        late Future<Map<String, dynamic>> shiftsResponse;
        late AnimationController _animationController;
        late AnimationController _fabAnimationController;
        late Animation<double> _fadeAnimation;
        late Animation<double> _slideAnimation;
        late Animation<double> _fabAnimation;

        int _currentPage = 0;
        final int _pageSize = 10;
        bool _hasMore = true;
        bool _isLoading = false;
        String _searchQuery = '';
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
                final shiftType = shift['shiftType'] ?? 'N/A';

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

                final isToday = shiftDate.year == now.year &&
                    shiftDate.month == now.month &&
                    shiftDate.day == now.day;

                if (isExcused) {
                        return 'EXCUSED (${shift['excuseReason'] ?? 'No reason'})';
                }

                if (isToday && now.isBefore(shiftStart)) {
                        return 'Scheduled for $shiftType ($startTimeStr - $endTimeStr)';
                }

                if (now.isAfter(shiftEnd)) {
                        return 'OFF';
                } else if (now.isAfter(shiftStart) && now.isBefore(shiftEnd)) {
                        final remainingMinutes = shiftEnd.difference(now).inMinutes;
                        final hours = remainingMinutes ~/ 60;
                        final minutes = remainingMinutes % 60;
                        return hours > 0
                            ? 'ONGOING ($hours:${minutes.toString().padLeft(2, '0')} remaining)'
                            : 'ONGOING (${minutes} min remaining)';
                } else {
                        final hoursUntilStart = shiftStart.difference(now).inHours;
                        final minutesUntilStart = shiftStart.difference(now).inMinutes % 60;
                        return hoursUntilStart > 0
                            ? 'Starts in $hoursUntilStart hr ${minutesUntilStart} min'
                            : 'Starts in ${minutesUntilStart} min';
                }
        }

        Future<Map<String, dynamic>> _fetchShifts() async {
                setState(() => _isLoading = true);

                try {
                        final response = await gql.sendAuthenticatedQuery(getShiftsByStationQuery, {
                                "stationUid": widget.stationUid,
                                "page": _currentPage,
                                "size": _pageSize,
                        });

                        print('Full shifts response: ${json.encode(response)}');

                        if (response['errors'] != null) {
                                throw Exception(response['errors'][0]['message']);
                        }

                        final data = response['data']?['getShiftsByStation'] ?? {};

                        List<Map<String, dynamic>> shifts = [];
                        int totalElements = 0;
                        int totalPages = 0;

                        if (data['data'] != null) {
                                shifts = List<Map<String, dynamic>>.from(data['data'] ?? []);
                                totalElements = data['totalElements'] ?? data['elements'] ?? shifts.length;
                                totalPages = data['totalPages'] ?? data['pages'] ?? 1;
                        } else if (data is List) {
                                shifts = List<Map<String, dynamic>>.from(data);
                                totalElements = shifts.length;
                                totalPages = 1;
                        } else if (data['content'] != null) {
                                shifts = List<Map<String, dynamic>>.from(data['content'] ?? []);
                                totalElements = data['totalElements'] ?? shifts.length;
                                totalPages = data['totalPages'] ?? 1;
                        }

                        print('Parsed shifts: $shifts');
                        print('Total elements: $totalElements');
                        print('Total pages: $totalPages');

                        setState(() => _hasMore = _currentPage < totalPages - 1 && shifts.isNotEmpty);

                        return {
                                'shifts': shifts,
                                'totalElements': totalElements,
                                'totalPages': totalPages,
                                'currentPage': _currentPage,
                        };
                } catch (e) {
                        print("Error fetching shifts: $e");
                        rethrow;
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
                        _searchController.clear();
                });
                shiftsResponse = _fetchShifts();
                _animationController.reset();
                _animationController.forward();
        }

        Future<void> _deleteShift(String uid) async {
                final confirm = await _showModernDialog('Confirm Deletion', 'Are you sure you want to delete this shift? This action cannot be undone.');

                if (confirm == true) {
                        try {
                                final response = await gql.sendAuthenticatedMutation(deleteOfficerShiftMutation, {"uid": uid});

                                if (response['errors'] != null) {
                                        throw Exception(response['errors'][0]['message']);
                                }

                                final result = response['data']?['deleteOfficerShift'];
                                final message = result?['message'] ?? "Delete failed";

                                _showModernSnackBar(
                                        message,
                                        isSuccess: result?['status'] == 'Success',
                                );

                                _refreshList();
                        } catch (e) {
                                _showModernSnackBar("Error: $e", isSuccess: false);
                        }
                }
        }

        Future<void> _excuseShift(String shiftId, bool isExcused) async {
                String? excuseReason;
                print('Excuse shift called for shiftId: $shiftId, isExcused: $isExcused');

                await showDialog<void>(
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
                                                content: ConstrainedBox(
                                                        constraints: BoxConstraints(
                                                                maxHeight: MediaQuery.of(context).size.height * 0.6,
                                                                maxWidth: 300,
                                                        ),
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
                                                                padding: const EdgeInsets.all(20),
                                                                child: Column(
                                                                        mainAxisSize: MainAxisSize.min,
                                                                        children: [
                                                                                Container(
                                                                                        width: 60,
                                                                                        height: 60,
                                                                                        decoration: BoxDecoration(
                                                                                                gradient: LinearGradient(
                                                                                                        colors: [Color(0xFFFFA726), Color(0xFFFF8F00)],
                                                                                                ),
                                                                                                borderRadius: BorderRadius.circular(15),
                                                                                        ),
                                                                                        child: Icon(
                                                                                                isExcused ? Icons.undo : Icons.note_alt,
                                                                                                color: Colors.white,
                                                                                                size: 32,
                                                                                        ),
                                                                                ),
                                                                                const SizedBox(height: 20),
                                                                                Text(
                                                                                        isExcused ? 'Remove Excuse' : 'Excuse Shift',
                                                                                        style: TextStyle(
                                                                                                fontSize: 18,
                                                                                                fontWeight: FontWeight.w700,
                                                                                                color: Color(0xFF1A1F36),
                                                                                        ),
                                                                                        textAlign: TextAlign.center,
                                                                                ),
                                                                                const SizedBox(height: 12),
                                                                                Text(
                                                                                        isExcused
                                                                                            ? 'Remove the excuse for this shift?'
                                                                                            : 'Enter a reason for excusing this shift.',
                                                                                        style: TextStyle(
                                                                                                fontSize: 14,
                                                                                                color: Color(0xFF8F9BB3),
                                                                                        ),
                                                                                        textAlign: TextAlign.center,
                                                                                ),
                                                                                const SizedBox(height: 12),
                                                                                if (!isExcused)
                                                                                        ConstrainedBox(
                                                                                                constraints: const BoxConstraints(maxWidth: 300),
                                                                                                child: TextField(
                                                                                                        onChanged: (value) => excuseReason = value,
                                                                                                        decoration: InputDecoration(
                                                                                                                labelText: 'Excuse Reason',
                                                                                                                prefixIcon: Icon(Icons.note, color: Color(0xFF2E5BFF)),
                                                                                                                filled: true,
                                                                                                                fillColor: Color(0xFFF5F7FA),
                                                                                                                border: OutlineInputBorder(
                                                                                                                        borderRadius: BorderRadius.circular(12),
                                                                                                                        borderSide: BorderSide.none,
                                                                                                                ),
                                                                                                        ),
                                                                                                        maxLines: 2,
                                                                                                ),
                                                                                        ),
                                                                                const SizedBox(height: 20),
                                                                                Row(
                                                                                        mainAxisSize: MainAxisSize.min,
                                                                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                                                        children: [
                                                                                                Flexible(
                                                                                                        child: _ModernButton(
                                                                                                                text: 'Cancel',
                                                                                                                onPressed: () => Navigator.of(context).pop(),
                                                                                                                isOutlined: true,
                                                                                                                isDialogButton: true,
                                                                                                        ),
                                                                                                ),
                                                                                                const SizedBox(width: 12),
                                                                                                Flexible(
                                                                                                        child: _ModernButton(
                                                                                                                text: isExcused ? 'Remove' : 'Confirm',
                                                                                                                onPressed: () {
                                                                                                                        if (isExcused || excuseReason != null && excuseReason!.isNotEmpty) {
                                                                                                                                Navigator.of(context).pop();
                                                                                                                                print('Excuse action: shiftId=$shiftId, isExcused=$isExcused, reason=$excuseReason');
                                                                                                                        }
                                                                                                                },
                                                                                                                gradient: LinearGradient(
                                                                                                                        colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
                                                                                                                ),
                                                                                                                isDialogButton: true,
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
                        ),
                );
        }

        Future<void> _reassignShift(String uid, String shiftDate, String startTime, String endTime) async {
                final availableOfficers = await _fetchAvailableOfficers(shiftDate, startTime, endTime);

                if (availableOfficers.isEmpty) {
                        _showModernSnackBar("No available officers found for this time slot", isSuccess: false);
                        return;
                }

                final newOfficerUid = await _showReassignDialog(availableOfficers);

                if (newOfficerUid != null) {
                        try {
                                final response = await gql.sendAuthenticatedMutation(reassignShiftMutation, {
                                        "uid": uid,
                                        "newOfficerUid": newOfficerUid,
                                });

                                if (response['errors'] != null) {
                                        throw Exception(response['errors'][0]['message']);
                                }

                                final result = response['data']?['reassignShift'];
                                final message = result?['message'] ?? "Reassign failed";

                                _showModernSnackBar(
                                        message,
                                        isSuccess: result?['status'] == 'Success',
                                );

                                _refreshList();
                        } catch (e) {
                                _showModernSnackBar("Error: $e", isSuccess: false);
                        }
                }
        }

        Future<List<Map<String, dynamic>>> _fetchAvailableOfficers(String date, String startTime, String endTime) async {
                try {
                        final response = await gql.sendAuthenticatedQuery(
                                """
        query GetAvailableOfficersForSlot(\$date: String!, \$startTime: String!, \$endTime: String!) {
          getAvailableOfficersForSlot(date: \$date, startTime: \$startTime, endTime: \$endTime) {
            status
            message
            data {
              uid
              badgeNumber
              userAccount {
                name
                phoneNumber
              }
            }
          }
        }
        """,
                                {
                                        "date": date,
                                        "startTime": startTime,
                                        "endTime": endTime,
                                },
                        );

                        if (response['errors'] != null) {
                                throw Exception(response['errors'][0]['message']);
                        }

                        final data = response['data']?['getAvailableOfficersForSlot'] ?? {};
                        return List<Map<String, dynamic>>.from(data['data'] ?? []);
                } catch (e) {
                        print("Error fetching available officers: $e");
                        _showModernSnackBar("Failed to fetch available officers: $e", isSuccess: false);
                        return [];
                }
        }

        Future<String?> _showReasonDialog(String title, String message) async {
                final controller = TextEditingController();
                return showDialog<String>(
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
                                                                                                colors: [Color(0xFFFFA726), Color(0xFFFF8F00)],
                                                                                        ),
                                                                                        borderRadius: BorderRadius.circular(15),
                                                                                ),
                                                                                child: const Icon(
                                                                                        Icons.note_add_rounded,
                                                                                        color: Colors.white,
                                                                                        size: 32,
                                                                                ),
                                                                        ),
                                                                        const SizedBox(height: 20),
                                                                        Text(
                                                                                title,
                                                                                style: TextStyle(
                                                                                        fontSize: 18,
                                                                                        fontWeight: FontWeight.w700,
                                                                                        color: Color(0xFF1A1F36),
                                                                                ),
                                                                                textAlign: TextAlign.center,
                                                                        ),
                                                                        const SizedBox(height: 12),
                                                                        Text(
                                                                                message,
                                                                                style: TextStyle(
                                                                                        fontSize: 14,
                                                                                        color: Color(0xFF8F9BB3),
                                                                                ),
                                                                                textAlign: TextAlign.center,
                                                                        ),
                                                                        const SizedBox(height: 12),
                                                                        TextField(
                                                                                controller: controller,
                                                                                decoration: InputDecoration(
                                                                                        labelText: 'Reason',
                                                                                        hintText: 'Enter excuse reason',
                                                                                        prefixIcon: Icon(Icons.note, color: Color(0xFF2E5BFF)),
                                                                                        filled: true,
                                                                                        fillColor: Color(0xFFF5F7FA),
                                                                                        border: OutlineInputBorder(
                                                                                                borderRadius: BorderRadius.circular(12),
                                                                                                borderSide: BorderSide.none,
                                                                                        ),
                                                                                ),
                                                                                maxLines: 3,
                                                                        ),
                                                                        const SizedBox(height: 20),
                                                                        Row(
                                                                                children: [
                                                                                        Expanded(
                                                                                                child: _ModernButton(
                                                                                                        text: 'Cancel',
                                                                                                        onPressed: () => Navigator.of(context).pop(null),
                                                                                                        isOutlined: true,
                                                                                                ),
                                                                                        ),
                                                                                        const SizedBox(width: 12),
                                                                                        Expanded(
                                                                                                child: _ModernButton(
                                                                                                        text: 'Submit',
                                                                                                        onPressed: () => Navigator.of(context).pop(controller.text.trim()),
                                                                                                        gradient: LinearGradient(
                                                                                                                colors: [Color(0xFFFFA726), Color(0xFFFF8F00)],
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

        Future<String?> _showReassignDialog(List<Map<String, dynamic>> availableOfficers) async {
                String? selectedUid;
                print('Available officers: ${json.encode(availableOfficers)}');

                return showDialog<String>(
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
                                                content: ConstrainedBox(
                                                        constraints: BoxConstraints(
                                                                maxHeight: MediaQuery.of(context).size.height * 0.6,
                                                                maxWidth: 300,
                                                        ),
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
                                                                padding: const EdgeInsets.all(20),
                                                                child: Column(
                                                                        mainAxisSize: MainAxisSize.min,
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
                                                                                        child: const Icon(
                                                                                                Icons.swap_horiz_rounded,
                                                                                                color: Colors.white,
                                                                                                size: 32,
                                                                                        ),
                                                                                ),
                                                                                const SizedBox(height: 20),
                                                                                Text(
                                                                                        'Reassign Shift',
                                                                                        style: TextStyle(
                                                                                                fontSize: 18,
                                                                                                fontWeight: FontWeight.w700,
                                                                                                color: Color(0xFF1A1F36),
                                                                                        ),
                                                                                        textAlign: TextAlign.center,
                                                                                ),
                                                                                const SizedBox(height: 12),
                                                                                Text(
                                                                                        'Select a new officer to assign this shift to.',
                                                                                        style: TextStyle(
                                                                                                fontSize: 14,
                                                                                                color: Color(0xFF8F9BB3),
                                                                                        ),
                                                                                        textAlign: TextAlign.center,
                                                                                ),
                                                                                const SizedBox(height: 12),
                                                                                if (availableOfficers.isEmpty)
                                                                                        Column(
                                                                                                children: [
                                                                                                        Icon(
                                                                                                                Icons.people_outline,
                                                                                                                size: 40,
                                                                                                                color: Color(0xFF8F9BB3),
                                                                                                        ),
                                                                                                        const SizedBox(height: 12),
                                                                                                        Text(
                                                                                                                'No available officers found',
                                                                                                                style: TextStyle(
                                                                                                                        fontSize: 14,
                                                                                                                        color: Color(0xFFFF6B6B),
                                                                                                                ),
                                                                                                                textAlign: TextAlign.center,
                                                                                                        ),
                                                                                                ],
                                                                                        )
                                                                                else
                                                                                        ConstrainedBox(
                                                                                                constraints: BoxConstraints(
                                                                                                        maxWidth: 300,
                                                                                                        minHeight: 60,
                                                                                                ),
                                                                                                child: DropdownButtonFormField<String>(
                                                                                                        value: selectedUid,
                                                                                                        items: availableOfficers.map((officer) {
                                                                                                                final name = officer['userAccount']?['name']?.toString() ?? 'Unknown Officer';
                                                                                                                final badgeNumber = officer['badgeNumber']?.toString() ?? 'N/A';
                                                                                                                return DropdownMenuItem<String>(
                                                                                                                        value: officer['uid']?.toString(),
                                                                                                                        child: Text('$name ($badgeNumber)'),
                                                                                                                );
                                                                                                        }).toList(),
                                                                                                        onChanged: (value) => selectedUid = value,
                                                                                                        decoration: InputDecoration(
                                                                                                                labelText: 'Available Officers',
                                                                                                                prefixIcon: Icon(Icons.people, color: Color(0xFF2E5BFF)),
                                                                                                                filled: true,
                                                                                                                fillColor: Color(0xFFF5F7FA),
                                                                                                                border: OutlineInputBorder(
                                                                                                                        borderRadius: BorderRadius.circular(12),
                                                                                                                        borderSide: BorderSide.none,
                                                                                                                ),
                                                                                                        ),
                                                                                                        isExpanded: true,
                                                                                                ),
                                                                                        ),
                                                                                const SizedBox(height: 20),
                                                                                Row(
                                                                                        mainAxisSize: MainAxisSize.min,
                                                                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                                                        children: [
                                                                                                Flexible(
                                                                                                        child: _ModernButton(
                                                                                                                text: 'Cancel',
                                                                                                                onPressed: () => Navigator.of(context).pop(null),
                                                                                                                isOutlined: true,
                                                                                                                isDialogButton: true,
                                                                                                        ),
                                                                                                ),
                                                                                                const SizedBox(width: 12),
                                                                                                Flexible(
                                                                                                        child: _ModernButton(
                                                                                                                text: 'Reassign',
                                                                                                                onPressed: () => Navigator.of(context).pop(selectedUid),
                                                                                                                gradient: LinearGradient(
                                                                                                                        colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
                                                                                                                ),
                                                                                                                isDialogButton: true,
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
                        ),
                );
        }

        Future<bool?> _showModernDialog(String title, String message) {
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
                                                                                title,
                                                                                style: TextStyle(
                                                                                        fontSize: 18,
                                                                                        fontWeight: FontWeight.w700,
                                                                                        color: Color(0xFF1A1F36),
                                                                                ),
                                                                                textAlign: TextAlign.center,
                                                                        ),
                                                                        const SizedBox(height: 12),
                                                                        Text(
                                                                                message,
                                                                                style: TextStyle(
                                                                                        fontSize: 14,
                                                                                        color: Color(0xFF8F9BB3),
                                                                                ),
                                                                                textAlign: TextAlign.center,
                                                                        ),
                                                                        const SizedBox(height: 20),
                                                                        Row(
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
                                                                                                        text: title == 'Remove Excuse' ? 'Remove' : 'Delete',
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
                                                    ? LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)])
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

        void _showShiftForm({Map<String, dynamic>? existingShift}) {
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
                                                                                                                                existingShift != null ? Icons.edit : Icons.schedule,
                                                                                                                                color: Colors.white,
                                                                                                                        ),
                                                                                                                        const SizedBox(width: 20),
                                                                                                                        Expanded(
                                                                                                                                child: Text(
                                                                                                                                        existingShift != null ? 'Edit Shift' : 'Assign Shift',
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
                                                                                                        child: SingleChildScrollView(
                                                                                                                padding: const EdgeInsets.all(20),
                                                                                                                child: OfficerShiftForm(
                                                                                                                        existingShift: existingShift,
                                                                                                                        stationUid: widget.stationUid,
                                                                                                                        onSubmit: _refreshList,
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
                                        hintText: 'Search shifts...',
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

        List<Map<String, dynamic>> _filterShifts(List<Map<String, dynamic>> shifts) {
                if (_searchQuery.isEmpty) return shifts;

                return shifts.where((shift) {
                        final officerName = shift['officer']?['userAccount']?['name']?.toString().toLowerCase() ?? '';
                        final badgeNumber = shift['officer']?['badgeNumber']?.toString().toLowerCase() ?? '';
                        final shiftDate = shift['shiftDate']?.toString().toLowerCase() ?? '';
                        final shiftType = shift['shiftType']?.toString().toLowerCase() ?? '';
                        final dutyDescription = shift['dutyDescription']?.toString().toLowerCase() ?? '';
                        final startTime = shift['startTime']?.toString().toLowerCase() ?? '';
                        final endTime = shift['endTime']?.toString().toLowerCase() ?? '';
                        final excuseReason = shift['excuseReason']?.toString().toLowerCase() ?? '';
                        final query = _searchQuery.toLowerCase();

                        return officerName.contains(query) ||
                            badgeNumber.contains(query) ||
                            shiftDate.contains(query) ||
                            shiftType.contains(query) ||
                            dutyDescription.contains(query) ||
                            startTime.contains(query) ||
                            endTime.contains(query) ||
                            excuseReason.contains(query);
                }).toList();
        }

        Widget _buildShiftCard(Map<String, dynamic> shift, int index) {
                print('Building shift card $index: ${json.encode(shift)}');

                final officerName = shift['officer']?['userAccount']?['name']?.toString() ?? 'Unknown Officer';
                final badgeNumber = shift['officer']?['badgeNumber']?.toString() ?? 'N/A';
                final shiftDate = shift['shiftDate']?.toString() ?? 'N/A';
                final shiftType = shift['shiftType']?.toString() ?? 'N/A';
                final dutyDescription = shift['dutyDescription']?.toString() ?? 'No description';
                final isPunishmentMode = shift['isPunishmentMode']?.toString() == 'true' || false;
                final startTime = shift['startTime']?.toString() ?? '06:00';
                final endTime = shift['endTime']?.toString() ?? '14:00';
                final shiftStatus = _calculateShiftStatus(shift);
                final isExcused = shift['isExcused']?.toString() == 'true' || false;
                final excuseReason = shift['excuseReason']?.toString() ?? '';
                final isButtonDisabled = shiftStatus.contains('OFF') || shiftStatus.contains('EXCUSED');

                Color getCardBackgroundColor() {
                        if (isPunishmentMode) {
                                return Color(0xFFFFCDD2).withOpacity(0.08);
                        } else if (isExcused) {
                                return Color(0xFFFFECB3).withOpacity(0.08);
                        } else {
                                return Color(0xBBDEFB).withOpacity(0.08);
                        }
                }

                LinearGradient getHeroGradient() {
                        if (isPunishmentMode) {
                                return LinearGradient(
                                        colors: [
                                                Color(0xFFFF6B6B).withOpacity(0.8),
                                                Color(0xFFFF6B6B),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                );
                        } else if (isExcused) {
                                return LinearGradient(
                                        colors: [
                                                Color(0xFFFFA726).withOpacity(0.8),
                                                Color(0xFFFFA726),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                );
                        } else {
                                return LinearGradient(
                                        colors: [
                                                Color(0xFF2E5BFF).withOpacity(0.8),
                                                Color(0xFF2E5BFF),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                );
                        }
                }

                IconData getHeroIcon() {
                        if (isPunishmentMode) return Icons.warning_rounded;
                        if (isExcused) return Icons.event_busy_rounded;
                        return Icons.schedule_rounded;
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
                                                    color: getCardBackgroundColor(),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(
                                                            color: isPunishmentMode
                                                                ? Color(0xFFFF6B6B).withOpacity(0.2)
                                                                : isExcused
                                                                ? Color(0xFFFFA726).withOpacity(0.2)
                                                                : Color(0xFF2E5BFF).withOpacity(0.2),
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
                                                            onTap: isButtonDisabled ? null : () => _showShiftForm(existingShift: shift),
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
                                                                                                                                    color: (isPunishmentMode
                                                                                                                                        ? Color(0xFFFF6B6B)
                                                                                                                                        : isExcused
                                                                                                                                        ? Color(0xFFFFA726)
                                                                                                                                        : Color(0xFF2E5BFF))
                                                                                                                                        ?.withOpacity(0.3) ??
                                                                                                                                        Color(0xFF2E5BFF).withOpacity(0.3),
                                                                                                                                    blurRadius: 8,
                                                                                                                                    offset: const Offset(0, 2),
                                                                                                                            ),
                                                                                                                    ],
                                                                                                            ),
                                                                                                            child: Icon(
                                                                                                                    getHeroIcon(),
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
                                                                                                                                            if (isPunishmentMode)
                                                                                                                                                    Container(
                                                                                                                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                                                                                                                            decoration: BoxDecoration(
                                                                                                                                                                    color: Color(0xFFFFCDD2).withOpacity(0.15),
                                                                                                                                                                    borderRadius: BorderRadius.circular(12),
                                                                                                                                                                    border: Border.all(
                                                                                                                                                                            color: Color(0xFFFF6B6B).withOpacity(0.3),
                                                                                                                                                                            width: 1,
                                                                                                                                                                    ),
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
                                                                                                                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                                                                                                                            decoration: BoxDecoration(
                                                                                                                                                                    color: Color(0xFFFFECB3).withOpacity(0.15),
                                                                                                                                                                    borderRadius: BorderRadius.circular(12),
                                                                                                                                                                    border: Border.all(
                                                                                                                                                                            color: Color(0xFFFFA726).withOpacity(0.3),
                                                                                                                                                                            width: 1,
                                                                                                                                                                    ),
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
                                                                                    Column(
                                                                                            children: [
                                                                                                    Row(
                                                                                                            children: [
                                                                                                                    Expanded(
                                                                                                                            child: _buildInfoRow(
                                                                                                                                    Icons.badge_rounded,
                                                                                                                                    'Badge',
                                                                                                                                    badgeNumber,
                                                                                                                            ),
                                                                                                                    ),
                                                                                                                    const SizedBox(width: 20),
                                                                                                                    Expanded(
                                                                                                                            child: _buildInfoRow(
                                                                                                                                    Icons.calendar_today_rounded,
                                                                                                                                    'Date',
                                                                                                                                    shiftDate,
                                                                                                                            ),
                                                                                                                    ),
                                                                                                            ],
                                                                                                    ),
                                                                                                    const SizedBox(height: 8),
                                                                                                    Row(
                                                                                                            children: [
                                                                                                                    Expanded(
                                                                                                                            child: _buildInfoRow(
                                                                                                                                    Icons.schedule_rounded,
                                                                                                                                    'Type',
                                                                                                                                    '$shiftType ($startTime - $endTime)',
                                                                                                                            ),
                                                                                                                    ),
                                                                                                            ],
                                                                                                    ),
                                                                                                    const SizedBox(height: 8),
                                                                                                    Row(
                                                                                                            children: [
                                                                                                                    Expanded(
                                                                                                                            child: _buildInfoRow(
                                                                                                                                    Icons.info_outline_rounded,
                                                                                                                                    'Status',
                                                                                                                                    shiftStatus,
                                                                                                                                    textColor: _getStatusColor(shiftStatus),
                                                                                                                            ),
                                                                                                                    ),
                                                                                                            ],
                                                                                                    ),
                                                                                                    const SizedBox(height: 8),
                                                                                                    _buildInfoRow(
                                                                                                            Icons.description_rounded,
                                                                                                            'Description',
                                                                                                            dutyDescription,
                                                                                                            maxLines: 2,
                                                                                                    ),
                                                                                                    if (isExcused && excuseReason.isNotEmpty) ...[
                                                                                                            const SizedBox(height: 8),
                                                                                                            _buildInfoRow(
                                                                                                                    Icons.note_rounded,
                                                                                                                    'Excuse Reason',
                                                                                                                    excuseReason,
                                                                                                                    maxLines: 2,
                                                                                                                    textColor: Color(0xFFFFA726),
                                                                                                            ),
                                                                                                    ],
                                                                                            ],
                                                                                    ),
                                                                                    const SizedBox(height: 20),
                                                                                    Row(
                                                                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                                                            children: [
                                                                                                    _buildActionButton(
                                                                                                            icon: Icons.edit_rounded,
                                                                                                            label: 'Edit',
                                                                                                            color: Color(0xFF2E5BFF),
                                                                                                            onPressed: isButtonDisabled ? null : () => _showShiftForm(existingShift: shift),
                                                                                                    ),
                                                                                                    _buildActionButton(
                                                                                                            icon: Icons.swap_horiz_rounded,
                                                                                                            label: 'Reassign',
                                                                                                            color: Color(0xFFFFB75E),
                                                                                                            onPressed: isButtonDisabled
                                                                                                                ? null
                                                                                                                : () => _reassignShift(
                                                                                                                    shift['uid']?.toString() ?? '',
                                                                                                                    shift['shiftDate']?.toString() ?? DateTime.now().toIso8601String().split('T')[0],
                                                                                                                    shift['startTime']?.toString() ?? '06:00',
                                                                                                                    shift['endTime']?.toString() ?? '14:00',
                                                                                                            ),
                                                                                                    ),
                                                                                                    _buildActionButton(
                                                                                                            icon: isExcused ? Icons.undo_rounded : Icons.event_busy_rounded,
                                                                                                            label: isExcused ? 'Unexcuse' : 'Excuse',
                                                                                                            color: Color(0xFFFFA726),
                                                                                                            onPressed: isButtonDisabled ? null : () => _excuseShift(shift['uid']?.toString() ?? '', isExcused),
                                                                                                    ),
                                                                                                    _buildActionButton(
                                                                                                            icon: Icons.delete_outline_rounded,
                                                                                                            label: 'Delete',
                                                                                                            color: Color(0xFFFF6B6B),
                                                                                                            onPressed: isButtonDisabled ? null : () => _deleteShift(shift['uid']?.toString() ?? ''),
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

        Widget _buildInfoRow(
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
                                        color: Color(0xFF8F9BB3),
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
                                                                        color: Color(0xFF8F9BB3),
                                                                        fontWeight: FontWeight.w500,
                                                                ),
                                                        ),
                                                        const SizedBox(height: 1),
                                                        Text(
                                                                value,
                                                                style: TextStyle(
                                                                        fontSize: 13,
                                                                        color: textColor ?? Color(0xFF1A1F36),
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

        Widget _buildActionButton({
                required IconData icon,
                required String label,
                required Color color,
                required VoidCallback? onPressed,
        }) {
                final isDisabled = onPressed == null;
                return Opacity(
                        opacity: isDisabled ? 0.4 : 1.0,
                        child: Column(
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
                        ),
                );
        }

        Color _getStatusColor(String status) {
                if (status.contains('OFF')) {
                        return Color(0xFFFF6B6B);
                } else if (status.contains('ONGOING')) {
                        return Color(0xFF4CAF50);
                } else if (status.contains('EXCUSED')) {
                        return Color(0xFFFFA726);
                } else {
                        return Color(0xFF2E5BFF);
                }
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
                                                        Icons.schedule,
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
                                                                        'Total Shifts',
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
                                                                        'Shifts at ${widget.stationName}',
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
                                                                                                                                colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
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
                                                                                                                'No shifts found',
                                                                                                                style: TextStyle(
                                                                                                                        fontSize: 16,
                                                                                                                        fontWeight: FontWeight.w600,
                                                                                                                        color: Color(0xFF1A1F36),
                                                                                                                ),
                                                                                                                textAlign: TextAlign.center,
                                                                                                        ),
                                                                                                        const SizedBox(height: 12),
                                                                                                        Text(
                                                                                                                'Click the (+) button to assign the first shift',
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
                                                                                        if (filteredShifts.isEmpty && _searchQuery.isNotEmpty)
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
                                                                                                ...filteredShifts.asMap().entries.map((entry) {
                                                                                                        return _buildShiftCard(entry.value, entry.key);
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
                                                        colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                                                ),
                                                borderRadius: BorderRadius.circular(15),
                                                boxShadow: [
                                                        BoxShadow(
                                                                color: Color(0xFF4CAF50).withOpacity(0.3),
                                                                blurRadius: 10,
                                                                offset: Offset(0, 5),
                                                        ),
                                                ],
                                        ),
                                        child: FloatingActionButton.extended(
                                                onPressed: () => _showShiftForm(),
                                                backgroundColor: Colors.transparent,
                                                elevation: 0,
                                                icon: const Icon(Icons.add, color: Colors.white),
                                                label: Text(
                                                        'Assign Shift',
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
        final bool isDialogButton;

        const _ModernButton({
                required this.text,
                required this.onPressed,
                this.icon,
                this.isOutlined = false,
                this.gradient,
                this.isDialogButton = false,
        });

        @override
        Widget build(BuildContext context) {
                final textStyle = isDialogButton
                    ? TextStyle(
                        color: isOutlined ? Color(0xFF1A1F36) : Colors.white,
                        fontSize: 14,
                )
                    : TextStyle(
                        color: isOutlined ? Color(0xFF1A1F36) : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                );

                final padding = isDialogButton
                    ? const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 12,
                )
                    : const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                );

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
                                                        padding: padding,
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
                                                                                style: textStyle,
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
                                                padding: padding,
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
                                                                        style: textStyle,
                                                                ),
                                                        ],
                                                ),
                                        ),
                                ),
                        ),
                );
        }
}