import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'presentation/screens/home_shell.dart';
import 'presentation/theme/app_theme.dart';

class TaskFlowApp extends StatelessWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const HomeShell(),
    );
  }
}
