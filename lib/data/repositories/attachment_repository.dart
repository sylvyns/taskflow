import 'package:drift/drift.dart';

import '../../models/app_exception.dart';
import '../database/app_database.dart';
import '../validators.dart';

/// Вложения. В БД сохраняется путь к файлу, а не содержимое.
class AttachmentRepository {
  AttachmentRepository(this._db);

  final AppDatabase _db;

  Stream<List<Attachment>> watchAttachments(int taskId) => _query(taskId).watch();

  Future<List<Attachment>> getAttachments(int taskId) => _query(taskId).get();

  SimpleSelectStatement<$AttachmentsTable, Attachment> _query(int taskId) => _db.select(_db.attachments)
    ..where((a) => a.taskId.equals(taskId))
    ..orderBy([(a) => OrderingTerm.desc(a.addedAt), (a) => OrderingTerm.desc(a.id)]);

  Future<int> addAttachment({
    required int taskId,
    required String fileName,
    required String filePath,
    int? sizeBytes,
  }) async {
    final name = Validators.requiredText(fileName, 'Название файла', maxLength: 255);
    final path = Validators.requiredText(filePath, 'Путь к файлу', maxLength: 1024);
    return _db.transaction(() async {
      final task = await (_db.select(_db.tasks)..where((t) => t.id.equals(taskId) & t.deletedAt.isNull()))
          .getSingleOrNull();
      if (task == null) throw const NotFoundException('Задача не найдена');
      return _db.into(_db.attachments).insert(
            AttachmentsCompanion.insert(
              taskId: taskId,
              fileName: name,
              filePath: path,
              sizeBytes: Value(sizeBytes),
              addedAt: Value(DateTime.now()),
            ),
          );
    });
  }

  Future<void> deleteAttachment(int id) async {
    final deleted = await (_db.delete(_db.attachments)..where((a) => a.id.equals(id))).go();
    if (deleted == 0) throw const NotFoundException('Вложение не найдено');
  }
}
