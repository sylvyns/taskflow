import 'package:drift/drift.dart';

import '../../models/app_exception.dart';
import '../../models/enums.dart';
import '../../models/task_models.dart';
import '../../models/task_query.dart';
import '../database/app_database.dart';
import '../validators.dart';

/// Задачи: CRUD, фильтрация/поиск/сортировка/пагинация, история изменений,
/// Undo, корзина (Soft Delete) и ограничение нагрузки исполнителя.
class TaskRepository {
  TaskRepository(this._db);

  final AppDatabase _db;

  /// Задание 3: не более трёх незавершённых задач с одной датой дедлайна.
  static const int maxOpenTasksPerDay = 3;

  $TasksTable get _t => _db.tasks;

  // =====================================================================
  // Чтение
  // =====================================================================

  JoinedSelectStatement<HasResultSet, dynamic> _joined() {
    return _db.select(_db.tasks).join([
      innerJoin(_db.projects, _db.projects.id.equalsExp(_db.tasks.projectId)),
      leftOuterJoin(_db.users, _db.users.id.equalsExp(_db.tasks.assigneeId)),
    ]);
  }

  TaskWithDetails _map(TypedResult row) => TaskWithDetails(
        task: row.readTable(_db.tasks),
        project: row.readTable(_db.projects),
        assignee: row.readTableOrNull(_db.users),
      );

  /// WHERE-условие по фильтрам. Удалённые (в корзине) задачи исключаются.
  Expression<bool> _where(TaskQuery q) {
    Expression<bool> e = _t.deletedAt.isNull();
    if (q.projectId != null) e = e & _t.projectId.equals(q.projectId!);
    if (q.assigneeId != null) e = e & _t.assigneeId.equals(q.assigneeId!);
    if (q.status != null) e = e & _t.status.equals(q.status!.name);
    if (q.priority != null) e = e & _t.priority.equals(q.priority!.name);
    final text = q.search.trim();
    if (text.isNotEmpty) {
      final pattern = '%$text%';
      e = e & (_t.title.like(pattern) | _t.description.like(pattern));
    }
    return e;
  }

  List<OrderingTerm> _order(TaskSort sort) => switch (sort) {
        TaskSort.newest => [OrderingTerm.desc(_t.createdAt), OrderingTerm.desc(_t.id)],
        TaskSort.oldest => [OrderingTerm.asc(_t.createdAt), OrderingTerm.asc(_t.id)],
        TaskSort.deadlineAsc => [OrderingTerm.asc(_t.deadline), OrderingTerm.asc(_t.id)],
        TaskSort.deadlineDesc => [OrderingTerm.desc(_t.deadline), OrderingTerm.desc(_t.id)],
      };

  JoinedSelectStatement<HasResultSet, dynamic> _pageQuery(TaskQuery q) {
    return _joined()
      ..where(_where(q))
      ..orderBy(_order(q.sort))
      ..limit(q.pageSize, offset: q.page * q.pageSize);
  }

  /// Реактивная страница задач: обновляется при любом изменении задач,
  /// проектов или пользователей (Drift `watch()`).
  Stream<TaskPage> watchTaskPage(TaskQuery q) {
    return _pageQuery(q).watch().asyncMap(
          (rows) async => TaskPage(
            items: rows.map(_map).toList(),
            total: await countTasks(q),
            page: q.page,
            pageSize: q.pageSize,
          ),
        );
  }

  Future<TaskPage> getTaskPage(TaskQuery q) async {
    final rows = await _pageQuery(q).get();
    return TaskPage(items: rows.map(_map).toList(), total: await countTasks(q), page: q.page, pageSize: q.pageSize);
  }

  Future<int> countTasks(TaskQuery q) async {
    final count = _t.id.count();
    final query = _db.selectOnly(_t)
      ..addColumns([count])
      ..where(_where(q));
    return await query.map((row) => row.read(count)).getSingle() ?? 0;
  }

  /// Одна задача (в том числе удалённая — экран покажет баннер корзины).
  Stream<TaskWithDetails?> watchTask(int id) =>
      (_joined()..where(_t.id.equals(id))).watchSingleOrNull().map((row) => row == null ? null : _map(row));

