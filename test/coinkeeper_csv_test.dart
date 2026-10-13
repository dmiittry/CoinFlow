import 'package:flutter_test/flutter_test.dart';
import 'package:coin_flow/data/csv_service.dart';
import 'package:coin_flow/domain/models.dart';

// Fictional fixtures only: personal exports must not be committed to this repo.
const header =
    'Date,Type,From,To,Tags,Amount,Currency,Amount converted,Currency of conversion,Recurrence,Note';
const sample =
    '$header\r\n'
    '01.10.2026,income,Работа,Банк,,1000.00,RUB,,,false,Зарплата\r\n'
    '02.10.2026,expense,Банк,Продукты,,125.50,RUB,,,false,Покупки\r\n'
    '03.10.2026,transfer,Банк,Наличные,,200.00,RUB,,,false,Снятие\r\n';

void main() {
  final csv = CsvService();

  test('large multi-year export preserves every row and reuses cards', () {
    final content = StringBuffer('$header\n');
    for (var i = 0; i < 7500; i++) {
      content.writeln(
        '01.01.${2018 + i % 9},expense,Банк,Еда,,1.23,RUB,,,false,Строка $i',
      );
    }
    final data = csv.parse(content.toString());
    expect(data.cards.length, 2);
    expect(data.entries.length, 7500);
    expect(data.entries.map((e) => e.id).toSet().length, 7500);
    expect(data.entries.last.note, 'Строка 7499');
    expect(data.total(CardKind.wallet, DateTime(2026)), -922500);
  });

  test(
    'detect CoinKeeper and map three transaction directions to auto-created cards',
    () {
      final preview = csv.preview(sample);
      final data = preview.data;
      expect(preview.formatName, 'CoinKeeper');
      expect(preview.notices.first, contains('нет начальных остатков'));
      expect(data.cards.length, 4);
      expect(data.entries.map((e) => e.kind), EntryKind.values);
      MoneyCard card(String name) =>
          data.cards.singleWhere((c) => c.name == name);
      expect(card('Работа').kind, CardKind.income);
      expect(card('Продукты').kind, CardKind.expense);
      expect(data.value(card('Банк'), DateTime(2026, 10)), 67450);
      expect(data.value(card('Наличные'), DateTime(2026, 10)), 20000);
      expect(data.total(CardKind.expense, DateTime(2026, 10)), 12550);
      expect(data.total(CardKind.income, DateTime(2026, 10)), 100000);
      expect(data.cards.every((c) => c.opening == 0 && c.budget == 0), isTrue);
      expect(data.entries.map((e) => e.note), [
        'Зарплата',
        'Покупки',
        'Снятие',
      ]);
    },
  );

  test(
    'keep local calendar dates on month boundaries without timezone conversion',
    () {
      final data = csv.parse(
        '$header\n01.01.2020,expense,Банк,Еда,,1,RUB,,,false,',
      );
      expect(data.entries.single.date, DateTime(2020, 1, 1));
      expect(data.entries.single.date.isUtc, isFalse);
      expect(data.total(CardKind.expense, DateTime(2019, 12)), 0);
      expect(data.total(CardKind.expense, DateTime(2020, 1)), 100);
    },
  );

  test(
    'quoted names, comma amounts, multiline notes, tags and recurrence survive',
    () {
      final data = csv.preview(
        '\uFEFF$header\n'
        '29.02.2024,expense,"Банк, основной","Дом; ремонт","важное, дом","25,75",RUB,,,true,"Строка 1\nСтрока ""2"""',
      );
      expect(data.data.entries.single.amount, 2575);
      expect(data.data.cards.any((c) => c.name == 'Банк, основной'), isTrue);
      expect(
        data.data.entries.single.note,
        'Строка 1\nСтрока "2"\nМетки: важное, дом\nПовторение CoinKeeper: true',
      );
      expect(
        data.notices.last,
        contains('Автоматические повторяющиеся операции не создаются'),
      );
      final back = csv.parse(csv.export(data.data));
      expect(
        back.cards.map((c) => c.toJson()),
        data.data.cards.map((c) => c.toJson()),
      );
      expect(back.entries.single.toJson(), data.data.entries.single.toJson());
    },
  );

  test('header order, case, optional columns and semicolon separator', () {
    final data = csv.parse(
      ' AMOUNT ;To; Currency ;FROM;Type;Date\n12,50;Еда;rub;Банк;EXPENSE;03.10.2026',
    );
    expect(data.entries.single.amount, 1250);
    expect(data.entries.single.note, isEmpty);
  });

  test(
    'reuse cards within kind but keep same names across different kinds',
    () {
      final data = csv.parse(
        '$header\n'
        '03.10.2026,income,Общее,Общее,,10,RUB,,,false,\n'
        '02.10.2026,expense, общее ,Общее,,1,RUB,,,false,\n'
        '01.10.2026,expense,ОБЩЕЕ,общее,,2,RUB,,,false,',
      );
      expect(data.cards.length, 3);
      expect(data.entries[0].walletId, data.entries[1].walletId);
      expect(data.entries[1].targetId, data.entries[2].targetId);
      expect(
        data.cards.where((c) => c.kind == CardKind.wallet).single.openingDate,
        DateTime(2026, 10, 1),
      );
    },
  );

  test(
    'identical source rows are real separate transactions and are not dropped',
    () {
      const row = '01.10.2026,expense,Банк,Еда,,10,RUB,,,false,\n';
      final data = csv.parse('$header\n$row$row');
      expect(data.entries.length, 2);
      expect(data.entries.map((e) => e.id).toSet().length, 2);
      expect(data.cards.length, 2);
    },
  );

  test(
    'correction records retain source type and independent category names',
    () {
      final data = csv.parse(
        '$header\n'
        '01.10.2026,income,correction,Банк,,10,RUB,,,false,\n'
        '01.10.2026,expense,Банк,correction,,3,RUB,,,false,',
      );
      expect(data.cards.where((c) => c.name == 'correction').length, 2);
      expect(data.total(CardKind.wallet, DateTime(2026, 10)), 700);
    },
  );

  test(
    'reject invalid fields with source row number instead of skipping records',
    () {
      for (final row in [
        '31.02.2026,expense,Банк,Еда,,1,RUB,,,false,',
        '2026-10-01,expense,Банк,Еда,,1,RUB,,,false,',
        '01.10.2026,unknown,Банк,Еда,,1,RUB,,,false,',
        '01.10.2026,expense,,Еда,,1,RUB,,,false,',
        '01.10.2026,expense,Банк, ,,1,RUB,,,false,',
        '01.10.2026,expense,Банк,Еда,,0,RUB,,,false,',
        '01.10.2026,expense,Банк,Еда,,-1,RUB,,,false,',
        '01.10.2026,expense,Банк,Еда,,1.005,RUB,,,false,',
        '01.10.2026,transfer,Банк,банк,,1,RUB,,,false,',
        '01.10.2026,expense,Банк,Еда,,1,USD,80,RUB,false,',
        '01.10.2026,expense,Банк,Еда,,1,,,,false,',
        '01.10.2026,transfer,Банк,Кошелек,,1,RUB,1,USD,false,',
        '01.10.2026,expense,Банк,Еда,,1,RUB,2,RUB,false,',
        '01.10.2026,expense,Банк,Еда,,1,RUB,1,,false,',
      ]) {
        expect(
          () => csv.parse('$header\n$row'),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'row',
              contains('Строка 2 CoinKeeper'),
            ),
          ),
          reason: row,
        );
      }
    },
  );

  test('required and duplicate headers and malformed row width rejected', () {
    expect(
      () => csv.parse('Date,Type,Amount\n01.10.2026,expense,1'),
      throwsFormatException,
    );
    expect(
      () => csv.parse(
        '$header,DATE\n01.10.2026,expense,Банк,Еда,,1,RUB,,,false,,01.10.2026',
      ),
      throwsFormatException,
    );
    expect(
      () => csv.parse('$header\n01.10.2026,expense,Банк'),
      throwsFormatException,
    );
  });

  test('same-currency conversion retains metadata without counting twice', () {
    final data = csv.parse(
      '$header\n01.10.2026,transfer,Банк,Кошелек,,1,RUB,1,RUB,false,',
    );
    expect(data.entries.single.note, 'Сумма конвертации: 1.00 RUB');
    expect(data.entries.single.amount, 100);
    expect(data.total(CardKind.wallet, DateTime(2026, 10)), 0);
  });

  test(
    'legacy formats and full backup remain readable after adding detection',
    () {
      expect(csv.preview(csv.template()).formatName, 'Снимок остатков');
      final data = csv.parse(sample);
      final back = csv.preview(csv.export(data));
      expect(back.formatName, 'Полная копия CoinFlow');
      expect(
        back.data.cards.map((c) => c.toJson()),
        data.cards.map((c) => c.toJson()),
      );
      expect(
        {for (final e in back.data.entries) e.id: e.toJson()},
        {for (final e in data.entries) e.id: e.toJson()},
      );
      expect(csv.preview(header).data.entries, isEmpty);
    },
  );
}
