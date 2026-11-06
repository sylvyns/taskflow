import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../models/enums.dart';
import '../../models/task_models.dart';
import '../../models/task_query.dart';
import '../../state/providers.dart';
import '../screens/task_detail_screen.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'task_card.dart';

/// Список задач с поиском, фильтрами (статус, приоритет, исполнитель),
/// сортировкой и постраничной навигацией. Данные приходят из Drift `watch()`,
/// поэтому список обновляется сам при любом изменении в БД.
class TaskListView extends ConsumerStatefulWidget {
  const TaskListView({super.key, this.projectId, this.assigneeId, this.showProject = true});

  /// Зафиксированный проект (экран проекта).
  final int? projectId;

  /// Зафиксированный исполнитель (экран пользователя).
  final int? assigneeId;
  final bool showProject;

  @override
  ConsumerState<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends ConsumerState<TaskListView> {
  late TaskQuery _query = TaskQuery(projectId: widget.projectId, assigneeId: widget.assigneeId);
  final _searchController = TextEditingController();
  Timer? _debounce;
  TaskPage? _lastPage;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _setQuery(TaskQuery query) => setState(() => _query = query);

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _setQuery(_query.copyWith(search: value, page: 0));
    });
  }

  List<User> _assigneeOptions() {
    if (widget.projectId != null) {
      final members = ref.watch(projectMembersProvider(widget.projectId!)).valueOrNull ?? const <MemberWithUser>[];
      return members.map((m) => m.user).toList();
    }
    return ref.watch(usersProvider).valueOrNull ?? const <User>[];
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(taskPageProvider(_query));
    if (async.hasValue) _lastPage = async.value;
    final page = async.valueOrNull ?? _lastPage;
    final assignees = widget.assigneeId == null ? _assigneeOptions() : const <User>[];

    String assigneeLabel = 'Исполнитель';
    if (_query.assigneeId != null && widget.assigneeId == null) {
      for (final u in assignees) {
        if (u.id == _query.assigneeId) assigneeLabel = u.name;
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: softInput(
              'Поиск по названию и описанию',
              icon: Icons.search_rounded,
              suffix: _query.search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        _setQuery(_query.copyWith(search: '', page: 0));
                      },
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _MenuChip<TaskStatus>(
                icon: Icons.flag_outlined,
                label: _query.status?.label ?? 'Статус',
                active: _query.status != null,
                options: [(null, 'Все статусы'), for (final s in TaskStatus.values) (s, s.label)],
                onSelected: (s) => _setQuery(_query.copyWith(status: s, page: 0)),
              ),
              const SizedBox(width: 8),
              _MenuChip<TaskPriority>(
                icon: Icons.local_fire_department_outlined,
                label: _query.priority?.label ?? 'Приоритет',
                active: _query.priority != null,
                options: [(null, 'Все приоритеты'), for (final p in TaskPriority.values) (p, p.label)],
                onSelected: (p) => _setQuery(_query.copyWith(priority: p, page: 0)),
              ),
              if (widget.assigneeId == null) ...[
                const SizedBox(width: 8),
                _ChipFace(
                  icon: Icons.person_outline_rounded,
                  label: assigneeLabel,
                  active: _query.assigneeId != null,
                  onTap: () async {
                    final pick = await showUserPicker(
                      context,
                      users: assignees,
                      title: 'Фильтр по исполнителю',
                      noneLabel: 'Все исполнители',
                      selectedId: _query.assigneeId,
                    );
                    if (pick != null) _setQuery(_query.copyWith(assigneeId: pick.user?.id, page: 0));
                  },
                ),
              ],
              const SizedBox(width: 8),
              _MenuChip<TaskSort>(
                icon: Icons.swap_vert_rounded,
                label: _query.sort.label,
                active: false,
                options: [for (final s in TaskSort.values) (s, s.label)],
                onSelected: (s) => _setQuery(_query.copyWith(sort: s ?? TaskSort.newest, page: 0)),
              ),
              if (_query.hasFilters || (widget.assigneeId == null && _query.assigneeId != null)) ...[
                const SizedBox(width: 8),
                _ChipFace(
                  icon: Icons.filter_alt_off_outlined,
                  label: 'Сбросить',
                  active: false,
                  onTap: () {
                    _searchController.clear();
                    _setQuery(TaskQuery(projectId: widget.projectId, assigneeId: widget.assigneeId, sort: _query.sort));
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildList(page, async)),
        if (page != null && page.total > 0) _Pager(page: page, onPage: (p) => _setQuery(_query.copyWith(page: p))),
      ],
    );
  }

  Widget _buildList(TaskPage? page, AsyncValue<TaskPage> async) {
    if (page == null) {
      if (async.hasError) {
        return EmptyState(icon: Icons.cloud_off_rounded, title: 'Не удалось загрузить задачи', subtitle: '${async.error}');
      }
      return const Center(child: CircularProgressIndicator());
    }
    if (page.items.isEmpty) {
      return EmptyState(
        icon: Icons.inbox_outlined,
        title: _query.hasFilters ? 'Ничего не найдено' : 'Задач пока нет',
        subtitle: _query.hasFilters ? 'Попробуйте изменить фильтры или запрос' : 'Создайте первую задачу кнопкой «+»',
        action: page.page > 0
            ? TextButton(onPressed: () => _setQuery(_query.copyWith(page: 0)), child: const Text('К первой странице'))
            : null,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      itemCount: page.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final item = page.items[i];
        return TaskCard(
          item: item,
          showProject: widget.showProject,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: item.task.id)),
          ),
        );
      },
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({required this.page, required this.onPage});

  final TaskPage page;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Pastel.outline),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Первая страница',
            onPressed: page.hasPrevious ? () => onPage(0) : null,
            icon: const Icon(Icons.first_page_rounded),
          ),
          IconButton(
            tooltip: 'Назад',
            onPressed: page.hasPrevious ? () => onPage(page.page - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              'Стр. ${page.page + 1} из ${page.pageCount} · задач: ${page.total}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Pastel.ink, fontSize: 13),
            ),
          ),
          IconButton(
            tooltip: 'Вперёд',
            onPressed: page.hasNext ? () => onPage(page.page + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          IconButton(
            tooltip: 'Последняя страница',
            onPressed: page.hasNext ? () => onPage(page.pageCount - 1) : null,
            icon: const Icon(Icons.last_page_rounded),
          ),
        ],
      ),
    );
  }
}

