import 'dart:math';

import 'package:drift/drift.dart';

import '../../models/benchmark.dart';
import '../../models/enums.dart';
import '../database/app_database.dart';

class _BenchCase {
  const _BenchCase(this.name, this.sql, this.variables);

  final String name;
  final String sql;
  final List<Variable> variables;
}

/// Генерация тестовой БД и сравнение скорости запросов с индексами и без.
class BenchmarkRepository {
  BenchmarkRepository(this._db);

  final AppDatabase _db;

  static const _verbs = [
    'Подготовить', 'Проверить', 'Исправить', 'Обновить',
    'Спроектировать', 'Протестировать', 'Согласовать', 'Описать',
  ];
  static const _nouns = [
    'отчёт', 'дизайн экрана', 'API авторизации', 'баг в корзине',
    'документацию', 'миграцию БД', 'презентацию', 'сборку релиза',
  ];

  /// Заполняет БД тестовыми данными (существующие данные удаляются).
  ///
  /// Каждый пользователь состоит ровно в одном проекте (10 участников на
  /// проект), задачи назначаются только участникам своего проекта, а у
  /// каждого исполнителя не больше одной задачи на дату — так соблюдаются
  /// правила целостности и лимит из Задания 3.
  Future<SeedReport> seed({
    int users = 1000,
    int projects = 100,
    int tasks = 10000,
    int membersPerProject = 10,
  }) async {
    final watch = Stopwatch()..start();
    final random = Random(42);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 18);
    var memberCount = 0;

    await _db.transaction(() async {
      await _db.delete(_db.taskHistory).go();
      await _db.delete(_db.comments).go();
      await _db.delete(_db.attachments).go();
      await _db.delete(_db.tasks).go();
      await _db.delete(_db.projectMembers).go();
      await _db.delete(_db.projects).go();
      await _db.delete(_db.users).go();

      await _db.batch((b) {
        b.insertAll(_db.users, [
          for (var i = 1; i <= users; i++)
            UsersCompanion.insert(
              id: Value(i),
              name: 'Пользователь ${i.toString().padLeft(4, '0')}',
              email: 'user$i@taskflow.test',
              registeredAt: Value(now.subtract(Duration(days: i % 365))),
            ),
        ]);

        b.insertAll(_db.projects, [
          for (var p = 1; p <= projects; p++)
            ProjectsCompanion.insert(
              id: Value(p),
              name: 'Проект ${p.toString().padLeft(3, '0')}',
              description: Value('Тестовый проект №$p'),
              createdAt: Value(now.subtract(Duration(days: 120 - p % 90))),
              status: Value(p % 10 == 0 ? ProjectStatus.completed : ProjectStatus.active),
            ),
        ]);

        final members = <ProjectMembersCompanion>[];
        for (var p = 1; p <= projects; p++) {
          for (var k = 0; k < membersPerProject; k++) {
            members.add(
              ProjectMembersCompanion.insert(
                projectId: p,
                userId: _memberUserId(p, k, membersPerProject, users),
                role: Value(k == 0 ? ProjectRole.owner : (k == 1 ? ProjectRole.admin : ProjectRole.member)),
                joinedAt: Value(now),
              ),
            );
          }
        }
        memberCount = members.length;
        b.insertAll(_db.projectMembers, members);

        final rows = <TasksCompanion>[];
        for (var i = 0; i < tasks; i++) {
          final project = i % projects + 1;
          final slot = i ~/ projects; // порядковый номер задачи внутри проекта
          final memberIndex = slot % membersPerProject;
          final dayOffset = slot ~/ membersPerProject + project % 30 - 10;
          final roll = random.nextInt(100);
          final status = roll < 40
              ? TaskStatus.todo
              : roll < 65
                  ? TaskStatus.inProgress
                  : roll < 92
                      ? TaskStatus.done
                      : TaskStatus.cancelled;
          final created = now.subtract(Duration(days: i % 90, minutes: i));
          rows.add(
            TasksCompanion.insert(
              title: '${_verbs[random.nextInt(_verbs.length)]} ${_nouns[random.nextInt(_nouns.length)]} #${i + 1}',
              description: Value('Автоматически созданная задача ${i + 1} для проверки производительности'),
              projectId: project,
              assigneeId: Value(_memberUserId(project, memberIndex, membersPerProject, users)),
              priority: Value(TaskPriority.values[random.nextInt(TaskPriority.values.length)]),
              status: Value(status),
              deadline: DateTime(today.year, today.month, today.day + dayOffset, 18),
              createdAt: Value(created),
              updatedAt: Value(created),
            ),
          );
        }
        b.insertAll(_db.tasks, rows);
      });
    });

