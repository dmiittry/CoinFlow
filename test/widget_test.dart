import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coin_flow/application/app_controller.dart';
import 'package:coin_flow/data/repository.dart';
import 'package:coin_flow/main.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ru');
  });
  testWidgets('login, add expense, theme and session survive restart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await SharedPreferences.getInstance();
    final c = AppController(LocalFinanceRepository(prefs), prefs);
    await c.initialize();
    await tester.pumpWidget(CoinFlowApp(controller: c));
    await tester.enterText(find.byType(TextField).at(0), 'demo');
    await tester.enterText(find.byType(TextField).at(1), 'wrong');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(find.text('Неверный логин или пароль'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), 'demo123');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Добавить карточку: Кошельки'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final count = c.data.entries.length;
    await tester.tap(find.text('Операция'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '125,50');
    await tester.tap(find.text('Сохранить операцию'));
    await tester.pumpAndSettle();
    expect(c.data.entries.length, count + 1);
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Темная тема'));
    await tester.pumpAndSettle();
    expect(c.themeMode, ThemeMode.dark);
    expect(tester.takeException(), isNull);
    final restarted = AppController(LocalFinanceRepository(prefs), prefs);
    await restarted.initialize();
    expect(restarted.signedIn, isTrue);
    expect(restarted.themeMode, ThemeMode.dark);
    expect(restarted.data.entries.length, count + 1);
  });
  testWidgets('small screen overview and editors have no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await SharedPreferences.getInstance();
    final c = AppController(LocalFinanceRepository(prefs), prefs);
    await c.initialize();
    await c.login('demo', 'demo123');
    await tester.pumpWidget(CoinFlowApp(controller: c));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Операция'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
