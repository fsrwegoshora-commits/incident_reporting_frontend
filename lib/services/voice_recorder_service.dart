import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceRecorderService {
  static final VoiceRecorderService _instance = VoiceRecorderService._internal();
  factory VoiceRecorderService() => _instance;
  VoiceRecorderService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  String? _recordingPath;
  bool _isRecording = false;
  Timer? _timer;
  int _recordDuration = 0;

  bool get isRecording => _isRecording;
  int get recordDuration => _recordDuration;

  /// Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Start recording
  Future<bool> startRecording() async {
    try {
      if (!await requestPermission()) {
        print('❌ Microphone permission denied');
        return false;
      }

      // Check if already recording
      if (await _recorder.isRecording()) {
        print('⚠️ Already recording');
        return false;
      }

      // Get temporary directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${directory.path}/voice_note_$timestamp.m4a';

      // Start recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _recordingPath!,
      );

      _isRecording = true;
      _recordDuration = 0;

      // Start timer
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        _recordDuration++;
      });

      print('🎤 Recording started: $_recordingPath');
      return true;
    } catch (e) {
      print('❌ Failed to start recording: $e');
      return false;
    }
  }

  /// Stop recording
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) {
        print('⚠️ Not recording');
        return null;
      }

      final path = await _recorder.stop();
      _isRecording = false;
      _timer?.cancel();

      print('✅ Recording stopped: $path');
      print('⏱️ Duration: $_recordDuration seconds');

      return path;
    } catch (e) {
      print('❌ Failed to stop recording: $e');
      return null;
    }
  }

  /// Cancel recording
  Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _recorder.stop();
        _isRecording = false;
        _timer?.cancel();
        _recordDuration = 0;

        // Delete the file
        if (_recordingPath != null) {
          final file = File(_recordingPath!);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      print('❌ Failed to cancel recording: $e');
    }
  }

  /// Format duration
  String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
  }
}