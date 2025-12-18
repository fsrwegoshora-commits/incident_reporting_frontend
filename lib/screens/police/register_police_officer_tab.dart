import 'package:flutter/material.dart';
import '../../services/graphql_service.dart';
import '../../utils/graphql_query.dart';
import '../../theme/app_theme.dart';

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
  _RegisterPoliceOfficerTabState createState() => _RegisterPoliceOfficerTabState();
}

class _RegisterPoliceOfficerTabState extends State<RegisterPoliceOfficerTab> {
  final _formKey = GlobalKey<FormState>();
  final _badgeNumberController = TextEditingController();
  String? _selectedUserUid;
  String? _selectedStationUid;
  String? _selectedDepartmentUid;
  String _selectedRank = 'PC';
  bool _isLoading = false;
  List<Map<String, dynamic>> _specialUsers = [];
  List<Map<String, dynamic>> _policeStations = [];
  List<Map<String, dynamic>> _departments = [];

  // Define ranks with both value and display name
  final List<Map<String, String>> _ranks = [
    {"value": "PC", "label": "Police Constable (PC)"},
    {"value": "CPL", "label": "Corporal (CPL)"},
    {"value": "SGT", "label": "Sergeant (SGT)"},
    {"value": "S_SGT", "label": "Senior Sergeant (S/SGT)"},
    {"value": "SM", "label": "Staff Sergeant (SM)"},
    {"value": "A_ISP", "label": "Assistant Inspector (A/ISP)"},
    {"value": "ISP", "label": "Inspector (ISP)"},
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
    if (widget.existingOfficer != null) {
      _badgeNumberController.text = widget.existingOfficer!['badgeNumber'] ?? '';
      _selectedUserUid = widget.existingOfficer!['userAccount']?['uid']?.toString();
      _selectedStationUid = widget.existingOfficer!['station']?['uid']?.toString();
      _selectedDepartmentUid = widget.existingOfficer!['department']?['uid']?.toString();
      _selectedRank = widget.existingOfficer!['code'] ?? 'PC';
    } else if (widget.preSelectedStationUid != null) {
      _selectedStationUid = widget.preSelectedStationUid;
    }
  }

