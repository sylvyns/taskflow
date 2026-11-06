import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/enums.dart';
import 'package:taskflow/presentation/theme/app_theme.dart';
import 'package:taskflow/presentation/widgets/common.dart';

void main() {
  testWidgets('Чипы статуса и приоритета отображаются с подписями', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Column(children: [StatusChip(TaskStatus.inProgress), PriorityChip(TaskPriority.critical)]),
        ),
      ),
    );
    expect(find.text('В работе'), findsOneWidget);
    expect(find.text('Критический'), findsOneWidget);
  });
}
