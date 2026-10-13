import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:coin_flow/application/app_controller.dart';
import 'package:coin_flow/data/csv_service.dart';
import 'package:coin_flow/data/demo_data.dart';
import 'package:coin_flow/data/repository.dart';
import 'package:coin_flow/domain/models.dart';
import 'package:coin_flow/ui/style.dart';

class DelayedRepository implements FinanceRepository {
  final completer = Completer<void>();
  @override
  Future<FinanceData> load() async => demoData();
  @override
  Future<void> save(FinanceData data) => completer.future;
}

class FailingStore extends InMemorySharedPreferencesStore {
  FailingStore(super.data) : super.withData();
  String? rejectedKey;
  bool throws = false;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == rejectedKey) {
      if (throws) throw StateError('Device storage failed');
      return false;
    }
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (key == rejectedKey) return false;
    return super.remove(key);
  }
}

Future<AppController> controller() async {
  final prefs = await SharedPreferences.getInstance();
  final result = AppController(LocalFinanceRepository(prefs), prefs);
  await result.initialize();
  addTearDown(result.dispose);
  return result;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final csv = CsvService();

  test('empty database can be exported and imported without demo data', () {
    final data = FinanceData(cards: [], entries: []);
    expect(csv.parse(csv.export(data)).toJson(), data.toJson());
    expect(
      csv.parse(csv.template(empty: true)).cards.every((c) => c.opening == 0),
      isTrue,
    );
  });

  test(
    'CSV delimiter ignores separators inside quoted names and empty lines',
    () {
      final result = csv.parse(
        '\n"Кошелек: Банк; личный","Расход: Еда"\n"12,50",0',
      );
      expect(result.cards.first.name, 'Банк; личный');
      expect(result.cards.first.opening, 1250);
      expect(csv.parse('Кошелек: Банк\n1,25').cards.single.opening, 125);
      expect(
        csv.parse('"Кошелек: Банк, личный"\n1,25').cards.single.opening,
        125,
      );
    },
  );

  test('dates reject calendar overflow in CSV and saved JSON', () {
    for (final date in [
      '2026-02-29',
      '2026-04-31',
      '2026-00-01',
      '0000-01-01',
      '2026-01-01T25:00:00',
      '2026-01-01T12:61:00',
      '2026-01-01T250000',
      '2026-01-01T12:00:00+03:99',
    ]) {
      expect(() => parseFinanceDate(date), throwsFormatException, reason: date);
    }
    expect(parseFinanceDate('2024-02-29').day, 29);
    final precise = DateTime(2026, 10, 13, 12, 30, 59, 123, 456);
    expect(parseFinanceDate(precise.toIso8601String()), precise);
    expect(
      parseFinanceDate('2026-10-13T01:00:00+09:00'),
      DateTime.utc(2026, 10, 12, 16),
    );
    final raw = demoData().toJson();
    (raw['entries'] as List).first['date'] = '2026-02-31';
    expect(() => FinanceData.fromJson(raw), throwsFormatException);
  });

  test(
    'CSV reports malformed rows and rejects UTF-8 payload above byte limit',
    () {
      expect(
        () => csv.parse('Кошелек: A;Кошелек: B\n"1"extra;2'),
        throwsFormatException,
      );
      expect(
        () => csv.parse(
          'Кошелек: ${List.filled(3 * 1024 * 1024, 'я').join()}\n0',
        ),
        throwsFormatException,
      );
      final invalid = csv
          .export(demoData())
          .replaceFirst('"Операция"', '"Неизвестно"');
      expect(() => csv.parse(invalid), throwsFormatException);
    },
  );

  test(
    'blank transaction IDs, excessive money and mismatched cards rejected',
    () {
      final data = demoData();
      for (final entry in [
        MoneyEntry(
          id: ' ',
          kind: EntryKind.expense,
          walletId: 'cash',
          targetId: 'food',
          amount: 1,
          date: DateTime.now(),
        ),
        MoneyEntry(
          id: 'x',
          kind: EntryKind.expense,
          walletId: 'cash',
          targetId: 'food',
          amount: maxMoney + 1,
          date: DateTime.now(),
        ),
        MoneyEntry(
          id: 'x',
          kind: EntryKind.income,
          walletId: 'cash',
          targetId: 'food',
          amount: 1,
          date: DateTime.now(),
        ),
        MoneyEntry(
          id: 'x',
          kind: EntryKind.transfer,
          walletId: 'cash',
          targetId: 'cash',
          amount: 1,
          date: DateTime.now(),
        ),
      ]) {
        expect(
          () => FinanceData(cards: data.cards, entries: [entry]).validate(),
          throwsFormatException,
        );
      }
      expect(money(100000000000001), contains(',01'));
      expect(money(-1), '−0,01 ₽');
    },
  );

  test(
    'editing entry recalculates both wallets, category, month and survives restart',
    () async {
      final c = await controller();
      final e = c.data.entries.first;
      final beforeCash = c.data.value(c.data.card('cash'), c.month);
      final beforeBank = c.data.value(c.data.card('bank'), c.month);
      await c.updateEntry(
        MoneyEntry(
          id: e.id,
          kind: EntryKind.transfer,
          walletId: 'bank',
          targetId: 'cash',
          amount: 750,
          date: DateTime(2020, 1, 4),
          note: 'исправлено',
        ),
      );
      expect(c.data.entries.length, 5);
      expect(
        c.data.value(c.data.card('cash'), c.month),
        beforeCash + e.amount + 750,
      );
      expect(c.data.value(c.data.card('bank'), c.month), beforeBank - 750);
      expect(c.data.value(c.data.card('food'), c.month), 0);
      final restarted = await controller();
      expect(restarted.data.toJson(), c.data.toJson());
      await c.deleteEntry(c.data.entries.first);
      await expectLater(c.updateEntry(e), throwsStateError);
    },
  );

  test(
    'card updates preserve order, validate duplicates and block linked deletion',
    () async {
      final c = await controller();
      final order = c.data.cards.map((e) => e.id).toList();
      await c.saveCard(
        c.data.card('cash').copyWith(name: 'Наличные', opening: -100),
      );
      expect(c.data.cards.map((e) => e.id), order);
      await expectLater(
        c.saveCard(c.data.card('bank').copyWith(name: 'наличные')),
        throwsFormatException,
      );
      await expectLater(c.deleteCard(c.data.card('cash')), throwsStateError);
      await c.deleteCard(c.data.card('invest'));
      expect(c.data.cards.any((card) => card.id == 'invest'), isFalse);
    },
  );

  test(
    'theme and logout persist; month boundaries cross years safely',
    () async {
      final c = await controller();
      expect(await c.login('demo', 'bad'), isFalse);
      expect(await c.login(' demo ', 'demo123'), isTrue);
      await c.setTheme(ThemeMode.dark);
      await c.logout();
      final restarted = await controller();
      expect(restarted.signedIn, isFalse);
      expect(restarted.themeMode, ThemeMode.dark);
      c.selectMonth(DateTime(2025, 12));
      c.moveMonth(1);
      expect(c.month, DateTime(2026, 1));
      c.selectMonth(DateTime(1));
      c.moveMonth(-1);
      expect(c.month, DateTime(1));
    },
  );

  test(
    'clear and restore retain original history and survive restart',
    () async {
      final c = await controller();
      final original = c.data.toJson();
      await c.clearData();
      expect((await controller()).data.cards, isEmpty);
      expect(c.previousData!.toJson(), original);
      await c.replace(c.previousData!);
      expect((await controller()).data.toJson(), original);
    },
  );

  test(
    'corrupt primary recovers last good version without overwriting evidence',
    () async {
      final c = await controller();
      final original = c.data.toJson();
      await c.clearData();
      await c.preferences.setString(LocalFinanceRepository.key, '{broken');
      final recovered = await controller();
      expect(recovered.data.toJson(), original);
      expect(recovered.recoveryNotice, isNotNull);
      expect(c.preferences.getString(LocalFinanceRepository.key), '{broken');
      await recovered.saveCard(
        recovered.data.card('cash').copyWith(name: 'Восстановлен'),
      );
      expect(recovered.previousData!.toJson(), original);
      expect((await controller()).data.card('cash').name, 'Восстановлен');
    },
  );

  test(
    'invalid database without usable backup fails without resetting data',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(LocalFinanceRepository.key, '{broken');
      await prefs.setString(LocalFinanceRepository.backupKey, '{also broken');
      await expectLater(
        LocalFinanceRepository(prefs).load(),
        throwsFormatException,
      );
      expect(prefs.getString(LocalFinanceRepository.key), '{broken');
    },
  );

  test(
    'overlapping writes cannot overwrite an in-flight transaction',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = DelayedRepository();
      final c = AppController(repo, prefs);
      await c.initialize();
      final first = c.clearData();
      expect(c.busy, isTrue);
      await expectLater(c.saveCard(c.data.cards.first), throwsStateError);
      repo.completer.complete();
      await first;
      expect(c.busy, isFalse);
      expect(c.data.cards, isEmpty);
      c.dispose();
    },
  );

  test('local backup contains exact previous successful snapshot', () async {
    final c = await controller();
    final previous = jsonEncode(c.data.toJson());
    await c.saveCard(
      MoneyCard(id: 'new', name: 'Новый', kind: CardKind.wallet),
    );
    expect(c.preferences.getString(LocalFinanceRepository.backupKey), previous);
  });

  test('reject totals that cannot be represented exactly on all platforms', () {
    final data = FinanceData(
      cards: [
        for (var i = 0; i < 100; i++)
          MoneyCard(
            id: '$i',
            name: 'Wallet $i',
            kind: CardKind.wallet,
            opening: maxMoney,
          ),
      ],
      entries: [],
    );
    expect(data.validate, throwsFormatException);
  });

  test(
    'missing primary recovers backup instead of restoring demo data',
    () async {
      final c = await controller();
      final original = c.data.toJson();
      await c.clearData();
      await c.preferences.remove(LocalFinanceRepository.key);
      final recovered = await controller();
      expect(recovered.data.toJson(), original);
      expect(recovered.recoveryNotice, isNotNull);
    },
  );

  for (final throws in [false, true]) {
    test(
      'failed database write (throws=$throws) preserves cache, backup and retry',
      () async {
        final c = await controller();
        final original = c.data.toJson();
        final store = FailingStore({
          for (final key in c.preferences.getKeys())
            'flutter.$key': c.preferences.get(key)!,
        })..throws = throws;
        SharedPreferencesStorePlatform.instance = store;
        for (final key in [
          LocalFinanceRepository.backupKey,
          LocalFinanceRepository.key,
        ]) {
          store.rejectedKey = 'flutter.$key';
          await expectLater(c.clearData(), throwsStateError);
          expect(c.data.toJson(), original);
          expect(c.busy, isFalse);
          expect(
            (await LocalFinanceRepository(c.preferences).load()).toJson(),
            original,
          );
        }
        store.rejectedKey = null;
        await c.clearData();
        expect(c.previousData!.toJson(), original);
        expect((await controller()).data.cards, isEmpty);
      },
    );
  }

  test(
    'failed login, logout and theme writes preserve session and cached settings',
    () async {
      final c = await controller();
      final store = FailingStore({
        for (final key in c.preferences.getKeys())
          'flutter.$key': c.preferences.get(key)!,
      });
      SharedPreferencesStorePlatform.instance = store;
      store.rejectedKey = 'flutter.demo_session';
      await expectLater(c.login('demo', 'demo123'), throwsStateError);
      expect(c.signedIn, isFalse);
      expect(c.preferences.getBool('demo_session'), isNull);
      store.rejectedKey = null;
      await c.login('demo', 'demo123');
      store.rejectedKey = 'flutter.demo_session';
      await expectLater(c.logout(), throwsStateError);
      expect(c.signedIn, isTrue);
      expect(c.preferences.getBool('demo_session'), isTrue);
      store.rejectedKey = 'flutter.theme';
      await expectLater(c.setTheme(ThemeMode.dark), throwsStateError);
      expect(c.themeMode, ThemeMode.system);
      expect(c.preferences.getString('theme'), isNull);
      expect(c.preferencesBusy, isFalse);
    },
  );
}
