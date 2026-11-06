import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/data/repositories/task_repository.dart';
import 'package:taskflow/models/app_exception.dart';
import 'package:taskflow/models/enums.dart';
import 'package:taskflow/models/task_query.dart';

import 'helpers/test_helpers.dart';

void main() {
  late Fixture f;

  setUp(() async => f = await createFixture());
  tearDown(() => f.close());

  group('Создание задач и целостность', () {
    test('13. Создание задачи сохраняет все поля и первую запись истории', () async {
      final deadline = f.inDays(3);
      final id = await f.newTask(
        title: 'Сверстать экран',
        description: 'Главная страница',
        assigneeId: f.bob,
        priority: TaskPriority.high,
        deadline: deadline,
      );
      final task = (await f.tasks.getTask(id))!;
      expect(task.title, 'Сверстать экран');
      expect(task.projectId, f.projectId);
      expect(task.assigneeId, f.bob);
      expect(task.priority, TaskPriority.high);
      expect(task.status, TaskStatus.todo);
      expect(task.deadline, deadline);
      expect(task.deletedAt, isNull);

      final history = await f.tasks.getHistory(id);
      expect(history, hasLength(1));
      expect(history.single.entry.changeType, HistoryChangeType.created);
      expect(history.single.entry.newStatus, TaskStatus.todo);
      expect(history.single.actor!.id, f.alice);
    });

    test('14. Нельзя создать задачу без проекта или в несуществующем проекте', () async {
      await expectLater(
        f.tasks.createTask(projectId: null, title: 'X', deadline: f.inDays(1), actorId: f.alice),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        f.tasks.createTask(projectId: 9999, title: 'X', deadline: f.inDays(1), actorId: f.alice),
        throwsA(isA<NotFoundException>()),
      );
      expect(await f.db.select(f.db.tasks).get(), isEmpty);
    });

    test('15. Исполнитель должен быть участником проекта', () async {
      await expectLater(f.newTask(assigneeId: f.kira), throwsA(isA<BusinessRuleException>()));
      await f.projects.addMember(f.projectId, f.kira);
      expect(await f.newTask(assigneeId: f.kira), isPositive);
    });

    test('16. Транзакция: если история не сохранилась, задача тоже не сохраняется', () async {
      // actorId = 9999 нарушает внешний ключ task_history.changed_by → users.id,
      // поэтому вставка истории падает уже ПОСЛЕ вставки задачи.
      await expectLater(
        f.tasks.createTask(projectId: f.projectId, title: 'Откат', deadline: f.inDays(1), actorId: 9999),
        throwsA(anything),
      );
      expect(await f.db.select(f.db.tasks).get(), isEmpty, reason: 'задача откатилась вместе с историей');
      expect(await f.db.select(f.db.taskHistory).get(), isEmpty);
    });
  });

  group('Статус, история, переназначение', () {
    test('17. Изменение статуса автоматически пишет историю', () async {
      final id = await f.newTask(assigneeId: f.bob);
      await f.tasks.changeStatus(id, TaskStatus.inProgress, actorId: f.bob);
      await f.tasks.changeStatus(id, TaskStatus.done, actorId: f.alice);

      expect((await f.tasks.getTask(id))!.status, TaskStatus.done);
      final history = (await f.tasks.getHistory(id)).where((h) => h.entry.changeType == HistoryChangeType.status).toList();
      expect(history, hasLength(2));
      // Новые записи — первыми.
      expect(history[0].entry.previousStatus, TaskStatus.inProgress);
      expect(history[0].entry.newStatus, TaskStatus.done);
      expect(history[0].actor!.id, f.alice);
      expect(history[1].entry.previousStatus, TaskStatus.todo);
      expect(history[1].entry.newStatus, TaskStatus.inProgress);
      expect(history[1].actor!.id, f.bob);
    });

    test('18. Переназначение атомарно: проверка участника + запись в историю', () async {
      final id = await f.newTask(assigneeId: f.bob);

      await expectLater(f.tasks.reassign(id, f.kira, actorId: f.alice), throwsA(isA<BusinessRuleException>()));
      expect((await f.tasks.getTask(id))!.assigneeId, f.bob, reason: 'исполнитель не изменился');
      expect(await f.tasks.getHistory(id), hasLength(1), reason: 'история не пополнилась');

      await f.tasks.reassign(id, f.alice, actorId: f.alice);
      expect((await f.tasks.getTask(id))!.assigneeId, f.alice);
      final last = (await f.tasks.getHistory(id)).first.entry;
      expect(last.changeType, HistoryChangeType.assignee);
      expect(last.previousAssigneeId, f.bob);
      expect(last.newAssigneeId, f.alice);
    });

    test('19. Undo: последовательная отмена изменений статуса', () async {
      final id = await f.newTask();
      await f.tasks.changeStatus(id, TaskStatus.inProgress, actorId: f.alice);
      await f.tasks.changeStatus(id, TaskStatus.done, actorId: f.alice);

      expect(await f.tasks.undoLastStatusChange(id, actorId: f.alice), TaskStatus.inProgress);
      expect((await f.tasks.getTask(id))!.status, TaskStatus.inProgress);
      expect(await f.tasks.undoLastStatusChange(id, actorId: f.alice), TaskStatus.todo);
      expect((await f.tasks.getTask(id))!.status, TaskStatus.todo);

      await expectLater(f.tasks.undoLastStatusChange(id, actorId: f.alice), throwsA(isA<BusinessRuleException>()));

      final history = await f.tasks.getHistory(id);
      expect(history.where((h) => h.entry.changeType == HistoryChangeType.undo), hasLength(2));
      expect(history.where((h) => h.entry.isUndone), hasLength(2));
    });

    test('20. Лимит: не больше 3 незавершённых задач исполнителя на одну дату', () async {
      final day = f.inDays(5);
      final sameDayMorning = DateTime(day.year, day.month, day.day, 9);
      for (var i = 0; i < TaskRepository.maxOpenTasksPerDay; i++) {
        await f.newTask(title: 'Задача $i', assigneeId: f.bob, deadline: i.isEven ? day : sameDayMorning);
      }
      await expectLater(f.newTask(assigneeId: f.bob, deadline: day), throwsA(isA<BusinessRuleException>()));

      // Другая дата — можно.
      expect(await f.newTask(assigneeId: f.bob, deadline: f.inDays(6)), isPositive);

      // Переназначить на перегруженного исполнителя тоже нельзя.
      final free = await f.newTask(assigneeId: f.alice, deadline: day);
      await expectLater(f.tasks.reassign(free, f.bob, actorId: f.alice), throwsA(isA<BusinessRuleException>()));

      // После завершения одной задачи — снова можно.
      final first = (await f.tasks.getTaskPage(TaskQuery(projectId: f.projectId, assigneeId: f.bob, sort: TaskSort.oldest))).items.first;
      await f.tasks.changeStatus(first.task.id, TaskStatus.done, actorId: f.alice);
      expect(await f.newTask(assigneeId: f.bob, deadline: day), isPositive);
    });
  });

  group('Комментарии и вложения', () {
    test('21. Добавление и просмотр комментариев', () async {
      final id = await f.newTask();
      await f.comments.addComment(taskId: id, authorId: f.alice, body: 'Первый');
      await f.comments.addComment(taskId: id, authorId: f.bob, body: 'Второй');
      final list = await f.comments.getComments(id);
      expect(list.map((c) => c.comment.body), ['Первый', 'Второй']);
      expect(list.first.author.id, f.alice);
    });

    test('22. Нельзя комментировать несуществующую задачу', () async {
      await expectLater(
        f.comments.addComment(taskId: 4242, authorId: f.alice, body: 'Есть кто?'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('23. Удалить комментарий может только автор', () async {
      final id = await f.newTask();
      final commentId = await f.comments.addComment(taskId: id, authorId: f.alice, body: 'Мой комментарий');
      await expectLater(f.comments.deleteComment(commentId, actorId: f.bob), throwsA(isA<BusinessRuleException>()));
      await f.comments.deleteComment(commentId, actorId: f.alice);
      expect(await f.comments.getComments(id), isEmpty);
    });

    test('24. Вложение хранит путь к файлу, а не содержимое', () async {
      final id = await f.newTask();
      await f.attachments.addAttachment(taskId: id, fileName: 'spec.pdf', filePath: '/data/attachments/spec.pdf', sizeBytes: 2048);
      final list = await f.attachments.getAttachments(id);
      expect(list.single.fileName, 'spec.pdf');
      expect(list.single.filePath, '/data/attachments/spec.pdf');
      expect(list.single.taskId, id);
    });
  });

  group('Корзина (Soft Delete)', () {
    test('25. Удалённая задача остаётся в БД, но исключается из списков', () async {
      final id = await f.newTask(title: 'В корзину');
      await f.tasks.moveToTrash(id);

      final raw = await f.tasks.getTask(id);
      expect(raw, isNotNull, reason: 'физически запись не удалена');
      expect(raw!.deletedAt, isNotNull);
      expect((await f.tasks.getTaskPage(TaskQuery(projectId: f.projectId))).total, 0);
      expect((await f.tasks.getTrash()).single.task.id, id);
      // С удалённой задачей нельзя работать.
      await expectLater(f.tasks.changeStatus(id, TaskStatus.done, actorId: f.alice), throwsA(isA<NotFoundException>()));
    });

    test('26. Восстановление задачи из корзины', () async {
      final id = await f.newTask();
      await f.tasks.moveToTrash(id);
      await f.tasks.restoreFromTrash(id);
      expect((await f.tasks.getTask(id))!.deletedAt, isNull);
      expect((await f.tasks.getTaskPage(TaskQuery(projectId: f.projectId))).total, 1);
      expect(await f.tasks.getTrash(), isEmpty);
    });

    test('27. Полное удаление — только из корзины, с каскадом', () async {
      final id = await f.newTask();
      await f.comments.addComment(taskId: id, authorId: f.alice, body: 'к удалению');
      await expectLater(f.tasks.deletePermanently(id), throwsA(isA<BusinessRuleException>()));

      await f.tasks.moveToTrash(id);
      await f.tasks.deletePermanently(id);
      expect(await f.tasks.getTask(id), isNull);
      expect(await f.tasks.getHistory(id), isEmpty);
      expect(await f.comments.getComments(id), isEmpty);
    });
  });
}
