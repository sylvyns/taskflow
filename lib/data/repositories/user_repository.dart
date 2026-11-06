import 'package:drift/drift.dart';

import '../../models/app_exception.dart';
import '../../models/enums.dart';
import '../database/app_database.dart';
import '../validators.dart';

/// Работа с пользователями.
class UserRepository {
  UserRepository(this._db);

  final AppDatabase _db;

  Stream<List<User>> watchUsers({String search = ''}) => _usersQuery(search).watch();

  Future<List<User>> getUsers({String search = ''}) => _usersQuery(search).get();

  SimpleSelectStatement<$UsersTable, User> _usersQuery(String search) {
    final query = _db.select(_db.users);
    final text = search.trim();
    if (text.isNotEmpty) {
      final pattern = '%$text%';
      query.where((u) => u.name.like(pattern) | u.email.like(pattern));
    }
    query.orderBy([(u) => OrderingTerm.asc(u.name), (u) => OrderingTerm.asc(u.id)]);
    return query;
  }

  Stream<User?> watchUser(int id) => (_db.select(_db.users)..where((u) => u.id.equals(id))).watchSingleOrNull();

  Future<User?> getUser(int id) => (_db.select(_db.users)..where((u) => u.id.equals(id))).getSingleOrNull();

  Future<int> createUser({required String name, required String email, DateTime? registeredAt}) async {
    final cleanName = Validators.requiredText(name, 'Имя', maxLength: 100);
    final cleanEmail = Validators.email(email);
    return _db.transaction(() async {
      if (await _emailTaken(cleanEmail)) {
        throw ValidationException('Пользователь с email $cleanEmail уже существует');
      }
      return _db.into(_db.users).insert(
            UsersCompanion.insert(
              name: cleanName,
              email: cleanEmail,
              registeredAt: Value(registeredAt ?? DateTime.now()),
            ),
          );
    });
  }

  Future<void> updateUser(int id, {required String name, required String email}) async {
    final cleanName = Validators.requiredText(name, 'Имя', maxLength: 100);
    final cleanEmail = Validators.email(email);
    await _db.transaction(() async {
      if (await getUser(id) == null) {
        throw const NotFoundException('Пользователь не найден');
      }
      if (await _emailTaken(cleanEmail, exceptId: id)) {
        throw ValidationException('Пользователь с email $cleanEmail уже существует');
      }
      await (_db.update(_db.users)..where((u) => u.id.equals(id)))
          .write(UsersCompanion(name: Value(cleanName), email: Value(cleanEmail)));
    });
  }

  /// Удаление с учётом связей: запрещено, если у пользователя есть
  /// незавершённые задачи. Участие в проектах и комментарии удаляются
  /// каскадно, в завершённых задачах исполнитель становится NULL.
  Future<void> deleteUser(int id) async {
    await _db.transaction(() async {
      if (await getUser(id) == null) {
        throw const NotFoundException('Пользователь не найден');
      }
      final open = await countOpenTasks(id);
      if (open > 0) {
        throw BusinessRuleException(
          'Нельзя удалить пользователя: за ним закреплены незавершённые задачи ($open)',
        );
      }
      await (_db.delete(_db.users)..where((u) => u.id.equals(id))).go();
    });
  }

  /// Количество незавершённых (todo / inProgress) задач пользователя.
  Future<int> countOpenTasks(int userId) async {
    final t = _db.tasks;
    final count = t.id.count();
    final query = _db.selectOnly(t)
      ..addColumns([count])
      ..where(t.assigneeId.equals(userId) & t.deletedAt.isNull() & t.status.isIn(TaskStatus.openNames));
    return await query.map((row) => row.read(count)).getSingle() ?? 0;
  }

  Future<bool> _emailTaken(String email, {int? exceptId}) async {
    final query = _db.select(_db.users)..where((u) => u.email.equals(email));
    final found = await query.get();
    return found.any((u) => u.id != exceptId);
  }
}
