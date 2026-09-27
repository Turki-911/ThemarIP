import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class PickedAttachment {
  final String name;
  final int size;
  final Uint8List bytes;

  PickedAttachment({
    required this.name,
    required this.size,
    required this.bytes,
  });
}

class WebFilePicker {
  static Future<PickedAttachment?> pickFile() async {
    // file_picker v11: static method, no .platform needed
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'csv', 'txt', 'xlsx', 'png', 'jpg'],
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;

    Uint8List bytes;
    if (file.bytes != null) {
      // Available on web and when withData: true
      bytes = file.bytes!;
    } else if (file.path != null) {
      // Available on macOS / iOS / Android — read via dart:io
      bytes = await File(file.path!).readAsBytes();
    } else {
      return null;
    }

    return PickedAttachment(
      name: file.name,
      size: file.size,
      bytes: bytes,
    );
  }
}
