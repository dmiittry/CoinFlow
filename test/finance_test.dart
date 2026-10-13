import 'package:flutter_test/flutter_test.dart';
import 'package:coin_flow/data/csv_service.dart';
import 'package:coin_flow/data/demo_data.dart';
import 'package:coin_flow/domain/models.dart';

void main() {
  final csv = CsvService();
  test('CSV backup round trip preserves every field and three sections', () {
    final data = demoData();
    final encoded = csv.export(data);
    expect(csv.parse(encoded).toJson(), data.toJson());
    for (final section in CsvService.sections) {
      expect(encoded, contains(section));
    }
  });
  test('CSV handles quoted semicolons, newlines, quotes and BOM', () {
    final original = demoData();
    final entry = MoneyEntry(
      id: 'quoted',
      kind: EntryKind.income,
      walletId: 'cash',
      targetId: 'salary',
      amount: 120001,
      date: DateTime(2026, 10, 3),
      note: 'Работа; "проект"\nВторая строка',
    );
    final data = FinanceData(cards: original.cards, entries: [entry]);
    expect(csv.parse(csv.export(data)).toJson(), data.toJson());
  });
  test('wide import automatically creates arbitrary named cards', () {
    final data = csv.parse(
      '\uFEFFДата;Доход: Работа;Кошелек: Банк 1;Кошелек: Банк 2;Расход: Кофе;Расход: Дом\r\n2026-10-03;1000;500,50;-10;25;0',
    );
    expect(data.cards.length, 5);
    expect(data.cards[1].opening, 50050);
    expect(data.cards[2].opening, -1000);
    expect(data.entries, isEmpty);
    expect(csv.parse(csv.template()).cards.length, 6);
  });
  test(
    'invalid CSV rejects duplicate names, invalid sums, dates and dangling refs',
    () {
      for (final input in [
        'Кошелек: A;Кошелек: A\n1;2',
        'Кошелек: A;Кошелек: a\n1;2',
        'Расход: A\n-1',
        'Кошелек: A\n1.005',
        'Кошелек: A\n"bad',
        'Дата;Кошелек: A\n2026-02-31;1',
        'Кошелек: A\n1\n2',
        'Кошелек: A;Расход: B\n1',
      ]) {
        expect(() => csv.parse(input), throwsFormatException, reason: input);
      }
      final bad = csv
          .export(demoData())
          .replaceAll('"cash"', '"missing"')
          .replaceFirst('"missing"', '"cash"');
      expect(() => csv.parse(bad), throwsFormatException);
    },
  );
  test('integer arithmetic, income, expense, transfer and month filtering', () {
    final cards = [
      MoneyCard(id: 'a', name: 'A', kind: CardKind.wallet, opening: 100000),
      MoneyCard(id: 'b', name: 'B', kind: CardKind.wallet),
      MoneyCard(id: 's', name: 'Salary', kind: CardKind.income),
      MoneyCard(id: 'f', name: 'Food', kind: CardKind.expense),
    ];
    final data = FinanceData(
      cards: cards,
      entries: [
        MoneyEntry(
          id: '1',
          kind: EntryKind.income,
          walletId: 'a',
          targetId: 's',
          amount: 50000,
          date: DateTime(2026, 10, 1),
        ),
        MoneyEntry(
          id: '2',
          kind: EntryKind.expense,
          walletId: 'a',
          targetId: 'f',
          amount: 10001,
          date: DateTime(2026, 10, 2),
        ),
        MoneyEntry(
          id: '3',
          kind: EntryKind.transfer,
          walletId: 'a',
          targetId: 'b',
          amount: 20000,
          date: DateTime(2026, 10, 2),
        ),
      ],
    );
    data.validate();
    expect(data.value(cards[0], DateTime(2026, 10)), 119999);
    expect(data.value(cards[1], DateTime(2026, 10)), 20000);
    expect(data.total(CardKind.wallet, DateTime(2026, 9)), 139999);
    expect(data.total(CardKind.expense, DateTime(2026, 10)), 10001);
    expect(data.total(CardKind.expense, DateTime(2026, 9)), 0);
    expect(parseMoney('1 250,50 ₽'), 125050);
    expect(parseMoney('-0.01'), -1);
    expect(parseMoney(decimalMoney(-199)), -199);
    expect(() => parseMoney('NaN'), throwsFormatException);
  });
}
