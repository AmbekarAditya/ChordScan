// lib/services/detect_service.dart
import 'dart:async';


import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../models/song.dart';
import 'acr_cloud_service.dart';
import '../utils/file_utils.dart';

class DetectService {
  final AudioRecorder _audioRecorder = AudioRecorder();

  /// Stream of amplitude events for visualization
  Stream<Amplitude> get amplitudeStream => _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 100));

  /// Records audio for [duration] and then "detects" a song (mock).
  /// Returns the detected Song.
  Future<Song> detectSong({Duration duration = const Duration(seconds: 4)}) async {
    // 1. Check Permissions
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Microphone permission denied');
    }

    // 2. Prepare Path (Mobile only)
    String? filePath;
    if (!kIsWeb) {
      final tempDir = await getTemporaryDirectory();
      filePath = '${tempDir.path}/temp_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
    }

    // 3. Start Recording
    if (await _audioRecorder.hasPermission()) {
      // On web, path must be null to record to memory/blob
      await _audioRecorder.start(const RecordConfig(), path: filePath ?? '');
    }

    // 4. Wait
    await Future.delayed(duration);

    // 5. Stop Recording
    // On web, stop returns the Blob URL
    final String? path = await _audioRecorder.stop();
    print('Recording saved to: $path');

    if (path == null) {
      throw Exception('Recording failed (path is null)');
    }

    // 6. Identify Song
    final bytes = await FileUtils.readFileBytes(path);
    final AcrCloudService acrService = AcrCloudService();
    final Song? detected = await acrService.identifySong(bytes);

    if (detected == null) {
      throw Exception('No song identified');
    }
    
    return detected;
  }
}
