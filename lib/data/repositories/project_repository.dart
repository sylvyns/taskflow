import 'package:drift/drift.dart';

import '../../models/app_exception.dart';
import '../../models/enums.dart';
import '../../models/task_models.dart';
import '../database/app_database.dart';
import '../validators.dart';

/// Проекты и участники проектов (Many-to-Many).
class ProjectRepository {
  ProjectRepository(this._db);

  final AppDatabase _db;

  // ---------- Проекты ----------

  /// Список проектов с количеством задач (для прогресса в карточке).
  Stream<List<ProjectSummary>> watchProjects() => _summaryQuery().watch().map(_mapSummaries);

  Future<List<ProjectSummary>> getProjects() async => _mapSummaries(await _summaryQuery().get());

  JoinedSelectStatement<HasResultSet, dynamic> _summaryQuery() {
    final p = _db.projects;
    final t = _db.tasks;
    return _db.select(p).join([
      leftOuterJoin(t, t.projectId.equalsExp(p.id) & t.deletedAt.isNull(), useColumns: false),
    ])
      ..addColumns([_total, _done, _cancelled])
      ..groupBy([p.id])
      ..orderBy([OrderingTerm.desc(p.createdAt), OrderingTerm.desc(p.id)]);
  }

  late final Expression<int> _total = _db.tasks.id.count();
  late final Expression<int> _done = _db.tasks.id.count(filter: _db.tasks.status.equals(TaskStatus.done.name));
  late final Expression<int> _cancelled =
      _db.tasks.id.count(filter: _db.tasks.status.equals(TaskStatus.cancelled.name));

  List<ProjectSummary> _mapSummaries(List<TypedResult> rows) => rows
      .map(
        (row) => ProjectSummary(
          project: row.readTable(_db.projects),
          total: row.read(_total) ?? 0,
          done: row.read(_done) ?? 0,
          cancelled: row.read(_cancelled) ?? 0,
        ),
      )
      .toList();

  Stream<Project?> watchProject(int id) =>
      (_db.select(_db.projects)..where((p) => p.id.equals(id))).watchSingleOrNull();

  Future<Project?> getProject(int id) =>
      (_db.select(_db.projects)..where((p) => p.id.equals(id))).getSingleOrNull();

  /// Создаёт проект; если указан [ownerId], он сразу добавляется с ролью Owner.
  Future<int> createProject({
    required String name,
    String description = '',
    ProjectStatus status = ProjectStatus.active,
    DateTime? endDate,
    int? ownerId,
  }) async {
    final cleanName = Validators.requiredText(name, 'Название', maxLength: 120);
    final cleanDescription = Validators.optionalText(description, 'Описание', maxLength: 2000);
    final now = DateTime.now();
    _validateEndDate(now, endDate);

    return _db.transaction(() async {
      final projectId = await _db.into(_db.projects).insert(
            ProjectsCompanion.insert(
              name: cleanName,
              description: Value(cleanDescription),
              status: Value(status),
              createdAt: Value(now),
              endDate: Value(endDate),
            ),
          );
      if (ownerId != null) {
        await _requireUser(ownerId);
        await _db.into(_db.projectMembers).insert(
              ProjectMembersCompanion.insert(
                projectId: projectId,
                userId: ownerId,
                role: const Value(ProjectRole.owner),
                joinedAt: Value(now),
              ),
            );
      }
      return projectId;
    });
  }

  Future<void> updateProject(
    int id, {
    required String name,
    String description = '',
    required ProjectStatus status,
    DateTime? endDate,
  }) async {
    final cleanName = Validators.requiredText(name, 'Название', maxLength: 120);
    final cleanDescription = Validators.optionalText(description, 'Описание', maxLength: 2000);
    await _db.transaction(() async {
      final project = await getProject(id);
      if (project == null) throw const NotFoundException('Проект не найден');
      _validateEndDate(project.createdAt, endDate);
      await (_db.update(_db.projects)..where((p) => p.id.equals(id))).write(
        ProjectsCompanion(
          name: Value(cleanName),
          description: Value(cleanDescription),
          status: Value(status),
          endDate: Value(endDate),
        ),
      );
    });
  }

