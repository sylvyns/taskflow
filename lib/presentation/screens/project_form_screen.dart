import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../models/enums.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Создание или редактирование проекта.
class ProjectFormScreen extends ConsumerStatefulWidget {
  const ProjectFormScreen({super.key, this.existing});

  final Project? existing;

  @override
  ConsumerState<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends ConsumerState<ProjectFormScreen> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late ProjectStatus _status = widget.existing?.status ?? ProjectStatus.active;
  late DateTime? _endDate = widget.existing?.endDate;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final created = widget.existing?.createdAt ?? now;
    final first = DateTime(created.year, created.month, created.day);
    final last = DateTime(now.year + 10);
    var initial = _endDate ?? now.add(const Duration(days: 30));
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last);
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(projectRepositoryProvider);
    final me = ref.read(currentUserProvider);
    final ok = await runGuarded(context, () async {
      if (_editing) {
        await repo.updateProject(
          widget.existing!.id,
          name: _name.text,
          description: _description.text,
          status: _status,
          endDate: _endDate,
        );
      } else {
        await repo.createProject(
          name: _name.text,
          description: _description.text,
          status: _status,
          endDate: _endDate,
          ownerId: me?.id,
        );
      }
    }, success: _editing ? 'Проект сохранён' : 'Проект создан');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Редактирование проекта' : 'Новый проект')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: softInput('Название', icon: Icons.folder_outlined)),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: 6,
            decoration: softInput('Описание', icon: Icons.notes_rounded),
          ),
          const SizedBox(height: 20),
          const SectionHeader('Статус проекта'),
          Wrap(
            spacing: 8,
            children: [
              for (final s in ProjectStatus.values)
                ChoiceChip(
                  label: Text(s.label),
                  selected: _status == s,
                  showCheckmark: false,
                  selectedColor: s.colors.background,
                  onSelected: (_) => setState(() => _status = s),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.event_available_outlined, color: Pastel.lavender),
              title: const Text('Дата завершения'),
              subtitle: Text(_endDate == null ? 'Не указана (необязательно)' : fmtDate(_endDate!)),
              onTap: _pickEndDate,
              trailing: _endDate == null
                  ? const Icon(Icons.chevron_right_rounded)
                  : IconButton(
                      tooltip: 'Очистить',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _endDate = null),
                    ),
            ),
          ),
          if (!_editing) ...[
            const SizedBox(height: 12),
            Text(
              me == null
                  ? 'Совет: добавьте пользователя — создатель проекта станет его Owner.'
                  : 'Вы (${me.name}) будете добавлены в проект с ролью Owner.',
              style: const TextStyle(color: Pastel.inkSoft),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(_editing ? 'Сохранить' : 'Создать проект'),
          ),
        ],
      ),
    );
  }
}
