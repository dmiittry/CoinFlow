enum CardKind { income, wallet, expense }

enum EntryKind { income, expense, transfer }

String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
int _sequence = 0;

class MoneyCard {
  final String id;
  final String name;
  final CardKind kind;
  final int opening;
  final int budget;
  final String icon;
  final DateTime openingDate;

  MoneyCard({
    required this.id,
    required this.name,
    required this.kind,
    this.opening = 0,
    this.budget = 0,
    this.icon = 'wallet',
    DateTime? openingDate,
  }) : openingDate = openingDate ?? DateTime.now();

  MoneyCard copyWith({
    String? name,
    int? opening,
    int? budget,
    String? icon,
    DateTime? openingDate,
  }) => MoneyCard(
    id: id,
    name: name ?? this.name,
    kind: kind,
    opening: opening ?? this.opening,
    budget: budget ?? this.budget,
    icon: icon ?? this.icon,
    openingDate: openingDate ?? this.openingDate,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'opening': opening,
    'budget': budget,
    'icon': icon,
    'opening_date': openingDate.toIso8601String(),
  };
  factory MoneyCard.fromJson(Map<String, dynamic> json) => MoneyCard(
    id: json['id'],
    name: json['name'],
    kind: CardKind.values.byName(json['kind']),
    opening: json['opening'],
    budget: json['budget'],
    icon: json['icon'],
    openingDate: parseFinanceDate(json['opening_date']),
  );
}

class MoneyEntry {
  final String id;
  final EntryKind kind;
  final String walletId;
  final String targetId;
  final int amount;
  final DateTime date;
  final String note;
  const MoneyEntry({
    required this.id,
    required this.kind,
    required this.walletId,
    required this.targetId,
    required this.amount,
    required this.date,
    this.note = '',
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'wallet_id': walletId,
    'target_id': targetId,
    'amount': amount,
    'date': date.toIso8601String(),
    'note': note,
  };
  factory MoneyEntry.fromJson(Map<String, dynamic> json) => MoneyEntry(
    id: json['id'],
    kind: EntryKind.values.byName(json['kind']),
    walletId: json['wallet_id'],
    targetId: json['target_id'],
    amount: json['amount'],
    date: parseFinanceDate(json['date']),
    note: json['note'],
  );
}

class FinanceData {
  final List<MoneyCard> cards;
  final List<MoneyEntry> entries;
  FinanceData({
    required List<MoneyCard> cards,
    required List<MoneyEntry> entries,
  }) : cards = List.unmodifiable(cards),
       entries = List.unmodifiable(entries);

  MoneyCard card(String id) => cards.firstWhere((c) => c.id == id);
  int value(MoneyCard card, DateTime month) {
    var result =
        card.kind == CardKind.wallet || sameMonth(card.openingDate, month)
        ? card.opening
        : 0;
    for (final entry in entries) {
      if (card.kind == CardKind.wallet) {
        if (entry.walletId == card.id) {
          result += entry.kind == EntryKind.income
              ? entry.amount
              : -entry.amount;
        }
        if (entry.kind == EntryKind.transfer && entry.targetId == card.id) {
          result += entry.amount;
        }
      } else if (entry.targetId == card.id && sameMonth(entry.date, month)) {
        result += entry.amount;
      }
    }
    return result;
  }

