import 'enums.dart';

/// Варианты сортировки списка задач.
enum TaskSort {
  newest('Сначала новые'),
  oldest('Сначала старые'),
  deadlineAsc('Дедлайн: ближайшие'),
  deadlineDesc('Дедлайн: дальние');

  const TaskSort(this.label);

  final String label;
}

/// Параметры выборки задач: фильтры, поиск, сортировка, пагинация.
///
/// Неизменяемый объект с корректными `==`/`hashCode`, поэтому его можно
/// использовать как ключ `family`-провайдера.
class TaskQuery {
  const TaskQuery({
    this.projectId,
    this.assigneeId,
    this.status,
    this.priority,
    this.search = '',
    this.sort = TaskSort.newest,
    this.page = 0,
    this.pageSize = 20,
  });

  final int? projectId;
  final int? assigneeId;
  final TaskStatus? status;
  final TaskPriority? priority;
  final String search;
  final TaskSort sort;
  final int page;
  final int pageSize;

  static const Object _unset = Object();

  TaskQuery copyWith({
    Object? projectId = _unset,
    Object? assigneeId = _unset,
    Object? status = _unset,
    Object? priority = _unset,
    String? search,
    TaskSort? sort,
    int? page,
    int? pageSize,
  }) {
    return TaskQuery(
      projectId: identical(projectId, _unset) ? this.projectId : projectId as int?,
      assigneeId: identical(assigneeId, _unset) ? this.assigneeId : assigneeId as int?,
      status: identical(status, _unset) ? this.status : status as TaskStatus?,
      priority: identical(priority, _unset) ? this.priority : priority as TaskPriority?,
      search: search ?? this.search,
      sort: sort ?? this.sort,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  bool get hasFilters => status != null || priority != null || search.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is TaskQuery &&
      other.projectId == projectId &&
      other.assigneeId == assigneeId &&
      other.status == status &&
      other.priority == priority &&
      other.search == search &&
      other.sort == sort &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(projectId, assigneeId, status, priority, search, sort, page, pageSize);
}
