import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/graphql_service.dart';
import '../utils/graphql_query.dart';
import '../theme/app_theme.dart';

class ReportIncidentScreen extends StatefulWidget {
  final Map<String, dynamic> selectedStation;
  final Position userPosition;

  const ReportIncidentScreen({
    Key? key,
    required this.selectedStation,
    required this.userPosition,
  }) : super(key: key);

  @override
  _ReportIncidentScreenState createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  // Selected values
  String? _selectedIncidentType;
  bool _isLiveCallRequested = false;
  bool _isSubmitting = false;

  // 🔥 NEW: Location & Officer state
  bool _isLoadingLocation = true;
  String? _detectedLocation;
  Map<String, dynamic>? _currentOfficer;
  bool _isLoadingOfficer = false;
  String? _assignedOfficerUid;

  // Incident types
  final List<Map<String, dynamic>> _incidentTypes = [
    {'value': 'THEFT', 'label': 'Theft (Wizi)', 'icon': Icons.shopping_bag_outlined},
    {'value': 'ASSAULT', 'label': 'Assault (Shambulio)', 'icon': Icons.warning_rounded},
    {'value': 'ROBBERY', 'label': 'Robbery (Unyang\'anyi)', 'icon': Icons.dangerous_rounded},
    {'value': 'ACCIDENT', 'label': 'Accident (Ajali)', 'icon': Icons.car_crash_rounded},
    {'value': 'FIRE', 'label': 'Fire (Moto)', 'icon': Icons.local_fire_department_rounded},
    {'value': 'DOMESTIC_VIOLENCE', 'label': 'Domestic Violence', 'icon': Icons.home_outlined},
    {'value': 'FRAUD', 'label': 'Fraud (Udanganyifu)', 'icon': Icons.account_balance_outlined},
    {'value': 'MISSING_PERSON', 'label': 'Missing Person', 'icon': Icons.person_search_rounded},
    {'value': 'OTHER', 'label': 'Other (Nyingine)', 'icon': Icons.more_horiz_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _detectLocation();
    _loadCurrentOfficer();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // ============================================================================
  // 🔥 AUTO-DETECT LOCATION
  // ============================================================================

  Future<void> _detectLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final latitude = widget.userPosition.latitude;
      final longitude = widget.userPosition.longitude;

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];

        // Build readable address
        List<String> addressParts = [];

        if (place.street?.isNotEmpty == true) {
          addressParts.add(place.street!);
        }
        if (place.subLocality?.isNotEmpty == true) {
          addressParts.add(place.subLocality!);
        }
        if (place.locality?.isNotEmpty == true) {
          addressParts.add(place.locality!);
        }
        if (place.administrativeArea?.isNotEmpty == true) {
          addressParts.add(place.administrativeArea!);
        }

        final detectedAddress = addressParts.isNotEmpty
            ? addressParts.join(', ')
            : 'Current Location';

        setState(() {
          _detectedLocation = detectedAddress;
          _locationController.text = detectedAddress;
        });

        print('✅ Location detected: $detectedAddress');
      }
    } catch (e) {
      print('❌ Failed to detect location: $e');
      setState(() {
        _detectedLocation = 'Location detection failed';
        _locationController.text = 'Please enter location manually';
      });
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  // ============================================================================
  // 🔥 LOAD CURRENT OFFICER ON DUTY
  // ============================================================================

  Future<void> _loadCurrentOfficer() async {
    setState(() => _isLoadingOfficer = true);

    try {
      final gql = GraphQLService();
      final response = await gql.sendAuthenticatedQuery(
        getCurrentOfficerOnDutyQuery,
        {'stationUid': widget.selectedStation['uid']},
      );

      if (response.containsKey('errors')) {
        print('⚠️ No officer on duty currently');
        setState(() => _isLoadingOfficer = false);
        return;
      }

      final result = response['data']?['getCurrentOfficerOnDuty'];
      if (result['status'] == 'Success') {
        setState(() {
          _currentOfficer = result['data'];
          final officerData = result['data']['officer'];
          _assignedOfficerUid = officerData['uid'];  // Set UID hapa
        });
        print('✅ Officer on duty: ${_currentOfficer!['officer']['userAccount']['name']}');
        print('🔑 Officer UID: $_assignedOfficerUid');  // Debug log
      }
    } catch (e) {
      print('❌ Error loading officer: $e');
    } finally {
      setState(() => _isLoadingOfficer = false);
    }
  }

  // ============================================================================
  // BUILD METHOD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildStationInfo(),
            if (_currentOfficer != null) _buildOfficerInfoCard(),
            _buildLocationCard(),
            _buildReportForm(),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // APP BAR
  // ============================================================================

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Color(0xFF1A1F36)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Report Incident',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1F36),
        ),
      ),
    );
  }

  // ============================================================================
  // STATION INFO CARD
  // ============================================================================

  Widget _buildStationInfo() {
    return Container(
      margin: EdgeInsets.all(20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF2E5BFF).withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.local_police_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reporting to:',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  widget.selectedStation['name'] ?? 'Police Station',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.successGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  'Selected',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 🔥 OFFICER INFO CARD
  // ============================================================================

  Widget _buildOfficerInfoCard() {
    if (_isLoadingOfficer) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: 20),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Loading officer info...',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Color(0xFF8F9BB3),
              ),
            ),
          ],
        ),
      );
    }

    if (_currentOfficer == null) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: 20),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Color(0xFFFFE69C)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFF856404), size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No officer currently on duty at this station',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Color(0xFF856404),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final officer = _currentOfficer!['officer'];
    final user = officer['userAccount'];
    final rank = officer['code'] ?? '';
    final badge = officer['badgeNumber'] ?? '';

    return Container(
      margin: EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.successGreen, AppTheme.successGreen.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.successGreen.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Officer on Duty',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    Text(
                      user['name'],
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'ON DUTY',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _buildOfficerDetail(Icons.military_tech_rounded, rank),
                SizedBox(width: 16),
                _buildOfficerDetail(Icons.badge_rounded, badge),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficerDetail(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white),
        SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // 🔥 LOCATION CARD (Auto-detected)
  // ============================================================================

  Widget _buildLocationCard() {
    return Container(
      margin: EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFE4E9F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF2E5BFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.my_location_rounded,
                  color: Color(0xFF2E5BFF),
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detected Location',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1F36),
                      ),
                    ),
                    if (_isLoadingLocation)
                      Text(
                        'Detecting your location...',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Color(0xFF8F9BB3),
                        ),
                      )
                    else
                      Text(
                        _detectedLocation ?? 'Unknown',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Color(0xFF8F9BB3),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (_isLoadingLocation)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 12,
                        color: AppTheme.successGreen,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Auto',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.successGreen,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(0xFFF8F9FC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.gps_fixed_rounded, size: 14, color: Color(0xFF8F9BB3)),
                SizedBox(width: 8),
                Text(
                  'Lat: ${widget.userPosition.latitude.toStringAsFixed(6)}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Color(0xFF8F9BB3),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Lng: ${widget.userPosition.longitude.toStringAsFixed(6)}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Color(0xFF8F9BB3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // REPORT FORM
  // ============================================================================

  Widget _buildReportForm() {
    return Container(
      margin: EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Incident Details',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1F36),
              ),
            ),
            SizedBox(height: 20),

            // Incident Type Dropdown
            _buildIncidentTypeSelector(),
            SizedBox(height: 16),

            // Title Field
            _buildTextField(
              controller: _titleController,
              label: 'Title',
              hint: 'Brief title of the incident',
              icon: Icons.title_rounded,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            // Description Field
            _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Describe what happened...',
              icon: Icons.description_outlined,
              maxLines: 5,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Description is required';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            // 🔥 Location Field (Auto-filled, but editable)
            _buildTextField(
              controller: _locationController,
              label: 'Location',
              hint: 'Location details...',
              icon: Icons.location_on_outlined,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Location is required';
                }
                return null;
              },
            ),
            SizedBox(height: 8),
            Text(
              '💡 Location auto-detected. You can edit if needed.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Color(0xFF8F9BB3),
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: 16),

            // Live Call Toggle
            _buildLiveCallToggle(),
            SizedBox(height: 24),

            // Submit Button
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // FORM FIELDS
  // ============================================================================

  Widget _buildIncidentTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Incident Type *',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1F36),
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Color(0xFFF8F9FC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFFE4E9F2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedIncidentType,
              hint: Text(
                'Select incident type',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Color(0xFF8F9BB3),
                ),
              ),
              items: _incidentTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type['value'],
                  child: Row(
                    children: [
                      Icon(type['icon'], size: 20, color: Color(0xFF2E5BFF)),
                      SizedBox(width: 12),
                      Text(
                        type['label'],
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Color(0xFF1A1F36),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedIncidentType = value;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label *',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1F36),
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Color(0xFF2E5BFF)),
            filled: true,
            fillColor: Color(0xFFF8F9FC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFE4E9F2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFE4E9F2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFF2E5BFF), width: 2),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildLiveCallToggle() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE4E9F2)),
      ),
      child: Row(
        children: [
          Icon(Icons.phone_in_talk_rounded, color: Color(0xFF2E5BFF)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Request Live Call',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1F36),
                  ),
                ),
                Text(
                  'Get immediate phone assistance',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Color(0xFF8F9BB3),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isLiveCallRequested,
            onChanged: (value) {
              setState(() {
                _isLiveCallRequested = value;
              });
            },
            activeColor: AppTheme.successGreen,
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // SUBMIT BUTTON
  // ============================================================================

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitIncident,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF2E5BFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isSubmitting
            ? SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Colors.white),
          ),
        )
            : Text(
          'Submit Report',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // SUBMIT INCIDENT
  // ============================================================================

  Future<void> _submitIncident() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedIncidentType == null) {
      _showSnackBar('Please select incident type', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final gql = GraphQLService();
      final response = await gql.sendAuthenticatedQuery(
        createIncidentMutation,
        {
          'incidentDto': {
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'type': _selectedIncidentType,
            'location': _locationController.text.trim(),
            'latitude': widget.userPosition.latitude,
            'longitude': widget.userPosition.longitude,
            'liveCallRequested': _isLiveCallRequested,
            'assignedOfficerUid': _assignedOfficerUid,
            'assignedStationUid': widget.selectedStation['uid'],
          },
        },
      );

      if (response.containsKey('errors')) {
        _showSnackBar('Failed to submit report', isError: true);
        return;
      }

      final result = response['data']?['createIncident'];
      if (result['status'] == 'Success') {
        _showSuccessDialog();
      } else {
        _showSnackBar(result['message'] ?? 'Failed to submit', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // ============================================================================
  // UI HELPERS
  // ============================================================================

  void _showSuccessDialog() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.successGreen,
                    size: 50,
                  ),
                ),
                SizedBox(height:12),
                    Text(
                      'Report Submitted!',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1F36),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Your incident has been reported successfully. The police station will respond soon.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Color(0xFF8F9BB3),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close dialog
                          Navigator.pop(context); // Go back to dashboard
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Done',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}