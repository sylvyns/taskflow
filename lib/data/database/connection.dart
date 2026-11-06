import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Открывает файл SQLite `taskflow.sqlite` в каталоге приложения.
/// Данные сохраняются между запусками и доступны полностью офлайн.
QueryExecutor openConnection({String name = 'taskflow'}) => driftDatabase(name: name);
