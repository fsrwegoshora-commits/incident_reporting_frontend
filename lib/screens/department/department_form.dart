import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:incident_reporting_frontend/services/graphql_service.dart';
import 'package:incident_reporting_frontend/utils/graphql_query.dart';

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

class _DepartmentFormState extends State<DepartmentForm>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final GraphQLService _gql = GraphQLService();

  bool _isLoading = false;
  bool _isInitialized = false;
  String? _uid;
  String? _selectedDeptType;
  String? _selectedAgencyUid;
  String? _selectedAgencyDisplay;

  List<Map<String, dynamic>> _agencies = [];
  List<Map<String, dynamic>> _filteredAgencies = [];
  bool _agenciesLoading = false;

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // ✅ FIXED: Updated to match backend enum values
  final List<String> _departmentTypes = [
    'GENERAL_POLICE',
    'TRAFFIC_POLICE',
    'FIRE',
    'MEDICAL',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeForm();
    _loadAgencies();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
  }

  void _initializeForm() {
    if (widget.existingDepartment != null) {
      _uid = widget.existingDepartment!['uid'];
      _nameController.text = widget.existingDepartment!['name'] ?? '';
      _selectedDeptType = widget.existingDepartment!['type'];
      final agencyData = widget.existingDepartment!['agency'];
      if (agencyData != null) {
        _selectedAgencyUid = agencyData['uid'];
        _selectedAgencyDisplay = agencyData['name'];
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _slideController.forward();
        _fadeController.forward();
      }
    });
  }

  Future<void> _loadAgencies() async {
    setState(() => _agenciesLoading = true);

    try {
      final variables = {
        "pageableParam": {
          "page": 0,
          "size": 100,
        }
      };

      final response = await _gql.sendAuthenticatedQuery(getAgenciesQuery, variables);

      if (response['data'] != null && response['data']['getAgencies'] != null) {
        final data = response['data']['getAgencies'];
        if (data['data'] != null) {
          setState(() {
            _agencies = List<Map<String, dynamic>>.from(data['data']);
            _filteredAgencies = _agencies;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showModernSnackBar('Error loading agencies: $e', isSuccess: false);
      }
    } finally {
      if (mounted) {
        setState(() => _agenciesLoading = false);
      }
    }
  }

  void _filterAgencies(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredAgencies = _agencies;
      } else {
        _filteredAgencies = _agencies
            .where((agency) =>
        agency['name']?.toString().toLowerCase().contains(query.toLowerCase()) ?? false)
            .toList();
      }
    });
  }

  // ✅ Helper method to convert enum to display name
  String _getTypeDisplayName(String type) {
    switch (type) {
      case 'GENERAL_POLICE':
        return 'General Police';
      case 'TRAFFIC_POLICE':
        return 'Traffic Police';
      case 'FIRE':
        return 'Fire Department';
      case 'MEDICAL':
        return 'Medical';
      default:
        return type;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _saveDepartment() async {
    if (!mounted) return;

    if (_formKey.currentState!.validate()) {
      if (_selectedDeptType == null) {
        _showModernSnackBar('Please select a department type', isSuccess: false);
        return;
      }
      if (_selectedAgencyUid == null) {
        _showModernSnackBar('Please select an agency', isSuccess: false);
        return;
      }

      setState(() => _isLoading = true);

      try {
        final deptDto = {
          if (_uid != null) 'uid': _uid,
          'name': _nameController.text.trim(),
          'type': _selectedDeptType,
          'agencyUid': _selectedAgencyUid,
        };

        final response = await _gql.sendAuthenticatedMutation(
          saveDepartmentMutation,
          {'departmentDto': deptDto},
        );

        if (!mounted) return;
        final result = response['data']?['saveDepartment'];
        final message = result?['message'] ?? 'Operation failed';
        final status = result?['status']?.toString().toLowerCase();
        final isSuccess = status == "success" || status == "true";

        _showModernSnackBar(message, isSuccess: isSuccess);

          if (isSuccess) {
            await Future.delayed(const Duration(milliseconds: 500));
            Navigator.pop(context, true);
          }

      } catch (e) {
        if (mounted) {
          _showModernSnackBar('Error saving department: $e', isSuccess: false);
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _showModernSnackBar(String message, {required bool isSuccess}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isSuccess
                  ? [Color(0xFF10B981), Color(0xFF059669)]
                  : [Color(0xFFEF4444), Color(0xFFDC2626)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextFormField(
              controller: controller,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1A1A1A),
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey.shade400,
                  fontSize: 16,
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              validator: validator,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade100, Colors.yellow.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.category_rounded,
                    color: Colors.orange.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Department Type',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedDeptType != null
                          ? _getTypeDisplayName(_selectedDeptType!)
                          : 'Select a type',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 150,
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(12),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: _departmentTypes.map((type) {
                final isSelected = _selectedDeptType == type;
                return _buildTypeCard(type, isSelected);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCard(String type, bool isSelected) {
    // ✅ FIXED: Updated colors and icons for new department types
    Color getTypeColor() {
      switch (type) {
        case 'GENERAL_POLICE':
          return Colors.blue[700] ?? Colors.blue;
        case 'TRAFFIC_POLICE':
          return Colors.orange[700] ?? Colors.orange;
        case 'FIRE':
          return Colors.red[700] ?? Colors.red;
        case 'MEDICAL':
          return Colors.green[700] ?? Colors.green;
        default:
          return Colors.grey[700] ?? Colors.grey;
      }
    }

    // ✅ FIXED: Updated icons for new department types
    IconData getTypeIcon() {
      switch (type) {
        case 'GENERAL_POLICE':
          return Icons.security_rounded;
        case 'TRAFFIC_POLICE':
          return Icons.traffic_rounded;
        case 'FIRE':
          return Icons.local_fire_department_rounded;
        case 'MEDICAL':
          return Icons.local_hospital_rounded;
        default:
          return Icons.category_rounded;
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected ? getTypeColor().withOpacity(0.1) : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: getTypeColor().withOpacity(isSelected ? 0.5 : 0.1),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: getTypeColor().withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _selectedDeptType = type;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: getTypeColor().withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    getTypeIcon(),
                    color: getTypeColor(),
                    size: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getTypeDisplayName(type),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: const Color(0xFF1A1A1A),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAgencySelection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedAgencyDisplay != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade100, Colors.blue.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.business_rounded,
                      color: Colors.teal.shade600,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected Agency',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedAgencyDisplay!,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A1A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedAgencyUid = null;
                        _selectedAgencyDisplay = null;
                        _searchController.clear();
                        _filteredAgencies = _agencies;
                      });
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _filterAgencies,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF1A1A1A),
              ),
              decoration: InputDecoration(
                hintText: 'Search agency...',
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100.withOpacity(0.5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 250,
            child: _agenciesLoading
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    'Loading agencies...',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
                : _filteredAgencies.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.business_center_outlined,
                    size: 48,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No agencies found',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _filteredAgencies.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Colors.grey.shade200,
              ),
              itemBuilder: (context, index) {
                final agency = _filteredAgencies[index];
                final isSelected = _selectedAgencyUid == agency['uid'];

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.blue.shade50.withOpacity(0.8)
                        : Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: Colors.blue.shade200.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        if (mounted) {
                          setState(() {
                            _selectedAgencyUid = agency['uid'];
                            _selectedAgencyDisplay = agency['name'];
                            _searchController.clear();
                            _filteredAgencies = _agencies;
                          });
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.business_rounded,
                                color: Colors.blue.shade600,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    agency['name'] ?? 'Unknown',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: const Color(0xFF1A1A1A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    agency['code'] ?? '',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  color: Colors.blue.shade600,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernButton({
    required String text,
    required VoidCallback onPressed,
    required IconData icon,
    required List<Color> gradientColors,
    bool isLoading = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isLoading ? null : onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Processing...',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    text,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading...',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade800, Colors.teal.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.existingDepartment != null
                              ? 'Edit Department'
                              : 'Register Department',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 56),
                    child: Text(
                      'Fill in the details below',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Form Content
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildModernTextField(
                            controller: _nameController,
                            label: 'Department Name',
                            hint: 'Enter department name',
                            icon: Icons.domain_rounded,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Department name is required';
                              }
                              if (value.trim().length < 3) {
                                return 'Department name must be at least 3 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Department Type',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select the type of department',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildTypeSelection(),
                          const SizedBox(height: 24),
                          Text(
                            'Select Agency',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Choose which agency this department belongs to',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildAgencySelection(),
                          const SizedBox(height: 24),
                          _buildModernButton(
                            text: widget.existingDepartment != null
                                ? 'Update Department'
                                : 'Register Department',
                            icon: widget.existingDepartment != null
                                ? Icons.edit_rounded
                                : Icons.save_rounded,
                            gradientColors: [Color(0xFF10B981), Color(0xFF059669)],  // Kijani
                            onPressed: _saveDepartment,
                            isLoading: _isLoading,
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
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