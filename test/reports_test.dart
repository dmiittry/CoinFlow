import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coin_flow/application/app_controller.dart';
import 'package:coin_flow/data/csv_service.dart';
import 'package:coin_flow/data/repository.dart';
import 'package:coin_flow/domain/models.dart';
import 'package:coin_flow/domain/reports.dart';

FinanceData reportFixture() => FinanceData(
  cards: [
    MoneyCard(
      id: 'w',
      name: 'Карта',
      kind: CardKind.wallet,
      opening: 10000000,
      openingDate: DateTime(2020),
    ),
    MoneyCard(
      id: 'w2',
      name: 'Наличные',
      kind: CardKind.wallet,
      openingDate: DateTime(2020),
    ),
    MoneyCard(id: 'salary', name: 'Зарплата', kind: CardKind.income),
    MoneyCard(
      id: 'food',
      name: 'Продукты',
      kind: CardKind.expense,
      budget: 2000000,
      opening: 5000,
      openingDate: DateTime(2026, 10, 1),
    ),
    MoneyCard(id: 'taxi', name: 'Такси', kind: CardKind.expense),
  ],
  entries: [
    MoneyEntry(
      id: 'i',
      kind: EntryKind.income,
      walletId: 'w',
      targetId: 'salary',
      amount: 6000000,
      date: DateTime(2026, 10, 1),
    ),
    MoneyEntry(
      id: 'e',
      kind: EntryKind.expense,
      walletId: 'w',
      targetId: 'food',
      amount: 250000,
      date: DateTime(2026, 10, 2, 23, 59, 59),
    ),
    MoneyEntry(
      id: 't',
      kind: EntryKind.expense,
      walletId: 'w',
      targetId: 'taxi',
      amount: 80000,
      date: DateTime(2026, 10, 3),
    ),
    MoneyEntry(
      id: 'transfer',
      kind: EntryKind.transfer,
      walletId: 'w',
      targetId: 'w2',
      amount: 700000,
      date: DateTime(2026, 10, 2),
    ),
    MoneyEntry(
      id: 'outside',
      kind: EntryKind.expense,
      walletId: 'w',
      targetId: 'food',
      amount: 100,
      date: DateTime(2026, 11, 1),
    ),
  ],
);

