import '../domain/models.dart';

FinanceData demoData() {
  final now = DateTime.now();
  final cards = <MoneyCard>[];
  void add(
    String id,
    String name,
    CardKind kind,
    String icon, [
    int opening = 0,
    int budget = 0,
  ]) {
    cards.add(
      MoneyCard(
        id: id,
        name: name,
        kind: kind,
        icon: icon,
        opening: opening,
        budget: budget,
        openingDate: now,
      ),
    );
  }

  add('salary', 'Зарплата', CardKind.income, 'chart', 0, 15000000);
  add('other_income', 'Разное', CardKind.income, 'coins');
  add('invest_income', 'Инвестиции', CardKind.income, 'percent');
  add('freelance', 'Фриланс', CardKind.income, 'globe');
  add('cash', 'Кошелек', CardKind.wallet, 'wallet', 176300);
  add('bank', 'Тинькофф', CardKind.wallet, 'bank', 3176945);
  add('almaz', 'Алмаз', CardKind.wallet, 'chart', 49);
  add('invest', 'Т-Инвестиции', CardKind.wallet, 'building', 0);
  add('food', 'Продукты и хоз', CardKind.expense, 'groceries', 0, 2000000);
  add('cafe', 'Еда вне дома', CardKind.expense, 'cafe', 0, 4500000);
  add('taxi', 'Такси', CardKind.expense, 'bus');
  add('debt', 'Долги', CardKind.expense, 'bag');
  add('cigarettes', 'Сигареты', CardKind.expense, 'circle', 0, 230000);
  add('home', 'Дом и хозяйство', CardKind.expense, 'home', 0, 4800000);
  add('fun', 'Развлечения', CardKind.expense, 'movie');
  add('education', 'Образование', CardKind.expense, 'school');
  add('alcohol', 'Алкоголь', CardKind.expense, 'glass', 0, 2000000);
  add('tax', 'Налоги', CardKind.expense, 'percent');
  add('family', 'Семья', CardKind.expense, 'heart');
  add('upgrade', 'Upgrade', CardKind.expense, 'chart');
  add('clothes', 'Одежда', CardKind.expense, 'clothes');
  add('other', 'Разное', CardKind.expense, 'circle');
  add('internet', 'Интернет и связь', CardKind.expense, 'wifi');
  add('sport', 'Спорт', CardKind.expense, 'trophy');
  final entries = <MoneyEntry>[];
  void expense(String id, String wallet, int amount, String note) =>
      entries.add(
        MoneyEntry(
          id: 'demo_$id',
          kind: EntryKind.expense,
          walletId: wallet,
          targetId: id,
          amount: amount,
          date: DateTime(now.year, now.month, now.day, 10, entries.length * 5),
          note: note,
        ),
      );
  expense('food', 'cash', 10000, 'Покупки в магазине');
  expense('cafe', 'cash', 30000, 'Кофе и завтрак');
  expense('debt', 'bank', 3000000, 'Возврат долга');
  expense('cigarettes', 'cash', 30000, '');
  expense('alcohol', 'cash', 100000, '');
  return FinanceData(cards: cards, entries: entries);
}
