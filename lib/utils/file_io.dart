import 'dart:io';
import 'dart:typed_data';

class FileUtils {
  static Future<Uint8List> readFileBytes(String path) async {
    final file = File(path);
    return await file.readAsBytes();
  }
}
