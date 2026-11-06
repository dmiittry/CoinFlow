import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coin_flow/domain/models.dart';
import 'package:coin_flow/domain/reports.dart';
import 'package:coin_flow/ui/plan_screen.dart';
import 'package:coin_flow/ui/reports_screen.dart';
import 'audit_widget_test.dart' as helpers;
import 'reports_test.dart' show reportFixture;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ru');
  });

  testWidgets(
    'monthly plan edits category and reserve atomically, shows spending and persists',
    (tester) async {
      final c = await helpers.app(tester, data: reportFixture());
      c.selectMonth(DateTime(2026, 10));
      await tester.pumpAndSettle();
      await helpers.tap(tester, find.text('План'));
      expect(find.byType(PlanScreen), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('plan-food')), '20000');
      await helpers.tap(tester, find.byKey(const ValueKey('plan-reserve')));
      await tester.enterText(
        find.byKey(const ValueKey('plan-reserve')),
        '1000',
      );
      await helpers.tap(tester, find.byKey(const ValueKey('save-plan')));
      expect(find.byType(PlanScreen), findsNothing);
      expect(c.data.planFor(c.month).total, 2100000);
      expect(PlanProgress.calculate(c.data, c.month).otherSpent, 80000);
      expect(find.text('Остальное: 800 ₽ из 1 000 ₽'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed plan save keeps draft, and cancel leaves original plan', (
    tester,
  ) async {
    final repository = helpers.ControlledRepository();
    final c = await helpers.app(tester, repository: repository);
    await helpers.tap(tester, find.text('План'));
    await tester.enterText(find.byKey(const ValueKey('plan-food')), '42');
    repository.fail = true;
    await helpers.tap(tester, find.byKey(const ValueKey('save-plan')));
    expect(find.text('Ошибка записи на устройство'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('plan-food')))
          .controller!
          .text,
      '42',
    );
    expect(c.data.monthlyPlans, isEmpty);
    await helpers.tap(tester, find.byTooltip('Закрыть план'));
    expect(c.data.planFor(c.month).total, 100000);
  });

  testWidgets(
    'report periods, custom range cancellation and category details work',
    (tester) async {
      final c = await helpers.app(tester, data: reportFixture());
      c.selectMonth(DateTime(2026, 10));
      await tester.pumpAndSettle();
      await helpers.tap(tester, find.text('Отчёты'));
      expect(find.byType(ReportsScreen), findsOneWidget);
      for (final period in ['day', 'week', 'quarter', 'year', 'all', 'month']) {
        await helpers.tap(tester, find.byKey(ValueKey('period-$period')));
        expect(
          tester
              .widget<ChoiceChip>(find.byKey(ValueKey('period-$period')))
              .selected,
          isTrue,
        );
      }
      await helpers.tap(tester, find.byKey(const ValueKey('period-custom')));
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(DateRangePickerDialog))).pop();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('period-month')))
            .selected,
        isTrue,
      );
      await helpers.tap(tester, find.byKey(const ValueKey('stat-food')));
      expect(find.text('Начальная сумма: 50 ₽'), findsOneWidget);
      expect(find.text('2 500 ₽'), findsWidgets);
      await helpers.tap(tester, find.byTooltip('Закрыть детализацию'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'copy previous month, invalid input and moving category to reserve',
    (tester) async {
      final c = await helpers.app(
        tester,
        data: reportFixture().copyWith(
          monthlyPlans: {
            '2026-09': MonthlyPlan(limits: {'food': 400000}, reserve: 100000),
          },
        ),
      );
      c.selectMonth(DateTime(2026, 10));
      await tester.pumpAndSettle();
      await helpers.tap(tester, find.text('План'));
      await helpers.tap(tester, find.text('Взять план прошлого месяца'));
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('plan-food')))
            .controller!
            .text,
        '4000.00',
      );
      await tester.enterText(find.byKey(const ValueKey('plan-food')), '-1');
      await helpers.tap(tester, find.byKey(const ValueKey('save-plan')));
      expect(
        find.text('План «Продукты» не может быть отрицательным'),
        findsOneWidget,
      );
      expect(c.data.monthlyPlans.containsKey('2026-10'), isFalse);
      await helpers.tap(tester, find.byKey(const ValueKey('plan-food')));
      await tester.enterText(find.byKey(const ValueKey('plan-food')), '0');
      await helpers.tap(tester, find.byKey(const ValueKey('save-plan')));
      expect(c.data.planFor(c.month).limits, isEmpty);
      expect(PlanProgress.calculate(c.data, c.month).otherSpent, 335000);
      expect(c.data.monthlyPlans['2026-09']!.limits['food'], 400000);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('custom period selection updates totals and trend table', (
    tester,
  ) async {
    final c = await helpers.app(tester, data: reportFixture());
    c.selectMonth(DateTime(2026, 10));
    await tester.pumpAndSettle();
    await helpers.tap(tester, find.text('Отчёты'));
    await helpers.tap(tester, find.byKey(const ValueKey('period-custom')));
    Navigator.of(tester.element(find.byType(DateRangePickerDialog))).pop(
      DateTimeRange(start: DateTime(2026, 10, 2), end: DateTime(2026, 10, 2)),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('period-custom')))
          .selected,
      isTrue,
    );
    expect(find.text('1 операция · 1 дн.'), findsOneWidget);
    expect(find.text('2 500 ₽'), findsOneWidget);
    await helpers.tap(tester, find.text('Значения по датам'));
    expect(find.text('Доходы 0 ₽ · расходы 2 500 ₽'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final setting in [
    (const Size(320, 740), 1.0, ThemeMode.light),
    (const Size(390, 844), 2.0, ThemeMode.dark),
    (const Size(844, 390), 1.0, ThemeMode.light),
    (const Size(1200, 800), 1.0, ThemeMode.dark),
  ]) {
    testWidgets(
      'reports and plans fit ${setting.$1} scale ${setting.$2} ${setting.$3}',
      (tester) async {
        final c = await helpers.app(
          tester,
          data: reportFixture(),
          size: setting.$1,
          scale: setting.$2,
        );
        c.selectMonth(DateTime(2026, 10));
        await c.setTheme(setting.$3);
        await tester.pumpAndSettle();
        await helpers.tap(tester, find.text('План'));
        await helpers.tap(tester, find.byKey(const ValueKey('plan-reserve')));
        await tester.enterText(
          find.byKey(const ValueKey('plan-reserve')),
          '10',
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await helpers.tap(tester, find.byTooltip('Закрыть план'));
        await helpers.tap(tester, find.text('Отчёты').last);
        await helpers.tap(tester, find.byKey(const ValueKey('stat-food')));
        expect(tester.takeException(), isNull);
        await helpers.tap(tester, find.byTooltip('Закрыть детализацию'));
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -700));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('empty reports and reserve-only plan work without categories', (
    tester,
  ) async {
    final c = await helpers.app(
      tester,
      data: FinanceData(cards: [], entries: []),
    );
    await helpers.tap(tester, find.text('План'));
    await tester.enterText(find.byKey(const ValueKey('plan-reserve')), '500');
    await helpers.tap(tester, find.byKey(const ValueKey('save-plan')));
    expect(c.data.planFor(c.month).reserve, 50000);
    await helpers.tap(tester, find.text('Отчёты'));
    await helpers.tap(tester, find.byKey(const ValueKey('period-all')));
    expect(
      find.text('За этот период пока нет доходов и расходов'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
