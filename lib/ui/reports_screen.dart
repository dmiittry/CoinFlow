import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../application/app_controller.dart';
import '../domain/models.dart';
import '../domain/reports.dart';
import 'style.dart';

const _periodLabels = {
  ReportPeriod.day: 'День',
  ReportPeriod.week: 'Неделя',
  ReportPeriod.month: 'Месяц',
  ReportPeriod.quarter: 'Квартал',
  ReportPeriod.year: 'Год',
  ReportPeriod.all: 'Всё время',
  ReportPeriod.custom: 'Свой период',
};
const _chartColors = [
  Color(0xFF00A887),
  Color(0xFF3999E5),
  Color(0xFF9471E8),
  Color(0xFFECA83B),
  Color(0xFFE66A7C),
  Color(0xFF39B6BB),
  Color(0xFF6B8C52),
  Color(0xFF9D7388),
];
String rangeLabel(ReportRange range) => range.start == range.end
    ? DateFormat('d MMM yyyy', 'ru').format(range.start)
    : '${DateFormat('d MMM yyyy', 'ru').format(range.start)} — ${DateFormat('d MMM yyyy', 'ru').format(range.end)}';

class ReportsScreen extends StatefulWidget {
  final AppController controller;
  const ReportsScreen({super.key, required this.controller});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportPeriod period = ReportPeriod.month;
  late DateTime anchor;
  ReportRange? custom;
  int? selectedBucket;
  AppController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    anchor = sameMonth(c.month, now) ? now : c.month;
  }

  ReportRange get range => period == ReportPeriod.custom && custom != null
      ? custom!
      : ReportRange.forPeriod(period, anchor, c.data);

  Future<void> choosePeriod(ReportPeriod value) async {
    if (value == ReportPeriod.custom) {
      final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime(1),
        lastDate: DateTime(9999, 12, 31),
        initialDateRange: DateTimeRange(
          start: range.start.isBefore(DateTime(1)) ? DateTime(1) : range.start,
          end: range.end.isAfter(DateTime(9999, 12, 31))
              ? DateTime(9999, 12, 31)
              : range.end,
        ),
        helpText: 'Период отчёта',
        saveText: 'Показать',
      );
      if (selected == null || !mounted) return;
      custom = ReportRange(selected.start, selected.end);
    }
    setState(() {
      period = value;
      selectedBucket = null;
    });
  }

  Future<void> chooseDate() async {
    if (period == ReportPeriod.custom) {
      await choosePeriod(period);
      return;
    }
    final date = await showDatePicker(
      context: context,
      initialDate: anchor,
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
      helpText: 'Выберите дату нужного периода',
    );
    if (date != null && mounted) {
      setState(() {
        anchor = date;
        selectedBucket = null;
      });
    }
  }

  DateTime shifted(int direction) => switch (period) {
    ReportPeriod.day => DateTime(
      anchor.year,
      anchor.month,
      anchor.day + direction,
    ),
    ReportPeriod.week => DateTime(
      anchor.year,
      anchor.month,
      anchor.day + 7 * direction,
    ),
    ReportPeriod.month => DateTime(anchor.year, anchor.month + direction),
    ReportPeriod.quarter => DateTime(anchor.year, anchor.month + direction * 3),
    ReportPeriod.year => DateTime(anchor.year + direction, anchor.month),
    _ => anchor,
  };
  bool canMove(int direction) =>
      shifted(direction).year >= 1 && shifted(direction).year <= 9999;
  void move(int direction) => setState(() {
    anchor = shifted(direction);
    selectedBucket = null;
  });

  void categoryDetails(CategoryStat stat, FinanceReport report) {
    final entries = report.entries
        .where((e) => e.targetId == stat.card.id)
        .toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: Column(
          children: [
            ListTile(
              title: Text(
                stat.card.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${money(stat.amount)} · ${rangeLabel(report.range)}',
              ),
              trailing: IconButton(
                tooltip: 'Закрыть детализацию',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: entries.length + (stat.opening != 0 ? 1 : 0),
                itemBuilder: (context, index) {
                  if (stat.opening != 0 && index == 0) {
                    return ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text('Начальная сумма: ${money(stat.opening)}'),
                      subtitle: Text(
                        '${DateFormat('dd.MM.yyyy').format(stat.card.openingDate)} · сумма из карточки, без отдельной операции',
                      ),
                    );
                  }
                  final e = entries[index - (stat.opening != 0 ? 1 : 0)];
                  return ListTile(
                    title: Text(money(e.amount)),
                    subtitle: Text(
                      '${DateFormat('dd.MM.yyyy').format(e.date)} · ${c.data.card(e.walletId).name}${e.note.isEmpty ? '' : '\n${e.note}'}',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = FinanceReport.calculate(c.data, range);
    final bucket =
        selectedBucket != null && selectedBucket! < report.trend.length
        ? report.trend[selectedBucket!]
        : null;
    return ListView(
      key: const PageStorageKey('reports-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final item in _periodLabels.entries)
              ChoiceChip(
                key: ValueKey('period-${item.key.name}'),
                label: Text(item.value),
                selected: period == item.key,
                onSelected: (_) => choosePeriod(item.key),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (period != ReportPeriod.all && period != ReportPeriod.custom)
              IconButton(
                tooltip: 'Предыдущий период',
                onPressed: canMove(-1) ? () => move(-1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
            Expanded(
              child: TextButton(
                onPressed: period == ReportPeriod.all ? null : chooseDate,
                child: Text(
                  rangeLabel(report.range),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            if (period != ReportPeriod.all && period != ReportPeriod.custom)
              IconButton(
                tooltip: 'Следующий период',
                onPressed: canMove(1) ? () => move(1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
          ],
        ),
        if (period != ReportPeriod.all && period != ReportPeriod.custom)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                anchor = DateTime.now();
                selectedBucket = null;
              }),
              icon: const Icon(Icons.today_outlined, size: 18),
              label: const Text('Текущий период'),
            ),
          ),
        ReportPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Доходы и расходы',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 24,
                runSpacing: 16,
                children: [
                  _metric('Доходы', money(report.income), cyan),
                  _metric('Расходы', money(report.expense), mint),
                  _metric(
                    'Разница',
                    money(report.net),
                    report.net < 0
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '${Intl.plural(report.entries.length, one: '${report.entries.length} операция', few: '${report.entries.length} операции', many: '${report.entries.length} операций', other: '${report.entries.length} операций', locale: 'ru')} · ${report.range.days} дн.',
              ),
              const SizedBox(height: 4),
              Text(
                'Средний расход за день: ${money(report.averageDailyExpense)}',
              ),
              Text('Самая крупная покупка: ${money(report.largestExpense)}'),
              const SizedBox(height: 10),
              const Text(
                'Переводы между кошельками не учитываются. Разница — доходы минус расходы, а не остаток кошельков.',
                style: TextStyle(fontSize: 12),
              ),
              if (report.openingTotal > 0)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Включены начальные суммы категорий на дату карточки. Они не входят в число операций и крупнейшую покупку.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        if (report.income == 0 && report.expense == 0)
          const ReportPanel(
            child: Column(
              children: [
                Icon(Icons.insights_outlined, size: 48, color: mint),
                SizedBox(height: 12),
                Text(
                  'За этот период пока нет доходов и расходов',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6),
                Text(
                  'Выберите другие даты или добавьте операцию.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else ...[
          ReportPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Динамика',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Голубой — доходы · зелёный — расходы',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                Text(
                  'Шкала до ${money(report.trend.fold<int>(0, (v, b) => math.max(v, math.max(b.income, b.expense))))}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) => Semantics(
                    label:
                        'График доходов и расходов. Точные значения доступны в таблице под графиком.',
                    child: GestureDetector(
                      onTapUp: (details) {
                        final index =
                            (details.localPosition.dx /
                                    constraints.maxWidth *
                                    report.trend.length)
                                .floor()
                                .clamp(0, report.trend.length - 1);
                        setState(() => selectedBucket = index);
                      },
                      child: SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _TrendPainter(
                            report.trend,
                            selectedBucket,
                            Theme.of(context).dividerColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 16,
                  children: [
                    Text(
                      DateFormat('dd.MM.yy').format(report.range.start),
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      DateFormat('dd.MM.yy').format(report.range.end),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  bucket == null
                      ? 'Нажмите на столбец для подробностей.'
                      : '${rangeLabel(bucket.range)}\nДоходы ${money(bucket.income)} · расходы ${money(bucket.expense)}',
                ),
                ExpansionTile(
                  key: const PageStorageKey('report-trend-table'),
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Значения по датам'),
                  children: [
                    for (final b in report.trend)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(rangeLabel(b.range)),
                        subtitle: Text(
                          'Доходы ${money(b.income)} · расходы ${money(b.expense)}',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          for (final group in [
            (report.expenses, 'Расходы по категориям', report.expense),
            (report.incomes, 'Источники доходов', report.income),
          ])
            ReportPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    group.$2,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (group.$1.isEmpty)
                    const Text('Нет данных за выбранный период')
                  else ...[
                    Center(
                      child: Semantics(
                        label:
                            '${group.$2}: ${money(group.$3)}. Подробности в списке ниже.',
                        child: SizedBox(
                          width: 180,
                          height: 180,
                          child: CustomPaint(
                            painter: _DonutPainter(group.$1),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(36),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    money(group.$3),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 19,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (final item in group.$1.indexed)
                      ListTile(
                        key: ValueKey('stat-${item.$2.card.id}'),
                        contentPadding: EdgeInsets.zero,
                        onTap: () => categoryDetails(item.$2, report),
                        leading: CircleAvatar(
                          backgroundColor:
                              _chartColors[item.$1 % _chartColors.length]
                                  .withValues(alpha: .15),
                          child: Icon(
                            cardIcons[item.$2.card.icon] ??
                                Icons.category_outlined,
                            color: _chartColors[item.$1 % _chartColors.length],
                          ),
                        ),
                        title: Text(item.$2.card.name),
                        subtitle: Text(
                          '${money(item.$2.amount)} · ${(item.$2.amount / group.$3 * 100).toStringAsFixed(1)}% · ${item.$2.operations} оп.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _metric(String title, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontSize: 12)),
      Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 23,
          color: color,
        ),
      ),
    ],
  );
}

class ReportPanel extends StatelessWidget {
  final Widget child;
  const ReportPanel({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Material(color: Colors.transparent, child: child),
  );
}

class _DonutPainter extends CustomPainter {
  final List<CategoryStat> stats;
  _DonutPainter(this.stats);
  @override
  void paint(Canvas canvas, Size size) {
    final total = stats.fold<int>(0, (s, c) => s + c.amount);
    if (total == 0) return;
    var start = -math.pi / 2;
    final rect = Rect.fromLTWH(16, 16, size.width - 32, size.height - 32);
    for (final item in stats.indexed) {
      final sweep = item.$2.amount / total * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = _chartColors[item.$1 % _chartColors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 24,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => true;
}

class _TrendPainter extends CustomPainter {
  final List<TrendBucket> buckets;
  final int? selected;
  final Color grid;
  _TrendPainter(this.buckets, this.selected, this.grid);
  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = buckets.fold<int>(
      0,
      (v, b) => math.max(v, math.max(b.income, b.expense)),
    );
    if (maxValue == 0) return;
    final step = size.width / buckets.length;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = grid
          ..strokeWidth = 1,
      );
    }
    for (final item in buckets.indexed) {
      final x = item.$1 * step;
      if (selected == item.$1) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 0, step, size.height),
            const Radius.circular(6),
          ),
          Paint()..color = cyan.withValues(alpha: .1),
        );
      }
      for (final bar in [
        (item.$2.income, cyan, .15),
        (item.$2.expense, mint, .52),
      ]) {
        final height = (size.height - 8) * bar.$1 / maxValue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              x + step * bar.$3,
              size.height - height,
              step * .3,
              height,
            ),
            const Radius.circular(3),
          ),
          Paint()..color = bar.$2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => true;
}