  /// Удаление проекта каскадно удаляет участников, задачи,
  /// а через задачи — комментарии, вложения и историю.
  Future<void> deleteProject(int id) async {
    final deleted = await (_db.delete(_db.projects)..where((p) => p.id.equals(id))).go();
    if (deleted == 0) throw const NotFoundException('Проект не найден');
  }

  void _validateEndDate(DateTime createdAt, DateTime? endDate) {
    if (endDate == null) return;
    final createdDay = DateTime(createdAt.year, createdAt.month, createdAt.day);
    if (endDate.isBefore(createdDay)) {
      throw const ValidationException('Дата завершения не может быть раньше даты создания');
    }
  }

  // ---------- Участники ----------

  Stream<List<MemberWithUser>> watchMembers(int projectId) => _membersQuery(projectId).watch().map(_mapMembers);

  Future<List<MemberWithUser>> getMembers(int projectId) async => _mapMembers(await _membersQuery(projectId).get());

  JoinedSelectStatement<HasResultSet, dynamic> _membersQuery(int projectId) {
    final m = _db.projectMembers;
    final u = _db.users;
    return _db.select(m).join([innerJoin(u, u.id.equalsExp(m.userId))])
      ..where(m.projectId.equals(projectId))
      ..orderBy([OrderingTerm.asc(u.name)]);
  }

  List<MemberWithUser> _mapMembers(List<TypedResult> rows) {
    final list = rows
        .map((row) => MemberWithUser(member: row.readTable(_db.projectMembers), user: row.readTable(_db.users)))
        .toList();
    // Owner → Admin → Member, внутри роли — по имени.
    list.sort((a, b) {
      final byRole = a.member.role.index.compareTo(b.member.role.index);
      return byRole != 0 ? byRole : a.user.name.compareTo(b.user.name);
    });
    return list;
  }

  Future<bool> isMember(int projectId, int userId) async {
    final row = await (_db.select(_db.projectMembers)
          ..where((m) => m.projectId.equals(projectId) & m.userId.equals(userId)))
        .getSingleOrNull();
    return row != null;
  }

  Future<void> addMember(int projectId, int userId, {ProjectRole role = ProjectRole.member}) async {
    await _db.transaction(() async {
      if (await getProject(projectId) == null) throw const NotFoundException('Проект не найден');
      await _requireUser(userId);
      if (await isMember(projectId, userId)) {
        throw const BusinessRuleException('Пользователь уже состоит в этом проекте');
      }
      await _db.into(_db.projectMembers).insert(
            ProjectMembersCompanion.insert(
              projectId: projectId,
              userId: userId,
              role: Value(role),
              joinedAt: Value(DateTime.now()),
            ),
          );
    });
  }

  Future<void> changeRole(int projectId, int userId, ProjectRole role) async {
    final updated = await (_db.update(_db.projectMembers)
          ..where((m) => m.projectId.equals(projectId) & m.userId.equals(userId)))
        .write(ProjectMembersCompanion(role: Value(role)));
    if (updated == 0) throw const NotFoundException('Участник не найден');
  }

  /// Удаляет участника. Запрещено, пока на нём есть незавершённые задачи
  /// этого проекта — иначе исполнителем оказался бы не участник проекта.
  Future<void> removeMember(int projectId, int userId) async {
    await _db.transaction(() async {
      final t = _db.tasks;
      final count = t.id.count();
      final query = _db.selectOnly(t)
        ..addColumns([count])
        ..where(
          t.projectId.equals(projectId) &
              t.assigneeId.equals(userId) &
              t.deletedAt.isNull() &
              t.status.isIn(TaskStatus.openNames),
        );
      final open = await query.map((row) => row.read(count)).getSingle() ?? 0;
      if (open > 0) {
        throw BusinessRuleException(
          'Сначала переназначьте незавершённые задачи участника ($open)',
        );
      }
      final removed = await (_db.delete(_db.projectMembers)
            ..where((m) => m.projectId.equals(projectId) & m.userId.equals(userId)))
          .go();
      if (removed == 0) throw const NotFoundException('Участник не найден');
    });
  }

  Future<void> _requireUser(int userId) async {
    final user = await (_db.select(_db.users)..where((u) => u.id.equals(userId))).getSingleOrNull();
    if (user == null) throw const NotFoundException('Пользователь не найден');
  }
}
