import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/repositories/attachment_repository.dart';
import '../data/repositories/benchmark_repository.dart';
import '../data/repositories/comment_repository.dart';
import '../data/repositories/project_repository.dart';
import '../data/repositories/stats_repository.dart';
import '../data/repositories/task_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/services/file_storage.dart';
import '../models/dashboard_stats.dart';
import '../models/task_models.dart';
import '../models/task_query.dart';

// ---------------------------------------------------------------------------
// Инфраструктура
// ---------------------------------------------------------------------------

/// Переопределяется в main.dart (и в тестах — in-memory базой).
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider должен быть переопределён в ProviderScope'),
);

final userRepositoryProvider = Provider((ref) => UserRepository(ref.watch(databaseProvider)));
final projectRepositoryProvider = Provider((ref) => ProjectRepository(ref.watch(databaseProvider)));
final taskRepositoryProvider = Provider((ref) => TaskRepository(ref.watch(databaseProvider)));
final commentRepositoryProvider = Provider((ref) => CommentRepository(ref.watch(databaseProvider)));
final attachmentRepositoryProvider = Provider((ref) => AttachmentRepository(ref.watch(databaseProvider)));
final statsRepositoryProvider = Provider((ref) => StatsRepository(ref.watch(databaseProvider)));
final benchmarkRepositoryProvider = Provider((ref) => BenchmarkRepository(ref.watch(databaseProvider)));
final fileStorageProvider = Provider((ref) => FileStorage());

// ---------------------------------------------------------------------------
// Пользователи и «текущий пользователь»
// ---------------------------------------------------------------------------

final usersProvider = StreamProvider<List<User>>((ref) => ref.watch(userRepositoryProvider).watchUsers());

final userSearchProvider = StreamProvider.autoDispose.family<List<User>, String>(
  (ref, search) => ref.watch(userRepositoryProvider).watchUsers(search: search),
);

final userProvider = StreamProvider.autoDispose.family<User?, int>(
  (ref, id) => ref.watch(userRepositoryProvider).watchUser(id),
);

/// Пользователь, от имени которого выполняются действия
/// (он записывается в историю изменений и становится автором комментариев).
final currentUserIdProvider = StateProvider<int?>((ref) => null);

final currentUserProvider = Provider<User?>((ref) {
  final users = ref.watch(usersProvider).valueOrNull ?? const <User>[];
  if (users.isEmpty) return null;
  final id = ref.watch(currentUserIdProvider);
  for (final user in users) {
    if (user.id == id) return user;
  }
  return users.first;
});

// ---------------------------------------------------------------------------
// Проекты
// ---------------------------------------------------------------------------

final projectsProvider = StreamProvider<List<ProjectSummary>>(
  (ref) => ref.watch(projectRepositoryProvider).watchProjects(),
);

final projectProvider = StreamProvider.autoDispose.family<Project?, int>(
  (ref, id) => ref.watch(projectRepositoryProvider).watchProject(id),
);

final projectMembersProvider = StreamProvider.autoDispose.family<List<MemberWithUser>, int>(
  (ref, projectId) => ref.watch(projectRepositoryProvider).watchMembers(projectId),
);

// ---------------------------------------------------------------------------
// Задачи
// ---------------------------------------------------------------------------

final taskPageProvider = StreamProvider.autoDispose.family<TaskPage, TaskQuery>(
  (ref, query) => ref.watch(taskRepositoryProvider).watchTaskPage(query),
);

final taskProvider = StreamProvider.autoDispose.family<TaskWithDetails?, int>(
  (ref, id) => ref.watch(taskRepositoryProvider).watchTask(id),
);

final taskHistoryProvider = StreamProvider.autoDispose.family<List<HistoryItem>, int>(
  (ref, taskId) => ref.watch(taskRepositoryProvider).watchHistory(taskId),
);

final canUndoProvider = StreamProvider.autoDispose.family<bool, int>(
  (ref, taskId) => ref.watch(taskRepositoryProvider).watchCanUndo(taskId),
);

final commentsProvider = StreamProvider.autoDispose.family<List<CommentWithAuthor>, int>(
  (ref, taskId) => ref.watch(commentRepositoryProvider).watchComments(taskId),
);

final attachmentsProvider = StreamProvider.autoDispose.family<List<Attachment>, int>(
  (ref, taskId) => ref.watch(attachmentRepositoryProvider).watchAttachments(taskId),
);

final trashProvider = StreamProvider.autoDispose<List<TaskWithDetails>>(
  (ref) => ref.watch(taskRepositoryProvider).watchTrash(),
);

// ---------------------------------------------------------------------------
// Статистика
// ---------------------------------------------------------------------------

final dashboardProvider = StreamProvider<DashboardStats>(
  (ref) => ref.watch(statsRepositoryProvider).watchStats(),
);
