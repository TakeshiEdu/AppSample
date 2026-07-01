import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class MediaImportService {
  Future<String?> pickAndCopy({required String role}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions:
          Platform.isWindows
              ? const ['wav']
              : const ['wav', 'mp3', 'm4a', 'aac', 'caf'],
    );
    final selectedPath = result?.files.single.path;
    if (selectedPath == null) return null;

    final documents = await getApplicationDocumentsDirectory();
    final inputDirectory = Directory(path.join(documents.path, 'inputs'));
    await inputDirectory.create(recursive: true);
    final extension = path.extension(selectedPath).toLowerCase();
    final target = path.join(
      inputDirectory.path,
      '${DateTime.now().microsecondsSinceEpoch}_$role$extension',
    );
    await File(selectedPath).copy(target);
    return target;
  }
}
