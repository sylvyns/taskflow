import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task_models.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/shell_actions.dart';
import 'project_detail_screen.dart';
import 'project_form_screen.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Проекты'), actions: shellActions()),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'projects_fab',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProjectFormScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Проект'),
      ),
      body: AsyncValueWidget<List<ProjectSummary>>(
        value: projects,
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.folder_open_rounded,
              title: 'Проектов пока нет',
              subtitle: 'Создайте проект, добавьте участников и распределите задачи',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _ProjectCard(summary: items[i]),
          );
        },
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.summary});

  final ProjectSummary summary;

  @override
  Widget build(BuildContext context) {
    final project = summary.project;
    final percent = (summary.progress * 100).round();
    return SoftCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: project.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: project.status.colors.background, borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.folder_rounded, color: project.status.colors.foreground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  project.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Pastel.ink),
                ),
              ),
              ProjectStatusChip(project.status),
            ],
          ),
          if (project.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              project.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Pastel.inkSoft),
            ),
          ],
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: summary.progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(10),
            backgroundColor: Pastel.lavenderLight,
            color: Pastel.mint,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('$percent% · ${summary.done} из ${summary.total - summary.cancelled} задач',
                  style: const TextStyle(fontSize: 12.5, color: Pastel.inkSoft)),
              const Spacer(),
              const Icon(Icons.event_outlined, size: 14, color: Pastel.inkSoft),
              const SizedBox(width: 4),
              Text(
                project.endDate == null ? 'без срока' : 'до ${fmtDate(project.endDate!)}',
                style: const TextStyle(fontSize: 12.5, color: Pastel.inkSoft),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