    await _db.customStatement('ANALYZE');
    watch.stop();
    return SeedReport(users: users, projects: projects, members: memberCount, tasks: tasks, elapsed: watch.elapsed);
  }

  static int _memberUserId(int project, int k, int perProject, int users) =>
      ((project - 1) * perProject + k) % users + 1;

  List<_BenchCase> _cases() {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day + 3);
    return [
      _BenchCase(
        'Фильтр: статус + приоритет',
        "SELECT * FROM tasks WHERE deleted_at IS NULL AND status = ? AND priority = ? "
            'ORDER BY created_at DESC LIMIT 20',
        [Variable.withString(TaskStatus.inProgress.name), Variable.withString(TaskPriority.critical.name)],
      ),
      _BenchCase(
        'Задачи исполнителя',
        'SELECT * FROM tasks WHERE assignee_id = ? AND deleted_at IS NULL ORDER BY deadline LIMIT 20',
        [Variable.withInt(500)],
      ),
      _BenchCase(
        'Задачи проекта, сортировка по дедлайну',
        'SELECT * FROM tasks WHERE project_id = ? AND deleted_at IS NULL ORDER BY deadline LIMIT 20',
        [Variable.withInt(50)],
      ),
      _BenchCase(
        'Пагинация: страница 50 по дедлайну',
        'SELECT * FROM tasks WHERE deleted_at IS NULL ORDER BY deadline LIMIT 20 OFFSET 1000',
        const [],
      ),
      _BenchCase(
        'Лимит задач на дату (Задание 3)',
        "SELECT COUNT(*) AS c FROM tasks WHERE assignee_id = ? AND deleted_at IS NULL "
            "AND status IN ('todo', 'inProgress') AND deadline >= ? AND deadline < ?",
        [
          Variable.withInt(500),
          Variable.withDateTime(day),
          Variable.withDateTime(DateTime(day.year, day.month, day.day + 1)),
        ],
      ),
      _BenchCase(
        'Поиск LIKE по названию/описанию',
        'SELECT * FROM tasks WHERE deleted_at IS NULL AND (title LIKE ? OR description LIKE ?) LIMIT 20',
        [Variable.withString('%миграцию%'), Variable.withString('%миграцию%')],
      ),
    ];
  }

  /// Выполняет каждый запрос [repeats] раз с индексами и без них.
  Future<List<BenchmarkResult>> runBenchmark({int repeats = 30}) async {
    final cases = _cases();
    final withTimes = <double>[];
    final withPlans = <String>[];
    final withoutTimes = <double>[];
    final withoutPlans = <String>[];

    try {
      await _db.createIndexes();
      await _db.customStatement('ANALYZE');
      for (final c in cases) {
        withTimes.add(await _measure(c, repeats, 'with_index'));
        withPlans.add(await _plan(c, 'with_index'));
      }

      await _db.dropIndexes();
      for (final c in cases) {
        withoutTimes.add(await _measure(c, repeats, 'without_index'));
        withoutPlans.add(await _plan(c, 'without_index'));
      }
    } finally {
      // Индексы обязательно возвращаются на место.
      await _db.createIndexes();
      await _db.customStatement('ANALYZE');
    }

    return [
      for (var i = 0; i < cases.length; i++)
        BenchmarkResult(
          name: cases[i].name,
          sql: cases[i].sql,
          withIndexMs: withTimes[i],
          withoutIndexMs: withoutTimes[i],
          planWithIndex: withPlans[i],
          planWithoutIndex: withoutPlans[i],
        ),
    ];
  }

  // Комментарий-метка делает текст SQL уникальным для каждого этапа, чтобы
  // кэш подготовленных запросов не вернул план, построенный до DROP INDEX.
  Future<double> _measure(_BenchCase c, int repeats, String tag) async {
    final sql = '/* $tag */ ${c.sql}';
    await _db.customSelect(sql, variables: c.variables).get(); // прогрев
    final watch = Stopwatch()..start();
    for (var i = 0; i < repeats; i++) {
      await _db.customSelect(sql, variables: c.variables).get();
    }
    watch.stop();
    return watch.elapsedMicroseconds / repeats / 1000.0;
  }

  Future<String> _plan(_BenchCase c, String tag) async {
    final rows = await _db.customSelect('EXPLAIN QUERY PLAN /* $tag */ ${c.sql}', variables: c.variables).get();
    return rows.map((r) => r.read<String>('detail')).join('\n');
  }
}
