import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:incident_reporting_frontend/core/constants/enums.dart';
import 'package:incident_reporting_frontend/core/network/api_service.dart';
import 'package:incident_reporting_frontend/core/theme/app_theme.dart';
import 'package:incident_reporting_frontend/core/widgets/widgets.dart';

class DispatchCenterPage extends StatefulWidget {
  final String? stationUid;

  const DispatchCenterPage({Key? key, this.stationUid}) : super(key: key);

  @override
  _DispatchCenterPageState createState() => _DispatchCenterPageState();
}

class _DispatchCenterPageState extends State<DispatchCenterPage>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();

  late TabController _tabController;

  List<Map<String, dynamic>> _activeDispatches = [];
  List<Map<String, dynamic>> _availableVehicles = [];
  bool _isLoadingDispatches = true;
  bool _isLoadingVehicles = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadActiveDispatches(),
      _loadAvailableVehicles(),
    ]);
  }

  Future<void> _loadActiveDispatches() async {
    setState(() => _isLoadingDispatches = true);
    try {
      final response =
          await _api.getActiveDispatches(stationUid: widget.stationUid);
      if (response['status'] != 'Error') {
        setState(() {
          _activeDispatches =
              List<Map<String, dynamic>>.from(response['data'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error loading dispatches: $e');
    } finally {
      setState(() => _isLoadingDispatches = false);
    }
  }

  Future<void> _loadAvailableVehicles() async {
    setState(() => _isLoadingVehicles = true);
    try {
      final response = await _api.getAvailableVehicles();
      if (response['status'] != 'Error') {
        setState(() {
          _availableVehicles =
              List<Map<String, dynamic>>.from(response['data'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error loading available vehicles: $e');
    } finally {
      setState(() => _isLoadingVehicles = false);
    }
  }

  Future<void> _updateDispatchStatus(
      String dispatchUid, String newStatus) async {
    try {
      final response = await _api.updateDispatchStatus(dispatchUid, {
        'status': newStatus,
      });
      if (response['status'] == 'Error') {
        throw Exception(response['message']);
      }
      AppSnackbar.success(
          context, 'Status updated to ${DispatchStatusEnum.getLabel(newStatus)}');
      _loadData();
    } catch (e) {
      AppSnackbar.error(context, 'Error: $e');
    }
  }

  void _showDispatchDialog() {
    showDialog(
      context: context,
      builder: (context) => _DispatchDialog(
        availableVehicles: _availableVehicles,
        onDispatch: (dto) async {
          try {
            final response = await _api.dispatchVehicle(dto);
            if (response['status'] == 'Error') {
              throw Exception(response['message']);
            }
            AppSnackbar.success(context, 'Vehicle dispatched successfully');
            _loadData();
          } catch (e) {
            AppSnackbar.error(context, 'Error: $e');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: Text(
          'Dispatch Center',
          style: AppTheme.titleLarge.copyWith(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFEF4444),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_shipping_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Active (${_activeDispatches.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.directions_car_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Available (${_availableVehicles.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveDispatchesTab(),
          _buildAvailableVehiclesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showDispatchDialog,
        backgroundColor: const Color(0xFFEF4444),
        icon: const Icon(Icons.send_rounded, color: Colors.white),
        label: Text('Dispatch', style: AppTheme.buttonTextMedium),
      ),
    );
  }

  Widget _buildActiveDispatchesTab() {
    if (_isLoadingDispatches) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_activeDispatches.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 64, color: AppTheme.successGreen.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('No active dispatches', style: AppTheme.titleMedium),
            const SizedBox(height: 8),
            Text('All clear', style: AppTheme.bodyMedium),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadActiveDispatches,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spaceM),
        itemCount: _activeDispatches.length,
        itemBuilder: (context, index) =>
            _buildDispatchCard(_activeDispatches[index]),
      ),
    );
  }

  Widget _buildDispatchCard(Map<String, dynamic> dispatch) {
    final status = dispatch['status'] ?? '';
    final statusColor = DispatchStatusEnum.getColor(status);
    final vehicle = dispatch['vehicle'] ?? {};
    final incident = dispatch['incident'] ?? {};
    final eta = dispatch['etaMinutes'];

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceM),
      decoration: AppTheme.elevatedCardDecoration.copyWith(
        borderRadius: AppTheme.largeRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: AppTheme.cardRadius,
                  ),
                  child: Icon(
                    VehicleTypeEnum.getIcon(vehicle['vehicleType'] ?? ''),
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle['plateNumber'] ?? 'Vehicle',
                        style: AppTheme.titleSmall,
                      ),
                      Text(
                        VehicleTypeEnum.getLabel(vehicle['vehicleType'] ?? ''),
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    DispatchStatusEnum.getLabel(status),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),

            if (incident['title'] != null) ...[
              const SizedBox(height: AppTheme.spaceM),
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceM),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FC),
                  borderRadius: AppTheme.smallRadius,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFF59E0B), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        incident['title'],
                        style: AppTheme.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (eta != null)
                      Text(
                        '~$eta min ETA',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2E5BFF),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // Status update buttons
            const SizedBox(height: AppTheme.spaceM),
            _buildStatusButtons(dispatch['uid'], status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButtons(String dispatchUid, String currentStatus) {
    final List<Map<String, dynamic>> transitions = [];

    switch (currentStatus) {
      case DispatchStatusEnum.PENDING:
        transitions.addAll([
          {
            'label': 'Acknowledge',
            'status': DispatchStatusEnum.ACKNOWLEDGED,
            'color': const Color(0xFF2E5BFF),
          },
          {
            'label': 'Cancel',
            'status': DispatchStatusEnum.CANCELLED,
            'color': AppTheme.errorRed,
          },
        ]);
        break;
      case DispatchStatusEnum.ACKNOWLEDGED:
        transitions.add({
          'label': 'En Route',
          'status': DispatchStatusEnum.EN_ROUTE,
          'color': const Color(0xFF8B5CF6),
        });
        break;
      case DispatchStatusEnum.EN_ROUTE:
        transitions.add({
          'label': 'On Scene',
          'status': DispatchStatusEnum.ON_SCENE,
          'color': const Color(0xFFEF4444),
        });
        break;
      case DispatchStatusEnum.ON_SCENE:
        transitions.addAll([
          {
            'label': 'Clear Scene',
            'status': DispatchStatusEnum.CLEARED,
            'color': AppTheme.successGreen,
          },
        ]);
        break;
    }

    if (transitions.isEmpty) return const SizedBox.shrink();

    return Row(
      children: transitions
          .map((t) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: OutlinedButton(
                  onPressed: () =>
                      _updateDispatchStatus(dispatchUid, t['status']),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: t['color']),
                    shape: RoundedRectangleBorder(
                        borderRadius: AppTheme.buttonRadius),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                  child: Text(
                    t['label'],
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: t['color'],
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildAvailableVehiclesTab() {
    if (_isLoadingVehicles) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_availableVehicles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.no_crash_rounded,
                size: 64, color: Colors.grey.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('No vehicles available', style: AppTheme.titleMedium),
            const SizedBox(height: 8),
            Text('All vehicles are currently deployed',
                style: AppTheme.bodyMedium),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAvailableVehicles,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spaceM),
        itemCount: _availableVehicles.length,
        itemBuilder: (context, index) =>
            _buildAvailableVehicleCard(_availableVehicles[index]),
      ),
    );
  }

  Widget _buildAvailableVehicleCard(Map<String, dynamic> vehicle) {
    final type = vehicle['vehicleType'] ?? '';
    final typeColor = VehicleTypeEnum.getColor(type);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceM),
      decoration: AppTheme.elevatedCardDecoration.copyWith(
        borderRadius: AppTheme.largeRadius,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppTheme.spaceM),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.12),
            borderRadius: AppTheme.cardRadius,
          ),
          child: Icon(
            VehicleTypeEnum.getIcon(type),
            color: typeColor,
            size: 24,
          ),
        ),
        title: Text(
          vehicle['plateNumber'] ?? 'No Plate',
          style: AppTheme.titleSmall,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(VehicleTypeEnum.getLabel(type), style: AppTheme.bodySmall),
            if (vehicle['model'] != null)
              Text(vehicle['model'], style: AppTheme.bodySmall),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.successGreen.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'AVAILABLE',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.successGreen,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// DISPATCH DIALOG
// ============================================================================

class _DispatchDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableVehicles;
  final Future<void> Function(Map<String, dynamic>) onDispatch;

  const _DispatchDialog({
    required this.availableVehicles,
    required this.onDispatch,
  });

  @override
  __DispatchDialogState createState() => __DispatchDialogState();
}

class __DispatchDialogState extends State<_DispatchDialog> {
  final _formKey = GlobalKey<FormState>();
  final _incidentUidCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _selectedVehicleUid;
  bool _isLoading = false;

  @override
  void dispose() {
    _incidentUidCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await widget.onDispatch({
        'vehicleUid': _selectedVehicleUid,
        'incidentUid': _incidentUidCtrl.text.trim(),
        'notes': _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
      });
      Navigator.pop(context);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceL),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.12),
                      borderRadius: AppTheme.cardRadius,
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Color(0xFFEF4444), size: 22),
                  ),
                  const SizedBox(width: AppTheme.spaceM),
                  Expanded(
                    child: Text('Dispatch Vehicle', style: AppTheme.titleLarge),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceL),

              if (widget.availableVehicles.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceM),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: AppTheme.cardRadius,
                    border: Border.all(color: const Color(0xFFFBBF24)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFF59E0B)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No vehicles currently available. All units are deployed.',
                          style: AppTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                DropdownButtonFormField<String>(
                  value: _selectedVehicleUid,
                  decoration: InputDecoration(
                    labelText: 'Select Vehicle *',
                    border: OutlineInputBorder(
                        borderRadius: AppTheme.cardRadius),
                    prefixIcon: const Icon(Icons.directions_car_rounded),
                  ),
                  items: widget.availableVehicles
                      .map((v) => DropdownMenuItem(
                            value: v['uid'] as String,
                            child: Text(
                              '${v['plateNumber']} — ${VehicleTypeEnum.getLabel(v['vehicleType'] ?? '')}',
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedVehicleUid = v),
                  validator: (v) =>
                      v == null ? 'Please select a vehicle' : null,
                ),
                const SizedBox(height: AppTheme.spaceM),

                TextFormField(
                  controller: _incidentUidCtrl,
                  decoration: InputDecoration(
                    labelText: 'Incident UID *',
                    border: OutlineInputBorder(
                        borderRadius: AppTheme.cardRadius),
                    prefixIcon: const Icon(Icons.warning_amber_rounded),
                    helperText: 'Enter the UID of the incident',
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Incident UID is required' : null,
                ),
                const SizedBox(height: AppTheme.spaceM),

                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Dispatch Notes',
                    border: OutlineInputBorder(
                        borderRadius: AppTheme.cardRadius),
                    prefixIcon: const Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceL),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
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
                        : Text('Dispatch Vehicle',
                            style: AppTheme.buttonTextMedium),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
