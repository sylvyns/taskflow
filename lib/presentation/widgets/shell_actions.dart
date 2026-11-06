import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../screens/performance_screen.dart';
import '../screens/trash_screen.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Общие действия AppBar: выбор текущего пользователя и меню.
List<Widget> shellActions() => const [CurrentUserButton(), _MoreMenu(), SizedBox(width: 4)];

/// Показывает, от чьего имени выполняются действия, и позволяет сменить его.
class CurrentUserButton extends ConsumerWidget {
  const CurrentUserButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final name = me?.name ?? 'Гость';
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () async {
          final users = ref.read(usersProvider).valueOrNull ?? const [];
          if (users.isEmpty) {
            showSnack(context, 'Сначала добавьте пользователя на вкладке «Люди»');
            return;
          }
          final pick = await showUserPicker(context, users: users, title: 'Работать от имени', selectedId: me?.id);
          final user = pick?.user;
          if (user != null) ref.read(currentUserIdProvider.notifier).state = user.id;
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
          decoration: BoxDecoration(color: Pastel.lavenderLight, borderRadius: BorderRadius.circular(30)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserAvatar(name: name, radius: 13),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Text(
                  name.split(' ').first,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Pastel.lavenderDeep),
                ),
              ),
              const Icon(Icons.expand_more_rounded, size: 18, color: Pastel.lavenderDeep),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        final page = value == 'trash' ? const TrashScreen() : const PerformanceScreen();
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'trash',
          child: ListTile(leading: Icon(Icons.delete_outline_rounded), title: Text('Корзина задач')),
        ),
        PopupMenuItem(
          value: 'perf',
          child: ListTile(leading: Icon(Icons.speed_rounded), title: Text('Производительность')),
        ),
      ],
    );
  }
}
