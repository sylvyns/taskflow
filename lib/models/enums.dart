/// Перечисления предметной области.
///
/// В базе данных хранятся через `textEnum` — в столбец пишется `name`
/// (todo, inProgress, done, cancelled …), как и требует задание.
library;

enum TaskStatus {
  todo('Ожидает'),
  inProgress('В работе'),
  done('Завершена'),
  cancelled('Отменена');

  const TaskStatus(this.label);

  final String label;

  /// Незавершённая задача (ожидает или выполняется).
  bool get isOpen => this == TaskStatus.todo || this == TaskStatus.inProgress;

  /// Имена незавершённых статусов — для SQL-фильтров.
  static List<String> get openNames => [TaskStatus.todo.name, TaskStatus.inProgress.name];
}

enum TaskPriority {
  low('Низкий'),
  medium('Средний'),
  high('Высокий'),
  critical('Критический');

  const TaskPriority(this.label);

  final String label;
}

enum ProjectStatus {
  active('Активный'),
  completed('Завершённый'),
  archived('Архивный');

  const ProjectStatus(this.label);

  final String label;
}

enum ProjectRole {
  owner('Owner'),
  admin('Admin'),
  member('Member');

  const ProjectRole(this.label);

  final String label;
}

/// Тип записи в истории изменений задачи.
enum HistoryChangeType {
  /// Задача создана (первая запись истории).
  created,

  /// Изменение статуса.
  status,

  /// Назначение / переназначение исполнителя.
  assignee,

  /// Отмена последнего изменения статуса (Undo).
  undo,
}