/// Обёртка значения пункта меню (PopupMenuButton не передаёт null в onSelected).
class _Opt<T> {
  const _Opt(this.value);

  final T? value;
}

class _MenuChip<T> extends StatelessWidget {
  const _MenuChip({
    required this.label,
    required this.active,
    required this.options,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool active;
  final List<(T?, String)> options;
  final ValueChanged<T?> onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_Opt<T>>(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (option) => onSelected(option.value),
      itemBuilder: (_) => [
        for (final option in options) PopupMenuItem(value: _Opt<T>(option.$1), child: Text(option.$2)),
      ],
      child: _ChipFace(label: label, active: active, icon: icon),
    );
  }
}

class _ChipFace extends StatelessWidget {
  const _ChipFace({required this.label, required this.active, this.icon, this.onTap});

  final String label;
  final bool active;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final face = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? Pastel.lavenderLight : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: active ? Pastel.lavender.withValues(alpha: 0.5) : Pastel.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: active ? Pastel.lavenderDeep : Pastel.inkSoft),
            const SizedBox(width: 6),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Pastel.lavenderDeep : Pastel.ink,
              ),
            ),
          ),
          if (onTap == null) ...[
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Pastel.inkSoft),
          ],
        ],
      ),
    );
    if (onTap == null) return face;
    return InkWell(borderRadius: BorderRadius.circular(30), onTap: onTap, child: face);
  }
}
