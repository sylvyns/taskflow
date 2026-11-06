import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/database/app_database.dart';
import 'data/database/connection.dart';
import 'state/providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase(openConnection());
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: const TaskFlowApp(),
    ),
  );
}
