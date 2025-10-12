import 'package:flutter/material.dart';
import '../services/graphql_service.dart';
import '../utils/graphql_query.dart';
import '../theme/app_theme.dart';

class RegisterSpecialUserTab extends StatefulWidget {
  final Map<String, dynamic>? existingUser;
  final VoidCallback? onSubmit;

  const RegisterSpecialUserTab({super.key, this.existingUser, this.onSubmit});

  @override
  _RegisterSpecialUserTabState createState() => _RegisterSpecialUserTabState();
}

class _RegisterSpecialUserTabState extends State<RegisterSpecialUserTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedStationUid;
  final gql = GraphQLService();

  String _selectedRole = 'POLICE_OFFICER';
  bool _isLoading = false;
  List<Map<String, dynamic>> _policeStations = [];

  final List<String> _roles = [
    'POLICE_OFFICER',
    'STATION_ADMIN',
    'AGENCY_REP',
  ];

  final Map<String, String> _roleDisplayNames = {
    'POLICE_OFFICER': 'Police Officer',
    'STATION_ADMIN': 'Station Admin',
    'AGENCY_REP': 'Agency Representative',
  };

  @override
  void initState() {
    super.initState();
    _fetchPoliceStations();
    if (widget.existingUser != null) {
      _nameController.text = widget.existingUser!['name'] ?? '';
      _phoneController.text = widget.existingUser!['phoneNumber'] ?? '';
      _selectedRole = widget.existingUser!['role'] ?? 'POLICE_OFFICER';
      // Set _selectedStationUid only if it's valid; otherwise, keep it null
      _selectedStationUid = widget.existingUser!['station']?['uid']?.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchPoliceStations() async {
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
      final policeStations = List<Map<String, dynamic>>.from(data['data'] ?? []);
      setState(() {
        _policeStations = policeStations;
        // Validate _selectedStationUid after fetching stations
        if (_selectedStationUid != null &&
            !policeStations.any((station) => station['uid']?.toString() == _selectedStationUid) &&
            _selectedRole != 'AGENCY_REP') {
          _selectedStationUid = policeStations.isNotEmpty ? policeStations.first['uid']?.toString() : null;
        } else if (_selectedRole == 'AGENCY_REP' && _selectedStationUid != 'none') {
          _selectedStationUid = 'none';
        }
      });
    } catch (e) {
      print("Error fetching police stations: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.all(AppTheme.spaceM),
            decoration: BoxDecoration(
              gradient: AppTheme.errorGradient,
              borderRadius: AppTheme.cardRadius,
            ),
            child: Text(
              "Error loading police stations: $e",
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.cardWhite),
            ),
          ),
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppTheme.cardRadius),
          elevation: 0,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final variables = {
        "userDto": {
          if (widget.existingUser != null) "uid": widget.existingUser!['uid'],
          "name": _nameController.text.trim(),
          "phoneNumber": _phoneController.text.trim(),
          "role": _selectedRole,
          if (_selectedStationUid != null && _selectedStationUid!.isNotEmpty && _selectedStationUid != 'none')
            "stationUid": _selectedStationUid,
        }
      };

      print("📡 Sending mutation with variables: $variables");

      final response = await gql.sendAuthenticatedMutation(registerSpecialUserMutation, variables);

      print("📡 Register special user response: $response");

      if (response['errors'] != null) {
        final errorMessage = response['errors'][0]['message'] ?? 'Unknown error';
        throw Exception(errorMessage);
      }

      final result = response['data']?['registerSpecialUser'];
      final success = result?['status'] == 'Success';
      final serverMessage = result?['message'] ?? 'Registration failed';
      final displayMessage = success ? 'User registered successfully' : serverMessage;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.all(AppTheme.spaceM),
            decoration: BoxDecoration(
              gradient: success ? AppTheme.successGradient : AppTheme.errorGradient,
              borderRadius: AppTheme.cardRadius,
            ),
            child: Text(
              displayMessage,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.cardWhite),
            ),
          ),
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppTheme.cardRadius),
          elevation: 0,
          duration: const Duration(seconds: 4),
        ),
      );

      if (success) {
        if (!isEditing) {
          _nameController.clear();
          _phoneController.clear();
          _selectedStationUid = _policeStations.isNotEmpty ? _policeStations.first['uid']?.toString() : null;
          _selectedRole = 'POLICE_OFFICER';
        }

        if (widget.onSubmit != null) widget.onSubmit!();

        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    } catch (e) {
      print("❌ Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.all(AppTheme.spaceM),
            decoration: BoxDecoration(
              gradient: AppTheme.errorGradient,
              borderRadius: AppTheme.cardRadius,
            ),
            child: Text(
              "Error: ${e.toString()}",
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.cardWhite),
            ),
          ),
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppTheme.cardRadius),
          elevation: 0,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool get isEditing => widget.existingUser != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 540,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.spaceL),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                        Icons.person_add_alt_1,
                        size: 40,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceM),
                    Text(
                      isEditing ? "Edit User Information" : "Register New User",
                      style: AppTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spaceS),
                    Text(
                      "Fill in all required user information below",
                      style: AppTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceL),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spaceL),
                decoration: AppTheme.elevatedCardDecoration,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      style: AppTheme.bodyLarge,
                      decoration: AppTheme.getInputDecoration(
                        labelText: "Full Name",
                        prefixIcon: Icons.person,
                      ),
                      validator: (value) => value!.isEmpty ? "Name is required" : null,
                    ),
                    const SizedBox(height: AppTheme.spaceM),
                    TextFormField(
                      controller: _phoneController,
                      style: AppTheme.bodyLarge,
                      decoration: AppTheme.getInputDecoration(
                        labelText: "Phone Number",
                        prefixIcon: Icons.phone,
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value!.isEmpty) return "Phone number is required";
                        if (!RegExp(r'^\+255\d{9}$').hasMatch(value)) {
                          return "Enter a valid number (+255712345678)";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spaceM),
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      style: AppTheme.bodyLarge,
                      isExpanded: true,
                      items: _roles.map((role) => DropdownMenuItem<String>(
                        value: role,
                        child: Text(
                          _roleDisplayNames[role] ?? role,
                          style: AppTheme.bodyLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedRole = value!;
                          // Reset _selectedStationUid based on new role
                          if (_selectedRole == 'AGENCY_REP') {
                            _selectedStationUid = 'none';
                          } else {
                            _selectedStationUid = _policeStations.isNotEmpty
                                ? _policeStations.first['uid']?.toString()
                                : null;
                          }
                        });
                      },
                      decoration: AppTheme.getInputDecoration(
                        labelText: "Role Type",
                        prefixIcon: Icons.admin_panel_settings,
                      ),
                      validator: (value) => value == null ? "Role is required" : null,
                    ),
                    const SizedBox(height: AppTheme.spaceM),
                    DropdownButtonFormField<String>(
                      value: _selectedStationUid,
                      style: AppTheme.bodyLarge,
                      isExpanded: true,
                      items: [
                        if (_selectedRole == 'AGENCY_REP')
                          DropdownMenuItem<String>(
                            value: 'none',
                            child: Text(
                              'Not Required',
                              style: AppTheme.bodyLarge.copyWith(color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ..._policeStations.map((station) {
                          return DropdownMenuItem<String>(
                            value: station['uid']?.toString() ?? '',
                            child: Text(
                              station['name']?.toString() ?? 'Unknown Station',
                              style: AppTheme.bodyLarge,
                            ),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) => setState(() => _selectedStationUid = value),
                      decoration: AppTheme.getInputDecoration(
                        labelText: "Police Station",
                        prefixIcon: Icons.local_police,
                      ),
                      validator: (value) {
                        if ((_selectedRole == 'POLICE_OFFICER' || _selectedRole == 'STATION_ADMIN') &&
                            (value == null || value.isEmpty || value == 'none')) {
                          return "Police station is required for this role";
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceL),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spaceL),
                decoration: AppTheme.elevatedCardDecoration,
                child: Column(
                  children: [
                    _isLoading
                        ? Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                            strokeWidth: 4,
                          ),
                          const SizedBox(height: AppTheme.spaceM),
                          Text(
                            "Processing...",
                            style: AppTheme.bodyMedium,
                          ),
                        ],
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
                          shape: RoundedRectangleBorder(
                            borderRadius: AppTheme.buttonRadius,
                          ),
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
                              const Icon(Icons.person_add, size: 24),
                              const SizedBox(width: AppTheme.spaceS),
                              Flexible( // <-- inazuia overflow
                                child: Text(
                                  isEditing ? "Update User" : "Register User",
                                  style: AppTheme.buttonTextMedium,
                                ),
                              ),
                            ],
                          )

                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceM),
                    if (!isEditing) ...[
                      const Divider(
                        thickness: 1,
                        color: AppTheme.dividerColor,
                      ),
                      const SizedBox(height: AppTheme.spaceM),
                      Text(
                        "After registration, the user will receive an SMS to confirm their account.",
                        style: AppTheme.bodyMedium.copyWith(fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceL),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spaceM),
                decoration: BoxDecoration(
                  color: AppTheme.infoBlue.withOpacity(0.1),
                  borderRadius: AppTheme.cardRadius,
                  border: Border.all(color: AppTheme.infoBlueLight.withOpacity(0.5), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 20, color: AppTheme.infoBlue),
                        const SizedBox(width: AppTheme.spaceS),
                        Text(
                          "Instructions:",
                          style: AppTheme.titleMedium.copyWith(color: AppTheme.infoBlue),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceM),
                    _buildInstructionItem("• Police Officer: Requires a police station"),
                    _buildInstructionItem("• Station Admin: Requires a police station"),
                    _buildInstructionItem("• Agency Representative: Does not require a specific station"),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceXL),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceS),
      child: Text(
        text,
        style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}