import '../data/database/app_database.dart';

/// Задача вместе с проектом и исполнителем (результат JOIN).
class TaskWithDetails {
  const TaskWithDetails({required this.task, required this.project, this.assignee});

  final Task task;
  final Project project;
  final User? assignee;

  bool get isDeleted => task.deletedAt != null;

  bool isOverdueAt(DateTime now) => task.status.isOpen && task.deadline.isBefore(now);

  bool get isOverdue => isOverdueAt(DateTime.now());
}

/// Страница списка задач для пагинации.
class TaskPage {
  const TaskPage({required this.items, required this.total, required this.page, required this.pageSize});

  final List<TaskWithDetails> items;
  final int total;
  final int page;
  final int pageSize;

  int get pageCount => total == 0 ? 1 : (total + pageSize - 1) ~/ pageSize;
  bool get hasPrevious => page > 0;
  bool get hasNext => page + 1 < pageCount;
}

/// Запись истории + пользователь, который выполнил изменение.
class HistoryItem {
  const HistoryItem({required this.entry, this.actor});

  final TaskHistoryEntry entry;
  final User? actor;
}

/// Комментарий + автор.
class CommentWithAuthor {
  const CommentWithAuthor({required this.comment, required this.author});

  final Comment comment;
  final User author;
}

/// Участник проекта + пользователь.
class MemberWithUser {
  const MemberWithUser({required this.member, required this.user});

  final ProjectMember member;
  final User user;
}

/// Проект + счётчики задач для карточки в списке.
class ProjectSummary {
  const ProjectSummary({required this.project, required this.total, required this.done, required this.cancelled});

  final Project project;
  final int total;
  final int done;
  final int cancelled;

  /// Доля выполнения (отменённые задачи не учитываются).
  double get progress {
    final relevant = total - cancelled;
    return relevant <= 0 ? 0 : done / relevant;
  }
}
