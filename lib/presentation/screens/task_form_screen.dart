import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../models/enums.dart';
import '../../models/task_models.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Создание задачи или редактирование основных полей.
/// Статус и исполнитель существующей задачи меняются на экране задачи —
/// там же ведётся история изменений.
class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key, this.projectId, this.existing});

  final int? projectId;
  final Task? existing;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late int? _projectId = widget.existing?.projectId ?? widget.projectId;
  int? _assigneeId;
  late TaskPriority _priority = widget.existing?.priority ?? TaskPriority.medium;
  TaskStatus _status = TaskStatus.todo;
  late DateTime _deadline = widget.existing?.deadline ?? _endOfDay(DateTime.now().add(const Duration(days: 7)));
  bool _saving = false;

  bool get _editing => widget.existing != null;

  static DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59);

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline.isBefore(first) ? first : _deadline,
      firstDate: first,
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _deadline = _endOfDay(picked));
  }

  Future<void> _save() async {
    final me = ref.read(currentUserProvider);
    if (me == null) {
      showSnack(context, 'Сначала добавьте пользователя — от его имени ведётся история', error: true);
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(taskRepositoryProvider);
    final ok = await runGuarded(context, () async {
      if (_editing) {
        await repo.updateTask(
          widget.existing!.id,
          title: _title.text,
          description: _description.text,
          priority: _priority,
          deadline: _deadline,
        );
      } else {
        await repo.createTask(
          projectId: _projectId,
          title: _title.text,
          description: _description.text,
          assigneeId: _assigneeId,
          priority: _priority,
          status: _status,
          deadline: _deadline,
          actorId: me.id,
        );
      }
    }, success: _editing ? 'Задача сохранена' : 'Задача создана');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider).valueOrNull ?? const <ProjectSummary>[];
    final members = _projectId == null
        ? const <MemberWithUser>[]
        : ref.watch(projectMembersProvider(_projectId!)).valueOrNull ?? const <MemberWithUser>[];

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Редактирование задачи' : 'Новая задача')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _title, decoration: softInput('Название', icon: Icons.title_rounded)),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: 8,
            decoration: softInput('Описание', icon: Icons.notes_rounded),
          ),
          if (!_editing) ...[
            const SizedBox(height: 12),
            InputDecorator(
              decoration: softInput('Проект', icon: Icons.folder_outlined),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  isDense: true,
                  value: projects.any((p) => p.project.id == _projectId) ? _projectId : null,
                  hint: const Text('Выберите проект'),
                  borderRadius: BorderRadius.circular(16),
                  items: [
                    for (final p in projects)
                      DropdownMenuItem(value: p.project.id, child: Text(p.project.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: widget.projectId != null
                      ? null
                      : (value) => setState(() {
                            _projectId = value;
                            _assigneeId = null;
                          }),
                ),
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: softInput('Исполнитель (только участники проекта)', icon: Icons.person_outline_rounded),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  isExpanded: true,
                  isDense: true,
                  value: members.any((m) => m.user.id == _assigneeId) ? _assigneeId : null,
                  borderRadius: BorderRadius.circular(16),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Без исполнителя')),
                    for (final m in members)
                      DropdownMenuItem<int?>(
                        value: m.user.id,
                        child: Text('${m.user.name} · ${m.member.role.label}', overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: _projectId == null ? null : (value) => setState(() => _assigneeId = value),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const SectionHeader('Приоритет'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in TaskPriority.values)
                ChoiceChip(
                  avatar: Icon(p.icon, size: 16, color: p.colors.foreground),
                  label: Text(p.label),
                  selected: _priority == p,
                  showCheckmark: false,
                  selectedColor: p.colors.background,
                  onSelected: (_) => setState(() => _priority = p),
                ),
            ],
          ),
          if (!_editing) ...[
            const SizedBox(height: 20),
            const SectionHeader('Начальный статус'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in TaskStatus.values)
                  ChoiceChip(
                    avatar: Icon(s.icon, size: 16, color: s.colors.foreground),
                    label: Text(s.label),
                    selected: _status == s,
                    showCheckmark: false,
                    selectedColor: s.colors.background,
                    onSelected: (_) => setState(() => _status = s),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.event_outlined, color: Pastel.lavender),
              title: const Text('Дедлайн'),
              subtitle: Text(fmtDate(_deadline)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _pickDeadline,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'У одного исполнителя может быть не больше трёх незавершённых задач с одной датой дедлайна.',
            style: TextStyle(color: Pastel.inkSoft, fontSize: 12.5),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(_editing ? 'Сохранить' : 'Создать задачу'),
          ),
        ],
      ),
    );
  }
}
