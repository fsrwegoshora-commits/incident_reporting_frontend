import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:incident_reporting_frontend/core/constants/enums.dart';
import 'package:incident_reporting_frontend/core/network/api_service.dart';
import 'package:incident_reporting_frontend/core/theme/app_theme.dart';
import 'package:incident_reporting_frontend/core/widgets/widgets.dart';

class VehicleManagementPage extends StatefulWidget {
  final String? stationUid;
  final bool isFireStation; // true=fire, false=medical

  const VehicleManagementPage({
    Key? key,
    this.stationUid,
    this.isFireStation = true,
  }) : super(key: key);

  @override
  _VehicleManagementPageState createState() => _VehicleManagementPageState();
}

class _VehicleManagementPageState extends State<VehicleManagementPage>
    with TickerProviderStateMixin {
  final _api = ApiService();
  List<Map<String, dynamic>> _vehicles = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  int _currentPage = 0;
  final int _pageSize = 20;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: AppTheme.normalAnimation,
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _fetchVehicles();
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchVehicles() async {
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> response;
      if (widget.stationUid != null) {
        response = await _api.getVehiclesByStation(
          widget.stationUid!,
          page: _currentPage,
          size: _pageSize,
        );
      } else {
        response = await _api.getVehicles(
          page: _currentPage,
          size: _pageSize,
        );
      }

      if (response['status'] == 'Error') {
        throw Exception(response['message']);
      }

      final vehicles = response['data'] ?? [];
      final totalPages = response['pages'] ?? 0;

      setState(() {
        if (_currentPage == 0) {
          _vehicles = List<Map<String, dynamic>>.from(vehicles);
        } else {
          _vehicles.addAll(List<Map<String, dynamic>>.from(vehicles));
        }
        _hasMore = _currentPage < totalPages - 1;
        _isLoading = false;
      });
    } catch (e) {
      AppSnackbar.error(context, 'Error loading vehicles: $e');
      setState(() => _isLoading = false);
    }
  }

  void _refresh() {
    setState(() {
      _currentPage = 0;
      _hasMore = true;
      _searchQuery = '';
      _searchController.clear();
    });
    _fetchVehicles();
    _animController.reset();
    _animController.forward();
  }

  Future<void> _deleteVehicle(String uid) async {
    final confirm = await _showDeleteDialog();
    if (confirm != true) return;

    try {
      final response = await _api.deleteVehicle(uid);
      if (response['status'] == 'Error') {
        throw Exception(response['message']);
      }
      AppSnackbar.success(context, 'Vehicle deleted');
      _refresh();
    } catch (e) {
      AppSnackbar.error(context, 'Error: $e');
    }
  }

  Future<bool?> _showDeleteDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.largeRadius),
        title: Text('Delete Vehicle', style: AppTheme.titleLarge),
        content: Text(
          'Are you sure you want to remove this vehicle?',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTheme.bodyMedium),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openVehicleForm({Map<String, dynamic>? vehicle}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.cardRadius),
        child: VehicleFormDialog(
          existingVehicle: vehicle,
          stationUid: widget.stationUid,
          isFireStation: widget.isFireStation,
          onSubmit: _refresh,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filtered() {
    if (_searchQuery.isEmpty) return _vehicles;
    final q = _searchQuery.toLowerCase();
    return _vehicles.where((v) {
      return (v['plateNumber'] ?? '').toString().toLowerCase().contains(q) ||
          (v['model'] ?? '').toString().toLowerCase().contains(q) ||
          (v['vehicleType'] ?? '').toString().toLowerCase().contains(q) ||
          (v['status'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
  }

  Color get _themeColor =>
      widget.isFireStation ? const Color(0xFFEF4444) : const Color(0xFF10B981);

  LinearGradient get _themeGradient => widget.isFireStation
      ? const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
        )
      : const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        );

  Widget _buildVehicleCard(Map<String, dynamic> vehicle, int index) {
    final type = vehicle['vehicleType'] ?? '';
    final status = vehicle['status'] ?? '';
    final statusColor = VehicleStatusEnum.getColor(status);
    final typeColor = VehicleTypeEnum.getColor(type);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        margin: EdgeInsets.only(
          left: AppTheme.spaceM,
          right: AppTheme.spaceM,
          bottom: AppTheme.spaceM,
          top: index == 0 ? AppTheme.spaceS : 0,
        ),
        decoration: AppTheme.elevatedCardDecoration.copyWith(
          borderRadius: AppTheme.largeRadius,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppTheme.largeRadius,
            onTap: () => _openVehicleForm(vehicle: vehicle),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceM),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.12),
                      borderRadius: AppTheme.cardRadius,
                    ),
                    child: Icon(
                      VehicleTypeEnum.getIcon(type),
                      color: typeColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle['plateNumber'] ?? 'No Plate',
                          style: AppTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          VehicleTypeEnum.getLabel(type),
                          style: AppTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                VehicleStatusEnum.getLabel(status),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            if (vehicle['model'] != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  vehicle['model'],
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: AppTheme.errorRed,
                    onPressed: () => _deleteVehicle(vehicle['uid']),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();

    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: BoxDecoration(gradient: _themeGradient),
              child: FlexibleSpaceBar(
                title: Text(
                  widget.isFireStation
                      ? 'Fire Vehicles'
                      : 'Ambulance Fleet',
                  style: AppTheme.titleLarge.copyWith(color: Colors.white),
                ),
                centerTitle: false,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _refresh,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(AppTheme.spaceM),
              decoration: AppTheme.primaryCardDecoration.copyWith(
                borderRadius: AppTheme.pillRadius,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: AppTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Search by plate, type, model…',
                  hintStyle: AppTheme.bodyMedium
                      .copyWith(color: AppTheme.textSecondary),
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _themeColor,
                      borderRadius: AppTheme.pillRadius,
                    ),
                    child: const Icon(Icons.search, color: Colors.white,
                        size: 20),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceM,
                      vertical: AppTheme.spaceM),
                ),
              ),
            ),
          ),

          // Stats card
          SliverToBoxAdapter(
            child: Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: AppTheme.spaceM),
              padding: const EdgeInsets.all(AppTheme.spaceL),
              decoration: BoxDecoration(
                gradient: _themeGradient,
                borderRadius: AppTheme.cardRadius,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceM),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: AppTheme.cardRadius,
                    ),
                    child: Icon(
                      widget.isFireStation
                          ? Icons.local_fire_department_rounded
                          : Icons.medical_services_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceM),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Vehicles',
                        style: AppTheme.bodyMedium
                            .copyWith(color: Colors.white.withOpacity(0.8)),
                      ),
                      Text(
                        '${filtered.length}',
                        style: AppTheme.headlineMedium
                            .copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${filtered.where((v) => v['status'] == VehicleStatusEnum.AVAILABLE).length} available',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${filtered.where((v) => v['status'] == VehicleStatusEnum.DISPATCHED || v['status'] == VehicleStatusEnum.EN_ROUTE || v['status'] == VehicleStatusEnum.ON_SCENE).length} active',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(
              child: SizedBox(height: AppTheme.spaceM)),

          if (_isLoading && _currentPage == 0)
            SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: _themeColor),
              ),
            )
          else if (filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isFireStation
                          ? Icons.fire_truck_rounded
                          : Icons.medical_services_rounded,
                      size: 64,
                      color: _themeColor.withOpacity(0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No matching vehicles'
                          : 'No vehicles registered',
                      style: AppTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap + to add a vehicle',
                      style: AppTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == filtered.length) {
                    if (_hasMore && _searchQuery.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(AppTheme.spaceL),
                        child: Center(
                          child: _isLoading
                              ? CircularProgressIndicator(
                                  color: _themeColor)
                              : TextButton(
                                  onPressed: () {
                                    setState(() => _currentPage++);
                                    _fetchVehicles();
                                  },
                                  child: Text('Load More',
                                      style: TextStyle(color: _themeColor)),
                                ),
                        ),
                      );
                    }
                    return const SizedBox(height: 100);
                  }
                  return _buildVehicleCard(filtered[index], index);
                },
                childCount:
                    filtered.length + (_hasMore || _isLoading ? 1 : 1),
              ),
            ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: _themeGradient,
          borderRadius: AppTheme.pillRadius,
          boxShadow: [AppTheme.elevatedShadow],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _openVehicleForm(),
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            'Add Vehicle',
            style: AppTheme.buttonTextMedium,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// VEHICLE FORM DIALOG
