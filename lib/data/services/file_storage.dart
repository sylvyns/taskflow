import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StoredFile {
  const StoredFile({required this.path, required this.sizeBytes});

  final String path;
  final int sizeBytes;
}

/// Копирует выбранный файл в каталог приложения, чтобы путь в БД
/// оставался действительным (временные файлы пикера могут удаляться).
class FileStorage {
  Future<StoredFile> saveCopy(String sourcePath, String fileName) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'attachments'));
    await dir.create(recursive: true);
    final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final target = p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}_$safeName');
    final copy = await File(sourcePath).copy(target);
    return StoredFile(path: copy.path, sizeBytes: await copy.length());
  }

  Future<bool> exists(String path) => File(path).exists();
}
