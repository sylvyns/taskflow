import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:taskflow/data/database/app_database.dart';
import 'package:taskflow/data/repositories/attachment_repository.dart';
import 'package:taskflow/data/repositories/comment_repository.dart';
import 'package:taskflow/data/repositories/project_repository.dart';
import 'package:taskflow/data/repositories/stats_repository.dart';
import 'package:taskflow/data/repositories/task_repository.dart';
import 'package:taskflow/data/repositories/user_repository.dart';
import 'package:taskflow/models/enums.dart';

/// Тестовое окружение: in-memory SQLite + все репозитории.
///
/// Базовые данные: Алиса (Owner), Боб (Member) — в проекте «Альфа»;
/// Кира — НЕ участник проекта.
class Fixture {
  Fixture(this.db)
      : users = UserRepository(db),
        projects = ProjectRepository(db),
        tasks = TaskRepository(db),
        comments = CommentRepository(db),
        attachments = AttachmentRepository(db),
        stats = StatsRepository(db);

  final AppDatabase db;
  final UserRepository users;
  final ProjectRepository projects;
  final TaskRepository tasks;
  final CommentRepository comments;
  final AttachmentRepository attachments;
  final StatsRepository stats;

  late int alice;
  late int bob;
  late int kira;
  late int projectId;

  /// Дедлайн через [days] дней (18:00).
  DateTime inDays(int days) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + days, 18);
  }

  Future<int> newTask({
    String title = 'Задача',
    String description = '',
    int? assigneeId,
    TaskStatus status = TaskStatus.todo,
    TaskPriority priority = TaskPriority.medium,
    DateTime? deadline,
    int? project,
  }) {
    return tasks.createTask(
      projectId: project ?? projectId,
      title: title,
      description: description,
      assigneeId: assigneeId,
      status: status,
      priority: priority,
      deadline: deadline ?? inDays(7),
      actorId: alice,
    );
  }

  Future<void> close() => db.close();
}

AppDatabase openTestDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

Future<Fixture> createFixture() async {
  final f = Fixture(openTestDatabase());
  f.alice = await f.users.createUser(name: 'Алиса Смирнова', email: 'alice@test.io');
  f.bob = await f.users.createUser(name: 'Боб Иванов', email: 'bob@test.io');
  f.kira = await f.users.createUser(name: 'Кира Петрова', email: 'kira@test.io');
  f.projectId = await f.projects.createProject(name: 'Альфа', description: 'Тестовый проект', ownerId: f.alice);
  await f.projects.addMember(f.projectId, f.bob);
  return f;
}
