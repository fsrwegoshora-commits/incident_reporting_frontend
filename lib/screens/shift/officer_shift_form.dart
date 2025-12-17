import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/graphql_service.dart';
import '../../utils/graphql_query.dart';
import '../../theme/app_theme.dart';

class OfficerShiftForm extends StatefulWidget {
        final Map<String, dynamic>? existingShift;
        final String stationUid;
        final VoidCallback onSubmit;

        const OfficerShiftForm({
                super.key,
                this.existingShift,
                required this.stationUid,
                required this.onSubmit,
        });

        @override
        State<OfficerShiftForm> createState() => _OfficerShiftFormState();
}

class _OfficerShiftFormState extends State<OfficerShiftForm> {
        final _formKey = GlobalKey<FormState>();
        final _dutyDescriptionController = TextEditingController();
        DateTime? _shiftDate = DateTime.now();
        String _shiftType = 'MORNING';
        String? _selectedOfficerUid;
        bool _isPunishmentMode = false;
        bool _isLoading = false;
        List<Map<String, dynamic>> _availableOfficers = [];
        Map<String, dynamic>? _existingOfficer;
        TimeOfDay? _startTime;
        TimeOfDay? _endTime;

        // Predefined shift times
        final Map<String, Map<String, TimeOfDay>> _shiftTimes = {
                'MORNING': {
                        'start': const TimeOfDay(hour: 6, minute: 0),
                        'end': const TimeOfDay(hour: 14, minute: 0),
                },
                'EVENING': {
                        'start': const TimeOfDay(hour: 14, minute: 0),
                        'end': const TimeOfDay(hour: 22, minute: 0),
                },
                'NIGHT': {
                        'start': const TimeOfDay(hour: 22, minute: 0),
                        'end': const TimeOfDay(hour: 6, minute: 0),
                },
        };

        @override
        void initState() {
                super.initState();

                if (widget.existingShift != null) {
                        _shiftDate = DateTime.parse(widget.existingShift!['shiftDate']);
                        _shiftType = widget.existingShift!['shiftType'];
                        _dutyDescriptionController.text = widget.existingShift!['dutyDescription'] ?? '';
                        _isPunishmentMode = widget.existingShift!['isPunishmentMode'] ?? false;
                        _selectedOfficerUid = widget.existingShift!['officer']?['uid'];
                        if (widget.existingShift!['startTime'] != null) {
                                _startTime = TimeOfDay.fromDateTime(DateFormat.Hm().parse(widget.existingShift!['startTime']));
                        }
                        if (widget.existingShift!['endTime'] != null) {
                                _endTime = TimeOfDay.fromDateTime(DateFormat.Hm().parse(widget.existingShift!['endTime']));
                        }

                        _existingOfficer = {
                                'uid': widget.existingShift!['officer']?['uid'],
                                'badgeNumber': widget.existingShift!['officer']?['badgeNumber'],
                                'userAccount': widget.existingShift!['officer']?['userAccount'],
                        };
                } else {
                        _updateShiftTimes(_shiftType);
                }

                _fetchAvailableOfficers();
        }

        @override
        void dispose() {
                _dutyDescriptionController.dispose();
                super.dispose();
        }

        Future<void> _fetchAvailableOfficers() async {
                if (_shiftDate == null || _startTime == null || _endTime == null) {
                        setState(() => _availableOfficers = []);
                        return;
                }

                setState(() => _isLoading = true);
                try {
                        final gql = GraphQLService();
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
                                        "date": DateFormat('yyyy-MM-dd').format(_shiftDate!),
                                        "startTime": "${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}",
                                        "endTime": "${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}",
                                },
                        );

                        if (response['errors'] != null) {
                                print('GraphQL Errors: ${response['errors']}');
                                throw Exception(response['errors'][0]['message']);
                        }

                        final data = response['data']?['getAvailableOfficersForSlot'] ?? {};
                        List<Map<String, dynamic>> availableOfficers = List<Map<String, dynamic>>.from(data['data'] ?? []);

                        if (widget.existingShift != null && _selectedOfficerUid != null) {
                                final officerExists = availableOfficers.any((officer) => officer['uid'] == _selectedOfficerUid);
                                if (!officerExists && _existingOfficer != null) {
                                        availableOfficers.add(_existingOfficer!);
                                }
                        }

