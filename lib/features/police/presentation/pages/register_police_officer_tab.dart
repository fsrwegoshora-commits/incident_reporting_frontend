import 'package:flutter/material.dart';
import 'package:incident_reporting_frontend/core/network/api_service.dart';
import 'package:incident_reporting_frontend/core/theme/app_theme.dart';
import 'package:incident_reporting_frontend/core/widgets/widgets.dart';

class RegisterPoliceOfficerTab extends StatefulWidget {
  final Map<String, dynamic>? existingOfficer;
  final String? preSelectedStationUid;
  final VoidCallback? onSubmit;

  const RegisterPoliceOfficerTab({
    super.key,
    this.existingOfficer,
    this.preSelectedStationUid,
    this.onSubmit,
  });

  @override
  State<RegisterPoliceOfficerTab> createState() => _RegisterPoliceOfficerTabState();
}

class _RegisterPoliceOfficerTabState extends State<RegisterPoliceOfficerTab> {
  final _formKey          = GlobalKey<FormState>();
  final _badgeCtrl        = TextEditingController();
  final _nameCtrl         = TextEditingController();
  final _phoneCtrl        = TextEditingController();

  String? _stationUid;
  String? _departmentUid;
  String  _rank           = 'PC';
  String? _position;
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isLoading         = false;
  bool _dataLoading       = false;

  List<Map<String, dynamic>> _stations    = [];
  List<Map<String, dynamic>> _departments = [];

  bool get _isEditing => widget.existingOfficer != null;

  // ─── Data ─────────────────────────────────────────────────────────────────
  static const _ranks = [
    DropdownItem(value: 'PC',    label: 'Police Constable (PC)'),
    DropdownItem(value: 'CPL',   label: 'Corporal (CPL)'),
    DropdownItem(value: 'SGT',   label: 'Sergeant (SGT)'),
    DropdownItem(value: 'S_SGT', label: 'Senior Sergeant (S/SGT)'),
    DropdownItem(value: 'SM',    label: 'Staff Sergeant (SM)'),
    DropdownItem(value: 'A_ISP', label: 'Assistant Inspector (A/ISP)'),
    DropdownItem(value: 'ISP',   label: 'Inspector (ISP)'),
  ];

