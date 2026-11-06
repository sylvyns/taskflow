import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/benchmark.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Генерация тестовой БД (1 000 пользователей, 100 проектов, 10 000 задач)
/// и сравнение скорости запросов с индексами и без них.
class PerformanceScreen extends ConsumerStatefulWidget {
  const PerformanceScreen({super.key});

  @override
  ConsumerState<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends ConsumerState<PerformanceScreen> {
  bool _busy = false;
  String? _busyText;
  SeedReport? _seed;
  List<BenchmarkResult>? _results;

  Future<void> _run(String text, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _busyText = text;
    });
    await runGuarded(context, action);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _seedDatabase() async {
    final ok = await confirmDialog(
      context,
      title: 'Сгенерировать тестовую БД?',
      message: 'Все текущие данные будут заменены: 1 000 пользователей, 100 проектов и 10 000 задач.',
      confirmLabel: 'Сгенерировать',
    );
    if (!ok || !mounted) return;
    await _run('Создаём 10 000 задач…', () async {
      final report = await ref.read(benchmarkRepositoryProvider).seed();
      ref.read(currentUserIdProvider.notifier).state = null;
      if (mounted) setState(() => _seed = report);
    });
  }

  Future<void> _benchmark() async {
    await _run('Сравниваем запросы с индексами и без…', () async {
      final results = await ref.read(benchmarkRepositoryProvider).runBenchmark();
      if (mounted) setState(() => _results = results);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Производительность')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader('Тестовая база данных', icon: Icons.dataset_outlined),
                const Text(
                  'Генерирует 1 000 пользователей, 100 проектов (по 10 участников) и 10 000 задач. '
                  'После этого на вкладке «Задачи» можно проверить поиск, фильтры, сортировку и пагинацию на большом объёме.',
                  style: TextStyle(color: Pastel.inkSoft, height: 1.35),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _seedDatabase,
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text('Сгенерировать'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _busy ? null : _benchmark,
                        icon: const Icon(Icons.speed_rounded),
                        label: const Text('Сравнить'),
                      ),
                    ),
                  ],
                ),
                if (_busy) ...[
                  const SizedBox(height: 14),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 6),
                  Text(_busyText ?? '', style: const TextStyle(color: Pastel.inkSoft)),
                ],
                if (_seed != null) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SoftChip(label: 'пользователей: ${_seed!.users}', colors: const ChipColors(Pastel.lavenderLight, Pastel.lavenderDeep)),
                      SoftChip(label: 'проектов: ${_seed!.projects}', colors: const ChipColors(Pastel.skyLight, Pastel.skyDeep)),
                      SoftChip(label: 'участников: ${_seed!.members}', colors: const ChipColors(Pastel.peachLight, Pastel.peachDeep)),
                      SoftChip(label: 'задач: ${_seed!.tasks}', colors: const ChipColors(Pastel.mintLight, Pastel.mintDeep)),
                      SoftChip(
                        label: 'за ${(_seed!.elapsed.inMilliseconds / 1000).toStringAsFixed(2)} с',
                        colors: const ChipColors(Pastel.butterLight, Pastel.butterDeep),
                        icon: Icons.timer_outlined,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (_results != null) ...[
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Среднее время одного запроса (30 повторов). Индекс не помогает поиску LIKE \'%…%\' '
                '— такой шаблон всё равно требует полного просмотра таблицы.',
                style: TextStyle(color: Pastel.inkSoft, fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 8),
            for (final r in _results!) ...[
              _ResultCard(result: r),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final BenchmarkResult result;

  @override
  Widget build(BuildContext context) {
    String ms(double v) => '${v.toStringAsFixed(v < 1 ? 3 : 2)} мс';
    final faster = result.speedup >= 1.1;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(result.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Pastel.ink)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SoftChip(
                label: 'с индексом ${ms(result.withIndexMs)}',
                colors: const ChipColors(Pastel.mintLight, Pastel.mintDeep),
                icon: Icons.bolt_rounded,
              ),
              SoftChip(
                label: 'без индекса ${ms(result.withoutIndexMs)}',
                colors: const ChipColors(Pastel.peachLight, Pastel.peachDeep),
                icon: Icons.hourglass_bottom_rounded,
              ),
              SoftChip(
                label: '×${result.speedup.toStringAsFixed(1)}',
                colors: faster
                    ? const ChipColors(Pastel.lavenderLight, Pastel.lavenderDeep)
                    : const ChipColors(Pastel.mauveLight, Pastel.mauveDeep),
              ),
            ],
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('SQL и план запроса', style: TextStyle(fontSize: 13, color: Pastel.lavenderDeep)),
              children: [
                _Code(result.sql),
                const SizedBox(height: 6),
                const Align(alignment: Alignment.centerLeft, child: Text('С индексами:', style: TextStyle(fontSize: 12))),
                _Code(result.planWithIndex),
                const SizedBox(height: 6),
                const Align(alignment: Alignment.centerLeft, child: Text('Без индексов:', style: TextStyle(fontSize: 12))),
                _Code(result.planWithoutIndex),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Code extends StatelessWidget {
  const _Code(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF6F2FB), borderRadius: BorderRadius.circular(12)),
      child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: Pastel.ink)),
    );
  }
}