  @override
  void dispose() {
    _badgeNumberController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchSpecialUsers(),
        _fetchPoliceStations(),
        _fetchDepartments(),
      ]);
    } catch (e) {
      _showErrorSnackBar("Error loading data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSpecialUsers() async {
    final gql = GraphQLService();
    try {
      final response = await gql.sendAuthenticatedQuery(getSpecialUsersQuery, {
        "role": "POLICE_OFFICER",
      });
      final data = response['data']?['getSpecialUsers'] ?? {};
      setState(() {
        _specialUsers = List<Map<String, dynamic>>.from(data['data'] ?? []);
        if (_selectedUserUid == null && _specialUsers.isNotEmpty && widget.existingOfficer == null) {
          _selectedUserUid = _specialUsers.first['uid']?.toString();
        }
      });
    } catch (e) {
      print("Error fetching special users: $e");
    }
  }

  Future<void> _fetchPoliceStations() async {
    final gql = GraphQLService();
    try {
      final response = await gql.sendAuthenticatedQuery(getPoliceStationsQueryMutation, {
        "pageableParam": {
          "page": 0,
          "size": 100,
          "sortBy": "name",
          "sortDirection": "ASC",
          "searchParam": null,
          "isActive": true,
        }
      });
      final data = response['data']?['getPoliceStations'] ?? {};
      setState(() {
        _policeStations = List<Map<String, dynamic>>.from(data['data'] ?? []);
        if (_selectedStationUid == null && _policeStations.isNotEmpty && widget.existingOfficer == null && widget.preSelectedStationUid == null) {
          _selectedStationUid = _policeStations.first['uid']?.toString();
        }
      });
    } catch (e) {
      print("Error fetching police stations: $e");
    }
  }

  Future<void> _fetchDepartments() async {
    final gql = GraphQLService();
    try {
      final response = await gql.sendAuthenticatedQuery(getDepartmentsQuery, {
        "pageableParam": {
          "page": 0,
          "size": 100,
          "sortBy": "name",
          "sortDirection": "ASC",
        }
      });
      final data = response['data']?['getDepartments'] ?? {};
      setState(() {
        _departments = List<Map<String, dynamic>>.from(data['data'] ?? []);
        if (_selectedDepartmentUid == null && _departments.isNotEmpty && widget.existingOfficer == null) {
          _selectedDepartmentUid = _departments.first['uid']?.toString();
        }
      });
    } catch (e) {
      print("Error fetching departments: $e");
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final gql = GraphQLService();

    try {
      final variables = {
        "policeOfficerDto": {
          if (widget.existingOfficer != null) "uid": widget.existingOfficer!['uid'],
          "badgeNumber": _badgeNumberController.text.trim(),
          "userUid": _selectedUserUid,
          "stationUid": _selectedStationUid,
          "departmentUid": _selectedDepartmentUid,
          "code": _selectedRank,
        }
      };

      print("📡 Sending mutation with variables: $variables");

      final response = await gql.sendAuthenticatedMutation(savePoliceOfficerMutation, variables);
      final result = response['data']?['savePoliceOfficer'];

      if (!mounted) return;

      final isSuccess = result?['status'] == 'Success' || result?['status'] == true;
      final message = result?['message'] ?? (isSuccess ? "Police officer saved successfully" : "Failed to save police officer");

      _showSuccessSnackBar(message);

      if (isSuccess) {
        // Delay to show snackbar
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          if (widget.onSubmit != null) {
            widget.onSubmit!();
          }
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar("Error saving police officer: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.all(AppTheme.spaceM),
          decoration: BoxDecoration(
            gradient: AppTheme.errorGradient,
            borderRadius: AppTheme.cardRadius,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.cardWhite.withOpacity(0.2),
                  borderRadius: AppTheme.smallRadius,
                ),
                child: Icon(
                  Icons.error,
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
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.cardRadius),
        elevation: 0,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.all(AppTheme.spaceM),
          decoration: BoxDecoration(
            gradient: AppTheme.successGradient,
            borderRadius: AppTheme.cardRadius,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.cardWhite.withOpacity(0.2),
                  borderRadius: AppTheme.smallRadius,
                ),
                child: Icon(
                  Icons.check_circle,
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
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.cardRadius),
        elevation: 0,
      ),
    );
  }

  bool get isEditing => widget.existingOfficer != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 640,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
      ),
      child: _isLoading
          ? Center(
        child: Container(
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
      )
          : SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.spaceL),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spaceL),
                decoration: AppTheme.elevatedCardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlueLight.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.local_police,
                        size: 40,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceM),
                    Text(
                      isEditing ? "Edit Police Officer" : "Register Police Officer",
                      style: AppTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spaceS),
                    Text(
                      "Fill in all required officer information below",
                      style: AppTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceL),
              // Form Fields Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spaceL),
                decoration: AppTheme.elevatedCardDecoration,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedUserUid,
                      style: AppTheme.bodyLarge,
                      items: _specialUsers.map((user) {
                        return DropdownMenuItem<String>(
                          value: user['uid']?.toString(),
                          child: Text(
                            user['name']?.toString() ?? 'Unknown User',
                            style: AppTheme.bodyLarge,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedUserUid = value),
                      decoration: AppTheme.getInputDecoration(
                        labelText: "Special User",
                        prefixIcon: Icons.person,
                      ),
                      validator: (value) => value == null ? "Special user is required" : null,
                    ),
                    const SizedBox(height: AppTheme.spaceM),
                    TextFormField(
                      controller: _badgeNumberController,
                      style: AppTheme.bodyLarge,
                      decoration: AppTheme.getInputDecoration(
                        labelText: "Badge Number",
                        prefixIcon: Icons.badge,
                      ),
                      validator: (value) => value!.isEmpty ? "Badge number is required" : null,
                    ),
                    const SizedBox(height: AppTheme.spaceM),
                    DropdownButtonFormField<String>(
                      value: _selectedRank,
                      style: AppTheme.bodyLarge,
                      items: _ranks.map((code) {
                        return DropdownMenuItem<String>(
                          value: code["value"],
                          child: Text(code["label"]!, style: AppTheme.bodyLarge),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedRank = value!),
                      decoration: AppTheme.getInputDecoration(
                        labelText: "Rank",
                        prefixIcon: Icons.military_tech,
                      ),
                      validator: (value) => value == null ? "Rank is required" : null,
                    ),
                    const SizedBox(height: AppTheme.spaceM),
                    widget.preSelectedStationUid != null
                        ? TextFormField(
                      initialValue: _policeStations
                          .firstWhere(
                            (station) => station['uid'] == widget.preSelectedStationUid,
                        orElse: () => {'name': 'Unknown Station'},
                      )['name']
                          ?.toString(),
                      style: AppTheme.bodyLarge,
                      decoration: AppTheme.getInputDecoration(
                        labelText: "Police Station",
                        prefixIcon: Icons.local_police,
                      ),
                      enabled: false,
                    )
                        : DropdownButtonFormField<String>(
                      value: _selectedStationUid,
                      style: AppTheme.bodyLarge,
                      items: _policeStations.map((station) {
                        return DropdownMenuItem<String>(
                          value: station['uid']?.toString(),
                          child: Text(
                            station['name']?.toString() ?? 'Unknown Station',
                            style: AppTheme.bodyLarge,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedStationUid = value),
                      decoration: AppTheme.getInputDecoration(
                        labelText: "Police Station",
                        prefixIcon: Icons.local_police,
                      ),
                      validator: (value) => value == null ? "Police station is required" : null,
                    ),
                    const SizedBox(height: AppTheme.spaceM),
                    DropdownButtonFormField<String>(
                      value: _selectedDepartmentUid,
                      style: AppTheme.bodyLarge,
                      items: _departments.map((dept) {
                        return DropdownMenuItem<String>(
                          value: dept['uid']?.toString(),
                          child: Text(
                            dept['name']?.toString() ?? 'Unknown Department',
                            style: AppTheme.bodyLarge,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedDepartmentUid = value),
                      decoration: AppTheme.getInputDecoration(
                        labelText: "Department",
                        prefixIcon: Icons.domain,
                      ),
                      validator: (value) => value == null ? "Department is required" : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceL),
              // Submit Button Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spaceL),
                decoration: AppTheme.elevatedCardDecoration,
                child: _isLoading
                    ? Center(
                  child: Container(
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
                )
                    : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: AppTheme.cardWhite,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spaceM,
                        horizontal: AppTheme.spaceL,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: AppTheme.buttonRadius),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ),
                    child: Container(
                      decoration: AppTheme.primaryButtonDecoration,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spaceM,
                        horizontal: AppTheme.spaceL,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.save, size: 24),
                          const SizedBox(width: AppTheme.spaceS),
                          Text(
                            isEditing ? "Update Officer" : "Register Officer",
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
      ),
    );
  }
}