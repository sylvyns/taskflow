import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../models/enums.dart';
import '../../models/task_models.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/task_list_view.dart';
import 'project_form_screen.dart';
import 'task_form_screen.dart';
import 'user_detail_screen.dart';

/// Проект: задачи проекта и участники с ролями.
class ProjectDetailScreen extends ConsumerStatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final int projectId;

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabs.indexIsChanging && mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _delete(Project project) async {
    final ok = await confirmDialog(
      context,
      title: 'Удалить проект?',
      message: 'Проект «${project.name}» будет удалён вместе со всеми задачами, комментариями, вложениями и историей.',
    );
    if (!ok || !mounted) return;
    final navigator = Navigator.of(context);
    final done = await runGuarded(
      context,
      () => ref.read(projectRepositoryProvider).deleteProject(project.id),
      success: 'Проект удалён',
    );
    if (done) navigator.pop();
  }

  Future<void> _addMember() async {
    final repo = ref.read(projectRepositoryProvider);
    final users = ref.read(usersProvider).valueOrNull ?? const <User>[];
    final members = await repo.getMembers(widget.projectId);
    final memberIds = members.map((m) => m.user.id).toSet();
    final candidates = users.where((u) => !memberIds.contains(u.id)).toList();
    if (!mounted) return;
    if (candidates.isEmpty) {
      showSnack(context, 'Все пользователи уже в проекте');
      return;
    }
    final pick = await showUserPicker(context, users: candidates, title: 'Добавить участника');
    final user = pick?.user;
    if (user == null || !mounted) return;
    final role = await _pickRole(context, ProjectRole.member);
    if (role == null || !mounted) return;
    await runGuarded(
      context,
      () => repo.addMember(widget.projectId, user.id, role: role),
      success: '${user.name} добавлен(а) в проект',
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(projectProvider(widget.projectId));
    final project = projectAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(project?.name ?? 'Проект', overflow: TextOverflow.ellipsis),
        actions: [
          if (project != null) ...[
            IconButton(
              tooltip: 'Редактировать',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ProjectFormScreen(existing: project)),
              ),
            ),
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _delete(project),
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Pastel.lavender,
          labelColor: Pastel.lavenderDeep,
          unselectedLabelColor: Pastel.inkSoft,
          tabs: const [Tab(text: 'Задачи'), Tab(text: 'Участники')],
        ),
      ),
      floatingActionButton: project == null
          ? null
          : _tabs.index == 0
              ? FloatingActionButton.extended(
                  heroTag: 'add_task',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => TaskFormScreen(projectId: widget.projectId)),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Задача'),
                )
              : FloatingActionButton.extended(
                  heroTag: 'add_member',
                  onPressed: _addMember,
                  icon: const Icon(Icons.person_add_alt_rounded),
                  label: const Text('Участник'),
                ),
      body: project == null
          ? (projectAsync.isLoading
              ? const Center(child: CircularProgressIndicator())
              : const EmptyState(icon: Icons.folder_off_outlined, title: 'Проект не найден'))
          : Column(
              children: [
                _ProjectHeader(project: project),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      TaskListView(projectId: widget.projectId, showProject: false),
                      _MembersTab(projectId: widget.projectId),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (project.description.isNotEmpty) ...[
              Text(project.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Pastel.ink)),
              const SizedBox(height: 10),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ProjectStatusChip(project.status),
                SoftChip(
                  label: 'создан ${fmtDate(project.createdAt)}',
                  colors: const ChipColors(Color(0xFFF4F1F8), Pastel.inkSoft),
                  icon: Icons.today_outlined,
                ),
                SoftChip(
                  label: project.endDate == null ? 'без срока' : 'до ${fmtDate(project.endDate!)}',
                  colors: const ChipColors(Pastel.butterLight, Pastel.butterDeep),
                  icon: Icons.event_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<ProjectRole?> _pickRole(BuildContext context, ProjectRole current) {
  return showDialog<ProjectRole>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Роль в проекте'),
      children: [
        for (final role in ProjectRole.values)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, role),
            child: Row(
              children: [
                Icon(
                  role == current ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: Pastel.lavender,
                ),
                const SizedBox(width: 12),
                RoleChip(role),
              ],
            ),
          ),
      ],
    ),
  );
}

class _MembersTab extends ConsumerWidget {
  const _MembersTab({required this.projectId});

  final int projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(projectMembersProvider(projectId));
    return AsyncValueWidget<List<MemberWithUser>>(
      value: members,
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.group_add_outlined,
            title: 'В проекте пока никого нет',
            subtitle: 'Только участники проекта могут быть исполнителями его задач',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final m = items[i];
            return SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => UserDetailScreen(userId: m.user.id)),
              ),
              child: ListTile(
                leading: UserAvatar(name: m.user.name),
                title: Text(m.user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [RoleChip(m.member.role), const SizedBox(width: 8), Expanded(child: Text(m.user.email, overflow: TextOverflow.ellipsis))]),
                ),
                trailing: PopupMenuButton<String>(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (value) async {
                    final repo = ref.read(projectRepositoryProvider);
                    if (value == 'role') {
                      final role = await _pickRole(context, m.member.role);
                      if (role != null && context.mounted) {
                        await runGuarded(context, () => repo.changeRole(projectId, m.user.id, role), success: 'Роль изменена');
                      }
                    } else if (value == 'remove') {
                      final ok = await confirmDialog(
                        context,
                        title: 'Удалить участника?',
                        message: '${m.user.name} больше не сможет быть исполнителем задач проекта.',
                      );
                      if (ok && context.mounted) {
                        await runGuarded(context, () => repo.removeMember(projectId, m.user.id), success: 'Участник удалён');
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'role', child: Text('Изменить роль')),
                    PopupMenuItem(value: 'remove', child: Text('Удалить из проекта')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