void main() {
  test('calendar week, leap day, quarter and year boundaries', () {
    final data = reportFixture();
    final week = ReportRange.forPeriod(
      ReportPeriod.week,
      DateTime(2026, 1, 1),
      data,
    );
    expect(week.start, DateTime(2025, 12, 29));
    expect(week.end, DateTime(2026, 1, 4));
    final leap = ReportRange.forPeriod(
      ReportPeriod.month,
      DateTime(2024, 2, 15),
      data,
    );
    expect(leap.days, 29);
    final quarter = ReportRange.forPeriod(
      ReportPeriod.quarter,
      DateTime(2026, 11, 1),
      data,
    );
    expect(quarter.start, DateTime(2026, 10, 1));
    expect(quarter.end, DateTime(2026, 12, 31));
    expect(
      ReportRange.forPeriod(ReportPeriod.year, DateTime(2024), data).days,
      366,
    );
    expect(
      () => ReportRange(DateTime(2026, 2), DateTime(2026)),
      throwsFormatException,
    );
  });

  test(
    'custom range includes entire last day, excludes transfers and wallet openings',
    () {
      final r = FinanceReport.calculate(
        reportFixture(),
        ReportRange(DateTime(2026, 10, 1), DateTime(2026, 10, 2)),
      );
      expect(r.income, 6000000);
      expect(r.expense, 255000);
      expect(r.net, 5745000);
      expect(r.entries.length, 2);
      expect(r.averageDailyExpense, 127500);
      expect(r.largestExpense, 250000);
      expect(r.openingTotal, 5000);
      expect(r.expenses.single.opening, 5000);
      expect(r.trend.map((b) => b.expense), [5000, 250000]);
    },
  );

  test(
    'day, all-time and bounded long-range trend totals reconcile with categories',
    () {
      final data = reportFixture();
      final day = FinanceReport.calculate(
        data,
        ReportRange.forPeriod(ReportPeriod.day, DateTime(2026, 10, 2), data),
      );
      expect(day.expense, 250000);
      expect(day.income, 0);
      final all = ReportRange.forPeriod(ReportPeriod.all, DateTime(2026), data);
      expect(all.start, DateTime(2026, 10, 1));
      expect(all.end, DateTime(2026, 11, 1));
      for (final range in [
        all,
        ReportRange(DateTime(2018, 2, 15), DateTime(2026, 12, 31)),
        ReportRange(DateTime(1), DateTime(9999, 12, 31)),
      ]) {
        final report = FinanceReport.calculate(data, range);
        expect(report.trend.length, lessThanOrEqualTo(12));
        expect(
          report.trend.fold<int>(0, (s, b) => s + b.expense),
          report.expense,
        );
        expect(
          report.trend.fold<int>(0, (s, b) => s + b.income),
          report.income,
        );
        expect(report.expense, 335100);
      }
      final empty = FinanceReport.calculate(
        FinanceData(cards: [], entries: []),
        ReportRange(DateTime(2026), DateTime(2026)),
      );
      expect(empty.expense, 0);
      expect(empty.averageDailyExpense, 0);
    },
  );

  test(
    'uncategorized plans share reserve, category overspend does not consume it twice',
    () {
      final data = reportFixture().copyWith(
        monthlyPlans: {
          '2026-10': MonthlyPlan(limits: {'food': 200000}, reserve: 100000),
          '2026-11': MonthlyPlan(limits: {'food': 500000}, reserve: 0),
        },
      );
      final p = PlanProgress.calculate(data, DateTime(2026, 10));
      expect(p.spent, 335000);
      expect(p.otherSpent, 80000);
      expect(p.remaining, -35000);
      expect(p.reserveRemaining, 20000);
      expect(p.spending['food'], 255000);
      expect(
        PlanProgress.calculate(data, DateTime(2026, 11)).remaining,
        499900,
      );
      final moved = data.copyWith(
        monthlyPlans: {'2026-10': MonthlyPlan(reserve: 400000)},
      );
      expect(
        PlanProgress.calculate(moved, DateTime(2026, 10)).otherSpent,
        335000,
      );
    },
  );

  test(
    'legacy data, explicit zero plan, JSON and CSV backups preserve independent months',
    () {
      final legacy = reportFixture().toJson()..remove('monthly_plans');
      expect(
        FinanceData.fromJson(legacy).planFor(DateTime(2026, 10)).total,
        2000000,
      );
      final data = reportFixture().copyWith(
        monthlyPlans: {
          '2026-10': MonthlyPlan(limits: {'food': 2000000}, reserve: 1000000),
          '2026-11': MonthlyPlan(),
        },
      );
      for (final restored in [
        FinanceData.fromJson(jsonDecode(jsonEncode(data.toJson()))),
        CsvService().parse(CsvService().export(data)),
      ]) {
        expect(
          restored.toJson()['monthly_plans'],
          data.toJson()['monthly_plans'],
        );
        expect(
          restored.cards.map((c) => c.toJson()),
          unorderedEquals(data.cards.map((c) => c.toJson())),
        );
        expect(
          restored.entries.map((e) => e.toJson()),
          unorderedEquals(data.entries.map((e) => e.toJson())),
        );
        expect(restored.planFor(DateTime(2026, 11)).total, 0);
        expect(restored.planFor(DateTime(2026, 12)).total, 2000000);
      }
      expect(
        () =>
            data.copyWith(monthlyPlans: {'2026-13': MonthlyPlan()}).validate(),
        throwsFormatException,
      );
      expect(
        () => data
            .copyWith(monthlyPlans: {'2026-10': MonthlyPlan(reserve: -1)})
            .validate(),
        throwsFormatException,
      );
      expect(
        () => data
            .copyWith(
              monthlyPlans: {
                '2026-10': MonthlyPlan(limits: {'w': 10}),
              },
            )
            .validate(),
        throwsFormatException,
      );
      expect(
        () => data
            .copyWith(
              monthlyPlans: {
                '2026-10': MonthlyPlan(limits: {'food': 0}),
              },
            )
            .validate(),
        throwsFormatException,
      );
    },
  );

  test(
    'plans survive operations, card edits, restart and backup; deleting category cleans references',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = AppController(LocalFinanceRepository(prefs), prefs);
      await c.initialize();
      await c.replace(reportFixture());
      c.selectMonth(DateTime(2026, 10));
      await c.savePlan(
        c.month,
        MonthlyPlan(limits: {'food': 900000}, reserve: 100000),
      );
      final entry = MoneyEntry(
        id: 'new',
        kind: EntryKind.expense,
        walletId: 'w',
        targetId: 'taxi',
        amount: 500,
        date: DateTime(2026, 10, 20),
      );
      await c.addEntry(entry);
      await c.updateEntry(
        MoneyEntry(
          id: 'new',
          kind: entry.kind,
          walletId: 'w',
          targetId: 'taxi',
          amount: 1000,
          date: entry.date,
        ),
      );
      await c.deleteEntry(c.data.entries.firstWhere((e) => e.id == 'new'));
      await c.saveCard(
        c.data.card('food').copyWith(name: 'Питание', budget: 950000),
      );
      expect(c.data.planFor(c.month).limits['food'], 950000);
      expect(c.data.planFor(c.month).reserve, 100000);
      final fresh = AppController(LocalFinanceRepository(prefs), prefs);
      await fresh.initialize();
      expect(fresh.data.monthlyPlans['2026-10']!.reserve, 100000);
      expect(fresh.previousData!.monthlyPlans['2026-10']!.reserve, 100000);
      final unused = MoneyCard(
        id: 'unused',
        name: 'Связь',
        kind: CardKind.expense,
        budget: 100,
      );
      await c.saveCard(unused);
      await c.deleteCard(unused);
      expect(c.data.planFor(c.month).limits.containsKey('unused'), isFalse);
      c.data.validate();
      c.dispose();
      fresh.dispose();
    },
  );
}