// ============================================================================

class VehicleFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existingVehicle;
  final String? stationUid;
  final bool isFireStation;
  final VoidCallback onSubmit;

  const VehicleFormDialog({
    Key? key,
    this.existingVehicle,
    this.stationUid,
    this.isFireStation = true,
    required this.onSubmit,
  }) : super(key: key);

  @override
  _VehicleFormDialogState createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends State<VehicleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  final _plateCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _waterCtrl = TextEditingController();

  String? _selectedType;
  bool _hasALS = false;
  bool _isLoading = false;

  bool get isEditing => widget.existingVehicle != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final v = widget.existingVehicle!;
      _plateCtrl.text = v['plateNumber'] ?? '';
      _modelCtrl.text = v['model'] ?? '';
      _selectedType = v['vehicleType'];
      _hasALS = v['hasAdvancedLifeSupport'] ?? false;
      _waterCtrl.text = (v['waterCapacityLitres'] ?? '').toString();
    } else {
      // Default type based on station
      _selectedType = widget.isFireStation
          ? VehicleTypeEnum.FIRE_TRUCK
          : VehicleTypeEnum.AMBULANCE;
    }
  }

  @override
  void dispose() {
    _plateCtrl.dispose();
    _modelCtrl.dispose();
    _waterCtrl.dispose();
    super.dispose();
  }

  List<String> get _typeOptions => widget.isFireStation
      ? VehicleTypeEnum.fireTypes
      : VehicleTypeEnum.medicalTypes;

  bool get _isFireType => VehicleTypeEnum.fireTypes.contains(_selectedType);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final dto = <String, dynamic>{
        'plateNumber': _plateCtrl.text.trim(),
        'model': _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
        'vehicleType': _selectedType,
        'stationUid': widget.stationUid,
      };

      if (_isFireType && _waterCtrl.text.isNotEmpty) {
        dto['waterCapacityLitres'] = int.tryParse(_waterCtrl.text);
      }
      if (!_isFireType) {
        dto['hasAdvancedLifeSupport'] = _hasALS;
      }

      if (isEditing) {
        dto['uid'] = widget.existingVehicle!['uid'];
      }

      final response = await _api.saveVehicle(dto);
      if (response['status'] == 'Error') {
        throw Exception(response['message']);
      }

      Navigator.pop(context);
      AppSnackbar.success(
          context, isEditing ? 'Vehicle updated' : 'Vehicle registered');
      widget.onSubmit();
    } catch (e) {
      AppSnackbar.error(context, 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.isFireStation
        ? const Color(0xFFEF4444)
        : const Color(0xFF10B981);

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceL),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.12),
                      borderRadius: AppTheme.cardRadius,
                    ),
                    child: Icon(
                      widget.isFireStation
                          ? Icons.local_fire_department_rounded
                          : Icons.medical_services_rounded,
                      color: themeColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceM),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Vehicle' : 'Register Vehicle',
                      style: AppTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceL),

              // Plate Number
              TextFormField(
                controller: _plateCtrl,
                decoration: InputDecoration(
                  labelText: 'Plate Number *',
                  border: OutlineInputBorder(
                      borderRadius: AppTheme.cardRadius),
                  prefixIcon: const Icon(Icons.numbers),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Plate number is required' : null,
              ),
              const SizedBox(height: AppTheme.spaceM),

              // Model
              TextFormField(
                controller: _modelCtrl,
                decoration: InputDecoration(
                  labelText: 'Model / Make',
                  border: OutlineInputBorder(
                      borderRadius: AppTheme.cardRadius),
                  prefixIcon: const Icon(Icons.directions_car_rounded),
                ),
              ),
              const SizedBox(height: AppTheme.spaceM),

              // Vehicle Type
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Vehicle Type *',
                  border: OutlineInputBorder(
                      borderRadius: AppTheme.cardRadius),
                  prefixIcon: const Icon(Icons.category_rounded),
                ),
                items: _typeOptions
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(VehicleTypeEnum.getLabel(t)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedType = v),
                validator: (v) =>
                    v == null ? 'Please select a vehicle type' : null,
              ),
              const SizedBox(height: AppTheme.spaceM),

              // Fire-specific: Water Capacity
              if (_isFireType) ...[
                TextFormField(
                  controller: _waterCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Water Capacity (Litres)',
                    border: OutlineInputBorder(
                        borderRadius: AppTheme.cardRadius),
                    prefixIcon: const Icon(Icons.water_drop_rounded),
                    suffixText: 'L',
                  ),
                ),
                const SizedBox(height: AppTheme.spaceM),
              ],

              // Medical-specific: ALS
              if (!_isFireType) ...[
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceM),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.06),
                    borderRadius: AppTheme.cardRadius,
                    border: Border.all(
                        color: themeColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Advanced Life Support (ALS)',
                                style: AppTheme.titleSmall),
                            Text(
                                'Has cardiac monitor, ventilator, ALS drugs',
                                style: AppTheme.bodySmall),
                          ],
                        ),
                      ),
                      Switch(
                        value: _hasALS,
                        onChanged: (v) => setState(() => _hasALS = v),
                        activeColor: themeColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceM),
              ],

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: AppTheme.buttonRadius),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          isEditing ? 'Save Changes' : 'Register Vehicle',
                          style: AppTheme.buttonTextMedium,
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