  int total(CardKind kind, DateTime month) => cards
      .where((c) => c.kind == kind)
      .fold(0, (sum, c) => sum + value(c, month));
  Map<String, dynamic> toJson() => {
    'version': 1,
    'cards': cards.map((c) => c.toJson()).toList(),
    'entries': entries.map((e) => e.toJson()).toList(),
  };
  factory FinanceData.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Неизвестная версия данных');
    }
    final data = FinanceData(
      cards: (json['cards'] as List).map((c) => MoneyCard.fromJson(c)).toList(),
      entries: (json['entries'] as List)
          .map((e) => MoneyEntry.fromJson(e))
          .toList(),
    );
    data.validate();
    return data;
  }
  void validate() {
    final ids = <String>{};
    final names = <String>{};
    final byId = {for (final card in cards) card.id: card};
    var aggregate = 0;
    void checkAggregate(int amount) {
      aggregate += amount;
      if (aggregate > 9007199254740991) {
        throw const FormatException(
          'Общая сумма базы слишком велика для точного расчёта',
        );
      }
    }

    for (final c in cards) {
      if (c.name.trim().isEmpty ||
          c.id.trim().isEmpty ||
          !ids.add(c.id) ||
          !names.add('${c.kind.name}:${c.name.trim().toLowerCase()}')) {
        throw const FormatException(
          'Пустое или повторяющееся название / ID карточки',
        );
      }
      if (c.budget < 0 || (c.kind != CardKind.wallet && c.opening < 0)) {
        throw const FormatException('Отрицательный лимит или сумма категории');
      }
      if (c.opening.abs() > maxMoney || c.budget > maxMoney) {
        throw const FormatException('Слишком большая сумма карточки');
      }
      validateFinanceDate(c.openingDate);
      checkAggregate(c.opening.abs() + c.budget);
    }
    final entryIds = <String>{};
    for (final e in entries) {
      if (e.id.trim().isEmpty ||
          !entryIds.add(e.id) ||
          e.amount <= 0 ||
          e.amount > maxMoney ||
          !ids.contains(e.walletId) ||
          !ids.contains(e.targetId)) {
        throw const FormatException(
          'Некорректная операция или ссылка на карточку',
        );
      }
      final expected = switch (e.kind) {
        EntryKind.income => CardKind.income,
        EntryKind.expense => CardKind.expense,
        EntryKind.transfer => CardKind.wallet,
      };
      validateFinanceDate(e.date);
      checkAggregate(e.amount);
      if (byId[e.walletId]!.kind != CardKind.wallet ||
          byId[e.targetId]!.kind != expected ||
          e.walletId == e.targetId) {
        throw const FormatException('Неверные карточки для операции');
      }
    }
  }
}

bool sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

const int maxMoney = 99999999999999;

void validateFinanceDate(DateTime date) {
  if (date.year < 1 || date.year > 9999) {
    throw const FormatException('Год должен быть от 0001 до 9999');
  }
}

/// DateTime.parse normalizes February 31; reject it rather than move money.
DateTime parseFinanceDate(String raw) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:$|T)').firstMatch(raw);
  final value = DateTime.tryParse(raw);
  if (match == null || value == null) {
    throw const FormatException('Неверная дата, используйте ГГГГ-ММ-ДД');
  }
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final time = RegExp(
    r'T(\d{2}):(\d{2})(?::(\d{2})(?:[.,]\d{1,6})?)?(?:[zZ]|[+-](\d{2}):?(\d{2}))?$',
  ).firstMatch(raw);
  if ((raw.contains('T') && time == null) ||
      (time != null &&
          (int.parse(time[1]!) > 23 ||
              int.parse(time[2]!) > 59 ||
              int.parse(time[3] ?? '0') > 59 ||
              int.parse(time[4] ?? '0') > 23 ||
              int.parse(time[5] ?? '0') > 59))) {
    throw const FormatException('Несуществующее время');
  }
  if (year < 1 ||
      month < 1 ||
      month > 12 ||
      day < 1 ||
      day > DateTime(year, month + 1, 0).day) {
    throw const FormatException('Несуществующая дата');
  }
  validateFinanceDate(value);
  return value;
}

/// Integer minor units: no floating-point arithmetic for money.
int parseMoney(String input) {
  final s = input.replaceAll(RegExp(r'[\s\u00a0₽]'), '').replaceAll(',', '.');
  if (!RegExp(r'^-?\d{1,12}(\.\d{1,2})?$').hasMatch(s)) {
    throw const FormatException(
      'Введите сумму: например, 1250,50 (до 2 знаков после запятой)',
    );
  }
  final negative = s.startsWith('-');
  final parts = s.replaceFirst('-', '').split('.');
  final minor =
      int.parse(parts[0]) * 100 +
      (parts.length > 1 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return negative ? -minor : minor;
}

String decimalMoney(int cents) =>
    '${cents < 0 ? '-' : ''}${cents.abs() ~/ 100}.${(cents.abs() % 100).toString().padLeft(2, '0')}';
