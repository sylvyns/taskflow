import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../models/app_exception.dart';
import '../../models/enums.dart';
import '../../models/task_models.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'task_form_screen.dart';

class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final int taskId;

  Future<void> _moveToTrash(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Переместить в корзину?',
      message: 'Задачу можно будет восстановить из корзины.',
      confirmLabel: 'В корзину',
    );
    if (!ok || !context.mounted) return;
    final repo = ref.read(taskRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final done = await runGuarded(context, () => repo.moveToTrash(taskId));
    if (!done) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Задача перемещена в корзину'),
        action: SnackBarAction(
          label: 'Восстановить',
          textColor: Pastel.mintLight,
          onPressed: () => repo.restoreFromTrash(taskId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskProvider(taskId));
    final item = taskAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Задача'),
        actions: [
          if (item != null && !item.isDeleted) ...[
            IconButton(
              tooltip: 'Редактировать',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TaskFormScreen(existing: item.task)),
              ),
            ),
            IconButton(
              tooltip: 'В корзину',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _moveToTrash(context, ref),
            ),
          ],
        ],
      ),
      body: AsyncValueWidget<TaskWithDetails?>(
        value: taskAsync,
        data: (data) => data == null
            ? const EmptyState(icon: Icons.search_off_rounded, title: 'Задача не найдена', subtitle: 'Возможно, она удалена навсегда')
            : _TaskDetailBody(item: data),
      ),
    );
  }
}

class _TaskDetailBody extends ConsumerWidget {
  const _TaskDetailBody({required this.item});

  final TaskWithDetails item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deleted = item.isDeleted;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        if (deleted) _TrashBanner(taskId: item.task.id),
        _HeaderCard(item: item),
        const SizedBox(height: 12),
        _StatusCard(item: item, enabled: !deleted),
        const SizedBox(height: 12),
        _PriorityAssigneeCard(item: item, enabled: !deleted),
        const SizedBox(height: 12),
        _CommentsCard(taskId: item.task.id, enabled: !deleted),
        const SizedBox(height: 12),
        _AttachmentsCard(taskId: item.task.id, enabled: !deleted),
        const SizedBox(height: 12),
        _HistoryCard(taskId: item.task.id),
      ],
    );
  }
}

/// Требует выбранного пользователя для действий, попадающих в историю.
User? _requireMe(BuildContext context, WidgetRef ref) {
  final me = ref.read(currentUserProvider);
  if (me == null) showSnack(context, 'Сначала добавьте пользователя', error: true);
  return me;
}

class _TrashBanner extends ConsumerWidget {
  const _TrashBanner({required this.taskId});

  final int taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        color: Pastel.roseLight,
        child: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Pastel.roseDeep),
            const SizedBox(width: 10),
            const Expanded(child: Text('Задача в корзине', style: TextStyle(color: Pastel.roseDeep, fontWeight: FontWeight.w600))),
            TextButton(
              onPressed: () => runGuarded(
                context,
                () => ref.read(taskRepositoryProvider).restoreFromTrash(taskId),
                success: 'Задача восстановлена',
              ),
              child: const Text('Восстановить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.item});

  final TaskWithDetails item;

  @override
  Widget build(BuildContext context) {
    final task = item.task;
    final overdue = item.isOverdue;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Pastel.ink)),
          const SizedBox(height: 8),
          Text(
            task.description.isEmpty ? 'Без описания' : task.description,
            style: TextStyle(color: task.description.isEmpty ? Pastel.inkSoft : Pastel.ink, height: 1.35),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          InfoRow(icon: Icons.folder_outlined, label: 'Проект', value: item.project.name),
          InfoRow(
            icon: Icons.event_outlined,
            label: 'Дедлайн',
            value: overdue ? '${fmtDate(task.deadline)} — просрочена' : fmtDate(task.deadline),
            valueColor: overdue ? Pastel.roseDeep : null,
          ),
          InfoRow(icon: Icons.today_outlined, label: 'Создана', value: fmtDateTime(task.createdAt)),
          InfoRow(icon: Icons.update_rounded, label: 'Изменена', value: fmtDateTime(task.updatedAt)),
        ],
      ),
    );
  }
}

