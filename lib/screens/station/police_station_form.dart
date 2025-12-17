import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:incident_reporting_frontend/services/graphql_service.dart';
import 'package:incident_reporting_frontend/utils/graphql_query.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class PoliceStationForm extends StatefulWidget {
  final Map<String, dynamic>? existingPoliceStation;
  final VoidCallback onSubmit;

  const PoliceStationForm({
    super.key,
    this.existingPoliceStation,
    required this.onSubmit,
  });

  @override
  State<PoliceStationForm> createState() => _PoliceStationFormState();
}

class _PoliceStationFormState extends State<PoliceStationForm>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactInfoController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _locationSearchController = TextEditingController();
  final GraphQLService _gql = GraphQLService();

  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isSearchingLocation = false;
  String? _uid;
  List<Map<String, dynamic>> _administrativeAreas = [];
  List<Map<String, dynamic>> _filteredAreas = [];
  String? _selectedAreaUid;
  String? _selectedAreaDisplay;
  Timer? _debounce;

  // Location variables
  double? _latitude;
  double? _longitude;
  String? _locationSource; // "current", "search", or "manual"

  // Location search variables
  List<Location> _locationSuggestions = [];
  bool _isSearchingLocations = false;
  Timer? _locationSearchDebounce;

  // Caching variables
  List<Map<String, dynamic>> _cachedAreas = [];
  bool _hasCachedData = false;
  Map<String, Map<String, dynamic>> _uidToArea = {};

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeForm();
    _requestLocationPermission();
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

  Future<void> _requestLocationPermission() async {
    bool locationService = await Geolocator.isLocationServiceEnabled();
    if (!locationService) {
      _showModernSnackBar('Please enable location services', isSuccess: false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        _showModernSnackBar('Location permissions are permanently denied', isSuccess: false);
      }
    }
  }

  void _initializeForm() {
    if (widget.existingPoliceStation != null) {
      _uid = widget.existingPoliceStation!['uid'];
      _nameController.text = widget.existingPoliceStation!['name'] ?? '';
      _contactInfoController.text = widget.existingPoliceStation!['contactInfo'] ?? '';
      final location = widget.existingPoliceStation!['policeStationLocation'];
      if (location != null) {
        _selectedAreaUid = location['uid'] ?? location['id']?.toString();
        _selectedAreaDisplay = _getAreaDisplayInfo(location);
      }
      final existingLocation = widget.existingPoliceStation!['location'];
      if (existingLocation != null) {
        _latitude = existingLocation['latitude']?.toDouble();
        _longitude = existingLocation['longitude']?.toDouble();
        _addressController.text = existingLocation['address'] ?? '';
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _loadAdministrativeAreas();
        _slideController.forward();
        _fadeController.forward();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _locationSearchDebounce?.cancel();
    _nameController.dispose();
    _contactInfoController.dispose();
    _searchController.dispose();
    _addressController.dispose();
    _locationSearchController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
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
        _locationSearchController.text = '${place.locality ?? 'Current'}, ${place.administrativeArea ?? 'Location'}';
      }

      if (mounted) {
        setState(() {});
        _showModernSnackBar('Current location fetched: ${_addressController.text}', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        _showModernSnackBar('Error getting location: $e', isSuccess: false);
      }
    } finally {
      if (mounted) {
        setState(() => _isSearchingLocation = false);
      }
    }
  }

  Future<void> _selectLocationFromSuggestion(Location location) async {
    setState(() => _isSearchingLocation = true);
    try {
      _latitude = location.latitude;
      _longitude = location.longitude;
      _locationSource = "search";

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        _addressController.text = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.country
        ].where((e) => e != null && e.isNotEmpty).join(', ');
      } else {
        _addressController.text = 'Lat: ${location.latitude.toStringAsFixed(6)}, Long: ${location.longitude.toStringAsFixed(6)}';
      }

      if (mounted) {
        setState(() {});
        _showModernSnackBar('Location selected successfully', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        _showModernSnackBar('Error setting location: $e', isSuccess: false);
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
                      hintText: 'e.g., Mipango Hostel, Dodoma',
                      hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                      prefixIcon: const Icon(Icons.location_on),
                      suffixIcon: _locationSearchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          _performRealLocationSearch(_locationSearchController.text, setDialogState);
                        },
                      )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      if (_locationSearchDebounce?.isActive ?? false) {
                        _locationSearchDebounce!.cancel();
                      }
                      _locationSearchDebounce = Timer(const Duration(milliseconds: 800), () {
                        if (value.isNotEmpty) {
                          _performRealLocationSearch(value, setDialogState);
                        } else {
                          setDialogState(() {
                            _locationSuggestions = [];
                          });
                        }
                      });
                    },
                    onSubmitted: (value) {
                      _performRealLocationSearch(value, setDialogState);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Search Results Section
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Search Results (${_locationSuggestions.length})',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _locationSuggestions.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final location = _locationSuggestions[index];
                                return _buildRealLocationSuggestionItem(location, setDialogState);
                              },
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_locationSearchController.text.isNotEmpty)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_off,
                              size: 48,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No locations found',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try a different search term',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Search for locations',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Enter a location name above',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
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

  Widget _buildRealLocationSuggestionItem(Location location, StateSetter setDialogState) {
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
                    child: Icon(
                      Icons.location_on,
                      color: Colors.green.shade600,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _locationSearchController.text,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          address,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Lat: ${location.latitude.toStringAsFixed(6)}, Long: ${location.longitude.toStringAsFixed(6)}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
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

  Future<void> _performRealLocationSearch(String query, StateSetter setDialogState) async {
    if (query.isEmpty) {
      setDialogState(() {
        _locationSuggestions = [];
      });
      return;
    }

    setDialogState(() {
      _isSearchingLocations = true;
      _locationSuggestions = [];
    });

    try {
      // Use geocoding package to get real locations from Google
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

      if (mounted) {
        _showModernSnackBar('Error searching locations: $e', isSuccess: false);
      }
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
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
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
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

  // ... REST OF YOUR EXISTING METHODS REMAIN THE SAME ...
  // _loadAdministrativeAreas, _filterAreas, _getRegionAndDistrict, etc.

  Future<void> _loadAdministrativeAreas({String searchTerm = ''}) async {
    if (!mounted) return;

    if (_hasCachedData && _cachedAreas.isNotEmpty && searchTerm.isEmpty) {
      setState(() {
        _administrativeAreas = _cachedAreas;
        _filteredAreas = _cachedAreas;
        _uidToArea = {for (var area in _cachedAreas) area['uid'].toString(): area};
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _gql.sendAuthenticatedQuery(
        getAdministrativeAreasQuery,
        {
          'pageableParam': {
            'page': 0,
            'size': 50,
            if (searchTerm.isNotEmpty) 'searchParam': searchTerm,
          },
          'areaLevels': null,
        },
      );

      if (!mounted) return;

      if (response['data'] != null && response['data']['getAdministrativeAreas'] != null) {
        final data = response['data']['getAdministrativeAreas'];
        if (data['data'] != null) {
          setState(() {
            _administrativeAreas = List<Map<String, dynamic>>.from(data['data']);
            _filteredAreas = _administrativeAreas;
            if (searchTerm.isEmpty) {
              _cachedAreas = _administrativeAreas;
              _hasCachedData = true;
            }
            _uidToArea = {for (var area in _administrativeAreas) area['uid'].toString(): area};
          });
        } else {
          _showModernSnackBar('No administrative areas found', isSuccess: false);
        }
      }
    } catch (e) {
      if (mounted) {
        _showModernSnackBar('Error loading areas: $e', isSuccess: false);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ... CONTINUE WITH ALL YOUR OTHER EXISTING METHODS ...

  // The rest of your methods (_filterAreas, _getRegionAndDistrict, _getAreaLevel,
  // _getAreaDisplayInfo, _getLevelColor, _getLevelIcon, _savePoliceStation,
  // _showModernSnackBar, _buildModernTextField, _buildSearchField,
  // _buildLocationInfoCard, _buildAreaSelection, _buildModernButton, build)
  // remain exactly the same as in your previous code

  void _filterAreas(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _loadAdministrativeAreas(searchTerm: query);
      }
    });
  }

  Map<String, String> _getRegionAndDistrict(Map<String, dynamic> area) {
    String region = '';
    String district = '';
    String ward = '';

    final label = area['label']?.toString() ?? '';
    if (label.isNotEmpty) {
      final parts = label.split(', ').map((e) => e.trim()).toList();
      for (var part in parts) {
        if (part.toLowerCase().contains('region') || part.toLowerCase().contains('mkoa')) {
          region = part.replaceAll(RegExp(r' (Region|Mkoa)$', caseSensitive: false), '');
        } else if (part.toLowerCase().contains('district') || part.toLowerCase().contains('wilaya')) {
          district = part.replaceAll(RegExp(r' (District|Wilaya|District Council)$', caseSensitive: false), '');
        } else if (part.toLowerCase().contains('ward') || part.toLowerCase().contains('kata')) {
          ward = part.replaceAll(RegExp(r' (Ward|Kata)$', caseSensitive: false), '');
        }
      }
    }

    String? currentUid = area['uid']?.toString();
    Set<String> visited = {if (currentUid != null) currentUid};
    while (currentUid != null && (region.isEmpty || district.isEmpty || ward.isEmpty)) {
      final current = _uidToArea[currentUid];
      if (current == null) break;
      final level = _getAreaLevel(current).toLowerCase();
      final name = current['name'] ?? '';
      if (level == 'region' || level == 'mkoa') {
        region = name;
      } else if (level == 'district' || level == 'wilaya') {
        district = name;
      } else if (level == 'ward' || level == 'kata') {
        ward = name;
      }
      currentUid = current['parentAreaId']?.toString();
      if (currentUid != null) visited.add(currentUid);
    }

    return {
      'region': region,
      'district': district,
      'ward': ward,
    };
  }

  String _getAreaLevel(Map<String, dynamic> area) {
    if (area['areaType'] != null &&
        area['areaType']['areaLevel'] != null &&
        area['areaType']['areaLevel']['level'] != null) {
      return area['areaType']['areaLevel']['level']?.toString() ?? '';
    }
    if (area['areaType'] != null &&
        area['areaType']['areaLevel'] != null &&
        area['areaType']['areaLevel']['name'] != null) {
      return area['areaType']['areaLevel']['name']?.toString() ?? '';
    }
    if (area['areaType'] != null && area['areaType']['name'] != null) {
      return area['areaType']['name']?.toString() ?? '';
    }
    return '';
  }

  String _getAreaDisplayInfo(Map<String, dynamic> area) {
    final name = area['name'] ?? 'Unknown Area';
    final level = _getAreaLevel(area);
    final areaCode = area['areaCode'] ?? '';
    final lineage = _getRegionAndDistrict(area);
    final region = lineage['region'];
    final district = lineage['district'];
    final ward = lineage['ward'];

    String info = name;

    if (ward!.isNotEmpty && ward != name) {
      info += ' - $ward';
    }
    if (district!.isNotEmpty && district != name && district != ward) {
      info += ' - $district';
    }
    if (region!.isNotEmpty && region != name && region != district) {
      info += ' - $region';
    }

    if (level.isNotEmpty) {
      info += ' ($level)';
    }

    if (areaCode.isNotEmpty) {
      info += ' [$areaCode]';
    }

    return info;
  }

  Color _getLevelColor(String level) {
    final colors = {
      'Country': Colors.red.shade600,
      'Region': Colors.orange.shade600,
      'Mkoa': Colors.orange.shade600,
      'District': Colors.blue.shade600,
      'Wilaya': Colors.blue.shade600,
      'Division': Colors.green.shade600,
      'Ward': Colors.purple.shade600,
      'Kata': Colors.purple.shade600,
      'Street': Colors.pink.shade600,
      'Kitongoji': Colors.pink.shade600,
      'Council': Colors.teal.shade600,
      'Town': Colors.cyan.shade600,
      'Area': Colors.indigo.shade600,
      'Village': Colors.brown.shade600,
    };
    return colors[level] ?? Colors.grey.shade600;
  }

  IconData _getLevelIcon(String level) {
    final icons = {
      'Country': Icons.public_rounded,
      'Region': Icons.map_rounded,
      'Mkoa': Icons.map_rounded,
      'District': Icons.location_city_rounded,
      'Wilaya': Icons.location_city_rounded,
      'Division': Icons.account_balance_rounded,
      'Ward': Icons.house_rounded,
      'Kata': Icons.house_rounded,
      'Street': Icons.add_road_rounded,
      'Kitongoji': Icons.add_road_rounded,
      'Council': Icons.business_rounded,
      'Town': Icons.location_city_rounded,
      'Area': Icons.my_location_rounded,
      'Village': Icons.home_rounded,
    };
    return icons[level] ?? Icons.place_rounded;
  }

  Future<void> _savePoliceStation() async {
    if (!mounted) return;

    if (_formKey.currentState!.validate()) {
      if (_selectedAreaUid == null) {
        _showModernSnackBar('Please select an administrative area', isSuccess: false);
        return;
      }
      if (_latitude == null || _longitude == null) {
        _showModernSnackBar('Please set a valid location', isSuccess: false);
        return;
      }
      if (!_uidToArea.containsKey(_selectedAreaUid)) {
        _showModernSnackBar('Selected area is invalid. Please choose again.', isSuccess: false);
        return;
      }

      setState(() => _isLoading = true);

      try {
        final policeStationDto = {
          if (_uid != null) 'uid': _uid,
          'name': _nameController.text.trim(),
          'contactInfo': _contactInfoController.text.trim(),
          'administrativeAreaUid': _selectedAreaUid,
          'location': {
            'latitude': _latitude,
            'longitude': _longitude,
            'address': _addressController.text.trim(),
          },
        };

        final response = await _gql.sendAuthenticatedMutation(
          savePoliceStationMutation,
          {'policeStationDto': policeStationDto},
        );

        if (!mounted) return;

        final result = response['data']?['savePoliceStation'];
        final message = result?['message'] ?? 'Operation failed';
        final isSuccess = result?['status'] == 'Success';

        _showModernSnackBar(message, isSuccess: isSuccess);

        if (isSuccess) {
          widget.onSubmit();
        }
      } catch (e) {
        if (mounted) {
          _showModernSnackBar('Error saving station: $e', isSuccess: false);
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
                  ? [Colors.green.shade700, Colors.green.shade500]
                  : [Colors.red.shade700, Colors.red.shade500],
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

  // ... CONTINUE WITH ALL YOUR REMAINING WIDGET BUILDING METHODS ...

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    bool readOnly = false,
    TextInputType? keyboardType,
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
              readOnly: readOnly,
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
              keyboardType: keyboardType,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
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
          controller: _searchController,
          onChanged: _filterAreas,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1A1A1A),
          ),
          decoration: InputDecoration(
            hintText: 'Search area (region, district, ward...)',
            hintStyle: GoogleFonts.poppins(
              color: Colors.grey.shade400,
              fontSize: 16,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade600, Colors.purple.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.clear_rounded, color: Colors.grey.shade400),
              onPressed: () {
                _searchController.clear();
                _filterAreas('');
              },
            )
                : null,
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
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Location Set Successfully',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Coordinates',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Lat: ${_latitude!.toStringAsFixed(6)}, Long: ${_longitude!.toStringAsFixed(6)}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Source: ${_locationSource ?? 'Manual'}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaSelection() {
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
          if (_selectedAreaDisplay != null)
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
                      Icons.location_on_rounded,
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
                          'Selected Area',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedAreaDisplay!,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A1A),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedAreaUid = null;
                        _selectedAreaDisplay = null;
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
          SizedBox(
            height: 300,
            child: _isLoading
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    'Searching areas...',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
                : _filteredAreas.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 48,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No areas found',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Try adjusting your search',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _filteredAreas.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Colors.grey.shade200,
              ),
              itemBuilder: (context, index) {
                final area = _filteredAreas[index];
                final level = _getAreaLevel(area);
                final isSelected = _selectedAreaUid == area['uid'];

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
                            _selectedAreaUid = area['uid'];
                            _selectedAreaDisplay = _getAreaDisplayInfo(area);
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
                                color: _getLevelColor(level).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getLevelIcon(level),
                                color: _getLevelColor(level),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getAreaDisplayInfo(area),
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: const Color(0xFF1A1A1A),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getLevelColor(level).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      level,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _getLevelColor(level),
                                      ),
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
                          widget.existingPoliceStation != null
                              ? 'Edit Police Station'
                              : 'Register Police Station',
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
                            label: 'Station Name',
                            hint: 'Enter police station name',
                            icon: Icons.local_police_rounded,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Station name is required';
                              }
                              return null;
                            },
                          ),
                          _buildModernTextField(
                            controller: _contactInfoController,
                            label: 'Phone Number',
                            hint: '+255 XXX XXX XXX',
                            icon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Phone number is required';
                              }
                              if (!RegExp(r'^\+255\d{9}$').hasMatch(value.trim())) {
                                return 'Enter a valid Tanzanian number (+255XXXXXXXXX)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Station Location',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Choose how to set the location',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildModernButton(
                            text: _isSearchingLocation ? 'Searching...' : 'Set Location',
                            onPressed: _showLocationPickerDialog,
                            icon: Icons.add_location_alt,
                            gradientColors: [Colors.purple.shade600, Colors.purple.shade400],
                            isLoading: _isSearchingLocation,
                          ),
                          const SizedBox(height: 16),
                          _buildLocationInfoCard(),
                          _buildModernTextField(
                            controller: _addressController,
                            label: 'Full Address',
                            hint: 'Complete address will appear here',
                            icon: Icons.location_on_rounded,
                            readOnly: true,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Address is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Administrative Area',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select the administrative area for this police station',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildSearchField(),
                          _buildAreaSelection(),
                          const SizedBox(height: 24),
                          _buildModernButton(
                            text: widget.existingPoliceStation != null
                                ? 'Update Station'
                                : 'Register Station',
                            icon: widget.existingPoliceStation != null
                                ? Icons.edit_rounded
                                : Icons.save_rounded,
                            gradientColors: [Colors.teal.shade600, Colors.blue.shade600],
                            onPressed: _savePoliceStation,
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