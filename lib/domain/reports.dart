import 'models.dart';

enum ReportPeriod { day, week, month, quarter, year, all, custom }

DateTime calendarDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

class ReportRange {
  final DateTime start;
  final DateTime end;
  ReportRange(DateTime start, DateTime end)
    : start = calendarDay(start),
      end = calendarDay(end) {
    if (this.end.isBefore(this.start)) {
      throw const FormatException('Конец периода раньше начала');
    }
  }
  bool contains(DateTime date) {
    final day = calendarDay(date);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  // UTC calendar arithmetic avoids a 23/25-hour DST day changing the count.
  int get days =>
      DateTime.utc(
        end.year,
        end.month,
        end.day,
      ).difference(DateTime.utc(start.year, start.month, start.day)).inDays +
      1;

  static ReportRange forPeriod(
    ReportPeriod period,
    DateTime anchor,
    FinanceData data,
  ) {
    final day = calendarDay(anchor);
    switch (period) {
      case ReportPeriod.day:
      case ReportPeriod.custom:
        return ReportRange(day, day);
      case ReportPeriod.week:
        final start = DateTime(day.year, day.month, day.day - day.weekday + 1);
        return ReportRange(
          start,
          DateTime(start.year, start.month, start.day + 6),
        );
      case ReportPeriod.month:
        return ReportRange(
          DateTime(day.year, day.month),
          DateTime(day.year, day.month + 1, 0),
        );
      case ReportPeriod.quarter:
        final month = ((day.month - 1) ~/ 3) * 3 + 1;
        return ReportRange(
          DateTime(day.year, month),
          DateTime(day.year, month + 3, 0),
        );
      case ReportPeriod.year:
        return ReportRange(DateTime(day.year), DateTime(day.year, 12, 31));
      case ReportPeriod.all:
        final dates = [
          for (final e in data.entries)
            if (e.kind != EntryKind.transfer) calendarDay(e.date),
          for (final c in data.cards)
            if (c.kind != CardKind.wallet && c.opening != 0)
              calendarDay(c.openingDate),
        ]..sort();
        return dates.isEmpty
            ? ReportRange(day, day)
            : ReportRange(dates.first, dates.last);
    }
  }
}

class CategoryStat {
  final MoneyCard card;
  final int amount;
  final int operations;
  final int opening;
  const CategoryStat(this.card, this.amount, this.operations, this.opening);
}

class TrendBucket {
  final ReportRange range;
  int income = 0;
  int expense = 0;
  TrendBucket(this.range);
}

class FinanceReport {
  final ReportRange range;
  final List<CategoryStat> incomes;
  final List<CategoryStat> expenses;
  final List<MoneyEntry> entries;
  final List<TrendBucket> trend;
  final int openingTotal;
  FinanceReport._(
    this.range,
    this.incomes,
    this.expenses,
    this.entries,
    this.trend,
    this.openingTotal,
  );
  int get income => incomes.fold(0, (s, c) => s + c.amount);
  int get expense => expenses.fold(0, (s, c) => s + c.amount);
  int get net => income - expense;
  int get averageDailyExpense => expense ~/ range.days;
  int get largestExpense => entries
      .where((e) => e.kind == EntryKind.expense)
      .fold(0, (max, e) => e.amount > max ? e.amount : max);

  factory FinanceReport.calculate(FinanceData data, ReportRange range) {
    final entries =
        data.entries
            .where(
              (e) => e.kind != EntryKind.transfer && range.contains(e.date),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final totals = <String, int>{};
    final counts = <String, int>{};
    final trend = _buckets(range);
    void addTrend(DateTime date, int amount, bool income) {
      final bucket = trend.firstWhere((b) => b.range.contains(date));
      if (income) {
        bucket.income += amount;
      } else {
        bucket.expense += amount;
      }
    }

    for (final e in entries) {
      totals.update(e.targetId, (v) => v + e.amount, ifAbsent: () => e.amount);
      counts.update(e.targetId, (v) => v + 1, ifAbsent: () => 1);
      addTrend(e.date, e.amount, e.kind == EntryKind.income);
    }
    var openingTotal = 0;
    final stats = <CategoryStat>[];
    for (final card in data.cards.where((c) => c.kind != CardKind.wallet)) {
      final opening = range.contains(card.openingDate) ? card.opening : 0;
      final total = (totals[card.id] ?? 0) + opening;
      if (opening != 0) {
        openingTotal += opening;
        addTrend(card.openingDate, opening, card.kind == CardKind.income);
      }
      if (total > 0) {
        stats.add(CategoryStat(card, total, counts[card.id] ?? 0, opening));
      }
    }
    stats.sort((a, b) => b.amount.compareTo(a.amount));
    return FinanceReport._(
      range,
      stats.where((c) => c.card.kind == CardKind.income).toList(),
      stats.where((c) => c.card.kind == CardKind.expense).toList(),
      entries,
      trend,
      openingTotal,
    );
  }

  static List<TrendBucket> _buckets(ReportRange range) {
    final result = <TrendBucket>[];
    final months =
        (range.end.year - range.start.year) * 12 +
        range.end.month -
        range.start.month +
        1;
    final stepMonths = (months / 12).ceil();
    var cursor = range.start;
    while (!cursor.isAfter(range.end)) {
      final next = range.days <= 31
          ? DateTime(cursor.year, cursor.month, cursor.day + 1)
          : DateTime(
              cursor.year,
              cursor.month + (months <= 12 ? 1 : stepMonths),
            );
      final end = DateTime(next.year, next.month, next.day - 1);
      result.add(
        TrendBucket(
          ReportRange(cursor, end.isAfter(range.end) ? range.end : end),
        ),
      );
      cursor = next;
    }
    return result;
  }
}

class PlanProgress {
  final MonthlyPlan plan;
  final Map<String, int> spending;
  final int otherSpent;
  final int spent;
  PlanProgress._(this.plan, this.spending, this.otherSpent, this.spent);
  int get remaining => plan.total - spent;
  int get reserveRemaining => plan.reserve - otherSpent;
  factory PlanProgress.calculate(FinanceData data, DateTime month) {
    final plan = data.planFor(month);
    final spending = {
      for (final c in data.cards.where((c) => c.kind == CardKind.expense))
        c.id: data.value(c, month),
    };
    final other = spending.entries
        .where((e) => !plan.limits.containsKey(e.key))
        .fold(0, (sum, e) => sum + e.value);
    return PlanProgress._(
      plan,
      spending,
      other,
      spending.values.fold(0, (a, b) => a + b),
    );
  }
}
