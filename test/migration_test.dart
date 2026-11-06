import 'package:drift/drift.dart' show OrderingTerm, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/data/database/app_database.dart';
import 'package:taskflow/data/database/indexes.dart';
import 'package:taskflow/data/repositories/task_repository.dart';
import 'package:taskflow/models/enums.dart';

import 'helpers/schema_v1.dart';
import 'helpers/test_helpers.dart';

/// Открывает БД, которая «была создана» первой версией приложения:
/// схема без tasks.priority, user_version = 1, есть данные.
AppDatabase openLegacyV1Database() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    NativeDatabase.memory(
      setup: (raw) {
        for (final sql in schemaV1) {
          raw.execute(sql);
        }
        for (final sql in seedV1) {
          raw.execute(sql);
        }
        raw.execute('PRAGMA user_version = 1');
      },
    ),
  );
}

void main() {
  test('33. Миграция v1 → v2: добавляет priority = medium и не теряет данные', () async {
    final db = openLegacyV1Database();
    addTearDown(db.close);

    // Первое обращение запускает onUpgrade(1 → 2).
    final tasks = await (db.select(db.tasks)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

    expect(tasks, hasLength(2), reason: 'старые записи сохранены');
    expect(tasks.map((t) => t.title), ['Старая задача', 'Готовая задача']);
    expect(tasks.every((t) => t.priority == TaskPriority.medium), isTrue);
    expect(tasks[1].status, TaskStatus.done);

    // Связанные данные тоже на месте.
    expect(await db.select(db.users).get(), hasLength(1));
    expect(await db.select(db.comments).get(), hasLength(1));
    expect(await db.select(db.taskHistory).get(), hasLength(1));

    // Версия схемы и индексы обновлены.
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), AppDatabase.currentSchemaVersion);
    expect(await db.existingIndexNames(), containsAll(appIndexes.keys));

    // После миграции приложение полноценно работает с новым полем.
    final repo = TaskRepository(db);
    await repo.changePriority(1, TaskPriority.critical);
    expect((await repo.getTask(1))!.priority, TaskPriority.critical);
    final newId = await repo.createTask(
      projectId: 1,
      title: 'Задача v2',
      priority: TaskPriority.high,
      deadline: DateTime(2031, 1, 1, 18),
      actorId: 1,
    );
    expect((await repo.getTask(newId))!.priority, TaskPriority.high);
  });

  test('34. Новая БД сразу создаётся в версии 2 со всеми индексами и внешними ключами', () async {
    final db = openTestDatabase();
    addTearDown(db.close);

    final columns = await db.customSelect('PRAGMA table_info(tasks)').get();
    expect(columns.map((c) => c.read<String>('name')), contains('priority'));
    expect(await db.existingIndexNames(), containsAll(appIndexes.keys));
    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.read<int>('foreign_keys'), 1);
  });
}
