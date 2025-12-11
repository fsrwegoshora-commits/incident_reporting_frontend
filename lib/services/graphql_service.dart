import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config_service.dart';

class GraphQLService {
  final ConfigService _config = ConfigService();
  String get endpoint => _config.graphqlEndpoint;


  /// 🔁 Send a GraphQL mutation with optional token
  Future<Map<String, dynamic>> sendMutation(
      String query,
      Map<String, dynamic> variables, {
        String? token,
      }) async {
    final headers = {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };

    print("📡 Sending mutation to $endpoint");
    print("📄 Query: $query");
    print("📦 Variables: $variables");

    final response = await http.post(
      Uri.parse(endpoint),
      headers: headers,
      body: jsonEncode({
        "query": query,
        "variables": variables,
      }),
    );

    print("✅ Status code: ${response.statusCode}");

    return jsonDecode(response.body);
  }

  /// 🔁 Send a GraphQL query with optional token
  Future<Map<String, dynamic>> sendQuery(
      String query,
      Map<String, dynamic> variables, {
        String? token,
      }) async {
    final headers = {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };

    final response = await http.post(
      Uri.parse(endpoint),
      headers: headers,
      body: jsonEncode({
        "query": query,
        "variables": variables,
      }),
    );

    return jsonDecode(response.body);
  }

  /// 🔐 Send mutation using token from SharedPreferences
  Future<Map<String, dynamic>> sendAuthenticatedMutation(
      String query,
      Map<String, dynamic> variables,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("jwt_token");
    return sendMutation(query, variables, token: token);
  }

  /// 🔐 Send query using token from SharedPreferences
  Future<Map<String, dynamic>> sendAuthenticatedQuery(
      String query,
      Map<String, dynamic> variables,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("jwt_token");
    return sendQuery(query, variables, token: token);
  }

  /// 📤 Upload file via GraphQL using Base64 (SPQR-friendly)
  Future<Map<String, dynamic>> uploadFileWithGraphQL(
      File file,
      String mediaType,
      ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("jwt_token");

      // Read file and encode it as Base64
      final bytes = await file.readAsBytes();
      final base64File = base64Encode(bytes);
      final fileName = file.path.split('/').last;

      // Prepare GraphQL mutation
      final mutation = '''
        mutation UploadMedia(\$base64File: String!, \$fileName: String!, \$mediaType: String!) {
          uploadMedia(base64File: \$base64File, fileName: \$fileName, mediaType: \$mediaType) {
            status
            message
            data {
              fileUrl
              fileName
              originalFileName
              fileSize
              mediaType
            }
          }
        }
      ''';

      final variables = {
        "base64File": "data:${_getMimeType(fileName)};base64,$base64File",
        "fileName": fileName,
        "mediaType": mediaType.toUpperCase(),
      };

      final headers = {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      };

      print("📤 Uploading via GraphQL (base64): ${file.path}");
      print("📁 Media type: $mediaType");

      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: jsonEncode({
          "query": mutation,
          "variables": variables,
        }),
      );

      print("✅ Upload response code: ${response.statusCode}");
      print("📄 Response body: ${response.body}");

      return jsonDecode(response.body);
    } catch (e) {
      print("❌ Upload error: $e");
      return {'errors': [{'message': 'Upload failed: $e'}]};
    }
  }

  /// 🧩 Helper method to detect MIME type based on extension
  String _getMimeType(String fileName) {
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
}