class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.item, required this.enabled});

  final TaskWithDetails item;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = item.task;
    final canUndo = ref.watch(canUndoProvider(task.id)).valueOrNull ?? false;
    final repo = ref.read(taskRepositoryProvider);

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Статус', icon: Icons.flag_outlined),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in TaskStatus.values)
                ChoiceChip(
                  avatar: Icon(s.icon, size: 16, color: s.colors.foreground),
                  label: Text(s.label),
                  selected: task.status == s,
                  showCheckmark: false,
                  selectedColor: s.colors.background,
                  onSelected: !enabled || task.status == s
                      ? null
                      : (_) {
                          final me = _requireMe(context, ref);
                          if (me == null) return;
                          runGuarded(context, () => repo.changeStatus(task.id, s, actorId: me.id));
                        },
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: enabled && canUndo
                ? () async {
                    final me = _requireMe(context, ref);
                    if (me == null) return;
                    try {
                      final restored = await repo.undoLastStatusChange(task.id, actorId: me.id);
                      if (context.mounted) showSnack(context, 'Статус возвращён: «${restored.label}»');
                    } on AppException catch (e) {
                      if (context.mounted) showSnack(context, e.message, error: true);
                    }
                  }
                : null,
            icon: const Icon(Icons.undo_rounded),
            label: const Text('Отменить последнее изменение статуса'),
          ),
        ],
      ),
    );
  }
}

class _PriorityAssigneeCard extends ConsumerWidget {
  const _PriorityAssigneeCard({required this.item, required this.enabled});

  final TaskWithDetails item;
  final bool enabled;

