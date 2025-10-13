import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MediaService {
  static final MediaService _instance = MediaService._internal();
  factory MediaService() => _instance;
  MediaService._internal();

  final Dio _dio = Dio();
  static const String _baseUrl = 'http://your-backend-url'; // ⚠️ Change this!

  /// Upload file to server
  Future<String?> uploadFile(File file, String fileType) async {
    try {
      // Get JWT token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        print('❌ No auth token found');
        return null;
      }

      // Prepare form data
      String fileName = file.path.split('/').last;
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
        'type': fileType, // 'audio', 'video', 'image'
      });

      // Upload
      final response = await _dio.post(
        '$_baseUrl/api/upload',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
        ),
        onSendProgress: (sent, total) {
          print('📤 Upload progress: ${(sent / total * 100).toStringAsFixed(0)}%');
        },
      );

      if (response.statusCode == 200) {
        final fileUrl = response.data['url'];
        print('✅ File uploaded: $fileUrl');
        return fileUrl;
      }

      return null;
    } catch (e) {
      print('❌ Upload failed: $e');
      return null;
    }
  }

  /// Download and save file locally
  Future<String?> downloadFile(String url, String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileName';

      await _dio.download(url, filePath);
      print('✅ File downloaded: $filePath');

      return filePath;
    } catch (e) {
      print('❌ Download failed: $e');
      return null;
    }
  }
}