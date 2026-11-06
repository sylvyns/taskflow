import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/task_list_view.dart';
import 'users_screen.dart';

/// Пользователь и все назначенные ему задачи.
class UserDetailScreen extends ConsumerWidget {
  const UserDetailScreen({super.key, required this.userId});

  final int userId;

  Future<void> _delete(BuildContext context, WidgetRef ref, User user) async {
    final ok = await confirmDialog(
      context,
      title: 'Удалить пользователя?',
      message: 'Пользователя нельзя удалить, пока за ним закреплены незавершённые задачи. '
          'Его комментарии и участие в проектах будут удалены.',
    );
    if (!ok || !context.mounted) return;
    final navigator = Navigator.of(context);
    final done = await runGuarded(
      context,
      () => ref.read(userRepositoryProvider).deleteUser(user.id),
      success: 'Пользователь удалён',
    );
    if (done) navigator.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider(userId));
    final user = userAsync.valueOrNull;
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.name ?? 'Пользователь', overflow: TextOverflow.ellipsis),
        actions: [
          if (user != null) ...[
            IconButton(
              tooltip: 'Редактировать',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showUserFormDialog(context, existing: user),
            ),
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _delete(context, ref, user),
            ),
          ],
        ],
      ),
      body: user == null
          ? (userAsync.isLoading
              ? const Center(child: CircularProgressIndicator())
              : const EmptyState(icon: Icons.person_off_outlined, title: 'Пользователь не найден'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: SoftCard(
                    child: Row(
                      children: [
                        UserAvatar(name: user.name, radius: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(user.email, style: const TextStyle(color: Pastel.inkSoft)),
                              const SizedBox(height: 2),
                              Text('Зарегистрирован ${fmtDate(user.registeredAt)}',
                                  style: const TextStyle(color: Pastel.inkSoft, fontSize: 12.5)),
                            ],
                          ),
                        ),
                        if (me?.id != user.id)
                          TextButton(
                            onPressed: () => ref.read(currentUserIdProvider.notifier).state = user.id,
                            child: const Text('Войти как'),
                          ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Назначенные задачи', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                Expanded(child: TaskListView(assigneeId: userId)),
              ],
            ),
    );
  }
}
