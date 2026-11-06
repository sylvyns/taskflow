import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/data/database/app_database.dart';
import 'package:taskflow/models/app_exception.dart';
import 'package:taskflow/models/enums.dart';

import 'helpers/test_helpers.dart';

void main() {
  late Fixture f;

  setUp(() async => f = await createFixture());
  tearDown(() => f.close());

  group('Пользователи', () {
    test('1. Создание пользователя сохраняет имя, email и дату регистрации', () async {
      final id = await f.users.createUser(name: '  Дмитрий  ', email: 'Dima@Test.IO');
      final user = await f.users.getUser(id);
      expect(user, isNotNull);
      expect(user!.name, 'Дмитрий');
      expect(user.email, 'dima@test.io', reason: 'email нормализуется в нижний регистр');
      expect(user.registeredAt.difference(DateTime.now()).inMinutes.abs(), lessThan(1));
    });

    test('2. Email уникален: репозиторий отклоняет дубликат (без учёта регистра)', () async {
      await expectLater(
        f.users.createUser(name: 'Двойник', email: 'ALICE@test.io'),
        throwsA(isA<ValidationException>()),
      );
      expect((await f.users.getUsers()).length, 3);
    });

    test('3. Email уникален и на уровне БД (ограничение UNIQUE)', () async {
      await expectLater(
        f.db.into(f.db.users).insert(UsersCompanion.insert(name: 'Обход', email: 'bob@test.io')),
        throwsA(isA<Exception>()),
      );
    });

    test('4. Некорректные данные не сохраняются', () async {
      await expectLater(f.users.createUser(name: '', email: 'x@test.io'), throwsA(isA<ValidationException>()));
      await expectLater(f.users.createUser(name: 'Иван', email: 'not-an-email'), throwsA(isA<ValidationException>()));
    });

    test('5. Редактирование пользователя и проверка занятости email', () async {
      await f.users.updateUser(f.bob, name: 'Борис Иванов', email: 'boris@test.io');
      final bob = await f.users.getUser(f.bob);
      expect(bob!.name, 'Борис Иванов');
      expect(bob.email, 'boris@test.io');
      await expectLater(
        f.users.updateUser(f.bob, name: 'Борис', email: 'alice@test.io'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('6. Удаление: запрещено при незавершённых задачах, разрешено после их завершения', () async {
      final taskId = await f.newTask(assigneeId: f.bob);
      await expectLater(f.users.deleteUser(f.bob), throwsA(isA<BusinessRuleException>()));

      await f.tasks.changeStatus(taskId, TaskStatus.done, actorId: f.alice);
      await f.users.deleteUser(f.bob);

      expect(await f.users.getUser(f.bob), isNull);
      // Связи: участие в проекте удалено каскадно, в задаче исполнитель → NULL.
      expect(await f.projects.isMember(f.projectId, f.bob), isFalse);
      expect((await f.tasks.getTask(taskId))!.assigneeId, isNull);
    });
  });

  group('Проекты и участники', () {
    test('7. Создание проекта: создатель становится Owner', () async {
      final project = await f.projects.getProject(f.projectId);
      expect(project!.name, 'Альфа');
      expect(project.status, ProjectStatus.active);
      final members = await f.projects.getMembers(f.projectId);
      expect(members.map((m) => (m.user.id, m.member.role)), containsAll([(f.alice, ProjectRole.owner), (f.bob, ProjectRole.member)]));
    });

    test('8. Дата завершения не может быть раньше даты создания', () async {
      await expectLater(
        f.projects.createProject(name: 'Прошлое', endDate: DateTime(2000)),
        throwsA(isA<ValidationException>()),
      );
    });

    test('9. Добавление участника и смена роли (Many-to-Many)', () async {
      await f.projects.addMember(f.projectId, f.kira, role: ProjectRole.admin);
      expect(await f.projects.isMember(f.projectId, f.kira), isTrue);
      await f.projects.changeRole(f.projectId, f.kira, ProjectRole.member);
      final kira = (await f.projects.getMembers(f.projectId)).firstWhere((m) => m.user.id == f.kira);
      expect(kira.member.role, ProjectRole.member);

      // Один пользователь — в нескольких проектах.
      final beta = await f.projects.createProject(name: 'Бета', ownerId: f.kira);
      expect(await f.projects.isMember(beta, f.kira), isTrue);
    });

    test('10. Повторное добавление пользователя в проект запрещено (репозиторий и UNIQUE)', () async {
      await expectLater(f.projects.addMember(f.projectId, f.bob), throwsA(isA<BusinessRuleException>()));
      await expectLater(
        f.db.into(f.db.projectMembers).insert(ProjectMembersCompanion.insert(projectId: f.projectId, userId: f.bob)),
        throwsA(isA<Exception>()),
      );
    });

    test('11. Нельзя убрать участника с незавершёнными задачами проекта', () async {
      await f.newTask(assigneeId: f.bob);
      await expectLater(f.projects.removeMember(f.projectId, f.bob), throwsA(isA<BusinessRuleException>()));
    });

    test('12. Удаление проекта каскадно удаляет задачи, участников, историю и комментарии', () async {
      final taskId = await f.newTask(assigneeId: f.bob);
      await f.comments.addComment(taskId: taskId, authorId: f.alice, body: 'Привет');
      await f.projects.deleteProject(f.projectId);

      expect(await f.db.select(f.db.tasks).get(), isEmpty);
      expect(await f.db.select(f.db.projectMembers).get(), isEmpty);
      expect(await f.db.select(f.db.taskHistory).get(), isEmpty);
      expect(await f.db.select(f.db.comments).get(), isEmpty);
      expect((await f.users.getUsers()).length, 3, reason: 'пользователи остаются');
    });
  });
}
