import 'package:flutter/material.dart';

import '../widgets/shell_actions.dart';
import '../widgets/task_list_view.dart';
import 'task_form_screen.dart';

/// Все задачи всех проектов: поиск, фильтры, сортировка, пагинация.
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Задачи'), actions: shellActions()),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'tasks_fab',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TaskFormScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Задача'),
      ),
      body: const TaskListView(),
    );
  }
}
