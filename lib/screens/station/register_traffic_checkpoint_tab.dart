import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import '../../services/graphql_service.dart';
import '../../utils/graphql_query.dart';
import '../../theme/app_theme.dart';

class RegisterTrafficCheckpointTab extends StatefulWidget {
  final Map<String, dynamic>? existingCheckpoint;
  final String? preSelectedStationUid;
  final VoidCallback? onSubmit;

  const RegisterTrafficCheckpointTab({
    super.key,
    this.existingCheckpoint,
    this.preSelectedStationUid,
    this.onSubmit,
  });

  @override
  _RegisterTrafficCheckpointTabState createState() => _RegisterTrafficCheckpointTabState();
}

class _RegisterTrafficCheckpointTabState extends State<RegisterTrafficCheckpointTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _coverageRadiusController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _addressController = TextEditingController();
  final _locationSearchController = TextEditingController();

  String? _selectedSupervisorUid;
  String? _selectedStationUid;
  String? _selectedDepartmentUid;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isAssigningSupervisor = false;
  bool _isSearchingLocation = false;
  bool _isSearchingLocations = false;
  bool _isLoadingSupervisors = false;

  List<Map<String, dynamic>> _policeOfficers = [];
  List<Map<String, dynamic>> _policeStations = [];
  List<Map<String, dynamic>> _departments = [];
  List<Location> _locationSuggestions = [];

  double? _latitude;
  double? _longitude;
  String? _locationSource;
  String? _savedCheckpointUid;

  Timer? _locationSearchDebounce;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _requestLocationPermission();
    if (widget.existingCheckpoint != null) {
      _initializeExistingData();
    } else if (widget.preSelectedStationUid != null) {
      _selectedStationUid = widget.preSelectedStationUid;
      // ✅ FIX: Use null coalescing to handle String?
      _fetchPoliceOfficersByStation(widget.preSelectedStationUid ?? '');
    }
  }

  Future<void> _requestLocationPermission() async {
    bool locationService = await Geolocator.isLocationServiceEnabled();
    if (!locationService) {
      _showErrorSnackBar('Please enable location services');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        _showErrorSnackBar('Location permissions are permanently denied');
      }
    }
  }

  void _initializeExistingData() {
    final checkpoint = widget.existingCheckpoint!;
    _nameController.text = checkpoint['name'] ?? '';
    _contactPhoneController.text = checkpoint['contactPhone'] ?? '';
    _coverageRadiusController.text = (checkpoint['coverageRadiusKm'] ?? '').toString();
    _latitudeController.text = (checkpoint['location']?['latitude'] ?? '').toString();
    _longitudeController.text = (checkpoint['location']?['longitude'] ?? '').toString();
    _addressController.text = checkpoint['location']?['address'] ?? '';
    _selectedSupervisorUid = checkpoint['supervisingOfficer']?['uid']?.toString();
    _selectedStationUid = checkpoint['parentStation']?['uid']?.toString();
    _selectedDepartmentUid = checkpoint['department']?['uid']?.toString();
    _isActive = checkpoint['active'] ?? true;
    _savedCheckpointUid = checkpoint['uid']?.toString();

    _latitude = checkpoint['location']?['latitude']?.toDouble();
    _longitude = checkpoint['location']?['longitude']?.toDouble();
    _locationSource = "existing";

    // ✅ Fetch supervisors from existing station
    if (_selectedStationUid != null) {
      _fetchPoliceOfficersByStation(_selectedStationUid!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactPhoneController.dispose();
    _coverageRadiusController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _addressController.dispose();
    _locationSearchController.dispose();
    _locationSearchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchPoliceStations(),
        _fetchDepartments(),
      ]);
    } catch (e) {
      _showErrorSnackBar("Error loading data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ NEW: Fetch supervisors from specific station
  Future<void> _fetchPoliceOfficersByStation(String stationUid) async {
    if (stationUid.isEmpty) return;

    setState(() => _isLoadingSupervisors = true);
    final gql = GraphQLService();
    try {
      final response = await gql.sendAuthenticatedQuery(getPoliceOfficersByStationQuery, {
        "pageableParam": {
          "page": 0,
          "size": 100,
          "sortBy": "userAccount.name",
          "sortDirection": "ASC",
        },
        "policeStationUid": stationUid,
      });

      print("📥 Officers by station response: $response");

      final data = response['data']?['getPoliceOfficersByStation'] ?? {};
      setState(() {
        _policeOfficers = List<Map<String, dynamic>>.from(data['data'] ?? []);

        // ✅ Auto-select first supervisor if available
        if (_selectedSupervisorUid == null && _policeOfficers.isNotEmpty && widget.existingCheckpoint == null) {
          _selectedSupervisorUid = _policeOfficers.first['uid']?.toString();
        }

        print("✅ Loaded ${_policeOfficers.length} supervisors from station");
      });
    } catch (e) {
      print("❌ Error fetching officers by station: $e");
      _showErrorSnackBar("Error loading supervisors: $e");
    } finally {
      setState(() => _isLoadingSupervisors = false);
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
        if (_selectedStationUid == null && _policeStations.isNotEmpty && widget.existingCheckpoint == null && widget.preSelectedStationUid == null) {
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
        // ✅ Filter for TRAFFIC departments only
        _departments = List<Map<String, dynamic>>.from(data['data'] ?? [])
            .where((dept) {
          final type = dept['type']?.toString().toUpperCase() ?? '';
          return type.contains('TRAFFIC');
        })
            .toList();

        if (_selectedDepartmentUid == null && _departments.isNotEmpty && widget.existingCheckpoint == null) {
          _selectedDepartmentUid = _departments.first['uid']?.toString();
        }
      });
    } catch (e) {
      print("Error fetching departments: $e");
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isSearchingLocation = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _latitude = position.latitude;
      _longitude = position.longitude;
      _locationSource = "current";

      _latitudeController.text = _latitude!.toStringAsFixed(6);
      _longitudeController.text = _longitude!.toStringAsFixed(6);

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        _addressController.text = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
        ].where((e) => e != null && e.isNotEmpty).join(', ');
      }

      if (mounted) {
        setState(() {});
        _showSuccessSnackBar('Current location fetched successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error getting location: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSearchingLocation = false);
      }
    }
  }

  void _showLocationPickerDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade600, Colors.blue.shade400],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_searching, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Choose Location Method',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildLocationOption(
                icon: Icons.gps_fixed,
                title: 'Current Location',
                subtitle: 'Use your device\'s GPS',
                colors: [Colors.blue.shade600, Colors.blue.shade400],
                onTap: () {
                  Navigator.pop(context);
                  _getCurrentLocation();
                },
              ),
              const SizedBox(height: 12),
              _buildLocationOption(
                icon: Icons.search,
                title: 'Search Location',
                subtitle: 'Search by name (e.g., Dar es Salaam)',
                colors: [Colors.green.shade600, Colors.green.shade400],
                onTap: () {
                  Navigator.pop(context);
                  _showSearchLocationDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSearchLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade50, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green.shade600, Colors.green.shade400],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.search, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Search Location',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Enter location name to search',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _locationSearchController,
                    style: GoogleFonts.poppins(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'e.g., Kariakoo, Dar es Salaam',
                      hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                      prefixIcon: const Icon(Icons.location_on),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      if (_locationSearchDebounce?.isActive ?? false) {
                        _locationSearchDebounce!.cancel();
                      }
                      _locationSearchDebounce = Timer(const Duration(milliseconds: 800), () {
                        if (value.isNotEmpty) {
                          _performLocationSearch(value, setDialogState);
                        } else {
                          setDialogState(() {
                            _locationSuggestions = [];
                          });
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_isSearchingLocations)
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Searching locations...'),
                        ],
                      ),
                    )
                  else if (_locationSuggestions.isNotEmpty)
                    Expanded(
                      child: ListView.separated(
                        itemCount: _locationSuggestions.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          return _buildLocationSuggestionItem(_locationSuggestions[index], setDialogState);
                        },
                      ),
                    )
                  else if (_locationSearchController.text.isNotEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.location_off, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text('No locations found', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text('Search for locations', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocationSuggestionItem(Location location, StateSetter setDialogState) {
    return FutureBuilder<List<Placemark>>(
      future: placemarkFromCoordinates(location.latitude, location.longitude),
      builder: (context, snapshot) {
        final address = snapshot.hasData && snapshot.data!.isNotEmpty
            ? _formatPlacemark(snapshot.data!.first)
            : 'Lat: ${location.latitude.toStringAsFixed(4)}, Long: ${location.longitude.toStringAsFixed(4)}';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              Navigator.pop(context);
              await _selectLocationFromSuggestion(location);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.location_on, color: Colors.green.shade600, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_locationSearchController.text,
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                        const SizedBox(height: 4),
                        Text(address,
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('Lat: ${location.latitude.toStringAsFixed(6)}, Long: ${location.longitude.toStringAsFixed(6)}',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatPlacemark(Placemark placemark) {
    return [
      placemark.street,
      placemark.subLocality,
      placemark.locality,
      placemark.administrativeArea,
      placemark.country
    ].where((e) => e != null && e.isNotEmpty).join(', ');
  }

  Future<void> _selectLocationFromSuggestion(Location location) async {
    setState(() => _isSearchingLocation = true);
    try {
      _latitude = location.latitude;
      _longitude = location.longitude;
      _locationSource = "search";

      _latitudeController.text = _latitude!.toStringAsFixed(6);
      _longitudeController.text = _longitude!.toStringAsFixed(6);

      List<Placemark> placemarks = await placemarkFromCoordinates(location.latitude, location.longitude);

      if (placemarks.isNotEmpty) {
        _addressController.text = _formatPlacemark(placemarks[0]);
      } else {
        _addressController.text = 'Lat: ${location.latitude.toStringAsFixed(6)}, Long: ${location.longitude.toStringAsFixed(6)}';
      }

      if (mounted) {
        setState(() {});
        _showSuccessSnackBar('Location selected successfully');
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Error setting location: $e');
    } finally {
      if (mounted) setState(() => _isSearchingLocation = false);
    }
  }

  Future<void> _performLocationSearch(String query, StateSetter setDialogState) async {
    if (query.isEmpty) {
      setDialogState(() => _locationSuggestions = []);
      return;
    }

    setDialogState(() {
      _isSearchingLocations = true;
      _locationSuggestions = [];
    });

    try {
      List<Location> locations = await locationFromAddress(query);
      setDialogState(() {
        _locationSuggestions = locations;
        _isSearchingLocations = false;
      });
    } catch (e) {
      setDialogState(() {
        _locationSuggestions = [];
        _isSearchingLocations = false;
      });
      if (mounted) _showErrorSnackBar('Error searching locations: $e');
    }
  }

  Widget _buildLocationOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationInfoCard() {
    if (_latitude == null || _longitude == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.shade100, shape: BoxShape.circle),
                child: Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Location Set Successfully',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lat: ${_latitude!.toStringAsFixed(6)}, Long: ${_longitude!.toStringAsFixed(6)}',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade800)),
                const SizedBox(height: 4),
                Text('Source: ${_locationSource ?? 'Manual'}',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ CRITICAL FIX: stationUid + supervisor assignment
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_latitude == null || _longitude == null) {
      _showErrorSnackBar('Please set location first');
      return;
    }

    if (_selectedDepartmentUid == null) {
      _showErrorSnackBar('Please select a TRAFFIC department');
      return;
    }

    if (_selectedStationUid == null) {
      _showErrorSnackBar('Please select a police station');
      return;
    }

    setState(() => _isLoading = true);
    final gql = GraphQLService();

    try {
      final dto = {
        "trafficCheckPointDto": {
          if (widget.existingCheckpoint != null) "uid": widget.existingCheckpoint!['uid'],
          "name": _nameController.text.trim(),
          "contactInfo": _contactPhoneController.text.trim(),
          "coverageRadiusKm": double.tryParse(_coverageRadiusController.text) ?? 0.0,
          "policeStationUid": _selectedStationUid,
          "departmentUid": _selectedDepartmentUid,
          "active": _isActive,
          "location": {
            "latitude": double.tryParse(_latitudeController.text) ?? 0.0,
            "longitude": double.tryParse(_longitudeController.text) ?? 0.0,
            "address": _addressController.text.trim(),
          }
        }
      };

      print("📡 Saving checkpoint with stationUid: $dto");

      final response = await gql.sendAuthenticatedMutation(saveTrafficCheckpointMutation, dto);

      print("📥 Backend response: $response");

      final result = response['data']?['saveTrafficCheckpoint'];

      if (!mounted) return;

      final isSuccess = result?['status'] == 'Success' || result?['status'] == true;
      final message = result?['message'] ?? (isSuccess ? "Checkpoint saved successfully" : "Failed to save");

      if (!isSuccess) {
        _showErrorSnackBar(message);
        setState(() => _isLoading = false);
        return;
      }

      // ✅ Get saved checkpoint UID
      _savedCheckpointUid = result?['data']?['uid']?.toString();

      // ✅ Step 2: Assign supervisor if selected & not editing
      if (_selectedSupervisorUid != null && _savedCheckpointUid != null && widget.existingCheckpoint == null) {
        setState(() => _isAssigningSupervisor = true);

        final assignResponse = await gql.sendAuthenticatedMutation(
          assignSupervisorMutation,
          {
            "checkpointUid": _savedCheckpointUid,
            "officerUid": _selectedSupervisorUid,
          },
        );

        print("📥 Supervisor assignment response: $assignResponse");

        final assignResult = assignResponse['data']?['assignSupervisor'];
        final assignSuccess = assignResult?['status'] == 'Success' || assignResult?['status'] == true;

        if (assignSuccess) {
          _showSuccessSnackBar('Checkpoint created & supervisor assigned! ✅');
        } else {
          _showSuccessSnackBar('Checkpoint saved (supervisor assignment pending)');
        }
      } else if (widget.existingCheckpoint != null && _selectedSupervisorUid != null) {
        // ✅ Step 2B: For editing - change supervisor
        setState(() => _isAssigningSupervisor = true);

        final changeResponse = await gql.sendAuthenticatedMutation(
          changeSupervisorMutation,
          {
            "checkpointUid": _savedCheckpointUid ?? widget.existingCheckpoint!['uid'],
            "newOfficerUid": _selectedSupervisorUid,
          },
        );

        print("📥 Supervisor change response: $changeResponse");

        final changeResult = changeResponse['data']?['changeSupervisor'];
        final changeSuccess = changeResult?['status'] == 'Success' || changeResult?['status'] == true;

        if (changeSuccess) {
          _showSuccessSnackBar('Checkpoint updated & supervisor changed! ✅');
        } else {
          _showSuccessSnackBar('Checkpoint updated');
        }
      } else {
        _showSuccessSnackBar(message);
      }

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        if (widget.onSubmit != null) {
          widget.onSubmit!();
        }
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print("❌ Error: $e");
      if (mounted) {
        _showErrorSnackBar("Error saving checkpoint: $e");
        setState(() => _isLoading = false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAssigningSupervisor = false;
        });
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
                child: Icon(Icons.error, color: AppTheme.cardWhite, size: 20),
              ),
              const SizedBox(width: AppTheme.spaceM),
              Expanded(
                child: Text(message, style: AppTheme.bodyMedium.copyWith(color: AppTheme.cardWhite)),
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
                child: Icon(Icons.check_circle, color: AppTheme.cardWhite, size: 20),
              ),
              const SizedBox(width: AppTheme.spaceM),
              Expanded(
                child: Text(message, style: AppTheme.bodyMedium.copyWith(color: AppTheme.cardWhite)),
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

  bool get isEditing => widget.existingCheckpoint != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
      child: (_isLoading || _isAssigningSupervisor)
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: AppTheme.pillRadius,
              ),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isAssigningSupervisor ? 'Assigning supervisor...' : 'Saving checkpoint...',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
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
                      child: Icon(Icons.traffic, size: 40, color: AppTheme.primaryBlue),
                    ),
                    const SizedBox(height: AppTheme.spaceM),
                    Text(
                      isEditing ? "Edit Traffic Checkpoint" : "Register Traffic Checkpoint",
                      style: AppTheme.titleLarge,
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
                        labelText: "Checkpoint Name",
                        prefixIcon: Icons.location_on,
                      ),
                      validator: (value) => value!.isEmpty ? "Name required" : null,
                    ),
                    const SizedBox(height: AppTheme.spaceM),
                    TextFormField(
                      controller: _contactPhoneController,
                      style: AppTheme.bodyLarge,
                      decoration: AppTheme.getInputDecoration(
                        labelText: "Contact Phone",
                        prefixIcon: Icons.phone,
                      ),
                      validator: (value) => value!.isEmpty ? "Phone required" : null,
                    ),
                    const SizedBox(height: AppTheme.spaceM),
                    TextFormField(
                      controller: _coverageRadiusController,
                      style: AppTheme.bodyLarge,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: AppTheme.getInputDecoration(
                        labelText: "Coverage Radius (km)",
                        prefixIcon: Icons.radio,
                      ),
                      validator: (value) => value!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: AppTheme.spaceL),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Station Location", style: AppTheme.titleSmall),
                    ),
                    const SizedBox(height: AppTheme.spaceM),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceM),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple.shade600, Colors.purple.shade400],
                        ),
                        borderRadius: AppTheme.buttonRadius,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isSearchingLocation ? null : _showLocationPickerDialog,
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isSearchingLocation) ...[
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text('Searching...', style: AppTheme.buttonTextMedium),
                                ] else ...[
                                  const Icon(Icons.add_location_alt, color: Colors.white),
                                  const SizedBox(width: AppTheme.spaceS),
                                  Text('Set Location', style: AppTheme.buttonTextMedium),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceM),
                    _buildLocationInfoCard(),
                    const SizedBox(height: AppTheme.spaceM),
                    TextFormField(
                      controller: _latitudeController,
                      style: AppTheme.bodyLarge,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: AppTheme.getInputDecoration(
                        labelText: "Latitude",
                        prefixIcon: Icons.my_location,
                      ),
                      validator: (value) => value!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: AppTheme.spaceM),
                    TextFormField(
                      controller: _longitudeController,
                      style: AppTheme.bodyLarge,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: AppTheme.getInputDecoration(
                        labelText: "Longitude",
                        prefixIcon: Icons.my_location,
                      ),
                      validator: (value) => value!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: AppTheme.spaceM),
                    TextFormField(
                      controller: _addressController,
                      style: AppTheme.bodyLarge,
                      maxLines: 2,
                      decoration: AppTheme.getInputDecoration(
                        labelText: "Address",
                        prefixIcon: Icons.home,
                      ),
                      validator: (value) => value!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: AppTheme.spaceL),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Assignment Details", style: AppTheme.titleSmall),
                    ),
                    const SizedBox(height: AppTheme.spaceM),
                    widget.preSelectedStationUid != null
                        ? TextFormField(
                      initialValue: _policeStations
                          .firstWhere(
                            (s) => s['uid'] == widget.preSelectedStationUid,
                        orElse: () => {'name': 'Unknown'},
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
                          child: Text(station['name']?.toString() ?? 'Unknown', style: AppTheme.bodyLarge),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedStationUid = value);
                        // ✅ Fetch supervisors when station changes
                        if (value != null) {
                          _fetchPoliceOfficersByStation(value);
                        }
                      },
                      decoration: AppTheme.getInputDecoration(
                        labelText: "Police Station",
                        prefixIcon: Icons.local_police,
                      ),
                      validator: (value) => value == null ? "Required" : null,
                    ),
                    const SizedBox(height: AppTheme.spaceM),
                    // ✅ Supervisors dropdown - Loads from selected station
                    if (_isLoadingSupervisors)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.borderColor),
                          borderRadius: AppTheme.cardRadius,
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E5BFF)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Loading supervisors...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF8F9BB3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: _selectedSupervisorUid,
                        style: AppTheme.bodyLarge,
                        items: _policeOfficers.map((officer) {
                          return DropdownMenuItem<String>(
                            value: officer['uid']?.toString(),
                            child: Text(
                              '${officer['userAccount']?['name']?.toString() ?? 'Unknown'} (${officer['badgeNumber'] ?? 'N/A'})',
                              style: AppTheme.bodyLarge,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedSupervisorUid = value),
                        decoration: AppTheme.getInputDecoration(
                          labelText: "Supervising Officer",
                          prefixIcon: Icons.person,
                        ),
                      ),
                    const SizedBox(height: AppTheme.spaceM),
                    DropdownButtonFormField<String>(
                      value: _selectedDepartmentUid,
                      style: AppTheme.bodyLarge,
                      items: _departments.map((dept) {
                        return DropdownMenuItem<String>(
                          value: dept['uid']?.toString(),
                          child: Text(dept['name']?.toString() ?? 'Unknown', style: AppTheme.bodyLarge),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedDepartmentUid = value),
                      decoration: AppTheme.getInputDecoration(
                        labelText: "Department (TRAFFIC only)",
                        prefixIcon: Icons.domain,
                      ),
                      validator: (value) => value == null ? "Required" : null,
                    ),
                    const SizedBox(height: AppTheme.spaceM),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderColor),
                        borderRadius: AppTheme.cardRadius,
                      ),
                      child: CheckboxListTile(
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value ?? true),
                        title: Text("Active Checkpoint", style: AppTheme.bodyLarge),
                        controlAffinity: ListTileControlAffinity.leading,
                        shape: RoundedRectangleBorder(borderRadius: AppTheme.cardRadius),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceL),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spaceL),
                decoration: AppTheme.elevatedCardDecoration,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceM),
                      shape: RoundedRectangleBorder(borderRadius: AppTheme.buttonRadius),
                      elevation: 0,
                    ),
                    child: Container(
                      decoration: AppTheme.primaryButtonDecoration,
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceM),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.save, size: 24, color: Colors.white),
                          const SizedBox(width: AppTheme.spaceS),
                          Text(
                            isEditing ? "Update" : "Register",
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