import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../enum/enum.dart';
import '../../services/graphql_service.dart';
import '../../utils/graphql_query.dart';
import '../../theme/app_theme.dart';

class BulkCheckpointShiftForm extends StatefulWidget {
  final String stationUid;
  final VoidCallback onSubmit;

  const BulkCheckpointShiftForm({
    super.key,
    required this.stationUid,
    required this.onSubmit,
  });

  @override
  State<BulkCheckpointShiftForm> createState() =>
      _BulkCheckpointShiftFormState();
}

class _BulkCheckpointShiftFormState extends State<BulkCheckpointShiftForm> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _shiftDate = DateTime.now();
  String _shiftTime = ShiftTimeEnum.MORNING;
  String _shiftDutyType = ShiftDutyTypeEnum.CHECKPOINT_DUTY;
  String? _selectedCheckpointUid;
  List<String> _selectedOfficerUids = [];
  bool _isLoading = false;
  List<Map<String, dynamic>> _availableCheckpoints = [];
  List<Map<String, dynamic>> _availableOfficers = [];
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _updateShiftTimes(_shiftTime);
    _fetchAvailableCheckpoints();
    _fetchAvailableOfficers();
  }

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
        _availableCheckpoints =
        List<Map<String, dynamic>>.from(data['data'] ?? []);
      });
    } catch (e) {
      print('Error fetching checkpoints: $e');
      _showModernSnackBar("Error loading checkpoints: $e", isSuccess: false);
    }
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
          "startTime":
          "${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}",
          "endTime":
          "${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}",
        },
      );

      if (response['errors'] != null) {
        throw Exception(response['errors'][0]['message']);
      }

      final data = response['data']?['getAvailableOfficersForSlot'] ?? {};
      setState(() {
        _availableOfficers =
        List<Map<String, dynamic>>.from(data['data'] ?? []);
      });
    } catch (e) {
      print('Error fetching officers: $e');
      _showModernSnackBar("Error loading available officers: $e",
          isSuccess: false);
      setState(() => _availableOfficers = []);
    } finally {
      setState(() => _isLoading = false);
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
      if (_selectedCheckpointUid == null) {
        _showModernSnackBar("Please select a checkpoint", isSuccess: false);
        return;
      }

      if (_selectedOfficerUids.isEmpty) {
        _showModernSnackBar("Please select at least one officer",
            isSuccess: false);
        return;
      }

      setState(() => _isLoading = true);
      final gql = GraphQLService();

      try {
        final variables = {
          "bulkCheckpointShiftDto": {
            "checkpointUid": _selectedCheckpointUid,
            "officerUids": _selectedOfficerUids,
            "shiftDate": DateFormat('yyyy-MM-dd').format(_shiftDate!),
            "shiftTime": _shiftTime,
            "shiftDutyType": _shiftDutyType,
            "startTime":
            "${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}",
            "endTime":
            "${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}",
          },
        };

        final response = await gql.sendAuthenticatedMutation(
            assignCheckpointShiftBulkMutation, variables);

        if (response['errors'] != null) {
          throw Exception(response['errors'][0]['message']);
        }

        final result = response['data']?['assignCheckpointShiftBulk'];
        if (result == null || result['status'] != 'Success') {
          _showModernSnackBar(
            result?['message'] ?? "Failed to assign shifts",
            isSuccess: false,
          );
        } else {
          final assignedCount = (result['data'] as List?)?.length ?? 0;
          _showModernSnackBar(
            "Successfully assigned $assignedCount shifts to checkpoint",
            isSuccess: true,
          );
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            widget.onSubmit();
            Navigator.pop(context);
          }
        }
      } catch (e) {
        print('Error assigning shifts: $e');
        _showModernSnackBar("Error assigning shifts: $e", isSuccess: false);
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

            // Shift Time Period
            DropdownButtonFormField<String>(
              value: _shiftTime,
              items: ShiftTimeEnum.values.map((time) {
                return DropdownMenuItem<String>(
                  value: time,
                  child: Text(ShiftTimeEnum.getLabel(time),
                      overflow: TextOverflow.ellipsis),
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
              validator: (value) =>
              value == null ? 'Please select a shift time' : null,
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
              validator: (value) =>
              _startTime == null ? 'Please select a shift time' : null,
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
              validator: (value) =>
              _endTime == null ? 'Please select a shift time' : null,
            ),
            const SizedBox(height: AppTheme.spaceM),

            // Checkpoint Selector
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
                          style: AppTheme.bodySmall
                              .copyWith(color: Colors.grey),
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
              value == null ? 'Please select a checkpoint' : null,
              isExpanded: true,
            ),
            const SizedBox(height: AppTheme.spaceM),

            // Officers Multi-Selector
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderColor),
                borderRadius: AppTheme.buttonRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spaceM),
                    child: Text(
                      'Select Officers (${_selectedOfficerUids.length} selected)',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_availableOfficers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spaceM),
                      child: Text(
                        'No officers available for this time slot',
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceM),
                      child: Column(
                        children: _availableOfficers.map((officer) {
                          final uid = officer['uid']?.toString() ?? '';
                          final name = officer['userAccount']?['name'] ??
                              'Unknown Officer';
                          final badgeNumber =
                              officer['badgeNumber'] ?? 'N/A';
                          final isSelected =
                          _selectedOfficerUids.contains(uid);

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedOfficerUids.add(uid);
                                } else {
                                  _selectedOfficerUids.remove(uid);
                                }
                              });
                            },
                            title: Text(
                              name,
                              style: AppTheme.bodyMedium,
                            ),
                            subtitle: Text(
                              'Badge: $badgeNumber',
                              style: AppTheme.bodySmall
                                  .copyWith(color: Colors.grey),
                            ),
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppTheme.primaryBlue,
                          );
                        }).toList(),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spaceM),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: _availableOfficers.isEmpty
                              ? null
                              : () {
                            setState(() {
                              if (_selectedOfficerUids.length ==
                                  _availableOfficers.length) {
                                _selectedOfficerUids.clear();
                              } else {
                                _selectedOfficerUids = _availableOfficers
                                    .map((o) => o['uid']?.toString() ?? '')
                                    .toList();
                              }
                            });
                          },
                          icon: const Icon(Icons.done_all),
                          label: Text(
                            _selectedOfficerUids.length ==
                                _availableOfficers.length
                                ? 'Deselect All'
                                : 'Select All',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                    valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.cardWhite),
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
                      padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spaceM),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_turned_in,
                              color: AppTheme.cardWhite, size: 20),
                          const SizedBox(width: AppTheme.spaceS),
                          Text(
                            'Assign Shifts',
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

  @override
  void dispose() {
    super.dispose();
  }
}