                        setState(() {
                                _availableOfficers = availableOfficers;
                                if (_selectedOfficerUid == null && _availableOfficers.isNotEmpty && widget.existingShift == null) {
                                        _selectedOfficerUid = _availableOfficers.first['uid']?.toString();
                                }
                        });
                } catch (e) {
                        print('Error fetching officers: $e');
                        _showModernSnackBar("Error loading available officers: $e", isSuccess: false);
                        setState(() => _availableOfficers = []);
                } finally {
                        setState(() => _isLoading = false);
                }
        }

        void _updateShiftTimes(String? shiftType) {
                if (shiftType != null && _shiftTimes.containsKey(shiftType)) {
                        setState(() {
                                _startTime = _shiftTimes[shiftType]!['start'];
                                _endTime = _shiftTimes[shiftType]!['end'];
                        });
                        _fetchAvailableOfficers();
                }
        }

        Future<void> _submitForm() async {
                if (_formKey.currentState!.validate()) {
                        if (_selectedOfficerUid == null) {
                                _showModernSnackBar("Please select an officer", isSuccess: false);
                                return;
                        }
                        setState(() => _isLoading = true);
                        final gql = GraphQLService();

                        try {
                                final variables = {
                                        "dto": {
                                                if (widget.existingShift != null) "uid": widget.existingShift!['uid'],
                                                "shiftDate": DateFormat('yyyy-MM-dd').format(_shiftDate!),
                                                "shiftType": _shiftType,
                                                "dutyDescription": _dutyDescriptionController.text.trim(),
                                                "isPunishmentMode": _isPunishmentMode,
                                                "officerUid": _selectedOfficerUid,
                                                "startTime": "${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}",
                                                "endTime": "${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}",
                                        },
                                };

                                final response = await gql.sendAuthenticatedMutation(saveShiftMutation, variables);

                                if (response['errors'] != null) {
                                        throw Exception(response['errors'][0]['message']);
                                }

                                final result = response['data']?['saveShift'];
                                if (result == null || result['status'] != 'Success') {
                                        _showModernSnackBar(
                                                result?['message'] ?? "Failed to save shift",
                                                isSuccess: false,
                                        );
                                } else {
                                        _showModernSnackBar(
                                                result['message'] ?? "Shift saved successfully",
                                                isSuccess: true,
                                        );
                                        widget.onSubmit();
                                        Navigator.pop(context);
                                }
                        } catch (e) {
                                print('Error saving shift: $e');
                                _showModernSnackBar("Error saving shift: $e", isSuccess: false);
                        } finally {
                                setState(() => _isLoading = false);
                        }
                }
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

        @override
        Widget build(BuildContext context) {
                return Form(
                        key: _formKey,
                        child: SingleChildScrollView(
                                padding: const EdgeInsets.all(AppTheme.spaceM),
                                child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                                TextFormField(
                                                        initialValue: DateFormat('yyyy-MM-dd').format(_shiftDate!),
                                                        decoration: AppTheme.getInputDecoration(
                                                                labelText: 'Shift Date',
                                                                prefixIcon: Icons.calendar_today,
                                                        ),
                                                        readOnly: true,
                                                        onTap: () async {
                                                                final date = await showDatePicker(
                                                                        context: context,
                                                                        initialDate: _shiftDate!,
                                                                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                                                );
                                                                if (date != null) {
                                                                        setState(() => _shiftDate = date);
                                                                        _fetchAvailableOfficers();
                                                                }
                                                        },
                                                        validator: (value) => value == null ? 'Please select a date' : null,
                                                ),
                                                const SizedBox(height: AppTheme.spaceM),
                                                DropdownButtonFormField<String>(
                                                        value: _shiftType,
                                                        items: ['MORNING', 'EVENING', 'NIGHT'].map((type) {
                                                                return DropdownMenuItem<String>(
                                                                        value: type,
                                                                        child: Text(type, overflow: TextOverflow.ellipsis),
                                                                );
                                                        }).toList(),
                                                        onChanged: (value) {
                                                                setState(() => _shiftType = value!);
                                                                _updateShiftTimes(value);
                                                        },
                                                        decoration: AppTheme.getInputDecoration(
                                                                labelText: 'Shift Type',
                                                                prefixIcon: Icons.timelapse,
                                                        ),
                                                        validator: (value) => value == null ? 'Please select a shift type' : null,
                                                        isExpanded: true, // Ensure dropdown takes full width
                                                ),
                                                const SizedBox(height: AppTheme.spaceM),
                                                TextFormField(
                                                        readOnly: true,
                                                        decoration: AppTheme.getInputDecoration(
                                                                labelText: 'Start Time',
                                                                hintText: _startTime?.format(context) ?? 'Select shift type',
                                                                prefixIcon: Icons.access_time,
                                                        ),
                                                        validator: (value) => _startTime == null ? 'Please select a shift type' : null,
                                                ),
                                                const SizedBox(height: AppTheme.spaceM),
                                                TextFormField(
                                                        readOnly: true,
                                                        decoration: AppTheme.getInputDecoration(
                                                                labelText: 'End Time',
                                                                hintText: _endTime?.format(context) ?? 'Select shift type',
                                                                prefixIcon: Icons.access_time,
                                                        ),
                                                        validator: (value) => _endTime == null ? 'Please select a shift type' : null,
                                                ),
                                                const SizedBox(height: AppTheme.spaceM),
                                                DropdownButtonFormField<String>(
                                                        value: _selectedOfficerUid,
                                                        hint: const Text('Select an Officer'),
                                                        items: _availableOfficers.map((officer) {
                                                                final name = officer['userAccount']?['name'] ?? 'Unknown Officer';
                                                                final badgeNumber = officer['badgeNumber'] ?? 'N/A';
                                                                final uid = officer['uid']?.toString();

                                                                return DropdownMenuItem<String>(
                                                                        value: uid,
                                                                        child: Row(
                                                                                children: [
                                                                                        Expanded(
                                                                                                child: Text(
                                                                                                        '$name ($badgeNumber)',
                                                                                                        overflow: TextOverflow.ellipsis,
                                                                                                        style: AppTheme.bodyMedium,
                                                                                                ),
                                                                                        ),
                                                                                ],
                                                                        ),
                                                                );
                                                        }).toList(),
                                                        onChanged: (value) => setState(() => _selectedOfficerUid = value),
                                                        decoration: AppTheme.getInputDecoration(
                                                                labelText: 'Officer',
                                                                prefixIcon: Icons.person,
                                                        ),
                                                        validator: (value) => value == null ? 'Please select an officer' : null,
                                                        isExpanded: true, // Ensure dropdown takes full width
                                                        dropdownColor: AppTheme.surfaceWhite, // Optional: Match theme
                                                        menuMaxHeight: 300, // Limit dropdown height for scrolling
                                                ),
                                                const SizedBox(height: AppTheme.spaceM),
                                                TextFormField(
                                                        controller: _dutyDescriptionController,
                                                        decoration: AppTheme.getInputDecoration(
                                                                labelText: 'Duty Description',
                                                                hintText: 'Enter duty description',
                                                                prefixIcon: Icons.description,
                                                        ),
                                                        maxLines: 3,
                                                        validator: (value) => value == null || value.isEmpty ? 'Please enter a description' : null,
                                                ),
                                                const SizedBox(height: AppTheme.spaceM),
                                                SwitchListTile(
                                                        value: _isPunishmentMode,
                                                        onChanged: (value) => setState(() => _isPunishmentMode = value),
                                                        title: Text('Punishment Mode', style: AppTheme.bodyMedium),
                                                        activeColor: AppTheme.primaryBlue,
                                                        tileColor: AppTheme.surfaceGrey,
                                                        shape: RoundedRectangleBorder(borderRadius: AppTheme.buttonRadius),
                                                ),
                                                const SizedBox(height: AppTheme.spaceXL),
                                                _isLoading
                                                    ? Container(
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
                                                )
                                                    : Container(
                                                        width: double.infinity,
                                                        decoration: AppTheme.primaryButtonDecoration,
                                                        child: Material(
                                                                color: Colors.transparent,
                                                                child: InkWell(
                                                                        borderRadius: AppTheme.buttonRadius,
                                                                        onTap: _submitForm,
                                                                        child: Container(
                                                                                padding: const EdgeInsets.symmetric(
                                                                                        vertical: AppTheme.spaceM,
                                                                                ),
                                                                                child: Row(
                                                                                        mainAxisSize: MainAxisSize.min,
                                                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                                                        children: [
                                                                                                Icon(Icons.save, color: AppTheme.cardWhite, size: 20),
                                                                                                const SizedBox(width: AppTheme.spaceS),
                                                                                                Text(
                                                                                                        widget.existingShift == null ? 'Assign Shift' : 'Update Shift',
                                                                                                        style: AppTheme.buttonTextMedium,
                                                                                                ),
                                                                                        ],
                                                                                ),
                                                                        ),
                                                                ),
                                                        ),
                                                ),
                                        ],
                                ),
                        ),
                );
        }
}