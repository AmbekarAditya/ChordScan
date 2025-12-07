// lib/services/acr_cloud_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../utils/secrets.dart';

class AcrCloudService {
  /// Send audio bytes to ACRCloud for identification
  Future<Song?> identifySong(Uint8List bytes) async {
    final int timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    // Generate signature
    final String signature = _generateSignature(
      'identify',
      timestamp.toString(),
      Secrets.acrAccessSecret,
    );

    // Prepare request
    final Uri uri = Uri.https(Secrets.acrHost, '/v1/identify');
    final request = http.MultipartRequest('POST', uri)
      ..fields['access_key'] = Secrets.acrAccessKey
      ..fields['data_type'] = 'audio'
      ..fields['signature_version'] = '1'
      ..fields['signature'] = signature
      ..fields['timestamp'] = timestamp.toString()
      ..fields['sample_bytes'] = bytes.lengthInBytes.toString()
      ..files.add(http.MultipartFile.fromBytes('sample', bytes, filename: 'recording.m4a'));

    // Send
    try {
      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      
      if (response.statusCode != 200) {
        throw Exception('ACRCloud error ${response.statusCode}: $respStr');
      }

      return _parseResponse(respStr);
    } catch (e) {
      print('ACRCloud identification failed: $e');
      rethrow;
    }
  }

  /// HMAC-SHA1 signature generation
  String _generateSignature(String httpMethod, String timestamp, String secret) {
    // string_to_sign = method + "\n" + uri + "\n" + access_key + "\n" + data_type + "\n" + signature_version + "\n" + timestamp
    // Note: The actual ACRCloud signature is simpler for V1:
    // canonical_string = method + "\n" + uri + "\n" + access_key + "\n" + data_type + "\n" + signature_version + "\n" + timestamp
    // Wait, checking docs... 
    // Standard ACRCloud V1 signature:
    // data = "POST" + "\n" + "/v1/identify" + "\n" + access_key + "\n" + "audio" + "\n" + "1" + "\n" + timestamp
    
    final String stringToSign = 
        'POST\n/v1/identify\n${Secrets.acrAccessKey}\naudio\n1\n$timestamp';
    
    final hmacSha1 = Hmac(sha1, utf8.encode(secret));
    final digest = hmacSha1.convert(utf8.encode(stringToSign));
    return base64Encode(digest.bytes);
  }

  /// Parse JSON response to Song model
  Song? _parseResponse(String jsonStr) {
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    final status = data['status'];
    
    if (status['code'] != 0) {
      // 1001 = No result, etc.
      print('ACRCloud Status: ${status['msg']} (Code: ${status['code']})');
      return null;
    }

    final metadata = data['metadata'];
    if (metadata != null && metadata['music'] != null) {
      final List<dynamic> music = metadata['music'];
      if (music.isNotEmpty) {
        final bestMatch = music[0];
        final String title = bestMatch['title'] ?? 'Unknown Title';
        final List<dynamic>? artists = bestMatch['artists'];
        final String artist = artists != null && artists.isNotEmpty 
            ? artists[0]['name'] 
            : 'Unknown Artist';

        return Song(title: title, artist: artist);
      }
    }
    return null;
  }
}
