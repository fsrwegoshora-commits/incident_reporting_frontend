import 'package:flutter/material.dart';
import 'package:incident_reporting_frontend/core/network/api_service.dart';
import 'package:incident_reporting_frontend/core/theme/app_theme.dart';
import 'package:incident_reporting_frontend/core/widgets/widgets.dart';

class AgencyForm extends StatefulWidget {
  final Map<String, dynamic>? existingAgency;
  final VoidCallback onSubmit;

  const AgencyForm({
    super.key,
    this.existingAgency,
    required this.onSubmit,
  });

  @override
  State<AgencyForm> createState() => _AgencyFormState();
}

class _AgencyFormState extends State<AgencyForm> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _codeCtrl    = TextEditingController();
  final _descCtrl    = TextEditingController();

  bool    _isLoading = false;
  String? _uid;

  bool get _isEditing => widget.existingAgency != null;

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final a = widget.existingAgency;
    if (a != null) {
      _uid          = a['uid'];
      _nameCtrl.text = a['name']        ?? '';
      _codeCtrl.text = a['code']        ?? '';
      _descCtrl.text = a['description'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ─── Network ──────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final dto = {
        if (_uid != null) 'uid': _uid,
        'name':        _nameCtrl.text.trim(),
        'code':        _codeCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
      };
      final res = await ApiService().saveAgency(dto);
      if (!mounted) return;
      final ok = res['status'] == 'Success';
      if (ok) {
        AppSnackbar.success(context, res['message'] ?? 'Agency saved successfully');
        widget.onSubmit();
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) Navigator.pop(context, true);
      } else {
        AppSnackbar.error(context, res['message'] ?? 'Failed to save agency');
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.gray50,
    appBar: AppTopBar(
      title: _isEditing ? 'Edit Agency' : 'Register Agency',
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceL),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            FormHeaderCard(
              icon: Icons.business_outlined,
              title: _isEditing ? 'Edit Agency' : 'Register Agency',
              subtitle: 'Fill in all required agency information below',
            ),
            const SizedBox(height: AppTheme.spaceM),

            FormSectionCard(
              title: 'Agency Details',
              icon: Icons.business_center_outlined,
              children: [
                FormTextInput(
                  controller: _nameCtrl,
                  label: 'Agency Name',
                  icon: Icons.business_outlined,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Agency name is required';
                    if (v.trim().length < 3) return 'Must be at least 3 characters';
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spaceM),
                FormTextInput(
                  controller: _codeCtrl,
                  label: 'Agency Code',
                  icon: Icons.tag_outlined,
                  hint: 'e.g. PF, TPA',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Agency code is required';
                    if (v.trim().length > 10) return 'Code must not exceed 10 characters';
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spaceM),
                FormTextInput(
                  controller: _descCtrl,
                  label: 'Description',
                  icon: Icons.description_outlined,
                  maxLines: 4,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Description is required';
                    if (v.trim().length < 10) return 'Must be at least 10 characters';
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceM),

            AppButton(
              label: _isEditing ? 'Update Agency' : 'Register Agency',
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
