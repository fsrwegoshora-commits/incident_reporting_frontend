import 'package:flutter/material.dart';
import 'package:incident_reporting_frontend/core/network/api_service.dart';
import 'package:incident_reporting_frontend/core/theme/app_theme.dart';
import 'package:incident_reporting_frontend/core/widgets/widgets.dart';

class DepartmentForm extends StatefulWidget {
  final Map<String, dynamic>? existingDepartment;
  final VoidCallback onSubmit;

  const DepartmentForm({
    super.key,
    this.existingDepartment,
    required this.onSubmit,
  });

  @override
  State<DepartmentForm> createState() => _DepartmentFormState();
}

class _DepartmentFormState extends State<DepartmentForm> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  String? _uid;
  String? _type;
  String? _agencyUid;

  bool _isLoading      = false;
  bool _agenciesLoading = false;

  List<Map<String, dynamic>> _agencies = [];

  bool get _isEditing => widget.existingDepartment != null;

  // ─── Data ─────────────────────────────────────────────────────────────────
  static const _types = [
    DropdownItem(value: 'GENERAL_POLICE', label: 'General Police',   icon: Icons.security_outlined),
    DropdownItem(value: 'TRAFFIC_POLICE', label: 'Traffic Police',   icon: Icons.traffic_outlined),
    DropdownItem(value: 'FIRE',           label: 'Fire Department',  icon: Icons.local_fire_department_outlined),
    DropdownItem(value: 'MEDICAL',        label: 'Medical',          icon: Icons.local_hospital_outlined),
  ];

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final d = widget.existingDepartment;
    if (d != null) {
      _uid       = d['uid'];
      _nameCtrl.text = d['name'] ?? '';
      _type      = d['type'];
      _agencyUid = d['agency']?['uid']?.toString();
    }
    _loadAgencies();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ─── Network ──────────────────────────────────────────────────────────────
  Future<void> _loadAgencies() async {
    setState(() => _agenciesLoading = true);
    try {
      final res  = await ApiService().getAgencies();
      final list = List<Map<String, dynamic>>.from(res['data'] ?? []);
      if (!mounted) return;
      setState(() {
        _agencies = list;
        if (_agencyUid == null && list.isNotEmpty && !_isEditing) {
          _agencyUid = list.first['uid']?.toString();
        }
      });
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Error loading agencies: $e');
    } finally {
      if (mounted) setState(() => _agenciesLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_type == null) {
      AppSnackbar.warning(context, 'Please select a department type');
      return;
    }
    if (_agencyUid == null) {
      AppSnackbar.warning(context, 'Please select an agency');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final dto = {
        if (_uid != null) 'uid': _uid,
        'name':      _nameCtrl.text.trim(),
        'type':      _type,
        'agencyUid': _agencyUid,
      };
      final res = await ApiService().saveDepartment(dto);
      if (!mounted) return;
      final ok = res['status'] == 'Success';
      if (ok) {
        AppSnackbar.success(context, res['message'] ?? 'Department saved successfully');
        widget.onSubmit();
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) Navigator.pop(context, true);
      } else {
        AppSnackbar.error(context, res['message'] ?? 'Failed to save department');
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
    if (_agenciesLoading) {
      return Scaffold(
        backgroundColor: AppTheme.gray50,
        appBar: AppTopBar(title: _isEditing ? 'Edit Department' : 'Register Department'),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
      );
    }

    final agencyItems = _agencies
        .map((a) => DropdownItem<String>(value: a['uid']!.toString(), label: a['name']?.toString() ?? '—'))
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.gray50,
      appBar: AppTopBar(title: _isEditing ? 'Edit Department' : 'Register Department'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceL),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              FormHeaderCard(
                icon: Icons.domain_outlined,
                title: _isEditing ? 'Edit Department' : 'Register Department',
                subtitle: 'Fill in all required department information below',
              ),
              const SizedBox(height: AppTheme.spaceM),

              FormSectionCard(
                title: 'Department Details',
                icon: Icons.apartment_outlined,
                children: [
                  FormTextInput(
                    controller: _nameCtrl,
                    label: 'Department Name',
                    icon: Icons.domain_outlined,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Department name is required';
                      if (v.trim().length < 3) return 'Must be at least 3 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.spaceM),
                  FormDropdown<String>(
                    label: 'Department Type',
                    icon: Icons.category_outlined,
                    value: _type,
                    items: _types,
                    onChanged: (v) => setState(() => _type = v),
                    validator: (v) => v == null ? 'Department type is required' : null,
                  ),
                  const SizedBox(height: AppTheme.spaceM),
                  FormDropdown<String>(
                    label: 'Agency',
                    icon: Icons.business_outlined,
                    value: _agencyUid,
                    items: agencyItems,
                    onChanged: (v) => setState(() => _agencyUid = v),
                    validator: (v) => v == null ? 'Agency is required' : null,
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceM),

              AppButton(
                label: _isEditing ? 'Update Department' : 'Register Department',
                icon: Icons.save_outlined,
                onPressed: _save,
                isLoading: _isLoading,
              ),
              const SizedBox(height: AppTheme.spaceM),
            ],
          ),
        ),
      ),
    );
  }
}
