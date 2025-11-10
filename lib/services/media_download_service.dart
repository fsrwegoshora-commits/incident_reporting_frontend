import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/graphql_service.dart';

class MediaDownloadService {
  final GraphQLService _gqlService;

  MediaDownloadService(this._gqlService);

  // ✅ SIMPLE DOWNLOAD - NO PERMISSIONS NEEDED
  Future<Map<String, dynamic>?> downloadMedia(String fileUrl) async {
    try {
      print('📥 Starting download for: $fileUrl');

      // Download from backend
      final response = await _gqlService.sendAuthenticatedQuery(
        '''
        query DownloadMedia(\$fileUrl: String!) {
          downloadMedia(fileUrl: \$fileUrl) {
            status
            message
            data {
              fileName
              fileSize
              mediaType
              base64Data
              mimeType
            }
          }
        }
        ''',
        {'fileUrl': fileUrl},
      );

      if (response.containsKey('errors')) {
        throw Exception('Download failed: ${response['errors']}');
      }

      final result = response['data']?['downloadMedia'];
      if (result['status'] != 'Success') {
        throw Exception(result['message'] ?? 'Download failed from server');
      }

      final mediaData = result['data'];
      final String base64Data = mediaData['base64Data'];
      final String fileName = mediaData['fileName'];
      final String mediaType = mediaData['mediaType'];

      // Extract and decode base64
      final String pureBase64 = base64Data.contains(',')
          ? base64Data.split(',').last
          : base64Data;

      final bytes = base64.decode(pureBase64);

      // Save file locally - NO PERMISSIONS NEEDED
      final String localPath = await _saveFileLocally(bytes, fileName, mediaType);

      // Save download record
      await _saveDownloadRecord(fileUrl, localPath, fileName, mediaType);

      print('✅ Download successful: $localPath');
      print('📊 File size: ${bytes.length} bytes');

      return {
        'localPath': localPath,
        'fileName': fileName,
        'fileSize': mediaData['fileSize'],
        'mediaType': mediaType,
        'mimeType': mediaData['mimeType'],
      };

    } catch (e) {
      print('❌ Download error: $e');
      rethrow;
    }
  }

  // ✅ USE APPLICATION DIRECTORY ONLY (No permissions needed)
  Future<String> _saveFileLocally(List<int> bytes, String fileName, String mediaType) async {
    try {
      // Get application documents directory - NO PERMISSIONS NEEDED
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String mediaDir = '${appDir.path}/downloaded_media';

      print('📁 App directory: ${appDir.path}');

      // Create main media directory
      final Directory dir = Directory(mediaDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        print('📁 Created media directory: $mediaDir');
      }

      // Create subdirectory for media type
      final String typeDir = '$mediaDir/${mediaType.toLowerCase()}s';
      final Directory typeDirectory = Directory(typeDir);
      if (!await typeDirectory.exists()) {
        await typeDirectory.create(recursive: true);
        print('📁 Created type directory: $typeDir');
      }

      // Save file
      final String filePath = '$typeDir/$fileName';
      final File file = File(filePath);
      await file.writeAsBytes(bytes);

      print('💾 File saved successfully: $filePath');

      // Verify file was saved
      final savedFile = File(filePath);
      final exists = await savedFile.exists();
      final fileSize = await savedFile.length();

      print('🔍 File verification - Exists: $exists, Size: $fileSize bytes');

      return filePath;
    } catch (e) {
      print('❌ Error saving file locally: $e');
      rethrow;
    }
  }

  // ✅ CHECK IF MEDIA IS DOWNLOADED
  Future<bool> isMediaDownloaded(String fileUrl) async {
    try {
      final localPath = await getLocalMediaPath(fileUrl);
      if (localPath == null) return false;

      // Check if file actually exists
      final file = File(localPath);
      final exists = await file.exists();

      if (!exists) {
        // Remove invalid record
        await _removeDownloadRecord(fileUrl);
        return false;
      }

      return true;
    } catch (e) {
      print('❌ Error checking download status: $e');
      return false;
    }
  }

  // ✅ GET LOCAL MEDIA PATH
  Future<String?> getLocalMediaPath(String fileUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloads = prefs.getStringList('downloaded_media') ?? [];

      for (final record in downloads) {
        final parts = record.split('|');
        if (parts.length >= 2 && parts[0] == fileUrl) {
          return parts[1];
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting local path: $e');
      return null;
    }
  }

  // ✅ SAVE DOWNLOAD RECORD
  Future<void> _saveDownloadRecord(String fileUrl, String localPath, String fileName, String mediaType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloads = prefs.getStringList('downloaded_media') ?? [];

      // Remove existing record
      final newDownloads = downloads.where((record) => !record.startsWith('$fileUrl|')).toList();

      // Add new record
      newDownloads.add('$fileUrl|$localPath|$fileName|$mediaType');

      await prefs.setStringList('downloaded_media', newDownloads);
      print('📝 Saved download record for: $fileName');
    } catch (e) {
      print('❌ Error saving download record: $e');
    }
  }

  // ✅ REMOVE DOWNLOAD RECORD
  Future<void> _removeDownloadRecord(String fileUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloads = prefs.getStringList('downloaded_media') ?? [];

      final newDownloads = downloads.where((record) => !record.startsWith('$fileUrl|')).toList();

      await prefs.setStringList('downloaded_media', newDownloads);
      print('🗑️ Removed download record for: $fileUrl');
    } catch (e) {
      print('❌ Error removing download record: $e');
    }
  }
  // ✅ ADD THIS METHOD TO VERIFY FILES
  Future<void> verifyDownloadedFiles() async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String mediaDir = '${appDir.path}/downloaded_media';
      final Directory dir = Directory(mediaDir);

      if (await dir.exists()) {
        final List<FileSystemEntity> files = await dir.list(recursive: true).toList();

        print('📁 === DOWNLOADED FILES VERIFICATION ===');
        print('📁 Base directory: $mediaDir');
        print('📁 Total files/folders: ${files.length}');

        for (final file in files) {
          final stat = await file.stat();
          print('📄 ${file.path} - ${stat.size} bytes');
        }
        print('📁 === END VERIFICATION ===');
      } else {
        print('❌ Download directory does not exist');
      }
    } catch (e) {
      print('❌ Verification error: $e');
    }
  }

  // ✅ DELETE DOWNLOADED MEDIA
  Future<bool> deleteDownloadedMedia(String fileUrl) async {
    try {
      final localPath = await getLocalMediaPath(fileUrl);

      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
          print('🗑️ Deleted file: $localPath');
        }
      }

      await _removeDownloadRecord(fileUrl);
      return true;

    } catch (e) {
      print('❌ Error deleting media: $e');
      return false;
    }
  }

  // ✅ GET DOWNLOADED MEDIA COUNT
  Future<int> getDownloadedMediaCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloads = prefs.getStringList('downloaded_media') ?? [];
      return downloads.length;
    } catch (e) {
      return 0;
    }
  }
}