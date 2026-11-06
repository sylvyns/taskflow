import 'enums.dart';

/// Данные для экрана статистики. Все числа считаются SQL-запросами
/// в [StatsRepository].
class DashboardStats {
  const DashboardStats({
    required this.projects,
    required this.totalTasks,
    required this.done,
    required this.open,
    required this.cancelled,
    required this.overdue,
    required this.unassigned,
    required this.byPriority,
    required this.byAssignee,
    required this.projectProgress,
  });

  final int projects;
  final int totalTasks;
  final int done;

  /// Незавершённые = ожидают + выполняются.
  final int open;
  final int cancelled;
  final int overdue;
  final int unassigned;
  final Map<TaskPriority, int> byPriority;
  final List<AssigneeStat> byAssignee;
  final List<ProjectProgress> projectProgress;
}

class AssigneeStat {
  const AssigneeStat({required this.userId, required this.name, required this.total, required this.open});

  final int userId;
  final String name;
  final int total;
  final int open;
}

class ProjectProgress {
  const ProjectProgress({
    required this.projectId,
    required this.name,
    required this.status,
    required this.total,
    required this.done,
    required this.percent,
  });

  final int projectId;
  final String name;
  final ProjectStatus status;
  final int total;
  final int done;

  /// Процент выполнения 0..100 (рассчитан в SQL).
  final double percent;
}