  Future<Task?> getTask(int id) => (_db.select(_t)..where((t) => t.id.equals(id))).getSingleOrNull();

  // =====================================================================
  // Создание и редактирование
  // =====================================================================

  /// Создание задачи и первой записи истории — в одной транзакции.
  /// Если запись истории не сохранится, задача тоже не сохранится.
  Future<int> createTask({
    required int? projectId,
    required String title,
    String description = '',
    int? assigneeId,
    TaskPriority priority = TaskPriority.medium,
    TaskStatus status = TaskStatus.todo,
    required DateTime deadline,
    required int actorId,
  }) async {
    if (projectId == null) {
      throw const ValidationException('Задача должна принадлежать проекту');
    }
    final pid = projectId;
    final cleanTitle = Validators.requiredText(title, 'Название', maxLength: 200);
    final cleanDescription = Validators.optionalText(description, 'Описание', maxLength: 5000);

    return _db.transaction(() async {
      await _requireProject(pid);
      if (assigneeId != null) {
        await _requireMember(pid, assigneeId);
        await _checkWorkload(assigneeId, deadline);
      }
      final now = DateTime.now();
      final taskId = await _db.into(_t).insert(
            TasksCompanion.insert(
              title: cleanTitle,
              description: Value(cleanDescription),
              projectId: pid,
              assigneeId: Value(assigneeId),
              priority: Value(priority),
              status: Value(status),
              deadline: deadline,
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _db.into(_db.taskHistory).insert(
            TaskHistoryCompanion.insert(
              taskId: taskId,
              changeType: HistoryChangeType.created,
              newStatus: Value(status),
              newAssigneeId: Value(assigneeId),
              changedBy: Value(actorId),
              changedAt: Value(now),
            ),
          );
      return taskId;
    });
  }

  Future<void> updateTask(
    int taskId, {
    required String title,
    String description = '',
    required TaskPriority priority,
    required DateTime deadline,
  }) async {
    final cleanTitle = Validators.requiredText(title, 'Название', maxLength: 200);
    final cleanDescription = Validators.optionalText(description, 'Описание', maxLength: 5000);
    await _db.transaction(() async {
      final task = await _requireActiveTask(taskId);
      final assignee = task.assigneeId;
      if (assignee != null && !_sameDay(task.deadline, deadline)) {
        await _checkWorkload(assignee, deadline, excludeTaskId: taskId);
      }
      await _writeTask(
        taskId,
        TasksCompanion(
          title: Value(cleanTitle),
          description: Value(cleanDescription),
          priority: Value(priority),
          deadline: Value(deadline),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> changePriority(int taskId, TaskPriority priority) async {
    await _db.transaction(() async {
      final task = await _requireActiveTask(taskId);
      if (task.priority == priority) return;
      await _writeTask(taskId, TasksCompanion(priority: Value(priority), updatedAt: Value(DateTime.now())));
    });
  }

  /// Изменение статуса + автоматическая запись в историю (атомарно).
  Future<void> changeStatus(int taskId, TaskStatus newStatus, {required int actorId}) async {
    await _db.transaction(() async {
      final task = await _requireActiveTask(taskId);
      if (task.status == newStatus) return;
      final now = DateTime.now();
      await _writeTask(taskId, TasksCompanion(status: Value(newStatus), updatedAt: Value(now)));
      await _db.into(_db.taskHistory).insert(
            TaskHistoryCompanion.insert(
              taskId: taskId,
              changeType: HistoryChangeType.status,
              previousStatus: Value(task.status),
              newStatus: Value(newStatus),
              changedBy: Value(actorId),
              changedAt: Value(now),
            ),
          );
    });
  }

  /// Переназначение исполнителя: проверка участия в проекте, проверка
  /// лимита, изменение исполнителя и запись события в историю — атомарно.
  /// [assigneeId] = null снимает исполнителя.
  Future<void> reassign(int taskId, int? assigneeId, {required int actorId}) async {
    await _db.transaction(() async {
      final task = await _requireActiveTask(taskId);
      if (task.assigneeId == assigneeId) return;
      if (assigneeId != null) {
        await _requireMember(task.projectId, assigneeId);
        await _checkWorkload(assigneeId, task.deadline, excludeTaskId: taskId);
      }
      final now = DateTime.now();
      await _writeTask(taskId, TasksCompanion(assigneeId: Value(assigneeId), updatedAt: Value(now)));
      await _db.into(_db.taskHistory).insert(
            TaskHistoryCompanion.insert(
              taskId: taskId,
              changeType: HistoryChangeType.assignee,
              previousAssigneeId: Value(task.assigneeId),
              newAssigneeId: Value(assigneeId),
              changedBy: Value(actorId),
              changedAt: Value(now),
            ),
          );
    });
  }

  Future<void> _writeTask(int id, TasksCompanion companion) =>
      (_db.update(_t)..where((t) => t.id.equals(id))).write(companion);

  // =====================================================================
  // История и Undo
  // =====================================================================

  Stream<List<HistoryItem>> watchHistory(int taskId) => _historyQuery(taskId).watch().map(_mapHistory);

  Future<List<HistoryItem>> getHistory(int taskId) async => _mapHistory(await _historyQuery(taskId).get());

  JoinedSelectStatement<HasResultSet, dynamic> _historyQuery(int taskId) {
    final h = _db.taskHistory;
    return _db.select(h).join([leftOuterJoin(_db.users, _db.users.id.equalsExp(h.changedBy))])
      ..where(h.taskId.equals(taskId))
      ..orderBy([OrderingTerm.desc(h.id)]);
  }

  List<HistoryItem> _mapHistory(List<TypedResult> rows) => rows
      .map((row) => HistoryItem(entry: row.readTable(_db.taskHistory), actor: row.readTableOrNull(_db.users)))
      .toList();

  SimpleSelectStatement<$TaskHistoryTable, TaskHistoryEntry> _undoableQuery(int taskId) {
    return _db.select(_db.taskHistory)
      ..where(
        (h) =>
            h.taskId.equals(taskId) &
            h.changeType.equals(HistoryChangeType.status.name) &
            h.isUndone.equals(false),
      )
      ..orderBy([(h) => OrderingTerm.desc(h.id)])
      ..limit(1);
  }

  /// Можно ли отменить последнее изменение статуса.
  Stream<bool> watchCanUndo(int taskId) => _undoableQuery(taskId).watchSingleOrNull().map((e) => e != null);

  /// Задание 2: отмена последнего изменения статуса.
  /// Возвращает восстановленный статус. Отменённая запись помечается
  /// `is_undone`, а сама отмена фиксируется в истории отдельной записью.
  /// Повторный вызов отменяет предыдущее изменение (многоуровневый Undo).
  Future<TaskStatus> undoLastStatusChange(int taskId, {required int actorId}) async {
    return _db.transaction(() async {
      final task = await _requireActiveTask(taskId);
      final last = await _undoableQuery(taskId).getSingleOrNull();
      if (last == null) {
        throw const BusinessRuleException('Нет изменений статуса, которые можно отменить');
      }
      final previous = last.previousStatus;
      if (previous == null || last.newStatus != task.status) {
        throw const BusinessRuleException('Статус задачи уже изменился — отмена невозможна');
      }
      final now = DateTime.now();
      await _writeTask(taskId, TasksCompanion(status: Value(previous), updatedAt: Value(now)));
      await (_db.update(_db.taskHistory)..where((h) => h.id.equals(last.id)))
          .write(const TaskHistoryCompanion(isUndone: Value(true)));
      await _db.into(_db.taskHistory).insert(
            TaskHistoryCompanion.insert(
              taskId: taskId,
              changeType: HistoryChangeType.undo,
              previousStatus: Value(task.status),
              newStatus: Value(previous),
              changedBy: Value(actorId),
              changedAt: Value(now),
            ),
          );
      return previous;
    });
  }

  // =====================================================================
  // Корзина (Soft Delete)
  // =====================================================================

  Stream<List<TaskWithDetails>> watchTrash() => _trashQuery().watch().map((rows) => rows.map(_map).toList());

  Future<List<TaskWithDetails>> getTrash() async => (await _trashQuery().get()).map(_map).toList();

  JoinedSelectStatement<HasResultSet, dynamic> _trashQuery() {
    return _joined()
      ..where(_t.deletedAt.isNotNull())
      ..orderBy([OrderingTerm.desc(_t.deletedAt), OrderingTerm.desc(_t.id)]);
  }

  /// Перемещение в корзину: строка остаётся в БД, заполняется deleted_at.
  Future<void> moveToTrash(int taskId) async {
    final updated = await (_db.update(_t)..where((t) => t.id.equals(taskId) & t.deletedAt.isNull()))
        .write(TasksCompanion(deletedAt: Value(DateTime.now())));
    if (updated == 0) throw const NotFoundException('Задача не найдена');
  }

  Future<void> restoreFromTrash(int taskId) async {
    final updated = await (_db.update(_t)..where((t) => t.id.equals(taskId) & t.deletedAt.isNotNull()))
        .write(TasksCompanion(deletedAt: const Value(null), updatedAt: Value(DateTime.now())));
    if (updated == 0) throw const NotFoundException('Задача не найдена в корзине');
  }

  /// Полное удаление (только из корзины). Комментарии, вложения и история
  /// удаляются каскадно.
  Future<void> deletePermanently(int taskId) async {
    final deleted = await (_db.delete(_t)..where((t) => t.id.equals(taskId) & t.deletedAt.isNotNull())).go();
    if (deleted == 0) {
      throw const BusinessRuleException('Навсегда удалить можно только задачу из корзины');
    }
  }

  Future<int> emptyTrash() => (_db.delete(_t)..where((t) => t.deletedAt.isNotNull())).go();

  // =====================================================================
  // Проверки целостности
  // =====================================================================

  /// Количество незавершённых задач исполнителя с дедлайном в ту же дату.
  /// Проверка выполняется запросом к БД (используется индекс
  /// idx_tasks_assignee_status).
  Future<int> countOpenTasksOnDate(int userId, DateTime date, {int? excludeTaskId}) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day + 1);
    final count = _t.id.count();
    Expression<bool> where = _t.assigneeId.equals(userId) &
        _t.deletedAt.isNull() &
        _t.status.isIn(TaskStatus.openNames) &
        _t.deadline.isBiggerOrEqualValue(start) &
        _t.deadline.isSmallerThanValue(end);
    if (excludeTaskId != null) where = where & _t.id.isNotValue(excludeTaskId);
    final query = _db.selectOnly(_t)
      ..addColumns([count])
      ..where(where);
    return await query.map((row) => row.read(count)).getSingle() ?? 0;
  }

  Future<void> _checkWorkload(int userId, DateTime deadline, {int? excludeTaskId}) async {
    final count = await countOpenTasksOnDate(userId, deadline, excludeTaskId: excludeTaskId);
    if (count >= maxOpenTasksPerDay) {
      final d = '${deadline.day.toString().padLeft(2, '0')}.${deadline.month.toString().padLeft(2, '0')}.${deadline.year}';
      throw BusinessRuleException(
        'У исполнителя уже $maxOpenTasksPerDay незавершённые задачи с дедлайном $d',
      );
    }
  }

  Future<void> _requireProject(int projectId) async {
    final project = await (_db.select(_db.projects)..where((row) => row.id.equals(projectId))).getSingleOrNull();
    if (project == null) throw const NotFoundException('Проект не найден — задачу нельзя создать без проекта');
  }

  Future<void> _requireMember(int projectId, int userId) async {
    final member = await (_db.select(_db.projectMembers)
          ..where((row) => row.projectId.equals(projectId) & row.userId.equals(userId)))
        .getSingleOrNull();
    if (member == null) {
      throw const BusinessRuleException('Исполнителем может быть только участник проекта');
    }
  }

  Future<Task> _requireActiveTask(int id) async {
    final task = await (_db.select(_t)..where((row) => row.id.equals(id) & row.deletedAt.isNull())).getSingleOrNull();
    if (task == null) throw const NotFoundException('Задача не найдена или находится в корзине');
    return task;
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
