import 'dart:typed_data';
import 'package:http/http.dart' as http;

class FileUtils {
  static Future<Uint8List> readFileBytes(String path) async {
    // On web, path is a blob URL
    final response = await http.get(Uri.parse(path));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw Exception('Failed to read blob: ${response.statusCode}');
  }
}
