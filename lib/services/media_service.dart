import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'graphql_service.dart';

class MediaService {
  final GraphQLService graphQLService;

  MediaService(this.graphQLService);

  /// 📤 Upload file to server using GraphQL (Base64-based)
  Future<Map<String, dynamic>?> uploadFileWithDetails(File file, String mediaType) async {
    try {
      print('📤 Starting upload for: ${file.path}');
      print('📁 File size: ${file.lengthSync()} bytes');
      print('🎯 Media type: $mediaType');

      // ✅ Validate file existence
      if (!await file.exists()) {
        print('❌ File does not exist: ${file.path}');
        return null;
      }

      // 👉 Send mutation
      final response = await graphQLService.uploadFileWithGraphQL(file, mediaType);

      // 🔎 Error checking
      if (response.containsKey('errors')) {
        print('❌ GraphQL upload error: ${response['errors']}');
        return null;
      }

      final uploadMedia = response['data']?['uploadMedia'];
      if (uploadMedia == null) {
        print('❌ Invalid response structure');
        return null;
      }

      print('📥 Server response: $uploadMedia');

      final status = (uploadMedia['status'] ?? '').toString().toLowerCase();

      if (status == 'success') {
        final mediaData = uploadMedia['data'];
        print('✅ File uploaded successfully: ${mediaData?['fileUrl']}');
        return mediaData;
      } else {
        print('❌ Upload failed: ${uploadMedia['message']}');
        return null;
      }


    } catch (e, stackTrace) {
      print('❌ Upload exception: $e');
      print('📋 Stack trace: $stackTrace');
      return null;
    }
  }

  /// 🔁 Simplified upload - returns only the file URL
  Future<String?> uploadFile(File file, String mediaType) async {
    final details = await uploadFileWithDetails(file, mediaType);
    return details?['fileUrl'];
  }

  /// 📥 "Download" file (placeholder - returns URL)
  Future<String?> downloadFile(String url, String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileName';
      print('✅ File would be stored at: $filePath');
      return url; // we just return URL for now
    } catch (e) {
      print('❌ Download failed: $e');
      return null;
    }
  }

  /// 📊 Format file size
  String getFileSizeString(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  /// 🧩 Get file extension
  String getFileExtension(String fileName) {
    if (fileName.contains('.')) {
      return fileName.substring(fileName.lastIndexOf('.')).toLowerCase();
    }
    return '';
  }

  /// 🖼️ Check if image
  bool isImageFile(String fileName) {
    final ext = getFileExtension(fileName);
    return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(ext);
  }

  /// 🎥 Check if video
  bool isVideoFile(String fileName) {
    final ext = getFileExtension(fileName);
    return ['.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm'].contains(ext);
  }

  /// 🎵 Check if audio
  bool isAudioFile(String fileName) {
    final ext = getFileExtension(fileName);
    return ['.mp3', '.wav', '.aac', '.ogg', '.m4a'].contains(ext);
  }

  /// 🔎 Detect media type from file
  String getMediaTypeFromFile(File file) {
    final fileName = file.path.split('/').last;

    if (isImageFile(fileName)) return 'IMAGE';
    if (isVideoFile(fileName)) return 'VIDEO';
    if (isAudioFile(fileName)) return 'AUDIO';

    return 'FILE';
  }
}
