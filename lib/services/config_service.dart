import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();

  factory ConfigService() => _instance;
  ConfigService._internal();

  late SharedPreferences _prefs;

  // Default values
  static const String _defaultHost = '10.220.105.163';
  static const int _defaultPort = 8080;
  static const String _keyHost = 'backend_host';
  static const String _keyPort = 'backend_port';

  /// Initialize ConfigService (call this in main())
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Set defaults if not already set
    if (!_prefs.containsKey(_keyHost)) {
      await _prefs.setString(_keyHost, _defaultHost);
    }
    if (!_prefs.containsKey(_keyPort)) {
      await _prefs.setInt(_keyPort, _defaultPort);
    }

    print("✅ ConfigService initialized - Host: $host, Port: $port");
  }

  /// Get GraphQL endpoint
  String get graphqlEndpoint => 'http://$host:$port/graphql';

  /// Get WebSocket endpoint
  String get wsEndpoint => 'ws://$host:$port/ws-notifications';

  /// Get media full URL prefix
  String get mediaUrlPrefix => 'http://$host:$port';

  /// Get video full URL prefix
  String get videoUrlPrefix => 'http://$host:$port';

  /// Get current host
  String get host => _prefs.getString(_keyHost) ?? _defaultHost;

  /// Get current port
  int get port => _prefs.getInt(_keyPort) ?? _defaultPort;

  /// Change backend host and port
  Future<void> setBackendAddress(String newHost, int newPort) async {
    await _prefs.setString(_keyHost, newHost);
    await _prefs.setInt(_keyPort, newPort);
    print("✅ Backend address updated to $newHost:$newPort");
  }

  /// Get display string (e.g., "10.220.105.163:8080")
  String get displayAddress => '$host:$port';

  /// Reset to defaults
  Future<void> resetToDefaults() async {
    await _prefs.setString(_keyHost, _defaultHost);
    await _prefs.setInt(_keyPort, _defaultPort);
    print("✅ Reset to defaults");
  }
}