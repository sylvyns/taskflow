import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../models/dashboard_stats.dart';
import '../../models/enums.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/shell_actions.dart';
import 'project_detail_screen.dart';
import 'user_detail_screen.dart';

/// Панель статистики. Все числа рассчитываются SQL-запросами
/// (StatsRepository) и пересчитываются автоматически при изменениях в БД.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardProvider);
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('TaskFlow', style: TextStyle(fontWeight: FontWeight.w800)), actions: shellActions()),
      body: AsyncValueWidget<DashboardStats>(
        value: stats,
        data: (s) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _Hero(stats: s, me: me),
            const SizedBox(height: 16),
            _StatGrid(stats: s),
            const SizedBox(height: 16),
            _PrioritySection(stats: s),
            const SizedBox(height: 16),
            _ProjectProgressSection(stats: s),
            const SizedBox(height: 16),
            _AssigneeSection(stats: s),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.stats, required this.me});

  final DashboardStats stats;
  final User? me;

  @override
  Widget build(BuildContext context) {
    final finished = stats.done + stats.open == 0 ? 0.0 : stats.done / (stats.done + stats.open);
    int myOpen = 0;
    for (final a in stats.byAssignee) {
      if (a.userId == me?.id) myOpen = a.open;
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: Pastel.heroGradient, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  me == null ? 'Добро пожаловать!' : 'Привет, ${me!.name.split(' ').first}!',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Pastel.ink),
                ),
                const SizedBox(height: 6),
                Text(
                  me == null
                      ? 'Начните с добавления пользователей и проекта'
                      : 'Открытых задач у вас: $myOpen',
                  style: const TextStyle(color: Pastel.inkSoft),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: finished,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.white.withValues(alpha: 0.7),
                    color: Pastel.mint,
                  ),
                ),
                Text(
                  '${(finished * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Pastel.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _StatTile('Проекты', stats.projects, Icons.folder_rounded, Pastel.lavenderLight, Pastel.lavenderDeep),
      _StatTile('Всего задач', stats.totalTasks, Icons.list_alt_rounded, Pastel.skyLight, Pastel.skyDeep),
      _StatTile('Завершено', stats.done, Icons.check_circle_rounded, Pastel.mintLight, Pastel.mintDeep),
      _StatTile('Незавершённые', stats.open, Icons.timelapse_rounded, Pastel.peachLight, Pastel.peachDeep),
      _StatTile('Просрочено', stats.overdue, Icons.alarm_rounded, Pastel.roseLight, Pastel.roseDeep),
      _StatTile('Отменено', stats.cancelled, Icons.block_rounded, Pastel.mauveLight, Pastel.mauveDeep),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 600 ? 3 : 2;
        final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final t in tiles) SizedBox(width: width, child: t)],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.label, this.value, this.icon, this.bg, this.fg);

  final String label;
  final int value;
  final IconData icon;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: fg, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Pastel.ink)),
                Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Pastel.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Горизонтальная полоска с подписью и значением.
class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value, required this.fraction, required this.color, this.trailing, this.onTap});

  final String label;
  final String value;
  final double fraction;
  final Color color;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
                Expanded(
                  child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Pastel.ink)),
                ),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: Pastel.ink)),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: fraction.clamp(0, 1).toDouble(),
              minHeight: 9,
              borderRadius: BorderRadius.circular(10),
              backgroundColor: color.withValues(alpha: 0.18),
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrioritySection extends StatelessWidget {
  const _PrioritySection({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final max = stats.byPriority.values.fold<int>(0, (a, b) => a > b ? a : b);
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Задачи по приоритетам', icon: Icons.local_fire_department_outlined),
          for (final p in TaskPriority.values.reversed)
            _Bar(
              label: p.label,
              value: '${stats.byPriority[p] ?? 0}',
              fraction: max == 0 ? 0 : (stats.byPriority[p] ?? 0) / max,
              color: p.barColor,
              trailing: Icon(p.icon, size: 18, color: p.colors.foreground),
            ),
        ],
      ),
    );
  }
}

class _ProjectProgressSection extends StatelessWidget {
  const _ProjectProgressSection({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final items = stats.projectProgress;
    final shown = items.take(10).toList();
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            'Выполнение проектов',
            icon: Icons.donut_large_rounded,
            trailing: items.length > shown.length
                ? Text('показано ${shown.length} из ${items.length}', style: const TextStyle(color: Pastel.inkSoft, fontSize: 12))
                : null,
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Проектов пока нет', style: TextStyle(color: Pastel.inkSoft)),
            ),
          for (final p in shown)
            _Bar(
              label: p.name,
              value: '${p.percent.toStringAsFixed(p.percent % 1 == 0 ? 0 : 1)}% · ${p.done}/${p.total}',
              fraction: p.percent / 100,
              color: p.status == ProjectStatus.archived ? Pastel.mauveDeep.withValues(alpha: 0.5) : Pastel.lavender,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: p.projectId)),
              ),
            ),
        ],
      ),
    );
  }
}

class _AssigneeSection extends StatelessWidget {
  const _AssigneeSection({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final items = stats.byAssignee;
    final shown = items.take(10).toList();
    final max = items.isEmpty ? 0 : items.first.total;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            'Задачи у исполнителей',
            icon: Icons.groups_2_outlined,
            trailing: items.length > shown.length
                ? Text('топ ${shown.length} из ${items.length}', style: const TextStyle(color: Pastel.inkSoft, fontSize: 12))
                : null,
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Задачи ещё никому не назначены', style: TextStyle(color: Pastel.inkSoft)),
            ),
          for (final a in shown)
            _Bar(
              label: a.name,
              value: '${a.total} (откр. ${a.open})',
              fraction: max == 0 ? 0 : a.total / max,
              color: Pastel.peach,
              trailing: UserAvatar(name: a.name, radius: 12),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => UserDetailScreen(userId: a.userId)),
              ),
            ),
          if (stats.unassigned > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Без исполнителя: ${stats.unassigned}', style: const TextStyle(color: Pastel.inkSoft)),
            ),
        ],
      ),
    );
  }
}
