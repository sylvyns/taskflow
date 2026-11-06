/// Итог генерации тестовой базы данных.
class SeedReport {
  const SeedReport({
    required this.users,
    required this.projects,
    required this.members,
    required this.tasks,
    required this.elapsed,
  });

  final int users;
  final int projects;
  final int members;
  final int tasks;
  final Duration elapsed;
}

/// Результат сравнения одного запроса с индексами и без них.
class BenchmarkResult {
  const BenchmarkResult({
    required this.name,
    required this.sql,
    required this.withIndexMs,
    required this.withoutIndexMs,
    required this.planWithIndex,
    required this.planWithoutIndex,
  });

  final String name;
  final String sql;

  /// Среднее время одного выполнения, мс.
  final double withIndexMs;
  final double withoutIndexMs;

  /// EXPLAIN QUERY PLAN.
  final String planWithIndex;
  final String planWithoutIndex;

  double get speedup => withIndexMs <= 0 ? 0 : withoutIndexMs / withIndexMs;
}
