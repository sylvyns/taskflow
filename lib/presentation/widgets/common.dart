import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../models/app_exception.dart';
import '../../models/enums.dart';
import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Форматирование
// ---------------------------------------------------------------------------

String _two(int v) => v.toString().padLeft(2, '0');

String fmtDate(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';

String fmtDateTime(DateTime d) => '${fmtDate(d)} ${_two(d.hour)}:${_two(d.minute)}';

String fmtBytes(int? bytes) {
  if (bytes == null) return '—';
  if (bytes < 1024) return '$bytes Б';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} МБ';
}

// ---------------------------------------------------------------------------
// Карточки, чипы, аватары
// ---------------------------------------------------------------------------

/// Белая карточка с мягкой лавандовой тенью и скруглением.
class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [BoxShadow(color: Color(0x149A88C9), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Material(
        color: color ?? Pastel.card,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(borderRadius: radius, border: Border.all(color: Pastel.outline)),
            child: child,
          ),
        ),
      ),
    );
  }
}

class SoftChip extends StatelessWidget {
  const SoftChip({super.key, required this.label, required this.colors, this.icon, this.dense = false});

  final String label;
  final ChipColors colors;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(30)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 13 : 15, color: colors.foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(color: colors.foreground, fontSize: dense ? 11.5 : 12.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.dense = false});

  final TaskStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) =>
      SoftChip(label: status.label, colors: status.colors, icon: status.icon, dense: dense);
}

class PriorityChip extends StatelessWidget {
  const PriorityChip(this.priority, {super.key, this.dense = false});

  final TaskPriority priority;
  final bool dense;

  @override
  Widget build(BuildContext context) =>
      SoftChip(label: priority.label, colors: priority.colors, icon: priority.icon, dense: dense);
}

class ProjectStatusChip extends StatelessWidget {
  const ProjectStatusChip(this.status, {super.key});

  final ProjectStatus status;

  @override
  Widget build(BuildContext context) => SoftChip(label: status.label, colors: status.colors);
}

class RoleChip extends StatelessWidget {
  const RoleChip(this.role, {super.key});

  final ProjectRole role;

  @override
  Widget build(BuildContext context) => SoftChip(label: role.label, colors: role.colors, dense: true);
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.radius = 18});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = Pastel.avatarColors[name.hashCode.abs() % Pastel.avatarColors.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        _initials(name),
        style: TextStyle(fontSize: radius * 0.75, fontWeight: FontWeight.w700, color: Pastel.ink),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts[0].characters.first + parts[1].characters.first).toUpperCase();
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.icon});

  final String title;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: Pastel.lavender),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Pastel.ink)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: Pastel.lavenderLight, shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: Pastel.lavender),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Pastel.ink),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(color: Pastel.inkSoft)),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.icon, required this.label, required this.value, this.valueColor});

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Pastel.inkSoft),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Pastel.inkSoft)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w600, color: valueColor ?? Pastel.ink),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Отображение AsyncValue: загрузка → данные / ошибка.
class AsyncValueWidget<T> extends StatelessWidget {
  const AsyncValueWidget({super.key, required this.value, required this.data});

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => EmptyState(icon: Icons.cloud_off_rounded, title: 'Что-то пошло не так', subtitle: '$error'),
    );
  }
}

/// Мягкое поле ввода.
InputDecoration softInput(String label, {IconData? icon, String? hint, Widget? suffix}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: Pastel.outline),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon, color: Pastel.inkSoft),
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white,
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(borderSide: const BorderSide(color: Pastel.lavender, width: 1.6)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

// ---------------------------------------------------------------------------
// Диалоги и уведомления
// ---------------------------------------------------------------------------

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Pastel.roseDeep : Pastel.lavenderDeep,
      ),
    );
}

/// Выполняет действие и показывает понятное сообщение об ошибке.
Future<bool> runGuarded(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null && context.mounted) showSnack(context, success);
    return true;
  } on AppException catch (e) {
    if (context.mounted) showSnack(context, e.message, error: true);
  } catch (e) {
    if (context.mounted) showSnack(context, 'Ошибка: $e', error: true);
  }
  return false;
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Удалить',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Pastel.rose),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Результат выбора пользователя ([user] == null — выбран вариант «нет»).
class UserPick {
  const UserPick(this.user);

  final User? user;
}

/// Диалог выбора пользователя с поиском (удобно и для 1000 записей).
Future<UserPick?> showUserPicker(
  BuildContext context, {
  required List<User> users,
  String title = 'Выберите пользователя',
  String? noneLabel,
  int? selectedId,
}) {
  return showDialog<UserPick>(
    context: context,
    builder: (_) => _UserPickerDialog(users: users, title: title, noneLabel: noneLabel, selectedId: selectedId),
  );
}

class _UserPickerDialog extends StatefulWidget {
  const _UserPickerDialog({required this.users, required this.title, this.noneLabel, this.selectedId});

  final List<User> users;
  final String title;
  final String? noneLabel;
  final int? selectedId;

  @override
  State<_UserPickerDialog> createState() => _UserPickerDialogState();
}

class _UserPickerDialogState extends State<_UserPickerDialog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final query = _search.toLowerCase();
    final filtered = query.isEmpty
        ? widget.users
        : widget.users
            .where((u) => u.name.toLowerCase().contains(query) || u.email.toLowerCase().contains(query))
            .toList();

    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: false,
              decoration: softInput('Поиск', icon: Icons.search_rounded),
              onChanged: (v) => setState(() => _search = v.trim()),
            ),
            const SizedBox(height: 8),
            if (widget.noneLabel != null)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Pastel.mauveLight,
                  child: Icon(Icons.person_off_outlined, color: Pastel.mauveDeep),
                ),
                title: Text(widget.noneLabel!),
                selected: widget.selectedId == null,
                onTap: () => Navigator.pop(context, const UserPick(null)),
              ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Никого не найдено', style: TextStyle(color: Pastel.inkSoft)))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final user = filtered[i];
                        return ListTile(
                          leading: UserAvatar(name: user.name),
                          title: Text(user.name),
                          subtitle: Text(user.email),
                          selected: user.id == widget.selectedId,
                          selectedTileColor: Pastel.lavenderLight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          onTap: () => Navigator.pop(context, UserPick(user)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть'))],
    );
  }
}
