import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../enum/enum.dart';
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
        String _shiftTime = ShiftTimeEnum.MORNING;
        String _shiftDutyType = ShiftDutyTypeEnum.STATION_DUTY;
        String? _selectedOfficerUid;
        String? _selectedCheckpointUid;
        bool _isPunishmentMode = false;
        bool _isLoading = false;
        List<Map<String, dynamic>> _availableOfficers = [];
        List<Map<String, dynamic>> _availableCheckpoints = [];
        Map<String, dynamic>? _existingOfficer;
        TimeOfDay? _startTime;
        TimeOfDay? _endTime;

        @override
        void initState() {
                super.initState();

                if (widget.existingShift != null) {
                        _loadExistingShift();
                } else {
                        _updateShiftTimes(_shiftTime);
                }

                _fetchAvailableOfficers();
                _fetchAvailableCheckpoints(); // ✅ IMPLEMENTED
        }

        void _loadExistingShift() {
                final shift = widget.existingShift!;
                _shiftDate = DateTime.parse(shift['shiftDate']);
                _shiftTime = shift['shiftTime'] ?? ShiftTimeEnum.MORNING;
                _shiftDutyType = shift['shiftDutyType'] ?? ShiftDutyTypeEnum.STATION_DUTY;
                _dutyDescriptionController.text = shift['dutyDescription'] ?? '';
                _isPunishmentMode = shift['isPunishmentMode'] ?? false;
                _selectedOfficerUid = shift['officer']?['uid'];
                _selectedCheckpointUid = shift['checkpointUid'];

                if (shift['startTime'] != null) {
                        _startTime = TimeOfDay.fromDateTime(DateFormat.Hm().parse(shift['startTime']));
                }
                if (shift['endTime'] != null) {
                        _endTime = TimeOfDay.fromDateTime(DateFormat.Hm().parse(shift['endTime']));
                }

                _existingOfficer = {
                        'uid': shift['officer']?['uid'],
                        'badgeNumber': shift['officer']?['badgeNumber'],
                        'userAccount': shift['officer']?['userAccount'],
                };

                _updateShiftTimes(_shiftTime);
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
                                getAvailableOfficersForSlotQuery,
                                {
                                        "date": DateFormat('yyyy-MM-dd').format(_shiftDate!),
                                        "startTime": "${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}",
                                        "endTime": "${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}",
                                },
                        );

                        if (response['errors'] != null) {
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

        // ✅ IMPLEMENTED: Fetch available checkpoints from backend
        Future<void> _fetchAvailableCheckpoints() async {
                try {
                        final gql = GraphQLService();
                        final response = await gql.sendAuthenticatedQuery(
                                getTrafficCheckpointsQuery,
                                {
                                        "pageableParam": {
                                                "page": 0,
                                                "size": 100,
                                                "sortBy": "name",
                                                "sortDirection": "ASC",
                                        }
                                },
                        );

                        if (response['errors'] != null) {
                                throw Exception(response['errors'][0]['message']);
                        }

                        final data = response['data']?['getTrafficCheckpoints'] ?? {};
                        setState(() {
                                _availableCheckpoints = List<Map<String, dynamic>>.from(data['data'] ?? []);
                                print("✅ Loaded ${_availableCheckpoints.length} checkpoints");
                        });
                } catch (e) {
                        print("❌ Error fetching checkpoints: $e");
                        _showModernSnackBar("Error loading checkpoints: $e", isSuccess: false);
                        setState(() => _availableCheckpoints = []);
                }
        }

        void _updateShiftTimes(String? shiftTime) {
                if (shiftTime != null) {
                        final timings = ShiftTimeEnum.getTimings()[shiftTime];
                        if (timings != null) {
                                setState(() {
                                        _startTime = timings['start'];
                                        _endTime = timings['end'];
                                });
                                _fetchAvailableOfficers();
                        }
                }
        }

        Future<void> _submitForm() async {
                if (_formKey.currentState!.validate()) {
                        if (_selectedOfficerUid == null) {
                                _showModernSnackBar("Please select an officer", isSuccess: false);
                                return;
                        }

                        if (_shiftDutyType == ShiftDutyTypeEnum.CHECKPOINT_DUTY && _selectedCheckpointUid == null) {
                                _showModernSnackBar("Please select a checkpoint for checkpoint duty", isSuccess: false);
                                return;
                        }

                        setState(() => _isLoading = true);
                        final gql = GraphQLService();

                        try {
                                final variables = {
                                        "dto": {
                                                if (widget.existingShift != null) "uid": widget.existingShift!['uid'],
                                                "shiftDate": DateFormat('yyyy-MM-dd').format(_shiftDate!),
                                                "shiftTime": _shiftTime,
                                                "shiftDutyType": _shiftDutyType,
                                                "dutyDescription": _dutyDescriptionController.text.trim(),
                                                "isPunishmentMode": _isPunishmentMode,
                                                "officerUid": _selectedOfficerUid,
                                                "startTime": "${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}",
                                                "endTime": "${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}",
                                                if (_selectedCheckpointUid != null) "checkpointUid": _selectedCheckpointUid,
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
                                        await Future.delayed(const Duration(milliseconds: 500));
                                        if (mounted) {
                                                widget.onSubmit();
                                                Navigator.pop(context);
                                        }
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
                                                // Shift Date
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

                                                // Shift Time (MORNING/EVENING/NIGHT)
                                                DropdownButtonFormField<String>(
                                                        value: _shiftTime,
                                                        items: ShiftTimeEnum.values.map((time) {
                                                                return DropdownMenuItem<String>(
                                                                        value: time,
                                                                        child: Text(ShiftTimeEnum.getLabel(time), overflow: TextOverflow.ellipsis),
                                                                );
                                                        }).toList(),
                                                        onChanged: (value) {
                                                                setState(() => _shiftTime = value!);
                                                                _updateShiftTimes(value);
                                                        },
                                                        decoration: AppTheme.getInputDecoration(
                                                                labelText: 'Shift Time Period',
                                                                prefixIcon: Icons.schedule,
                                                        ),
                                                        validator: (value) => value == null ? 'Please select a shift time' : null,
                                                        isExpanded: true,
                                                ),
                                                const SizedBox(height: AppTheme.spaceM),

                                                // Start Time (Read-only)
                                                TextFormField(
                                                        readOnly: true,
                                                        decoration: AppTheme.getInputDecoration(
                                                                labelText: 'Start Time',
                                                                hintText: _startTime?.format(context) ?? 'Select shift time',
                                                                prefixIcon: Icons.access_time,
                                                        ),
                                                        validator: (value) => _startTime == null ? 'Please select a shift time' : null,
                                                ),
                                                const SizedBox(height: AppTheme.spaceM),

                                                // End Time (Read-only)
                                                TextFormField(
                                                        readOnly: true,
                                                        decoration: AppTheme.getInputDecoration(
                                                                labelText: 'End Time',
                                                                hintText: _endTime?.format(context) ?? 'Select shift time',
                                                                prefixIcon: Icons.access_time,
                                                        ),
                                                        validator: (value) => _endTime == null ? 'Please select a shift time' : null,
                                                ),
                                                const SizedBox(height: AppTheme.spaceM),

                                                // Shift Duty Type
                                                DropdownButtonFormField<String>(
                                                        value: _shiftDutyType,
                                                        items: ShiftDutyTypeEnum.values.map((dutyType) {
                                                                return DropdownMenuItem<String>(
                                                                        value: dutyType,
                                                                        child: Row(
                                                                                children: [
                                                                                        Icon(
                                                                                                ShiftDutyTypeEnum.getIcon(dutyType),
                                                                                                size: 18,
                                                                                                color: ShiftDutyTypeEnum.getColor(dutyType),
                                                                                        ),
                                                                                        const SizedBox(width: 8),
                                                                                        Text(
                                                                                                ShiftDutyTypeEnum.getLabel(dutyType),
                                                                                                overflow: TextOverflow.ellipsis,
                                                                                        ),
                                                                                ],
                                                                        ),
                                                                );
                                                        }).toList(),
                                                        onChanged: (value) => setState(() => _shiftDutyType = value!),
                                                        decoration: AppTheme.getInputDecoration(
                                                                labelText: 'Shift Duty Type',
                                                                prefixIcon: Icons.work,
                                                        ),
                                                        validator: (value) => value == null ? 'Please select a duty type' : null,
                                                        isExpanded: true,
                                                ),
                                                const SizedBox(height: AppTheme.spaceM),

                                                // ✅ Checkpoint Selector (Show only if CHECKPOINT_DUTY) - NOW POPULATED
                                                if (_shiftDutyType == ShiftDutyTypeEnum.CHECKPOINT_DUTY)
                                                        Column(
                                                                children: [
                                                                        DropdownButtonFormField<String>(
                                                                                value: _selectedCheckpointUid,
                                                                                hint: const Text('Select a Checkpoint'),
                                                                                items: _availableCheckpoints.map((checkpoint) {
                                                                                        return DropdownMenuItem<String>(
                                                                                                value: checkpoint['uid']?.toString(),
                                                                                                child: Column(
                                                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                                                                        children: [
                                                                                                                Text(
                                                                                                                        checkpoint['name'] ?? 'Unknown Checkpoint',
                                                                                                                        overflow: TextOverflow.ellipsis,
                                                                                                                        style: AppTheme.bodyMedium,
                                                                                                                ),
                                                                                                                if (checkpoint['parentStation']?['name'] != null)
                                                                                                                        Text(
                                                                                                                                checkpoint['parentStation']['name'],
                                                                                                                                overflow: TextOverflow.ellipsis,
                                                                                                                                style: AppTheme.bodySmall.copyWith(color: Colors.grey),
                                                                                                                        ),
                                                                                                        ],
                                                                                                ),
                                                                                        );
                                                                                }).toList(),
                                                                                onChanged: (value) => setState(() => _selectedCheckpointUid = value),
                                                                                decoration: AppTheme.getInputDecoration(
                                                                                        labelText: 'Checkpoint',
                                                                                        prefixIcon: Icons.security,
                                                                                ),
                                                                                validator: (value) =>
                                                                                _shiftDutyType == ShiftDutyTypeEnum.CHECKPOINT_DUTY && value == null
                                                                                    ? 'Please select a checkpoint'
                                                                                    : null,
                                                                                isExpanded: true,
                                                                        ),
                                                                        const SizedBox(height: AppTheme.spaceM),
                                                                ],
                                                        ),

                                                // Officer Selector
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
                                                        isExpanded: true,
                                                        dropdownColor: AppTheme.surfaceWhite,
                                                        menuMaxHeight: 300,
                                                ),
                                                const SizedBox(height: AppTheme.spaceM),

                                                // Duty Description
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

                                                // Punishment Mode
                                                SwitchListTile(
                                                        value: _isPunishmentMode,
                                                        onChanged: (value) => setState(() => _isPunishmentMode = value),
                                                        title: Text('Punishment Mode', style: AppTheme.bodyMedium),
                                                        activeColor: AppTheme.primaryBlue,
                                                        tileColor: AppTheme.surfaceGrey,
                                                        shape: RoundedRectangleBorder(borderRadius: AppTheme.buttonRadius),
                                                ),
                                                const SizedBox(height: AppTheme.spaceXL),

                                                // Submit Button
                                                if (_isLoading)
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
                                                        )
                                                else
                                                        Container(
                                                                width: double.infinity,
                                                                decoration: AppTheme.primaryButtonDecoration,
                                                                child: Material(
                                                                        color: Colors.transparent,
                                                                        child: InkWell(
                                                                                borderRadius: AppTheme.buttonRadius,
                                                                                onTap: _submitForm,
                                                                                child: Container(
                                                                                        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceM),
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