import 'package:drift/drift.dart';

import '../../models/dashboard_stats.dart';
import '../../models/enums.dart';
import '../database/app_database.dart';

/// Статистика для Dashboard. Все показатели считаются SQL-запросами
/// непосредственно в SQLite.
class StatsRepository {
  StatsRepository(this._db);

  final AppDatabase _db;

  static const String totalsSql = '''
SELECT
  (SELECT COUNT(*) FROM projects) AS project_count,
  COUNT(*) AS task_count,
  COALESCE(SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END), 0) AS done_count,
  COALESCE(SUM(CASE WHEN status IN ('todo', 'inProgress') THEN 1 ELSE 0 END), 0) AS open_count,
  COALESCE(SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END), 0) AS cancelled_count,
  COALESCE(SUM(CASE WHEN status IN ('todo', 'inProgress') AND deadline < ? THEN 1 ELSE 0 END), 0) AS overdue_count,
  COALESCE(SUM(CASE WHEN assignee_id IS NULL THEN 1 ELSE 0 END), 0) AS unassigned_count
FROM tasks
WHERE deleted_at IS NULL
''';

  static const String byPrioritySql = '''
SELECT priority, COUNT(*) AS cnt
FROM tasks
WHERE deleted_at IS NULL
GROUP BY priority
''';

  static const String byAssigneeSql = '''
SELECT u.id AS user_id, u.name AS name,
       COUNT(t.id) AS total,
       COALESCE(SUM(CASE WHEN t.status IN ('todo', 'inProgress') THEN 1 ELSE 0 END), 0) AS open_count
FROM users u
JOIN tasks t ON t.assignee_id = u.id AND t.deleted_at IS NULL
GROUP BY u.id, u.name
ORDER BY total DESC, u.name
''';

  static const String projectProgressSql = '''
SELECT p.id AS project_id, p.name AS name, p.status AS status,
       COUNT(t.id) AS total,
       COALESCE(SUM(CASE WHEN t.status = 'done' THEN 1 ELSE 0 END), 0) AS done_count,
       ROUND(
         100.0 * SUM(CASE WHEN t.status = 'done' THEN 1 ELSE 0 END)
         / NULLIF(SUM(CASE WHEN t.status <> 'cancelled' THEN 1 ELSE 0 END), 0),
         1
       ) AS percent
FROM projects p
LEFT JOIN tasks t ON t.project_id = p.id AND t.deleted_at IS NULL
GROUP BY p.id, p.name, p.status
ORDER BY p.name
''';

  /// Пересчитывает статистику при каждом изменении связанных таблиц.
  Stream<DashboardStats> watchStats() async* {
    yield await loadStats();
    yield* _db
        .tableUpdates(TableUpdateQuery.onAllTables([_db.tasks, _db.projects, _db.users, _db.projectMembers]))
        .asyncMap((_) => loadStats());
  }

  Future<DashboardStats> loadStats({DateTime? now}) async {
    final moment = now ?? DateTime.now();

    final totals = await _db.customSelect(totalsSql, variables: [Variable.withDateTime(moment)]).getSingle();
    final priorityRows = await _db.customSelect(byPrioritySql).get();
    final assigneeRows = await _db.customSelect(byAssigneeSql).get();
    final projectRows = await _db.customSelect(projectProgressSql).get();

    final byPriority = {for (final p in TaskPriority.values) p: 0};
    for (final row in priorityRows) {
      final priority = TaskPriority.values.byName(row.read<String>('priority'));
      byPriority[priority] = row.read<int>('cnt');
    }

    return DashboardStats(
      projects: totals.read<int>('project_count'),
      totalTasks: totals.read<int>('task_count'),
      done: totals.read<int>('done_count'),
      open: totals.read<int>('open_count'),
      cancelled: totals.read<int>('cancelled_count'),
      overdue: totals.read<int>('overdue_count'),
      unassigned: totals.read<int>('unassigned_count'),
      byPriority: byPriority,
      byAssignee: assigneeRows
          .map(
            (row) => AssigneeStat(
              userId: row.read<int>('user_id'),
              name: row.read<String>('name'),
              total: row.read<int>('total'),
              open: row.read<int>('open_count'),
            ),
          )
          .toList(),
      projectProgress: projectRows
          .map(
            (row) => ProjectProgress(
              projectId: row.read<int>('project_id'),
              name: row.read<String>('name'),
              status: ProjectStatus.values.byName(row.read<String>('status')),
              total: row.read<int>('total'),
              done: row.read<int>('done_count'),
              percent: row.readNullable<double>('percent') ?? 0,
            ),
          )
          .toList(),
    );
  }
}