  static const _positions = [
    DropdownItem(value: 'OFFICER_IN_CHARGE',         label: 'Officer In-Charge (OIC)'),
    DropdownItem(value: 'DEPUTY_OFFICER_IN_CHARGE',  label: 'Deputy OIC'),
    DropdownItem(value: 'INVESTIGATOR',              label: 'Investigator'),
    DropdownItem(value: 'DETECTIVE',                 label: 'Detective'),
    DropdownItem(value: 'TRAFFIC_OFFICER',           label: 'Traffic Officer'),
    DropdownItem(value: 'PATROL_OFFICER',            label: 'Patrol Officer'),
    DropdownItem(value: 'ADMINISTRATIVE_OFFICER',    label: 'Administrative Officer'),
    DropdownItem(value: 'COMMUNITY_LIAISON_OFFICER', label: 'Community Liaison Officer'),
    DropdownItem(value: 'GENERAL_DUTY_OFFICER',      label: 'General Duty Officer'),
  ];

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _prefill();
    _fetchData();
  }

  void _prefill() {
    final o = widget.existingOfficer;
    if (o != null) {
      _badgeCtrl.text  = o['badgeNumber']  ?? '';
      _nameCtrl.text   = o['userAccount']?['name']?.toString()        ?? '';
      _phoneCtrl.text  = o['userAccount']?['phoneNumber']?.toString() ?? '';
      _stationUid      = o['station']?['uid']?.toString();
      _departmentUid   = o['department']?['uid']?.toString();
      _rank            = o['code'] ?? 'PC';
    } else if (widget.preSelectedStationUid != null) {
      _stationUid = widget.preSelectedStationUid;
    }
  }

  @override
  void dispose() {
    _badgeCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ─── Network ──────────────────────────────────────────────────────────────
  Future<void> _fetchData() async {
    setState(() => _dataLoading = true);
    try {
      await Future.wait([_loadStations(), _loadDepartments()]);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Error loading data: $e');
    } finally {
      if (mounted) setState(() => _dataLoading = false);
    }
  }

  Future<void> _loadStations() async {
    final res = await ApiService().getPoliceStations(page: 0, size: 100);
    if (!mounted) return;
    final list = List<Map<String, dynamic>>.from(res['data'] ?? []);
    setState(() {
      _stations = list;
      if (_stationUid == null && list.isNotEmpty && !_isEditing && widget.preSelectedStationUid == null) {
        _stationUid = list.first['uid']?.toString();
      }
    });
  }

  Future<void> _loadDepartments() async {
    final res = await ApiService().getDepartments(page: 0, size: 100);
    if (!mounted) return;
    final list = List<Map<String, dynamic>>.from(res['data'] ?? []);
    setState(() {
      _departments = list;
      if (_departmentUid == null && list.isNotEmpty && !_isEditing) {
        _departmentUid = list.first['uid']?.toString();
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final dto = {
        if (_isEditing) 'uid': widget.existingOfficer!['uid'],
        'badgeNumber':   _badgeCtrl.text.trim(),
        'name':          _nameCtrl.text.trim(),
        'phoneNumber':   _phoneCtrl.text.trim(),
        'stationUid':    _stationUid,
        'departmentUid': _departmentUid,
        'code':          _rank,
        if (_position != null) 'appointmentPosition': _position,
        if (_startDate != null)
          'appointmentStartDate': _startDate!.toIso8601String().split('T').first,
        if (_endDate != null)
          'appointmentEndDate': _endDate!.toIso8601String().split('T').first,
      };
      final res = await ApiService().savePoliceOfficer(dto);
      if (!mounted) return;
      final ok = res['status'] == 'Success';
      if (ok) {
        AppSnackbar.success(context, res['message'] ?? 'Officer saved successfully');
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) {
          widget.onSubmit?.call();
          Navigator.of(context).pop();
        }
      } else {
        AppSnackbar.error(context, res['message'] ?? 'Failed to save officer');
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_dataLoading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
      );
    }

    final stationItems = _stations
        .map((s) => DropdownItem<String>(value: s['uid']!.toString(), label: s['name']?.toString() ?? '—'))
        .toList();
    final deptItems = _departments
        .map((d) => DropdownItem<String>(value: d['uid']!.toString(), label: d['name']?.toString() ?? '—'))
        .toList();
    final preStationName = _stations
        .firstWhere((s) => s['uid'] == widget.preSelectedStationUid,
            orElse: () => {'name': 'Selected Station'})['name']
        ?.toString();

    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Header
          FormHeaderCard(
            icon: Icons.local_police_outlined,
            title: _isEditing ? 'Edit Police Officer' : 'Register Police Officer',
            subtitle: 'Fill in all required information below',
          ),
          const SizedBox(height: AppTheme.spaceM),

          // Account
          FormSectionCard(
            title: 'Officer Account',
            icon: Icons.person_outline,
            children: [
              FormTextInput(
                controller: _nameCtrl,
                label: 'Full Name',
                icon: Icons.person_outline,
                enabled: !_isEditing,
                validator: (v) => v == null || v.trim().isEmpty ? 'Full name is required' : null,
              ),
              const SizedBox(height: AppTheme.spaceM),
              FormTextInput(
                controller: _phoneCtrl,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                hint: '+255712345678',
                keyboardType: TextInputType.phone,
                enabled: !_isEditing,
                validator: (v) => v == null || v.trim().isEmpty ? 'Phone number is required' : null,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceM),

          // Officer details
          FormSectionCard(
            title: 'Officer Details',
            icon: Icons.badge_outlined,
            children: [
              FormTextInput(
                controller: _badgeCtrl,
                label: 'Badge Number',
                icon: Icons.badge_outlined,
                validator: (v) => v == null || v.isEmpty ? 'Badge number is required' : null,
              ),
              const SizedBox(height: AppTheme.spaceM),
              FormDropdown<String>(
                label: 'Rank',
                icon: Icons.military_tech_outlined,
                value: _rank,
                items: _ranks,
                onChanged: (v) => setState(() => _rank = v ?? 'PC'),
                validator: (v) => v == null ? 'Rank is required' : null,
              ),
              const SizedBox(height: AppTheme.spaceM),
              // Station
              widget.preSelectedStationUid != null
                  ? FormTextInput(
                      label: 'Police Station',
                      icon: Icons.location_city_outlined,
                      controller: TextEditingController(text: preStationName),
                      enabled: false,
                    )
                  : FormDropdown<String>(
                      label: 'Police Station',
                      icon: Icons.location_city_outlined,
                      value: _stationUid,
                      items: stationItems,
                      onChanged: (v) => setState(() => _stationUid = v),
                      validator: (v) => v == null ? 'Police station is required' : null,
                    ),
              const SizedBox(height: AppTheme.spaceM),
              FormDropdown<String>(
                label: 'Department',
                icon: Icons.domain_outlined,
                value: _departmentUid,
                items: deptItems,
                onChanged: (v) => setState(() => _departmentUid = v),
                validator: (v) => v == null ? 'Department is required' : null,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceM),

          // Station appointment (new officers only)
          if (!_isEditing) ...[
            FormSectionCard(
              title: 'Station Appointment',
              subtitle: 'Set the officer\'s role and tenure at this station',
              icon: Icons.assignment_ind_outlined,
              children: [
                FormDropdown<String>(
                  label: 'Position at Station',
                  icon: Icons.work_outline,
                  value: _position,
                  items: _positions,
                  onChanged: (v) => setState(() => _position = v),
                  validator: (v) => v == null ? 'Position is required' : null,
                ),
                const SizedBox(height: AppTheme.spaceM),
                FormDateRangePicker(
                  startDate: _startDate,
                  endDate: _endDate,
                  onStartPicked: (d) => setState(() => _startDate = d),
                  onEndPicked:   (d) => setState(() => _endDate   = d),
                  startLabel: 'Appointment Start',
                  endLabel:   'End Date (optional)',
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceM),
          ],

          // Submit
          AppButton(
            label: _isEditing ? 'Update Officer' : 'Register Officer',
            icon: Icons.save_outlined,
            onPressed: _submit,
            isLoading: _isLoading,
          ),
          const SizedBox(height: AppTheme.spaceM),
        ],
      ),
    );
  }
}
