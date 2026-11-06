import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/enums.dart';
import 'package:taskflow/models/task_models.dart';
import 'package:taskflow/models/task_query.dart';

import 'helpers/test_helpers.dart';

void main() {
  late Fixture f;

  setUp(() async => f = await createFixture());
  tearDown(() => f.close());

  group('Фильтрация, поиск, сортировка, пагинация', () {
    setUp(() async {
      await f.newTask(title: 'Сверстать макет', description: 'Figma', assigneeId: f.bob, priority: TaskPriority.high);
      await f.newTask(title: 'Написать API', description: 'Эндпоинт авторизации', assigneeId: f.alice, status: TaskStatus.inProgress);
      await f.newTask(title: 'Тесты', description: 'Покрыть API тестами', priority: TaskPriority.critical, status: TaskStatus.done);
    });

    test('28. Фильтр по статусу, приоритету и исполнителю', () async {
      final base = TaskQuery(projectId: f.projectId);
      expect((await f.tasks.getTaskPage(base.copyWith(status: TaskStatus.inProgress))).items.single.task.title, 'Написать API');
      expect((await f.tasks.getTaskPage(base.copyWith(priority: TaskPriority.critical))).items.single.task.title, 'Тесты');
      expect((await f.tasks.getTaskPage(base.copyWith(assigneeId: f.bob))).items.single.task.title, 'Сверстать макет');
      expect(
        (await f.tasks.getTaskPage(base.copyWith(status: TaskStatus.todo, priority: TaskPriority.critical))).total,
        0,
      );
    });

    test('29. Поиск по названию и описанию', () async {
      final base = TaskQuery(projectId: f.projectId);
      final byTitleOrDescription = await f.tasks.getTaskPage(base.copyWith(search: 'API'));
      expect(byTitleOrDescription.items.map((t) => t.task.title), unorderedEquals(['Написать API', 'Тесты']));
      final byDescription = await f.tasks.getTaskPage(base.copyWith(search: 'Figma'));
      expect(byDescription.items.single.task.title, 'Сверстать макет');
      expect((await f.tasks.getTaskPage(base.copyWith(search: 'нет такого'))).total, 0);
    });

    test('30. Сортировка по дедлайну и дате создания + пагинация', () async {
      for (var i = 0; i < 22; i++) {
        await f.newTask(title: 'Пакет $i', deadline: f.inDays(30 - i));
      }
      final query = TaskQuery(projectId: f.projectId, search: 'Пакет', sort: TaskSort.deadlineAsc, pageSize: 10);
      final p0 = await f.tasks.getTaskPage(query);
      final p2 = await f.tasks.getTaskPage(query.copyWith(page: 2));
      expect(p0.total, 22);
      expect(p0.pageCount, 3);
      expect(p0.items, hasLength(10));
      expect(p2.items, hasLength(2));
      expect(p0.items.first.task.title, 'Пакет 21', reason: 'ближайший дедлайн первым');
      final deadlines = p0.items.map((t) => t.task.deadline).toList();
      expect(deadlines, orderedEquals([...deadlines]..sort()));

      final newest = await f.tasks.getTaskPage(query.copyWith(sort: TaskSort.newest));
      expect(newest.items.first.task.title, 'Пакет 21', reason: 'созданная последней');
      final oldest = await f.tasks.getTaskPage(query.copyWith(sort: TaskSort.oldest));
      expect(oldest.items.first.task.title, 'Пакет 0');
    });
  });

  test('31. Статистика рассчитывается корректно (SQL)', () async {
    final beta = await f.projects.createProject(name: 'Бета', ownerId: f.alice);
    await f.newTask(assigneeId: f.bob, status: TaskStatus.done, priority: TaskPriority.high);
    await f.newTask(assigneeId: f.bob, status: TaskStatus.inProgress, priority: TaskPriority.high);
    await f.newTask(assigneeId: f.alice, deadline: f.inDays(-2), priority: TaskPriority.low); // просрочена
    await f.newTask(status: TaskStatus.cancelled, priority: TaskPriority.critical);
    await f.newTask(project: beta, assigneeId: f.alice, status: TaskStatus.done);
    final trashed = await f.newTask(title: 'удалена', assigneeId: f.alice);
    await f.tasks.moveToTrash(trashed); // не учитывается

    final s = await f.stats.loadStats();
    expect(s.projects, 2);
    expect(s.totalTasks, 5);
    expect(s.done, 2);
    expect(s.open, 2);
    expect(s.cancelled, 1);
    expect(s.overdue, 1);
    expect(s.unassigned, 1);
    expect(s.byPriority, {
      TaskPriority.low: 1,
      TaskPriority.medium: 1,
      TaskPriority.high: 2,
      TaskPriority.critical: 1,
    });
    final bob = s.byAssignee.firstWhere((a) => a.userId == f.bob);
    expect(bob.total, 2);
    expect(bob.open, 1);
    final alpha = s.projectProgress.firstWhere((p) => p.projectId == f.projectId);
    // 1 done из 3 неотменённых → 33.3 %
    expect(alpha.total, 4);
    expect(alpha.done, 1);
    expect(alpha.percent, closeTo(33.3, 0.05));
    expect(s.projectProgress.firstWhere((p) => p.projectId == beta).percent, 100);
  });

  test('32. Реактивность: watch() сам выдаёт новые данные после изменения БД', () async {
    final totals = <int>[];
    final sub = f.tasks.watchTaskPage(TaskQuery(projectId: f.projectId)).listen((TaskPage p) => totals.add(p.total));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await f.newTask(title: 'Новая');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final id = await f.newTask(title: 'Ещё одна');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await f.tasks.moveToTrash(id);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await sub.cancel();

    expect(totals.first, 0);
    expect(totals, containsAllInOrder([0, 1, 2, 1]));
  });
}
