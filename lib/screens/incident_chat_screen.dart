import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:incident_reporting_frontend/screens/video_player_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'dart:io';
import 'dart:async';

import '../services/graphql_service.dart';
import '../services/media_download_service.dart';
import '../services/media_service.dart';
import '../services/voice_recorder_service.dart';
import '../utils/graphql_query.dart';
import '../theme/app_theme.dart';

class IncidentChatScreen extends StatefulWidget {
  final String incidentUid;
  final String incidentTitle;
  final String currentUserUid;


  const IncidentChatScreen({
    Key? key,
    required this.incidentUid,
    required this.incidentTitle,
    required this.currentUserUid,
  }) : super(key: key);

  @override
  _IncidentChatScreenState createState() => _IncidentChatScreenState();
}

class _IncidentChatScreenState extends State<IncidentChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  final _audioPlayer = AudioPlayer();

  // Initialize services
  late GraphQLService _gqlService;
  late MediaService _mediaService;
  late VoiceRecorderService _voiceRecorder;
  late MediaDownloadService _mediaDownloadService;

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isRecording = false;
  int _recordDuration = 0;
  double _uploadProgress = 0.0;
  bool _showProgressDialog = false;

  String? _lastMessageId;
  DateTime? _lastMessageTime;
  int _previousMessageCount = 0;

  Timer? _refreshTimer;
  Timer? _recordingTimer;
  String? _playingAudioUrl;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadMessages();

    // Auto-refresh every 5 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 5), (_) {
      _loadMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _refreshTimer?.cancel();
    _recordingTimer?.cancel();
    _audioPlayer.dispose();
    _voiceRecorder.dispose();
    super.dispose();
  }

  void _initializeServices() {
    _gqlService = GraphQLService();
    _mediaService = MediaService(_gqlService);
    _voiceRecorder = VoiceRecorderService();
    _mediaDownloadService = MediaDownloadService(_gqlService);
  }

  // ==========================================================================
  // DATA LOADING
  // ==========================================================================

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final response = await _gqlService.sendAuthenticatedQuery(
        getAllIncidentMessagesQuery,
        {'incidentUid': widget.incidentUid},
      );

      if (response.containsKey('errors')) {
        if (!silent) {
          _showSnackBar('Failed to load messages', isError: true);
        }
        return;
      }

      final result = response['data']?['getAllIncidentMessages'];
      if (result['status'] != 'Success') {
        if (!silent) {
          _showSnackBar(result['message'] ?? 'Failed to load messages', isError: true);
        }
        return;
      }

      final messages = (result['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

      // TUMIA HAPA: Angalia kama kuna mabadiliko
      final hasNewMessages = _hasNewMessages(messages);

      setState(() {
        _messages = messages;
        _updateLastMessageInfo(messages);
      });

      if (hasNewMessages && messages.isNotEmpty) {
        _scrollToBottom();
      }

    } catch (e) {
      if (!silent) {
        _showSnackBar('Error: ${e.toString()}', isError: true);
      }
    } finally {
      if (!silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateLastMessageInfo(List<Map<String, dynamic>> messages) {
    if (messages.isEmpty) return;

    final lastMsg = messages.last;
    _lastMessageId = lastMsg['uid']?.toString();
    _lastMessageTime = DateTime.tryParse(lastMsg['sentAt'] ?? '');
    _previousMessageCount = messages.length;
  }

  bool _hasNewMessages(List<Map<String, dynamic>> newMessages) {
    if (newMessages.isEmpty) return false;
    if (_messages.isEmpty) return true;

    final newLastId = newMessages.last['uid']?.toString();
    if (newLastId != null && newLastId != _lastMessageId) {
      return true;
    }

    if (newMessages.length != _previousMessageCount) {
      return true;
    }

    final newLastTime = DateTime.tryParse(newMessages.last['sentAt'] ?? '');
    if (newLastTime != null && _lastMessageTime != null) {
      if (newLastTime.isAfter(_lastMessageTime!)) {
        return true;
      }
    }

    return false;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ==========================================================================
  // SEND TEXT MESSAGE
  // ==========================================================================

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();

    if (messageText.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final response = await _gqlService.sendAuthenticatedQuery(
        sendChatMessageMutation,
        {
          'chatMessageDto': {
            'incidentUid': widget.incidentUid,
            'message': messageText,
            'messageType': 'TEXT',
          },
        },
      );

      if (response.containsKey('errors')) {
        _showSnackBar('Failed to send message', isError: true);
        return;
      }

      final result = response['data']?['sendChatMessage'];
      if (result['status'] == 'Success') {
        _messageController.clear();
        await _loadMessages(silent: true);
      } else {
        _showSnackBar(result['message'] ?? 'Failed to send', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isSending = false);
    }
  }

  // ==========================================================================
  // BASE64 MEDIA UPLOAD METHODS
  // ==========================================================================

  Future<void> _uploadAndSendMedia(File file, String type) async {
    _showUploadProgressDialog();

    try {
      print('🚀 Starting Base64 upload for: ${file.path}');

      // Use the Base64 upload method
      final mediaDetails = await _mediaService.uploadFileWithDetails(file, type);

      _hideUploadProgressDialog();

      if (mediaDetails == null) {
        _showSnackBar('Failed to upload ${type.toLowerCase()}', isError: true);
        return;
      }

      await _sendMediaMessageWithDetails(
        mediaUrl: mediaDetails['fileUrl'],
        messageType: type,
        fileName: mediaDetails['fileName'],
        fileSize: mediaDetails['fileSize'],
        originalFileName: mediaDetails['originalFileName'],
        duration: null,
      );
    } catch (e) {
      _hideUploadProgressDialog();
      _showSnackBar('Upload error: ${e.toString()}', isError: true);
    }
  }

  Future<void> _uploadAndSendVoiceNote(String filePath) async {
    _showUploadProgressDialog();

    try {
      final file = File(filePath);
      print('🎙️ Starting voice note upload...');

      // Use the Base64 upload method for voice notes
      final mediaDetails = await _mediaService.uploadFileWithDetails(file, 'AUDIO');

      _hideUploadProgressDialog();

      if (mediaDetails == null) {
        _showSnackBar('Failed to upload voice note', isError: true);
        return;
      }

      await _sendMediaMessageWithDetails(
        mediaUrl: mediaDetails['fileUrl'],
        messageType: 'AUDIO',
        fileName: mediaDetails['fileName'],
        fileSize: mediaDetails['fileSize'],
        originalFileName: 'Voice Note',
        duration: _recordDuration,
      );
    } catch (e) {
      _hideUploadProgressDialog();
      _showSnackBar('Voice note upload error: ${e.toString()}', isError: true);
    }
  }

  void _showUploadProgressDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Uploading file...',
              style: GoogleFonts.poppins(),
            ),
            SizedBox(height: 8),
            Text(
              'Please wait',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _hideUploadProgressDialog() {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _sendMediaMessageWithDetails({
    required String mediaUrl,
    required String messageType,
    required String fileName,
    required int fileSize,
    required String originalFileName,
    required int? duration,
  }) async {
    setState(() => _isSending = true);

    try {
      String fullMediaUrl = mediaUrl;
      if (!mediaUrl.startsWith('http')) {
        fullMediaUrl = 'http://10.11.171.163:8080$mediaUrl';
      }

      // Prepare the complete message DTO
      final chatMessageDto = {
        'incidentUid': widget.incidentUid,
        'message': originalFileName,
        'messageType': messageType,
        'mediaUrl': fullMediaUrl,
        'mediaFileName': fileName,
        'mediaFileSize': fileSize,
      };

      // Add duration for audio messages
      if (duration != null && duration > 0) {
        chatMessageDto['mediaDuration'] = duration;
      }

      print('📤 Sending media message to GraphQL:');
      print('🔹 Incident UID: ${widget.incidentUid}');
      print('🔹 Message Type: $messageType');
      print('🔹 Media URL: $fullMediaUrl');
      print('🔹 File Name: $fileName');
      print('🔹 File Size: $fileSize');
      print('🔹 Full DTO: $chatMessageDto');

      final response = await _gqlService.sendAuthenticatedQuery(
        sendChatMessageMutation,
        {
          'chatMessageDto': chatMessageDto,
        },
      );

      print('📥 Send Message Response: $response');

      if (response.containsKey('errors')) {
        print('❌ GraphQL errors: ${response['errors']}');
        _showSnackBar('Failed to send message: ${response['errors']}', isError: true);
        return;
      }

      final result = response['data']?['sendChatMessage'];
      print('🔍 Send Message Result: $result');

      if (result['status'] == 'Success') {
        _showSnackBar('${messageType.toLowerCase()} sent successfully');
        await _loadMessages(silent: true);
      } else {
        print('❌ Send failed: ${result['message']}');
        _showSnackBar(result['message'] ?? 'Failed to send media', isError: true);
      }
    } catch (e) {
      print('❌ Send error: $e');
      _showSnackBar('Send error: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isSending = false);
    }
  }

  // ==========================================================================
  // VOICE RECORDING
  // ==========================================================================

  Future<void> _startVoiceRecording() async {
    // Check permission
    final hasPermission = await Permission.microphone.request();
    if (!hasPermission.isGranted) {
      _showPermissionDeniedDialog('Microphone');
      return;
    }

    final success = await _voiceRecorder.startRecording();

    if (!success) {
      _showSnackBar('Failed to start recording', isError: true);
      return;
    }

    setState(() {
      _isRecording = true;
      _recordDuration = 0;
    });

    _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _recordDuration = _voiceRecorder.recordDuration;
      });
    });
  }

  Future<void> _stopVoiceRecording() async {
    _recordingTimer?.cancel();

    final path = await _voiceRecorder.stopRecording();

    setState(() => _isRecording = false);

    if (path == null) {
      _showSnackBar('Failed to save recording', isError: true);
      return;
    }

    _showVoiceNotePreview(path);
  }

  Future<void> _cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    await _voiceRecorder.cancelRecording();

    setState(() {
      _isRecording = false;
      _recordDuration = 0;
    });
  }

  void _showVoiceNotePreview(String filePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Color(0xFF2E5BFF).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mic_rounded,
                  size: 40,
                  color: Color(0xFF2E5BFF),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Voice Note Recorded',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1F36),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Duration: ${_voiceRecorder.formatDuration(_recordDuration)}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Color(0xFF8F9BB3),
                ),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        File(filePath).delete();
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Color(0xFFE4E9F2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Delete',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.errorRed,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _uploadAndSendVoiceNote(filePath);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2E5BFF),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Send',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // IMAGE/VIDEO PICKER
  // ==========================================================================

  Future<void> _pickImage() async {
    final hasPermission = await Permission.photos.request();
    if (!hasPermission.isGranted) {
      _showPermissionDeniedDialog('Photos');
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return;

      await _uploadAndSendMedia(File(image.path), 'IMAGE');
    } catch (e) {
      _showSnackBar('Failed to pick image: $e', isError: true);
    }
  }

  Future<void> _takePhoto() async {
    final hasPermission = await Permission.camera.request();
    if (!hasPermission.isGranted) {
      _showPermissionDeniedDialog('Camera');
      return;
    }

    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo == null) return;

      await _uploadAndSendMedia(File(photo.path), 'IMAGE');
    } catch (e) {
      _showSnackBar('Failed to take photo: $e', isError: true);
    }
  }

  Future<void> _pickVideo() async {
    final hasPermission = await Permission.photos.request();
    if (!hasPermission.isGranted) {
      _showPermissionDeniedDialog('Photos');
      return;
    }

    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: Duration(minutes: 5),
      );

      if (video == null) return;

      await _uploadAndSendMedia(File(video.path), 'VIDEO');
    } catch (e) {
      _showSnackBar('Failed to pick video: $e', isError: true);
    }
  }

  // ==========================================================================
  // AUDIO PLAYBACK
  // ==========================================================================

  Future<void> _playAudio(String audioUrl) async {
    try {
      if (_playingAudioUrl == audioUrl) {
        await _audioPlayer.stop();
        setState(() => _playingAudioUrl = null);
        return;
      }

      // Stop any currently playing audio
      if (_playingAudioUrl != null) {
        await _audioPlayer.stop();
      }

      // Check if audio is downloaded locally
      final localPath = await _getLocalMediaPath(audioUrl);
      if (localPath == null) {
        _showSnackBar('Download audio to play', isError: true);
        return;
      }
      await _audioPlayer.play(DeviceFileSource(localPath));

      setState(() => _playingAudioUrl = audioUrl);

      _audioPlayer.onPlayerComplete.listen((_) {
        setState(() => _playingAudioUrl = null);
      });

    } catch (e) {
      print('❌ Audio playback error: $e');
      _showSnackBar('Failed to play audio: ${e.toString()}', isError: true);
    }
  }



  // ==========================================================================
