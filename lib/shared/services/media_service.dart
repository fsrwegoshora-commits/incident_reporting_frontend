import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../../core/network/api_service.dart';


class MediaService {
  final ApiService _api = ApiService();

  /// Upload file to server via REST (Base64-based)
  Future<Map<String, dynamic>?> uploadFileWithDetails(File file, String mediaType) async {
    try {
      print('📤 Starting upload for: ${file.path}');
      print('📁 File size: ${file.lengthSync()} bytes');
      print('🎯 Media type: $mediaType');

      if (!await file.exists()) {
        print('❌ File does not exist: ${file.path}');
        return null;
      }

      final response = await _api.uploadMedia(file, mediaType);

      final status = (response['status'] ?? '').toString().toLowerCase();

      if (status == 'success') {
        final mediaData = response['data'];
        print('✅ File uploaded successfully: ${mediaData?['fileUrl']}');
        return mediaData is Map<String, dynamic> ? mediaData : null;
      } else {
        print('❌ Upload failed: ${response['message']}');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ Upload exception: $e');
      print('📋 Stack trace: $stackTrace');
      return null;
    }
  }

  /// Simplified upload — returns only the file URL
  Future<String?> uploadFile(File file, String mediaType) async {
    final details = await uploadFileWithDetails(file, mediaType);
    return details?['fileUrl'];
  }

  /// Download file (returns URL)
  Future<String?> downloadFile(String url, String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileName';
      print('✅ File would be stored at: $filePath');
      return url;
    } catch (e) {
      print('❌ Download failed: $e');
      return null;
    }
  }

  String getFileSizeString(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  String getFileExtension(String fileName) {
    if (fileName.contains('.')) {
      return fileName.substring(fileName.lastIndexOf('.')).toLowerCase();
    }
    return '';
  }

  bool isImageFile(String fileName) {
    final ext = getFileExtension(fileName);
    return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(ext);
  }

  bool isVideoFile(String fileName) {
    final ext = getFileExtension(fileName);
    return ['.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm'].contains(ext);
  }

  bool isAudioFile(String fileName) {
    final ext = getFileExtension(fileName);
    return ['.mp3', '.wav', '.aac', '.ogg', '.m4a'].contains(ext);
  }

  String getMediaTypeFromFile(File file) {
    final fileName = file.path.split('/').last;
    if (isImageFile(fileName)) return 'IMAGE';
    if (isVideoFile(fileName)) return 'VIDEO';
    if (isAudioFile(fileName)) return 'AUDIO';
    return 'FILE';
  }
}
