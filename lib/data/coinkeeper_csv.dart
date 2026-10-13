import '../domain/models.dart';

/// Reads exported transactions only. It never accesses or writes app storage.
class CoinKeeperCsv {
  static const requiredHeaders = [
    'date',
    'type',
    'from',
    'to',
    'amount',
    'currency',
  ];

  static bool matches(List<String> headers) {
    final normalized = headers.map((h) => h.toLowerCase()).toSet();
    return normalized.contains('date') && normalized.contains('type');
  }

  static ({FinanceData data, List<String> notices}) parse(
    List<String> headers,
    List<List<String>> rows,
  ) {
    final normalized = headers.map((h) => h.toLowerCase()).toList();
    if (normalized.toSet().length != headers.length) {
      throw const FormatException('Повторяющиеся столбцы CoinKeeper');
    }
    final missing = requiredHeaders.where((h) => !normalized.contains(h));
    if (missing.isNotEmpty) {
      throw FormatException(
        'В CSV CoinKeeper отсутствуют столбцы: ${missing.join(', ')}',
      );
    }
    final columns = {
      for (var i = 0; i < normalized.length; i++) normalized[i]: i,
    };
    final cards = <String, MoneyCard>{};
    final entries = <MoneyEntry>[];
    var hasRecurrence = false;

    MoneyCard card(String name, CardKind kind, DateTime date) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) {
        throw const FormatException('Пустое название в From или To');
      }
      final key = '${kind.name}:${trimmed.toLowerCase()}';
      final existing = cards[key];
      if (existing != null) {
        if (date.isBefore(existing.openingDate)) {
          cards[key] = existing.copyWith(openingDate: date);
        }
        return cards[key]!;
      }
      return cards[key] = MoneyCard(
        id: newId(),
        name: trimmed,
        kind: kind,
        openingDate: date,
        icon: switch (kind) {
          CardKind.income => 'coins',
          CardKind.wallet => 'wallet',
          CardKind.expense => 'bag',
        },
      );
    }

    for (var i = 0; i < rows.length; i++) {
      String get(String name) =>
          columns.containsKey(name) ? rows[i][columns[name]!] : '';
      try {
        final date = _date(get('date').trim());
        final type = get('type').trim().toLowerCase();
        final kind = switch (type) {
          'income' => EntryKind.income,
          'expense' => EntryKind.expense,
          'transfer' => EntryKind.transfer,
          _ => throw FormatException(
            'Неизвестный тип операции CoinKeeper: $type',
          ),
        };
        if (get('currency').trim().toUpperCase() != 'RUB') {
          throw const FormatException(
            'Поддерживаются только операции в RUB. Валютные суммы нельзя импортировать как рубли.',
          );
        }
        final amount = parseMoney(get('amount'));
        if (amount <= 0) {
          throw const FormatException('Сумма операции должна быть больше нуля');
        }
        final noteParts = <String>[if (get('note').isNotEmpty) get('note')];
        if (get('tags').trim().isNotEmpty) {
          noteParts.add('Метки: ${get('tags')}');
        }
        final recurrence = get('recurrence').trim();
        if (recurrence.isNotEmpty && recurrence.toLowerCase() != 'false') {
          hasRecurrence = true;
          noteParts.add('Повторение CoinKeeper: $recurrence');
        }
        final converted = get('amount converted').trim();
        final conversionCurrency = get(
          'currency of conversion',
        ).trim().toUpperCase();
        if (converted.isNotEmpty || conversionCurrency.isNotEmpty) {
          if (converted.isEmpty || conversionCurrency.isEmpty) {
            throw const FormatException(
              'Не заполнены сумма или валюта конвертации',
            );
          }
          if (conversionCurrency != 'RUB') {
            throw const FormatException(
              'Мультивалютные переводы пока не поддерживаются',
            );
          }
          final convertedAmount = parseMoney(converted);
          if (convertedAmount != amount) {
            throw const FormatException(
              'Суммы одной операции в RUB не совпадают',
            );
          }
          noteParts.add(
            'Сумма конвертации: ${decimalMoney(convertedAmount)} RUB',
          );
        }
        final from = get('from');
        final to = get('to');
        final wallet = card(
          kind == EntryKind.income ? to : from,
          CardKind.wallet,
          date,
        );
        final target = card(
          kind == EntryKind.income ? from : to,
          switch (kind) {
            EntryKind.income => CardKind.income,
            EntryKind.expense => CardKind.expense,
            EntryKind.transfer => CardKind.wallet,
          },
          date,
        );
        if (wallet.id == target.id) {
          throw const FormatException('Кошельки перевода должны отличаться');
        }
        entries.add(
          MoneyEntry(
            id: newId(),
            kind: kind,
            walletId: wallet.id,
            targetId: target.id,
            amount: amount,
            date: date,
            note: noteParts.join('\n'),
          ),
        );
      } on FormatException catch (error) {
        throw FormatException('Строка ${i + 2} CoinKeeper: ${error.message}');
      }
    }
    return (
      data: FinanceData(
        cards: [
          for (final kind in CardKind.values)
            ...cards.values.where((c) => c.kind == kind),
        ],
        entries: entries,
      ),
      notices: [
        'В экспорте CoinKeeper нет начальных остатков и лимитов: они будут равны нулю. Остатки кошельков рассчитываются только по операциям из файла. Начальные остатки можно задать в настройках карточек.',
        'Комментарии сохраняются; метки добавляются к ним. Даты используются как указано в CSV, без сдвига часового пояса.',
        if (hasRecurrence)
          'Параметры повторения сохранены в комментариях. Автоматические повторяющиеся операции не создаются.',
      ],
    );
  }

  static DateTime _date(String value) {
    final match = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(value);
    if (match == null) {
      throw const FormatException(
        'Дата CoinKeeper должна иметь формат ДД.ММ.ГГГГ',
      );
    }
    return parseFinanceDate('${match[3]}-${match[2]}-${match[1]}');
  }
}