// MEDIA DOWNLOAD METHODS
// ==========================================================================


  Future<void> _downloadMedia(String mediaUrl, String mediaType, String? fileName) async {
    try {
      _showSnackBar('Downloading ${mediaType.toLowerCase()}...');

      final result = await _mediaDownloadService.downloadMedia(mediaUrl);

      if (result != null) {
        _showSnackBar('${mediaType.toLowerCase()} downloaded successfully!');
        setState(() {});

        // ✅ VERIFY THE DOWNLOAD
        await _mediaDownloadService.verifyDownloadedFiles();
      }
    } catch (e) {
      _showSnackBar('Download failed: ${e.toString()}', isError: true);
    }
  }

  Future<bool> _isMediaDownloaded(String mediaUrl) async {
    return await _mediaDownloadService.isMediaDownloaded(mediaUrl);
  }

  Future<String?> _getLocalMediaPath(String mediaUrl) async {
    return await _mediaDownloadService.getLocalMediaPath(mediaUrl);
  }

  void _showDownloadOptions(String mediaUrl, String mediaType, String? fileName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle Bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Color(0xFFE4E9F2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),

              Text(
                'Media Options',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1F36),
                ),
              ),
              SizedBox(height: 20),

              // Download Option
              _buildDownloadOption(
                icon: Icons.download_rounded,
                label: 'Download',
                subtitle: 'Save to device',
                color: Color(0xFF2E5BFF),
                onTap: () {
                  Navigator.pop(context);
                  _downloadMedia(mediaUrl, mediaType, fileName);
                },
              ),

              // View Local Option (if downloaded)
              FutureBuilder<bool>(
                future: _isMediaDownloaded(mediaUrl),
                builder: (context, snapshot) {
                  final isDownloaded = snapshot.data ?? false;
                  if (!isDownloaded) return SizedBox();

                  return _buildDownloadOption(
                    icon: Icons.folder_rounded,
                    label: 'View Local',
                    subtitle: 'Open downloaded file',
                    color: Color(0xFF4ECDC4),
                    onTap: () async {
                      Navigator.pop(context);
                      final localPath = await _getLocalMediaPath(mediaUrl);
                      if (localPath != null) {
                        _openLocalMedia(localPath, mediaType);
                      }
                    },
                  );
                },
              ),

              // Delete Download Option (if downloaded)
              FutureBuilder<bool>(
                future: _isMediaDownloaded(mediaUrl),
                builder: (context, snapshot) {
                  final isDownloaded = snapshot.data ?? false;
                  if (!isDownloaded) return SizedBox();

                  return _buildDownloadOption(
                    icon: Icons.delete_rounded,
                    label: 'Delete Local',
                    subtitle: 'Remove from device',
                    color: AppTheme.errorRed,
                    onTap: () {
                      Navigator.pop(context);
                      _deleteDownloadedMedia(mediaUrl);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1F36),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Color(0xFF8F9BB3),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteDownloadedMedia(String mediaUrl) async {
    try {
      final success = await _mediaDownloadService.deleteDownloadedMedia(mediaUrl);
      if (success) {
        _showSnackBar('Media deleted from device');
        setState(() {}); // Refresh UI
      } else {
        _showSnackBar('Failed to delete media', isError: true);
      }
    } catch (e) {
      _showSnackBar('Delete error: ${e.toString()}', isError: true);
    }
  }

  void _openLocalMedia(String localPath, String mediaType) {
    if (mediaType == 'IMAGE') {
      _showLocalImage(localPath);
    } else if (mediaType == 'VIDEO') {
      _showLocalVideo(localPath);
    } else if (mediaType == 'AUDIO') {
      _playLocalAudio(localPath);
    }
  }

  void _showLocalImage(String localPath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Local Image',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
          body: Center(
            child: PhotoView(
              imageProvider: FileImage(File(localPath)),
              backgroundDecoration: BoxDecoration(color: Colors.black),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2.0,
            ),
          ),
        ),
      ),
    );
  }

  void _showLocalVideo(String localPath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videoUrl: localPath),
      ),
    );
  }

  void _playLocalAudio(String localPath) async {
    try {
      if (_playingAudioUrl == localPath) {
        await _audioPlayer.stop();
        setState(() => _playingAudioUrl = null);
        return;
      }

      if (_playingAudioUrl != null) {
        await _audioPlayer.stop();
      }

      await _audioPlayer.play(DeviceFileSource(localPath));
      setState(() => _playingAudioUrl = localPath);

      _audioPlayer.onPlayerComplete.listen((_) {
        setState(() => _playingAudioUrl = null);
      });
    } catch (e) {
      _showSnackBar('Failed to play: $e', isError: true);
    }
  }

  // ==========================================================================
  // BUILD METHOD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? _buildLoading()
                : _messages.isEmpty
                ? _buildEmptyState()
                : _buildMessagesList(),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  // ==========================================================================
  // APP BAR
  // ==========================================================================

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Color(0xFF1A1F36)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Incident Chat',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1F36),
            ),
          ),
          Text(
            widget.incidentTitle,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Color(0xFF8F9BB3),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: Color(0xFF2E5BFF)),
          onPressed: () => _loadMessages(),
        ),
      ],
    );
  }

  // ==========================================================================
  // MESSAGES LIST
  // ==========================================================================

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMyMessage = message['sender']['uid'] == widget.currentUserUid;

        return _buildMessageBubble(
          message: message,
          isMyMessage: isMyMessage,
        );
      },
    );
  }

  // ==========================================================================
  // MESSAGE BUBBLE - ENHANCED FOR MEDIA
  // ==========================================================================

  Widget _buildMessageBubble({
    required Map<String, dynamic> message,
    required bool isMyMessage,
  }) {
    final sender = message['sender'];
    final senderName = sender['name'];
    final sentAt = message['sentAt'];
    final messageType = message['messageType'];
    final content = message['message'];
    final mediaUrl = message['mediaUrl'];
    final mediaFileName = message['mediaFileName'];
    final fileSize = message['mediaFileSize'];
    final duration = message['mediaDuration'];

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMyMessage) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF2E5BFF).withOpacity(0.1),
              child: Text(
                senderName[0].toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E5BFF),
                ),
              ),
            ),
            SizedBox(width: 8),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment: isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMyMessage)
                  Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 4),
                    child: Text(
                      senderName,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8F9BB3),
                      ),
                    ),
                  ),

                _buildMessageContent(
                  messageType: messageType,
                  content: content,
                  mediaUrl: mediaUrl,
                  mediaFileName: mediaFileName,
                  fileSize: fileSize,
                  duration: duration,
                  isMyMessage: isMyMessage,
                ),

                SizedBox(height: 4),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    _formatTime(sentAt),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Color(0xFF8F9BB3),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (isMyMessage) ...[
            SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF2E5BFF).withOpacity(0.1),
              child: Icon(Icons.person, size: 16, color: Color(0xFF2E5BFF)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageContent({
    required String messageType,
    required String content,
    required String? mediaUrl,
    required String? mediaFileName,
    required int? fileSize,
    required int? duration,
    required bool isMyMessage,
  }) {
    switch (messageType) {
      case 'TEXT':
        return _buildTextMessage(content, isMyMessage);
      case 'IMAGE':
        return _buildImageMessage(mediaUrl ?? content, mediaFileName, fileSize);
      case 'AUDIO':
        return _buildAudioMessage(
            mediaUrl ?? content,
            isMyMessage,
            duration,
            fileSize,
            mediaFileName ?? 'Audio Message'
        );
      case 'VIDEO':
        return _buildVideoMessage(mediaUrl ?? content, mediaFileName, fileSize);
      case 'SYSTEM':
        return _buildSystemMessage(content);
      default:
        return _buildTextMessage(content ?? 'Unknown message type', isMyMessage);
    }
  }

  Widget _buildTextMessage(String text, bool isMyMessage) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMyMessage ? Color(0xFF2E5BFF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: isMyMessage ? Colors.white : Color(0xFF1A1F36),
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildImageMessage(String imageUrl, String? fileName, int? fileSize) {
    return FutureBuilder<String?>(
      future: _getLocalMediaPath(imageUrl),
      builder: (context, snapshot) {
        final localPath = snapshot.data;
        final isDownloaded = localPath != null;
        final isSender = _isMessageFromCurrentUser(imageUrl); // NEW: Check if sender

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE CONTAINER
            GestureDetector(
              onTap: (isDownloaded || isSender) // CHANGED: Sender can always view
                  ? () => isSender
                  ? _showNetworkImagePreview(imageUrl, fileName) // Sender views directly
                  : _showLocalImage(localPath!) // Receiver views downloaded
                  : null,
              child: Container(
                width: 280,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: (isDownloaded || isSender) // CHANGED: Show image if downloaded OR sender
                      ? isSender
                      ? Image.network( // Sender sees network image
                    imageUrl,
                    fit: BoxFit.cover,
                    width: 280,
                    height: 200,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: Colors.grey[200],
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return _buildMediaPlaceholder('IMAGE', 'Failed to load');
                    },
                  )
                      : Image.file( // Receiver sees local file
                    File(localPath!),
                    fit: BoxFit.cover,
                    width: 280,
                    height: 200,
                  )
                      : _buildMediaPlaceholder('IMAGE', 'Tap to download'),
                ),
              ),
            ),

            // File info + Download button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // File name & size
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (fileName != null)
                          Text(
                            fileName,
                            style: GoogleFonts.poppins(fontSize: 12, color: Color(0xFF8F9BB3)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (fileSize != null)
                          Text(
                            _mediaService.getFileSizeString(fileSize),
                            style: GoogleFonts.poppins(fontSize: 11, color: Color(0xFF8F9BB3).withOpacity(0.7)),
                          ),
                      ],
                    ),
                  ),

                  // Download / Status button - HIDE for sender
                  if (!isSender) // CHANGED: Only show download button for receiver
                    GestureDetector(
                      onTap: () => isDownloaded
                          ? _showDownloadOptions(imageUrl, 'IMAGE', fileName)
                          : _downloadMedia(imageUrl, 'IMAGE', fileName),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDownloaded ? Colors.green.withOpacity(0.15) : Color(0xFF2E5BFF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isDownloaded ? Icons.check : Icons.download_rounded,
                              size: 16,
                              color: isDownloaded ? Colors.green : Color(0xFF2E5BFF),
                            ),
                            SizedBox(width: 4),
                            Text(
                              isDownloaded ? 'Saved' : 'Download',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: isDownloaded ? Colors.green : Color(0xFF2E5BFF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // For sender, show "You sent" indicator
                  if (isSender)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFF2E5BFF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check, size: 16, color: Color(0xFF2E5BFF)),
                          SizedBox(width: 4),
                          Text(
                            'You sent',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Color(0xFF2E5BFF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAudioMessage(String audioUrl, bool isMyMessage, int? duration, int? fileSize, String fileName) {
    return FutureBuilder<String?>(
      future: _getLocalMediaPath(audioUrl),
      builder: (context, snapshot) {
        final localPath = snapshot.data;
        final isDownloaded = localPath != null;
        final isPlaying = _playingAudioUrl == audioUrl;
        final isSender = _isMessageFromCurrentUser(audioUrl); // NEW
        final durationText = duration != null ? _formatDuration(Duration(seconds: duration)) : 'Unknown';

        return Container(
          constraints: BoxConstraints(maxWidth: 280),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMyMessage ? Color(0xFF2E5BFF) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Row(
            children: [
              // Play button (enabled if downloaded OR sender)
              GestureDetector(
                onTap: (isDownloaded || isSender) // CHANGED
                    ? () => isSender
                    ? _playNetworkAudio(audioUrl) // Sender plays directly
                    : _playLocalAudio(localPath!) // Receiver plays downloaded
                    : null,
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isMyMessage ? Colors.white.withOpacity(0.2) : Color(0xFF2E5BFF).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    (isDownloaded || isSender) // CHANGED
                        ? (isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded)
                        : Icons.download_rounded,
                    color: isMyMessage ? Colors.white : Color(0xFF2E5BFF),
                    size: 20,
                  ),
                ),
              ),
              SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fileName, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: isMyMessage ? Colors.white : Color(0xFF1A1F36)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    SizedBox(height: 2),
                    Text(
                      isSender ? durationText : (isDownloaded ? durationText : 'Download to play'), // CHANGED
                      style: GoogleFonts.poppins(fontSize: 10, color: isMyMessage ? Colors.white.withOpacity(0.8) : Color(0xFF8F9BB3)),
                    ),
                    if (fileSize != null && (isDownloaded || isSender)) // CHANGED
                      Text(_mediaService.getFileSizeString(fileSize), style: GoogleFonts.poppins(fontSize: 9, color: isMyMessage ? Colors.white.withOpacity(0.6) : Color(0xFF8F9BB3).withOpacity(0.8))),
                  ],
                ),
              ),

              // Download button (only for receiver)
              if (!isDownloaded && !isSender) // CHANGED
                GestureDetector(
                  onTap: () => _downloadMedia(audioUrl, 'AUDIO', fileName),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFF2E5BFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Download', style: GoogleFonts.poppins(fontSize: 11, color: Color(0xFF2E5BFF), fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoMessage(String videoUrl, String? fileName, int? fileSize) {
    return FutureBuilder<String?>(
      future: _getLocalMediaPath(videoUrl),
      builder: (context, snapshot) {
        final localPath = snapshot.data;
        final isDownloaded = localPath != null;
        final isSender = _isMessageFromCurrentUser(videoUrl); // NEW

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: (isDownloaded || isSender) // CHANGED
                  ? () => isSender
                  ? _showNetworkVideoPreview(videoUrl, fileName) // Sender plays directly
                  : _showLocalVideo(localPath!) // Receiver plays downloaded
                  : null,
              child: Container(
                width: 280,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: (isDownloaded || isSender) // CHANGED
                      ? Stack(
                    children: [
                      // Video thumbnail
                      Container(
                        color: Colors.black,
                        child: Center(
                          child: Icon(Icons.play_circle_fill, size: 70, color: Colors.white),
                        ),
                      ),
                      // Play button overlay
                      Container(
                        color: Colors.black.withOpacity(0.3),
                        child: Center(
                          child: Icon(Icons.play_arrow_rounded, size: 50, color: Colors.white),
                        ),
                      ),
                    ],
                  )
                      : Stack(
                    children: [
                      Container(
                        color: Colors.grey[200],
                        child: Center(
                          child: Icon(Icons.videocam_off, size: 60, color: Colors.grey[400]),
                        ),
                      ),
                      Container(
                        color: Colors.black.withOpacity(0.6),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.download_rounded, color: Colors.white, size: 40),
                              SizedBox(height: 8),
                              Text(
                                'Download to play',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // File info + button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (fileName != null)
                          Text(fileName, style: GoogleFonts.poppins(fontSize: 12, color: Color(0xFF8F9BB3)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (fileSize != null)
                          Text(_mediaService.getFileSizeString(fileSize), style: GoogleFonts.poppins(fontSize: 11, color: Color(0xFF8F9BB3).withOpacity(0.7))),
                      ],
                    ),
                  ),

                  // Only show download button for receiver
                  if (!isSender) // CHANGED
                    GestureDetector(
                      onTap: () => isDownloaded
                          ? _showDownloadOptions(videoUrl, 'VIDEO', fileName)
                          : _downloadMedia(videoUrl, 'VIDEO', fileName),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDownloaded
                              ? Colors.green.withOpacity(0.15)
                              : Color(0xFF2E5BFF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(isDownloaded ? Icons.check : Icons.download_rounded, size: 16, color: isDownloaded ? Colors.green : Color(0xFF2E5BFF)),
                            SizedBox(width: 4),
                            Text(isDownloaded ? 'Saved' : 'Download', style: GoogleFonts.poppins(fontSize: 12, color: isDownloaded ? Colors.green : Color(0xFF2E5BFF), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),

                  // For sender
                  if (isSender)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFF2E5BFF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check, size: 16, color: Color(0xFF2E5BFF)),
                          SizedBox(width: 4),
                          Text(
                            'You sent',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Color(0xFF2E5BFF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSystemMessage(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFFFE69C)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF856404)),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Color(0xFF856404),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
// ==========================================================================
// MEDIA PLACEHOLDER METHOD
// ==========================================================================

  Widget _buildMediaPlaceholder(String mediaType, String message) {
    IconData icon;
    Color color;

    switch (mediaType) {
      case 'IMAGE':
        icon = Icons.photo_rounded;
        color = Color(0xFF4ECDC4);
        break;
      case 'VIDEO':
        icon = Icons.videocam_rounded;
        color = Color(0xFFFFB75E);
        break;
      case 'AUDIO':
        icon = Icons.audiotrack_rounded;
        color = Color(0xFF2E5BFF);
        break;
      default:
        icon = Icons.insert_drive_file_rounded;
        color = Color(0xFF8F9BB3);
    }

    return Container(
      width: 280,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32,
              color: color,
            ),
          ),
          SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Color(0xFF8F9BB3),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // MESSAGE INPUT
  // ==========================================================================

  Widget _buildMessageInput() {
    if (_isRecording) {
      return _buildRecordingInterface();
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Attachment Button
            GestureDetector(
              onTap: _showAttachmentOptions,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(0xFFF8F9FC),
                  shape: BoxShape.circle,
                  border: Border.all(color: Color(0xFFE4E9F2)),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: Color(0xFF2E5BFF),
                  size: 20,
                ),
              ),
            ),
            SizedBox(width: 12),

            // Text Input
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Color(0xFFF8F9FC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Color(0xFFE4E9F2)),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Color(0xFF8F9BB3),
                    ),
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            SizedBox(width: 12),

            // Send/Voice Button
            GestureDetector(
              onTap: _messageController.text.trim().isEmpty
                  ? _startVoiceRecording
                  : _sendMessage,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF2E5BFF).withOpacity(0.3),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: _isSending
                    ? Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
                    : Icon(
                  _messageController.text.trim().isEmpty
                      ? Icons.mic_rounded
                      : Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // RECORDING INTERFACE
  // ==========================================================================

  Widget _buildRecordingInterface() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF5252)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFF5252).withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Recording Animation
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            SizedBox(width: 16),

            // Recording Timer
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Recording...',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _voiceRecorder.formatDuration(_recordDuration),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Cancel Button
            GestureDetector(
              onTap: _cancelVoiceRecording,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 4),
                    Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 12),

            // Stop Button
            GestureDetector(
              onTap: _stopVoiceRecording,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.stop_rounded,
                  color: Color(0xFFFF5252),
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
// NETWORK MEDIA PREVIEW FOR SENDER
// ==========================================================================

  void _showNetworkImagePreview(String imageUrl, String? fileName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              fileName ?? 'Image Preview',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
            ),
          ),
          body: Center(
            child: PhotoView(
              imageProvider: NetworkImage(imageUrl),
              backgroundDecoration: BoxDecoration(color: Colors.black),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2.0,
            ),
          ),
        ),
      ),
    );
  }

  void _showNetworkVideoPreview(String videoUrl, String? fileName) {
    // Convert to full URL if needed
    String fullVideoUrl = videoUrl;
    if (!videoUrl.startsWith('http')) {
      fullVideoUrl = 'http://10.11.171.163:8080$videoUrl';
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videoUrl: fullVideoUrl),
      ),
    );
  }

  void _playNetworkAudio(String audioUrl) {
    _playAudio(audioUrl); // Use existing audio playback
  }

// ==========================================================================
// HELPER: CHECK IF MESSAGE IS FROM CURRENT USER
// ==========================================================================

  bool _isMessageFromCurrentUser(String mediaUrl) {
    // Find the message that contains this media URL
    final message = _messages.firstWhere(
          (msg) => msg['mediaUrl'] == mediaUrl,
      orElse: () => {},
    );

    if (message.isEmpty) return false;

    final senderUid = message['sender']?['uid'];
    return senderUid == widget.currentUserUid;
  }

  // ==========================================================================
  // ATTACHMENT OPTIONS
  // ==========================================================================

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle Bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Color(0xFFE4E9F2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),

              Text(
                'Send Attachment',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1F36),
                ),
              ),
              SizedBox(height: 20),

              // Camera Option
              _buildAttachmentOption(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                subtitle: 'Take a photo',
                color: Color(0xFF4ECDC4),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),

              // Gallery Option
              _buildAttachmentOption(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                subtitle: 'Choose from gallery',
                color: Color(0xFF2E5BFF),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),

              // Video Option
              _buildAttachmentOption(
                icon: Icons.videocam_rounded,
                label: 'Video',
                subtitle: 'Send a video',
                color: Color(0xFFFFB75E),
                onTap: () {
                  Navigator.pop(context);
                  _pickVideo();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1F36),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Color(0xFF8F9BB3),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // FULL SCREEN MEDIA VIEWERS
  // ==========================================================================

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Image Viewer',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            actions: [
              // Download Button
              FutureBuilder<bool>(
                future: _isMediaDownloaded(imageUrl),
                builder: (context, snapshot) {
                  final isDownloaded = snapshot.data ?? false;
                  return IconButton(
                    icon: Icon(
                      isDownloaded ? Icons.download_done : Icons.download_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => isDownloaded
                        ? _showSnackBar('Already downloaded')
                        : _downloadMedia(imageUrl, 'IMAGE', null),
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.share_rounded, color: Colors.white),
                onPressed: () async {
                  try {
                    // TODO: Implement share functionality
                    _showSnackBar('Share feature coming soon!');
                  } catch (e) {
                    _showSnackBar('Share failed: $e', isError: true);
                  }
                },
              ),
            ],
          ),
          body: FutureBuilder<String?>(
            future: _getLocalMediaPath(imageUrl),
            builder: (context, snapshot) {
              final localPath = snapshot.data;
              final imageProvider = localPath != null
                  ? FileImage(File(localPath))
                  : NetworkImage(imageUrl) as ImageProvider;

              return Center(
                child: PhotoView(
                  imageProvider: imageProvider,
                  backgroundDecoration: BoxDecoration(color: Colors.black),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2.0,
                  initialScale: PhotoViewComputedScale.contained,
                  heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
                  loadingBuilder: (context, event) => Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ),
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Failed to load image',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap to retry',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showVideoPlayer(String videoUrl) {
    // Convert to full URL if needed
    String fullVideoUrl = videoUrl;
    if (!videoUrl.startsWith('http')) {
      fullVideoUrl = 'http://10.11.171.163:8080$videoUrl';
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videoUrl: fullVideoUrl),
      ),
    );
  }

  // ==========================================================================
  // LOADING & EMPTY STATES
  // ==========================================================================

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(Color(0xFF2E5BFF)),
          ),
          SizedBox(height: 16),
          Text(
            'Loading messages...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Color(0xFF8F9BB3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Color(0xFF2E5BFF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 50,
              color: Color(0xFF2E5BFF),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'No messages yet',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1F36),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start the conversation',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Color(0xFF8F9BB3),
            ),
          ),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Color(0xFF2E5BFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Color(0xFF2E5BFF),
                ),
                SizedBox(width: 8),
                Text(
                  'Messages will appear here',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Color(0xFF2E5BFF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // HELPER METHODS
  // ==========================================================================

  String _formatTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        final hour = dateTime.hour.toString().padLeft(2, '0');
        final minute = dateTime.minute.toString().padLeft(2, '0');
        return '${dateTime.day}/${dateTime.month} $hour:$minute';
      }
    } catch (e) {
      return dateTimeString;
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return "${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}";
    } else {
      return "${twoDigits(minutes)}:${twoDigits(seconds)}";
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showPermissionDeniedDialog(String permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppTheme.errorRed),
            SizedBox(width: 12),
            Text(
              'Permission Required',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          '$permission permission is required for this feature. '
              'Please enable it in app settings.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2E5BFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}