import 'package:drift/drift.dart';

import '../../models/enums.dart';
import 'indexes.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// База данных TaskFlow (SQLite через Drift).
///
/// История версий схемы:
///  * v1 — в таблице `tasks` нет поля `priority`;
///  * v2 — добавлено `tasks.priority`, всем старым задачам ставится `medium`.
@DriftDatabase(tables: [Users, Projects, ProjectMembers, Tasks, Comments, Attachments, TaskHistory])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  static const int currentSchemaVersion = 2;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await createIndexes();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // ALTER TABLE tasks ADD COLUMN priority TEXT NOT NULL DEFAULT 'medium'
            // Существующие строки сохраняются и получают значение по умолчанию.
            await m.addColumn(tasks, tasks.priority);
            // Явно проставляем medium (на случай пустых значений).
            await customStatement(
              "UPDATE tasks SET priority = 'medium' WHERE priority IS NULL OR priority = ''",
            );
          }
          await createIndexes();
        },
        beforeOpen: (details) async {
          // Без этого SQLite не проверяет внешние ключи и не выполняет каскады.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Внешние ключи заданы через customConstraint, поэтому Drift не знает
  /// о каскадах сам. Эти правила сообщают ему, какие таблицы меняются при
  /// каскадном удалении, — чтобы экраны (watch()) обновлялись автоматически.
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
        WritePropagation(
          on: TableUpdateQuery.onTableName('projects', limitUpdateKind: UpdateKind.delete),
          result: [
            TableUpdate('project_members', kind: UpdateKind.delete),
            TableUpdate('tasks', kind: UpdateKind.delete),
          ],
        ),
        WritePropagation(
          on: TableUpdateQuery.onTableName('users', limitUpdateKind: UpdateKind.delete),
          result: [
            TableUpdate('project_members', kind: UpdateKind.delete),
            TableUpdate('comments', kind: UpdateKind.delete),
            TableUpdate('tasks', kind: UpdateKind.update),
            TableUpdate('task_history', kind: UpdateKind.update),
          ],
        ),
        WritePropagation(
          on: TableUpdateQuery.onTableName('tasks', limitUpdateKind: UpdateKind.delete),
          result: [
            TableUpdate('comments', kind: UpdateKind.delete),
            TableUpdate('attachments', kind: UpdateKind.delete),
            TableUpdate('task_history', kind: UpdateKind.delete),
          ],
        ),
      ]);

  /// Создаёт все индексы приложения (идемпотентно).
  Future<void> createIndexes() async {
    for (final sql in appIndexes.values) {
      await customStatement(sql);
    }
  }

  /// Удаляет индексы приложения (используется только в бенчмарке).
  Future<void> dropIndexes() async {
    for (final name in appIndexes.keys) {
      await customStatement('DROP INDEX IF EXISTS $name');
    }
  }

  /// Имена индексов приложения, которые сейчас есть в БД.
  Future<Set<String>> existingIndexNames() async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%'",
    ).get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }
}
