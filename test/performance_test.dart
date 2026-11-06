import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/data/database/indexes.dart';
import 'package:taskflow/data/repositories/benchmark_repository.dart';
import 'package:taskflow/data/repositories/task_repository.dart';
import 'package:taskflow/models/enums.dart';
import 'package:taskflow/models/task_query.dart';

import 'helpers/test_helpers.dart';

void main() {
  test(
    '35. Тестовая БД 1000/100/10000: поиск, фильтры, пагинация и сравнение индексов',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final bench = BenchmarkRepository(db);
      final tasks = TaskRepository(db);

      final report = await bench.seed();
      expect(report.users, 1000);
      expect(report.projects, 100);
      expect(report.tasks, 10000);
      expect(await db.select(db.users).get(), hasLength(1000));

      // Пагинация по большому объёму.
      const query = TaskQuery(sort: TaskSort.deadlineAsc, pageSize: 20);
      final page = await tasks.getTaskPage(query.copyWith(page: 50));
      expect(page.total, 10000);
      expect(page.pageCount, 500);
      expect(page.items, hasLength(20));

      // Фильтр + поиск.
      final filtered = await tasks.getTaskPage(
        const TaskQuery(status: TaskStatus.inProgress, priority: TaskPriority.critical, search: 'миграцию'),
      );
      expect(filtered.items.every((t) => t.task.status == TaskStatus.inProgress), isTrue);
      expect(filtered.items.every((t) => t.task.title.contains('миграцию') || t.task.description.contains('миграцию')), isTrue);

      // Правило: все исполнители — участники своих проектов.
      final orphan = await db.customSelect('''
        SELECT COUNT(*) AS c FROM tasks t
        LEFT JOIN project_members m ON m.project_id = t.project_id AND m.user_id = t.assignee_id
        WHERE t.assignee_id IS NOT NULL AND m.id IS NULL
      ''').getSingle();
      expect(orphan.read<int>('c'), 0);

      // Сравнение скорости с индексами и без.
      final results = await bench.runBenchmark(repeats: 5);
      expect(results, isNotEmpty);
      // ignore: avoid_print
      print('\nЗапрос | с индексом, мс | без индекса, мс | ускорение');
      for (final r in results) {
        // ignore: avoid_print
        print('${r.name} | ${r.withIndexMs.toStringAsFixed(3)} | ${r.withoutIndexMs.toStringAsFixed(3)} | ×${r.speedup.toStringAsFixed(1)}');
      }
      final byAssignee = results.firstWhere((r) => r.name == 'Задачи исполнителя');
      expect(byAssignee.planWithIndex, contains('idx_tasks_assignee_status'));
      expect(byAssignee.planWithoutIndex, contains('SCAN'));

      // После бенчмарка индексы восстановлены.
      expect(await db.existingIndexNames(), containsAll(appIndexes.keys));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
