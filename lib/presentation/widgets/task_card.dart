import 'package:flutter/material.dart';

import '../../models/task_models.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.item, this.showProject = true, this.onTap});

  final TaskWithDetails item;
  final bool showProject;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final task = item.task;
    final overdue = item.isOverdue;
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Pastel.ink),
                ),
              ),
              const SizedBox(width: 8),
              PriorityChip(task.priority, dense: true),
            ],
          ),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              task.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Pastel.inkSoft, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(task.status, dense: true),
              if (showProject)
                SoftChip(
                  label: item.project.name,
                  colors: const ChipColors(Pastel.lavenderLight, Pastel.lavenderDeep),
                  icon: Icons.folder_outlined,
                  dense: true,
                ),
              SoftChip(
                label: overdue ? 'Просрочена · ${fmtDate(task.deadline)}' : fmtDate(task.deadline),
                colors: overdue
                    ? const ChipColors(Pastel.roseLight, Pastel.roseDeep)
                    : const ChipColors(Color(0xFFF4F1F8), Pastel.inkSoft),
                icon: Icons.event_outlined,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (item.assignee != null) ...[
                UserAvatar(name: item.assignee!.name, radius: 11),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.assignee!.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Pastel.ink),
                  ),
                ),
              ] else
                const Expanded(
                  child: Text('Без исполнителя', style: TextStyle(fontSize: 13, color: Pastel.inkSoft)),
                ),
              Text('создана ${fmtDate(task.createdAt)}', style: const TextStyle(fontSize: 11.5, color: Pastel.inkSoft)),
            ],
          ),
        ],
      ),
    );
  }
}
