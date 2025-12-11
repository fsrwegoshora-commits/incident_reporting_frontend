import 'config_service.dart';

class MediaUrlConverter {
  static final MediaUrlConverter _instance = MediaUrlConverter._internal();

  factory MediaUrlConverter() => _instance;
  MediaUrlConverter._internal();

  final ConfigService _config = ConfigService();

  /// Convert old IP URLs to current backend
  /// OLD: http://10.220.100.50:8080/media/xyz.jpg
  /// NEW: http://10.220.105.163:8080/media/xyz.jpg
  String convertMediaUrl(String oldUrl) {
    if (oldUrl.isEmpty) return oldUrl;

    try {
      // If already using current host, return as-is
      if (oldUrl.contains(_config.host)) {
        return oldUrl;
      }

      // Extract the path part (everything after :8080)
      // Example: /media/uploads/abc123.jpg
      final pathMatch = RegExp(r':\d+(/.*?)$').firstMatch(oldUrl);
      if (pathMatch == null) {
        print("⚠️ Could not extract path from: $oldUrl");
        return oldUrl;
      }

      final path = pathMatch.group(1) ?? '';
      final convertedUrl = '${_config.mediaUrlPrefix}$path';

      print("🔄 Converted URL:");
      print("   Old: $oldUrl");
      print("   New: $convertedUrl");

      return convertedUrl;
    } catch (e) {
      print("❌ Error converting URL: $e");
      return oldUrl;
    }
  }

  /// Check if URL is from old IP address
  bool isOldUrl(String url) {
    try {
      // Extract host from URL
      final hostMatch = RegExp(r'https?://([^/:]+)').firstMatch(url);
      if (hostMatch == null) return false;

      final urlHost = hostMatch.group(1);
      return urlHost != null && urlHost != _config.host;
    } catch (e) {
      return false;
    }
  }

  /// Batch convert multiple URLs
  List<String> convertMultipleUrls(List<String> urls) {
    return urls.map((url) => convertMediaUrl(url)).toList();
  }
}