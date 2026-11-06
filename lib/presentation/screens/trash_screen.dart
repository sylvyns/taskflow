import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task_models.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Корзина (Soft Delete): просмотр, восстановление и полное удаление.
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trash = ref.watch(trashProvider);
    final repo = ref.read(taskRepositoryProvider);
    final hasItems = trash.valueOrNull?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Корзина'),
        actions: [
          if (hasItems)
            IconButton(
              tooltip: 'Очистить корзину',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Очистить корзину?',
                  message: 'Все задачи из корзины будут удалены навсегда вместе с комментариями, вложениями и историей.',
                  confirmLabel: 'Очистить',
                );
                if (ok && context.mounted) {
                  await runGuarded(context, () => repo.emptyTrash(), success: 'Корзина очищена');
                }
              },
            ),
        ],
      ),
      body: AsyncValueWidget<List<TaskWithDetails>>(
        value: trash,
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.auto_delete_outlined,
              title: 'Корзина пуста',
              subtitle: 'Удалённые задачи появятся здесь — их можно восстановить',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final item = items[i];
              return SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.task.title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: Pastel.ink),
                          ),
                        ),
                        StatusChip(item.task.status, dense: true),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.project.name} · удалена ${fmtDateTime(item.task.deletedAt!)}',
                      style: const TextStyle(color: Pastel.inkSoft, fontSize: 12.5),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => runGuarded(
                            context,
                            () => repo.restoreFromTrash(item.task.id),
                            success: 'Задача восстановлена',
                          ),
                          icon: const Icon(Icons.restore_rounded),
                          label: const Text('Восстановить'),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: Pastel.roseDeep),
                          onPressed: () async {
                            final ok = await confirmDialog(
                              context,
                              title: 'Удалить навсегда?',
                              message: 'Задача «${item.task.title}» будет удалена из базы данных без возможности восстановления.',
                            );
                            if (ok && context.mounted) {
                              await runGuarded(
                                context,
                                () => repo.deletePermanently(item.task.id),
                                success: 'Задача удалена навсегда',
                              );
                            }
                          },
                          icon: const Icon(Icons.delete_forever_outlined),
                          label: const Text('Удалить'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
