import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/config_service.dart';


class ApiService {
  final ConfigService _config = ConfigService();

  String get _base => 'http://${_config.host}:${_config.port}';

  // ─── Private HTTP helpers ──────────────────────────────────────────────────

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Map<String, String> _headers({String? token, bool json = true}) {
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, String>? params]) {
    final uri = Uri.parse('$_base$path');
    return params != null && params.isNotEmpty
        ? uri.replace(queryParameters: params)
        : uri;
  }

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, String>? params, bool auth = true}) async {
    final token = auth ? await _token() : null;
    final res = await http.get(_uri(path, params), headers: _headers(token: token));
    return _parse(res);
  }

  Future<Map<String, dynamic>> _post(String path,
      {dynamic body, Map<String, String>? params, bool auth = true}) async {
    final token = auth ? await _token() : null;
    final res = await http.post(
      _uri(path, params),
      headers: _headers(token: token),
      body: body != null ? jsonEncode(body) : null,
    );
    return _parse(res);
  }

  Future<Map<String, dynamic>> _put(String path,
      {dynamic body, Map<String, String>? params, bool auth = true}) async {
    final token = auth ? await _token() : null;
    final res = await http.put(
      _uri(path, params),
      headers: _headers(token: token),
      body: body != null ? jsonEncode(body) : null,
    );
    return _parse(res);
  }

  Future<Map<String, dynamic>> _delete(String path,
      {Map<String, String>? params, bool auth = true}) async {
    final token = auth ? await _token() : null;
    final res = await http.delete(_uri(path, params), headers: _headers(token: token));
    return _parse(res);
  }

  Future<Map<String, dynamic>> _patch(String path,
      {Map<String, String>? params, bool auth = true}) async {
    final token = auth ? await _token() : null;
    final req = http.Request('PATCH', _uri(path, params));
    _headers(token: token).forEach((k, v) => req.headers[k] = v);
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _parse(res);
  }

  Map<String, dynamic> _parse(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'status': 'Success', 'data': decoded};
    } catch (_) {
      return {'status': 'Error', 'message': 'Invalid server response (${res.statusCode})'};
    }
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> requestOtp(String phoneNumber) =>
      _post('/api/auth/otp/request', params: {'phoneNumber': phoneNumber}, auth: false);

  Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String code) =>
      _post('/api/auth/otp/verify',
          params: {'phoneNumber': phoneNumber, 'code': code}, auth: false);

  Future<Map<String, dynamic>> validateToken(String token) =>
      _get('/api/auth/token/validate', params: {'token': token}, auth: false);

  Future<Map<String, dynamic>> refreshToken(String refreshToken) =>
      _post('/api/auth/token/refresh',
          params: {'refreshToken': refreshToken}, auth: false);

  Future<Map<String, dynamic>> logout() => _post('/api/auth/logout');

  // ─── Users ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> registerUser(Map<String, dynamic> userDto) =>
      _post('/api/users/register', body: userDto, auth: false);

  Future<Map<String, dynamic>> registerSpecialUser(Map<String, dynamic> userDto) =>
      _post('/api/users/register-special', body: userDto);

  Future<Map<String, dynamic>> getMe() => _get('/api/users/me');

  Future<Map<String, dynamic>> getUser(String uid) => _get('/api/users/$uid');

  Future<Map<String, dynamic>> getUsers(
          {int page = 0,
          int size = 10,
          String? key,
          bool? isActive,
          String sortBy = 'createdAt',
          String sortDirection = 'DESC'}) =>
      _get('/api/users', params: {
        'page': page.toString(),
        'size': size.toString(),
        'sortBy': sortBy,
        'sortDirection': sortDirection,
        if (key != null && key.isNotEmpty) 'key': key,
        if (isActive != null) 'isActive': isActive.toString(),
      });

  Future<Map<String, dynamic>> deleteUser(String uid) =>
      _delete('/api/users/$uid');

  Future<Map<String, dynamic>> deleteMyAccount() =>
      _delete('/api/users/me');

  Future<Map<String, dynamic>> getSpecialUsers({String? role}) =>
      _get('/api/users/special',
          params: {if (role != null) 'role': role});

  Future<Map<String, dynamic>> changeUserRole(String uid, String role,
          {String? stationUid}) =>
      _patch('/api/users/$uid/role', params: {
        'role': role,
        if (stationUid != null) 'stationUid': stationUid,
      });

  // ─── Police Stations ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> savePoliceStation(Map<String, dynamic> dto) =>
      _post('/api/police/stations', body: dto);

  Future<Map<String, dynamic>> getPoliceStation(String uid) =>
      _get('/api/police/stations/$uid');

  Future<Map<String, dynamic>> deletePoliceStation(String uid) =>
      _delete('/api/police/stations/$uid');

  Future<Map<String, dynamic>> getPoliceStations(
          {int page = 0,
          int size = 20,
          String? key,
          bool? isActive,
          String sortBy = 'name',
          String sortDirection = 'ASC'}) =>
      _get('/api/police/stations', params: {
        'page': page.toString(),
        'size': size.toString(),
        'sortBy': sortBy,
        'sortDirection': sortDirection,
        if (key != null && key.isNotEmpty) 'key': key,
        if (isActive != null) 'isActive': isActive.toString(),
      });

  Future<Map<String, dynamic>> getStationsByAdmin() =>
      _get('/api/police/stations/admin');

  Future<Map<String, dynamic>> getNearbyPoliceStations(
          double latitude, double longitude, double maxDistance) =>
      _get('/api/police/stations/nearby', params: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'maxDistance': maxDistance.toString(),
      });

  // ─── Police Officers ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> savePoliceOfficer(Map<String, dynamic> dto) =>
      _post('/api/police/officers', body: dto);

  Future<Map<String, dynamic>> getPoliceOfficer(String uid) =>
      _get('/api/police/officers/$uid');

  Future<Map<String, dynamic>> deletePoliceOfficer(String uid) =>
      _delete('/api/police/officers/$uid');

  Future<Map<String, dynamic>> getPoliceOfficers(
          {int page = 0,
          int size = 20,
          String? key,
          bool? isActive,
          String sortBy = 'createdAt',
          String sortDirection = 'DESC'}) =>
      _get('/api/police/officers', params: {
        'page': page.toString(),
        'size': size.toString(),
        'sortBy': sortBy,
        'sortDirection': sortDirection,
        if (key != null && key.isNotEmpty) 'key': key,
        if (isActive != null) 'isActive': isActive.toString(),
      });

  Future<Map<String, dynamic>> getPoliceOfficersByStation(String stationUid,
          {int page = 0, int size = 100}) =>
      _get('/api/police/officers/by-station/$stationUid',
          params: {'page': page.toString(), 'size': size.toString()});

  Future<Map<String, dynamic>> getAvailableOfficersForSlot(
          String date, String startTime, String endTime) =>
      _get('/api/police/officers/available/slot',
          params: {'date': date, 'startTime': startTime, 'endTime': endTime});

  // ─── Officer Shifts ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> saveShift(Map<String, dynamic> dto) =>
      _post('/api/police/shifts', body: dto);

  Future<Map<String, dynamic>> excuseShift(String uid, String reason) =>
      _put('/api/police/shifts/$uid/excuse', params: {'reason': reason});

  Future<Map<String, dynamic>> reassignShift(String uid, String newOfficerUid) =>
      _put('/api/police/shifts/$uid/reassign/$newOfficerUid');

  Future<Map<String, dynamic>> deleteOfficerShift(String uid) =>
      _delete('/api/police/shifts/$uid');

  Future<Map<String, dynamic>> getShiftsByStation(String stationUid,
          {int page = 0, int size = 20, bool? isActive}) =>
      _get('/api/police/shifts/station/$stationUid', params: {
        'page': page.toString(),
        'size': size.toString(),
        if (isActive != null) 'isActive': isActive.toString(),
      });

  Future<Map<String, dynamic>> getShiftsByOfficer(String officerUid,
          {int page = 0, int size = 20}) =>
      _get('/api/police/shifts/officer/$officerUid',
          params: {'page': page.toString(), 'size': size.toString()});

  Future<Map<String, dynamic>> getCurrentOfficerOnDuty(String stationUid) =>
      _get('/api/police/shifts/on-duty/$stationUid');

  Future<Map<String, dynamic>> getShiftsByCheckpoint(String checkpointUid,
          {int page = 0, int size = 20}) =>
      _get('/api/police/shifts/checkpoint/$checkpointUid',
          params: {'page': page.toString(), 'size': size.toString()});

  Future<Map<String, dynamic>> assignCheckpointShiftBulk(
          Map<String, dynamic> dto) =>
      _post('/api/police/shifts/checkpoint/bulk', body: dto);

  // ─── Traffic Checkpoints ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> saveTrafficCheckpoint(Map<String, dynamic> dto) =>
      _post('/api/police/checkpoints', body: dto);

  Future<Map<String, dynamic>> deleteTrafficCheckpoint(String uid) =>
      _delete('/api/police/checkpoints/$uid');

  Future<Map<String, dynamic>> getTrafficCheckpoint(String uid) =>
      _get('/api/police/checkpoints/$uid');

  Future<Map<String, dynamic>> getTrafficCheckpoints(
          {int page = 0, int size = 20, bool? isActive}) =>
      _get('/api/police/checkpoints', params: {
        'page': page.toString(),
        'size': size.toString(),
        if (isActive != null) 'isActive': isActive.toString(),
      });

  Future<Map<String, dynamic>> getCheckpointsByStation(String stationUid,
          {int page = 0, int size = 20}) =>
      _get('/api/police/checkpoints/station/$stationUid',
          params: {'page': page.toString(), 'size': size.toString()});

  Future<Map<String, dynamic>> assignSupervisor(
          String checkpointUid, String officerUid) =>
      _put('/api/police/checkpoints/$checkpointUid/assign-supervisor/$officerUid');

  Future<Map<String, dynamic>> changeSupervisor(
          String checkpointUid, String newOfficerUid) =>
      _put('/api/police/checkpoints/$checkpointUid/change-supervisor/$newOfficerUid');

  Future<Map<String, dynamic>> toggleCheckpoint(String checkpointUid) =>
      _put('/api/police/checkpoints/$checkpointUid/toggle');

  // ─── Incidents ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createIncident(Map<String, dynamic> dto) =>
      _post('/api/incidents', body: dto);

  Future<Map<String, dynamic>> updateIncident(Map<String, dynamic> dto) =>
      _put('/api/incidents', body: dto);

  Future<Map<String, dynamic>> deleteIncident(String uid) =>
      _delete('/api/incidents/$uid');

  Future<Map<String, dynamic>> getIncident(String uid) =>
      _get('/api/incidents/$uid');

  Future<Map<String, dynamic>> getMyIncidents(
          {int page = 0, int size = 20}) =>
      _get('/api/incidents/my',
          params: {'page': page.toString(), 'size': size.toString()});

  Future<Map<String, dynamic>> getStationIncidents(
          {int page = 0, int size = 20, String? status}) =>
      _get('/api/incidents/station', params: {
        'page': page.toString(),
        'size': size.toString(),
        if (status != null) 'status': status,
      });

  Future<Map<String, dynamic>> getOfficerIncidents(
          {int page = 0, int size = 20, String? status}) =>
      _get('/api/incidents/officer', params: {
        'page': page.toString(),
        'size': size.toString(),
        if (status != null) 'status': status,
      });

  // ─── Chat Messages ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> sendChatMessage(Map<String, dynamic> dto) =>
      _post('/api/chat/messages', body: dto);

  Future<Map<String, dynamic>> getAllIncidentMessages(String incidentUid) =>
      _get('/api/chat/messages/incident/$incidentUid/all');

  Future<Map<String, dynamic>> markMessagesAsRead(String incidentUid) =>
      _put('/api/chat/messages/read/$incidentUid');

  // ─── Media ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> uploadMedia(
      File file, String mediaType) async {
    try {
      final token = await _token();
      final bytes = await file.readAsBytes();
      final base64File = base64Encode(bytes);
      final fileName = file.path.split('/').last;
      final mimeType = _mimeType(fileName);

      return await _post('/api/media/upload', params: {
        'base64File': 'data:$mimeType;base64,$base64File',
        'fileName': fileName,
        'mediaType': mediaType.toUpperCase(),
      });
    } catch (e) {
      return {'status': 'Error', 'message': 'Upload failed: $e'};
    }
  }

  Future<Map<String, dynamic>> downloadMedia(String fileUrl) =>
      _get('/api/media/download', params: {'fileUrl': fileUrl});

  String _mimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }

  // ─── Agencies ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> saveAgency(Map<String, dynamic> dto) =>
      _post('/api/agencies', body: dto);

  Future<Map<String, dynamic>> deleteAgency(String uid) =>
      _delete('/api/agencies/$uid');

  Future<Map<String, dynamic>> getAgencies(
          {int page = 0, int size = 100}) =>
      _get('/api/agencies',
          params: {'page': page.toString(), 'size': size.toString()});

  // ─── Departments ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> saveDepartment(Map<String, dynamic> dto) =>
      _post('/api/departments', body: dto);

  Future<Map<String, dynamic>> deleteDepartment(String uid) =>
      _delete('/api/departments/$uid');

  Future<Map<String, dynamic>> getDepartments(
          {int page = 0, int size = 100}) =>
      _get('/api/departments',
          params: {'page': page.toString(), 'size': size.toString()});

  // ─── Administrative Areas ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> getAdministrativeAreas(
          {int page = 0, int size = 100, List<String>? areaLevels}) =>
      _get('/api/areas', params: {
        'page': page.toString(),
        'size': size.toString(),
        if (areaLevels != null && areaLevels.isNotEmpty)
          'areaLevels': areaLevels.join(','),
      });

  // ─── Notifications ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getUserNotifications(
          {int page = 0, int size = 20}) =>
      _get('/api/notifications',
          params: {'page': page.toString(), 'size': size.toString()});

  Future<Map<String, dynamic>> markNotificationAsRead(String notificationUid) =>
      _put('/api/notifications/$notificationUid/read');

  Future<Map<String, dynamic>> getUnreadCount() =>
      _get('/api/notifications/unread-count');

  Future<Map<String, dynamic>> clearNotifications(String userUid) =>
      _delete('/api/notifications/clear/$userUid');

  Future<Map<String, dynamic>> markAllNotificationsAsRead(String userUid) =>
      _put('/api/notifications/mark-all-read/$userUid');

  // ─── Device Tokens ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> registerDeviceToken({
    required String userUid,
    required String token,
    String deviceType = 'FLUTTER',
    String appVersion = '1.0.0',
  }) =>
      _post('/api/notifications/tokens', params: {
        'userUid': userUid,
        'token': token,
        'deviceType': deviceType,
        'appVersion': appVersion,
      });

  Future<Map<String, dynamic>> removeDeviceToken(String token) =>
      _delete('/api/notifications/tokens', params: {'token': token});

  // ─── Station Appointments ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> saveAppointment(Map<String, dynamic> dto) =>
      _post('/api/appointments', body: dto);

  Future<Map<String, dynamic>> getAppointmentsByStation(
          String stationUid, {int page = 0, int size = 50, String? status}) =>
      _get('/api/appointments/station/$stationUid', params: {
        'page': page.toString(),
        'size': size.toString(),
        if (status != null) 'status': status,
      });

  Future<Map<String, dynamic>> getActiveAppointmentsByStation(String stationUid) =>
      _get('/api/appointments/station/$stationUid/active');

  Future<Map<String, dynamic>> getAppointmentsByOfficer(String officerUid) =>
      _get('/api/appointments/officer/$officerUid');

  Future<Map<String, dynamic>> updateAppointmentStatus(String uid, String status) =>
      _patch('/api/appointments/$uid/status', params: {'status': status});

  Future<Map<String, dynamic>> deleteAppointment(String uid) =>
      _delete('/api/appointments/$uid');

  // ─── Emergency Vehicles ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> saveVehicle(Map<String, dynamic> dto) =>
      _post('/api/emergency/vehicles', body: dto);

  Future<Map<String, dynamic>> getVehicle(String uid) =>
      _get('/api/emergency/vehicles/$uid');

  Future<Map<String, dynamic>> deleteVehicle(String uid) =>
      _delete('/api/emergency/vehicles/$uid');

  Future<Map<String, dynamic>> getVehicles({int page = 0, int size = 20, String? key}) =>
      _get('/api/emergency/vehicles', params: {
        'page': page.toString(),
        'size': size.toString(),
        if (key != null && key.isNotEmpty) 'searchParam': key,
      });

  Future<Map<String, dynamic>> getVehiclesByStation(
          String stationUid, {int page = 0, int size = 50, String? key}) =>
      _get('/api/emergency/vehicles/by-station/$stationUid', params: {
        'page': page.toString(),
        'size': size.toString(),
        if (key != null && key.isNotEmpty) 'searchParam': key,
      });

  Future<Map<String, dynamic>> getAvailableVehicles({String? vehicleType}) =>
      _get('/api/emergency/vehicles/available',
          params: {if (vehicleType != null) 'vehicleType': vehicleType});

  Future<Map<String, dynamic>> updateVehicleStatus(String uid, String status) =>
      _put('/api/emergency/vehicles/$uid/status', params: {'status': status});

  // ─── Vehicle Shifts ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> saveVehicleShift(Map<String, dynamic> dto) =>
      _post('/api/emergency/vehicle-shifts', body: dto);

  Future<Map<String, dynamic>> deleteVehicleShift(String uid) =>
      _delete('/api/emergency/vehicle-shifts/$uid');

  Future<Map<String, dynamic>> getVehicleShiftsByStation(
          String stationUid, {int page = 0, int size = 20}) =>
      _get('/api/emergency/vehicle-shifts/station/$stationUid',
          params: {'page': page.toString(), 'size': size.toString()});

  Future<Map<String, dynamic>> getVehicleShiftsByVehicle(
          String vehicleUid, {int page = 0, int size = 20}) =>
      _get('/api/emergency/vehicle-shifts/vehicle/$vehicleUid',
          params: {'page': page.toString(), 'size': size.toString()});

  // ─── Dispatch ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> dispatchVehicle(Map<String, dynamic> dto) =>
      _post('/api/emergency/dispatch', body: dto);

  Future<Map<String, dynamic>> updateDispatchStatus(
          String uid, Map<String, dynamic> dto) =>
      _put('/api/emergency/dispatch/$uid/status', body: dto);

  Future<Map<String, dynamic>> getDispatchesByIncident(String incidentUid) =>
      _get('/api/emergency/dispatch/incident/$incidentUid');

  Future<Map<String, dynamic>> getDispatchesByVehicle(String vehicleUid) =>
      _get('/api/emergency/dispatch/vehicle/$vehicleUid');

  Future<Map<String, dynamic>> getActiveDispatches({String? stationUid}) =>
      _get('/api/emergency/dispatch/active',
          params: {if (stationUid != null) 'stationUid': stationUid});

  // ─── Vehicle Location ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> sendVehicleLocationPing(
          Map<String, dynamic> dto) =>
      _post('/api/emergency/location/ping', body: dto);

  Future<Map<String, dynamic>> getLatestVehicleLocation(String vehicleUid) =>
      _get('/api/emergency/location/$vehicleUid/latest');

  Future<Map<String, dynamic>> getVehicleTrail(
          String vehicleUid, {int lastMinutes = 60}) =>
      _get('/api/emergency/location/$vehicleUid/trail',
          params: {'lastMinutes': lastMinutes.toString()});
}