  Future<void> _reassign(BuildContext context, WidgetRef ref) async {
    final me = _requireMe(context, ref);
    if (me == null) return;
    final members = await ref.read(projectRepositoryProvider).getMembers(item.task.projectId);
    if (!context.mounted) return;
    final pick = await showUserPicker(
      context,
      users: members.map((m) => m.user).toList(),
      title: 'Исполнитель (участники проекта)',
      noneLabel: 'Снять исполнителя',
      selectedId: item.task.assigneeId,
    );
    if (pick == null || !context.mounted) return;
    await runGuarded(
      context,
      () => ref.read(taskRepositoryProvider).reassign(item.task.id, pick.user?.id, actorId: me.id),
      success: pick.user == null ? 'Исполнитель снят' : 'Исполнитель: ${pick.user!.name}',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = item.task;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Приоритет', icon: Icons.local_fire_department_outlined),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in TaskPriority.values)
                ChoiceChip(
                  avatar: Icon(p.icon, size: 16, color: p.colors.foreground),
                  label: Text(p.label),
                  selected: task.priority == p,
                  showCheckmark: false,
                  selectedColor: p.colors.background,
                  onSelected: !enabled || task.priority == p
                      ? null
                      : (_) => runGuarded(context, () => ref.read(taskRepositoryProvider).changePriority(task.id, p)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const SectionHeader('Исполнитель', icon: Icons.person_outline_rounded),
          Row(
            children: [
              if (item.assignee != null) ...[
                UserAvatar(name: item.assignee!.name),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.assignee!.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(item.assignee!.email, style: const TextStyle(color: Pastel.inkSoft, fontSize: 12.5)),
                    ],
                  ),
                ),
              ] else
                const Expanded(child: Text('Не назначен', style: TextStyle(color: Pastel.inkSoft))),
              FilledButton.tonal(
                onPressed: enabled ? () => _reassign(context, ref) : null,
                child: Text(item.assignee == null ? 'Назначить' : 'Переназначить'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.taskId});

  final int taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(taskHistoryProvider(taskId));
    final users = ref.watch(usersProvider).valueOrNull ?? const <User>[];
    final names = {for (final u in users) u.id: u.name};
    String who(int? id) => id == null ? 'нет' : (names[id] ?? 'удалённый пользователь');

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('История изменений', icon: Icons.history_rounded),
          history.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (items) => Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  _HistoryTile(item: items[i], who: who, isLast: i == items.length - 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item, required this.who, required this.isLast});

  final HistoryItem item;
  final String Function(int?) who;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final e = item.entry;
    final (IconData icon, ChipColors colors, String text) = switch (e.changeType) {
      HistoryChangeType.created => (
          Icons.add_circle_outline_rounded,
          const ChipColors(Pastel.lavenderLight, Pastel.lavenderDeep),
          'Задача создана · статус «${e.newStatus?.label ?? '—'}»'
              '${e.newAssigneeId != null ? ', исполнитель ${who(e.newAssigneeId)}' : ''}',
        ),
      HistoryChangeType.status => (
          Icons.flag_outlined,
          (e.newStatus ?? TaskStatus.todo).colors,
          'Статус: «${e.previousStatus?.label ?? '—'}» → «${e.newStatus?.label ?? '—'}»',
        ),
      HistoryChangeType.assignee => (
          Icons.person_outline_rounded,
          const ChipColors(Pastel.peachLight, Pastel.peachDeep),
          'Исполнитель: ${who(e.previousAssigneeId)} → ${who(e.newAssigneeId)}',
        ),
      HistoryChangeType.undo => (
          Icons.undo_rounded,
          const ChipColors(Pastel.butterLight, Pastel.butterDeep),
          'Отмена: «${e.previousStatus?.label ?? '—'}» → «${e.newStatus?.label ?? '—'}»',
        ),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: colors.background, shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: colors.foreground),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: Pastel.outline)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: e.isUndone ? Pastel.inkSoft : Pastel.ink,
                      decoration: e.isUndone ? TextDecoration.lineThrough : null,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.actor?.name ?? 'система'} · ${fmtDateTime(e.changedAt)}${e.isUndone ? ' · отменено' : ''}',
                    style: const TextStyle(color: Pastel.inkSoft, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentsCard extends ConsumerStatefulWidget {
  const _CommentsCard({required this.taskId, required this.enabled});

  final int taskId;
  final bool enabled;

  @override
  ConsumerState<_CommentsCard> createState() => _CommentsCardState();
}

class _CommentsCardState extends ConsumerState<_CommentsCard> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final me = _requireMe(context, ref);
    if (me == null) return;
    final ok = await runGuarded(
      context,
      () => ref.read(commentRepositoryProvider).addComment(taskId: widget.taskId, authorId: me.id, body: _controller.text),
    );
    if (ok) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(commentsProvider(widget.taskId));
    final me = ref.watch(currentUserProvider);

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Комментарии', icon: Icons.chat_bubble_outline_rounded),
          comments.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (items) => items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Комментариев пока нет', style: TextStyle(color: Pastel.inkSoft)),
                  )
                : Column(
                    children: [
                      for (final c in items)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.author.id == me?.id ? Pastel.lavenderLight : const Color(0xFFF7F4FB),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              UserAvatar(name: c.author.name, radius: 15),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${c.author.name} · ${fmtDateTime(c.comment.createdAt)}',
                                      style: const TextStyle(fontSize: 12, color: Pastel.inkSoft),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(c.comment.body, style: const TextStyle(color: Pastel.ink)),
                                  ],
                                ),
                              ),
                              // Удалять может только автор.
                              if (c.author.id == me?.id)
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Удалить',
                                  icon: const Icon(Icons.close_rounded, size: 18, color: Pastel.inkSoft),
                                  onPressed: () => runGuarded(
                                    context,
                                    () => ref.read(commentRepositoryProvider).deleteComment(c.comment.id, actorId: me!.id),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          if (widget.enabled)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: softInput('Написать комментарий…'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _send,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AttachmentsCard extends ConsumerWidget {
  const _AttachmentsCard({required this.taskId, required this.enabled});

  final int taskId;
  final bool enabled;

  Future<void> _attach(BuildContext context, WidgetRef ref) async {
    await runGuarded(context, () async {
      final result = await FilePicker.platform.pickFiles();
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final path = file.path;
      if (path == null) throw const ValidationException('Не удалось получить путь к файлу');
      final stored = await ref.read(fileStorageProvider).saveCopy(path, file.name);
      await ref.read(attachmentRepositoryProvider).addAttachment(
            taskId: taskId,
            fileName: file.name,
            filePath: stored.path,
            sizeBytes: stored.sizeBytes,
          );
    });
  }

  IconData _iconFor(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' || 'heic' => Icons.image_outlined,
      'pdf' => Icons.picture_as_pdf_outlined,
      'doc' || 'docx' || 'txt' || 'md' => Icons.description_outlined,
      'xls' || 'xlsx' || 'csv' => Icons.table_chart_outlined,
      'zip' || 'rar' || '7z' => Icons.folder_zip_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachments = ref.watch(attachmentsProvider(taskId));
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            'Вложения',
            icon: Icons.attach_file_rounded,
            trailing: enabled
                ? TextButton.icon(
                    onPressed: () => _attach(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Прикрепить'),
                  )
                : null,
          ),
          attachments.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (items) => items.isEmpty
                ? const Text('Файлов нет', style: TextStyle(color: Pastel.inkSoft))
                : Column(
                    children: [
                      for (final a in items)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Pastel.skyLight, borderRadius: BorderRadius.circular(12)),
                            child: Icon(_iconFor(a.fileName), color: Pastel.skyDeep),
                          ),
                          title: Text(a.fileName, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${fmtBytes(a.sizeBytes)} · ${fmtDateTime(a.addedAt)}\n${a.filePath}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          isThreeLine: true,
                          trailing: enabled
                              ? IconButton(
                                  tooltip: 'Открепить',
                                  icon: const Icon(Icons.link_off_rounded, color: Pastel.inkSoft),
                                  onPressed: () => runGuarded(
                                    context,
                                    () => ref.read(attachmentRepositoryProvider).deleteAttachment(a.id),
                                  ),
                                )
                              : null,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
