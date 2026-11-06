import 'package:drift/drift.dart';

import '../../models/enums.dart';

/// Пользователи. Email уникален (UNIQUE).
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get email => text().withLength(min: 3, max: 254).unique()();
  DateTimeColumn get registeredAt => dateTime().withDefault(currentDateAndTime)();
}

/// Проекты.
class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get status => textEnum<ProjectStatus>().withDefault(const Constant('active'))();
}

/// Участники проектов — связь Many-to-Many между users и projects.
/// Пара (project_id, user_id) уникальна: нельзя добавить одного
/// пользователя в проект дважды.
class ProjectMembers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().customConstraint('NOT NULL REFERENCES projects(id) ON DELETE CASCADE')();
  IntColumn get userId => integer().customConstraint('NOT NULL REFERENCES users(id) ON DELETE CASCADE')();
  TextColumn get role => textEnum<ProjectRole>().withDefault(const Constant('member'))();
  DateTimeColumn get joinedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {projectId, userId},
      ];
}

/// Задачи. One-to-Many: проект → задачи, пользователь → задачи.
///
/// Поле [priority] появилось во второй версии схемы (см. миграцию).
/// Поле [deletedAt] — Soft Delete (корзина).
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get projectId => integer().customConstraint('NOT NULL REFERENCES projects(id) ON DELETE CASCADE')();
  IntColumn get assigneeId => integer().nullable().customConstraint('NULL REFERENCES users(id) ON DELETE SET NULL')();
  TextColumn get priority => textEnum<TaskPriority>().withDefault(const Constant('medium'))();
  TextColumn get status => textEnum<TaskStatus>().withDefault(const Constant('todo'))();
  DateTimeColumn get deadline => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Комментарии к задачам.
class Comments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId => integer().customConstraint('NOT NULL REFERENCES tasks(id) ON DELETE CASCADE')();
  IntColumn get authorId => integer().customConstraint('NOT NULL REFERENCES users(id) ON DELETE CASCADE')();
  TextColumn get body => text().withLength(min: 1, max: 2000)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Вложения. В БД хранится только путь к файлу, а не его содержимое.
class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId => integer().customConstraint('NOT NULL REFERENCES tasks(id) ON DELETE CASCADE')();
  TextColumn get fileName => text().withLength(min: 1, max: 255)();
  TextColumn get filePath => text().withLength(min: 1, max: 1024)();
  IntColumn get sizeBytes => integer().nullable()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
}

/// История изменений задач.
@DataClassName('TaskHistoryEntry')
class TaskHistory extends Table {
  @override
  String get tableName => 'task_history';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId => integer().customConstraint('NOT NULL REFERENCES tasks(id) ON DELETE CASCADE')();
  TextColumn get changeType => textEnum<HistoryChangeType>()();
  TextColumn get previousStatus => textEnum<TaskStatus>().nullable()();
  TextColumn get newStatus => textEnum<TaskStatus>().nullable()();
  IntColumn get previousAssigneeId => integer().nullable()();
  IntColumn get newAssigneeId => integer().nullable()();
  IntColumn get changedBy => integer().nullable().customConstraint('NULL REFERENCES users(id) ON DELETE SET NULL')();
  DateTimeColumn get changedAt => dateTime().withDefault(currentDateAndTime)();

  /// Запись была отменена через Undo.
  BoolColumn get isUndone => boolean().withDefault(const Constant(false))();
}
