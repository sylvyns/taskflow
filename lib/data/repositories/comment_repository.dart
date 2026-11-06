import 'package:drift/drift.dart';

import '../../models/app_exception.dart';
import '../../models/task_models.dart';
import '../database/app_database.dart';
import '../validators.dart';

/// Комментарии к задачам.
class CommentRepository {
  CommentRepository(this._db);

  final AppDatabase _db;

  Stream<List<CommentWithAuthor>> watchComments(int taskId) => _query(taskId).watch().map(_mapRows);

  Future<List<CommentWithAuthor>> getComments(int taskId) async => _mapRows(await _query(taskId).get());

  JoinedSelectStatement<HasResultSet, dynamic> _query(int taskId) {
    final c = _db.comments;
    return _db.select(c).join([innerJoin(_db.users, _db.users.id.equalsExp(c.authorId))])
      ..where(c.taskId.equals(taskId))
      ..orderBy([OrderingTerm.asc(c.createdAt), OrderingTerm.asc(c.id)]);
  }

  List<CommentWithAuthor> _mapRows(List<TypedResult> rows) => rows
      .map((row) => CommentWithAuthor(comment: row.readTable(_db.comments), author: row.readTable(_db.users)))
      .toList();

  /// Добавление комментария. Нельзя комментировать несуществующую задачу.
  Future<int> addComment({required int taskId, required int authorId, required String body}) async {
    final text = Validators.requiredText(body, 'Комментарий', maxLength: 2000);
    return _db.transaction(() async {
      final task = await (_db.select(_db.tasks)..where((t) => t.id.equals(taskId) & t.deletedAt.isNull()))
          .getSingleOrNull();
      if (task == null) throw const NotFoundException('Нельзя добавить комментарий: задача не существует');
      final author = await (_db.select(_db.users)..where((u) => u.id.equals(authorId))).getSingleOrNull();
      if (author == null) throw const NotFoundException('Автор комментария не найден');
      return _db.into(_db.comments).insert(
            CommentsCompanion.insert(
              taskId: taskId,
              authorId: authorId,
              body: text,
              createdAt: Value(DateTime.now()),
            ),
          );
    });
  }

  /// Удалять комментарий может только его автор.
  Future<void> deleteComment(int commentId, {required int actorId}) async {
    await _db.transaction(() async {
      final comment = await (_db.select(_db.comments)..where((c) => c.id.equals(commentId))).getSingleOrNull();
      if (comment == null) throw const NotFoundException('Комментарий не найден');
      if (comment.authorId != actorId) {
        throw const BusinessRuleException('Удалять комментарий может только его автор');
      }
      await (_db.delete(_db.comments)..where((c) => c.id.equals(commentId))).go();
    });
  }
}
