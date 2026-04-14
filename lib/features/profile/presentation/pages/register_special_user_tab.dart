import 'package:flutter/material.dart';
import 'package:incident_reporting_frontend/core/network/api_service.dart';
import 'package:incident_reporting_frontend/core/theme/app_theme.dart';
import 'package:incident_reporting_frontend/core/widgets/widgets.dart';

class RegisterSpecialUserTab extends StatefulWidget {
  final Map<String, dynamic>? existingUser;
  final VoidCallback? onSubmit;

  const RegisterSpecialUserTab({super.key, this.existingUser, this.onSubmit});

  @override
  State<RegisterSpecialUserTab> createState() => _RegisterSpecialUserTabState();
}

class _RegisterSpecialUserTabState extends State<RegisterSpecialUserTab> {
  final _formKey       = GlobalKey<FormState>();
  final _nameCtrl      = TextEditingController();
  final _phoneCtrl     = TextEditingController();

  String  _role            = 'POLICE_OFFICER';
  String? _stationUid;
  bool    _isLoading       = false;
  bool    _dataLoading     = false;

  List<Map<String, dynamic>> _stations = [];

  bool get _isEditing => widget.existingUser != null;
  bool get _stationRequired => _role == 'POLICE_OFFICER' || _role == 'STATION_ADMIN';

  // ─── Data ─────────────────────────────────────────────────────────────────
  static const _roles = [
    DropdownItem(value: 'POLICE_OFFICER', label: 'Police Officer'),
    DropdownItem(value: 'STATION_ADMIN',  label: 'Station Admin'),
    DropdownItem(value: 'AGENCY_REP',     label: 'Agency Representative'),
  ];

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _prefill();
    _loadStations();
  }

  void _prefill() {
    final u = widget.existingUser;
    if (u != null) {
      _nameCtrl.text  = u['name']        ?? '';
      _phoneCtrl.text = u['phoneNumber'] ?? '';
      _role           = u['role']        ?? 'POLICE_OFFICER';
      _stationUid     = u['station']?['uid']?.toString();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ─── Network ──────────────────────────────────────────────────────────────
  Future<void> _loadStations() async {
    setState(() => _dataLoading = true);
    try {
      final res  = await ApiService().getPoliceStations(page: 0, size: 100, isActive: true);
      final list = List<Map<String, dynamic>>.from(res['data'] ?? []);
      if (!mounted) return;
      setState(() {
        _stations = list;
        // Validate existing station uid or auto-select
        if (_role == 'AGENCY_REP') {
          _stationUid = 'none';
        } else if (_stationUid != null &&
            !list.any((s) => s['uid']?.toString() == _stationUid)) {
          _stationUid = list.isNotEmpty ? list.first['uid']?.toString() : null;
        } else if (_stationUid == null && list.isNotEmpty && !_isEditing) {
          _stationUid = list.first['uid']?.toString();
        }
      });
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Error loading stations: $e');
    } finally {
      if (mounted) setState(() => _dataLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final dto = {
        if (_isEditing) 'uid': widget.existingUser!['uid'],
        'name':        _nameCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        'role':        _role,
        if (_stationRequired && _stationUid != null && _stationUid != 'none')
          'stationUid': _stationUid,
      };

      final res = await ApiService().registerSpecialUser(dto);
      if (!mounted) return;

      final ok = res['status'] == 'Success';
      if (ok) {
        AppSnackbar.success(context, res['message'] ?? 'User saved successfully');
        widget.onSubmit?.call();
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) Navigator.of(context).pop();
      } else {
        AppSnackbar.error(context, res['message'] ?? 'Failed to save user');
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

    final stationItems = [
      if (!_stationRequired)
        const DropdownItem<String>(value: 'none', label: 'Not Required'),
      ..._stations.map((s) => DropdownItem<String>(
            value: s['uid']!.toString(),
            label: s['name']?.toString() ?? '—',
          )),
    ];

    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Header
          FormHeaderCard(
            icon: Icons.person_add_alt_1_outlined,
            title: _isEditing ? 'Edit User' : 'Register New User',
            subtitle: 'Fill in all required user information below',
          ),
          const SizedBox(height: AppTheme.spaceM),

          // Account info
          FormSectionCard(
            title: 'User Information',
            icon: Icons.person_outline,
            children: [
              FormTextInput(
                controller: _nameCtrl,
                label: 'Full Name',
                icon: Icons.person_outline,
                validator: (v) => v == null || v.trim().isEmpty ? 'Full name is required' : null,
              ),
              const SizedBox(height: AppTheme.spaceM),
              FormTextInput(
                controller: _phoneCtrl,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                hint: '+255712345678',
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Phone number is required';
                  if (!RegExp(r'^\+255\d{9}$').hasMatch(v.trim())) {
                    return 'Enter a valid number (+255XXXXXXXXX)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spaceM),
              FormDropdown<String>(
                label: 'Role Type',
                icon: Icons.admin_panel_settings_outlined,
                value: _role,
                items: _roles,
                onChanged: (v) => setState(() {
                  _role = v ?? 'POLICE_OFFICER';
                  if (_role == 'AGENCY_REP') {
                    _stationUid = 'none';
                  } else {
                    _stationUid = _stations.isNotEmpty
                        ? _stations.first['uid']?.toString()
                        : null;
                  }
                }),
                validator: (v) => v == null ? 'Role is required' : null,
              ),
              const SizedBox(height: AppTheme.spaceM),
              FormDropdown<String>(
                label: 'Police Station',
                icon: Icons.location_city_outlined,
                value: _stationUid,
                items: stationItems,
                onChanged: (v) => setState(() => _stationUid = v),
                enabled: _stationRequired,
                validator: (v) {
                  if (_stationRequired && (v == null || v.isEmpty || v == 'none')) {
                    return 'Police station is required for this role';
                  }
                  return null;
                },
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceM),

          // Info box
          FormInfoBox(
            type: InfoBoxType.info,
            message: 'Police Officer & Station Admin require a station. '
                'Agency Representative does not need a station.',
          ),
          const SizedBox(height: AppTheme.spaceM),

          // Submit
          AppButton(
            label: _isEditing ? 'Update User' : 'Register User',
            icon: Icons.person_add_outlined,
            onPressed: _submit,
            isLoading: _isLoading,
          ),

          if (!_isEditing) ...[
            const SizedBox(height: AppTheme.spaceM),
            Text(
              'After registration, the user will receive an SMS to confirm their account.',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppTheme.spaceM),
        ],
      ),
    );
  }
}
