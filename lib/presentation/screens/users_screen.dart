import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../models/app_exception.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/shell_actions.dart';
import 'user_detail_screen.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  String _search = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(userSearchProvider(_search));
    final me = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Люди'), actions: shellActions()),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'users_fab',
        onPressed: () => showUserFormDialog(context),
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Пользователь'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: softInput('Поиск по имени или email', icon: Icons.search_rounded),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  if (mounted) setState(() => _search = v.trim());
                });
              },
            ),
          ),
          Expanded(
            child: AsyncValueWidget<List<User>>(
              value: users,
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: _search.isEmpty ? 'Пользователей пока нет' : 'Никого не найдено',
                    subtitle: _search.isEmpty ? 'Добавьте участников команды' : null,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final user = items[i];
                    return SoftCard(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => UserDetailScreen(userId: user.id)),
                      ),
                      child: ListTile(
                        leading: UserAvatar(name: user.name),
                        title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${user.email}\nс ${fmtDate(user.registeredAt)}'),
                        isThreeLine: true,
                        trailing: user.id == me?.id
                            ? const SoftChip(label: 'это вы', colors: ChipColors(Pastel.mintLight, Pastel.mintDeep), dense: true)
                            : const Icon(Icons.chevron_right_rounded, color: Pastel.inkSoft),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showUserFormDialog(BuildContext context, {User? existing}) =>
    showDialog<void>(context: context, builder: (_) => UserFormDialog(existing: existing));

/// Создание / редактирование пользователя. Ошибки (например, занятый email)
/// показываются прямо в диалоге.
class UserFormDialog extends ConsumerStatefulWidget {
  const UserFormDialog({super.key, this.existing});

  final User? existing;

  @override
  ConsumerState<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends ConsumerState<UserFormDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _email = TextEditingController(text: widget.existing?.email ?? '');
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(userRepositoryProvider);
    try {
      if (widget.existing == null) {
        await repo.createUser(name: _name.text, email: _email.text);
      } else {
        await repo.updateUser(widget.existing!.id, name: _name.text, email: _email.text);
      }
      if (mounted) Navigator.of(context).pop();
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Новый пользователь' : 'Редактирование'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _name, decoration: softInput('Имя', icon: Icons.person_outline_rounded)),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: softInput('Email', icon: Icons.alternate_email_rounded),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Pastel.roseLight, borderRadius: BorderRadius.circular(12)),
              child: Text(_error!, style: const TextStyle(color: Pastel.roseDeep)),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Отмена')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Сохранить')),
      ],
    );
  }
}
