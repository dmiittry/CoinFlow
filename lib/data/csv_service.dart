import 'dart:convert';
import '../domain/models.dart';

class CsvService {
  static const headers = [
    'Раздел',
    'Запись',
    'ID',
    'Название',
    'Сумма',
    'Лимит',
    'Иконка',
    'Дата',
    'Кошелек',
    'Категория',
    'Тип',
    'Комментарий',
  ];
  static const sections = ['Доходы', 'Кошельки', 'Расходы'];

  String export(FinanceData data) {
    final rows = <List<String>>[headers];
    for (final kind in CardKind.values) {
      for (final c in data.cards.where((c) => c.kind == kind)) {
        rows.add([
          sections[kind.index],
          'Карточка',
          c.id,
          c.name,
          decimalMoney(c.opening),
          decimalMoney(c.budget),
          c.icon,
          c.openingDate.toIso8601String(),
          '',
          '',
          '',
          '',
        ]);
      }
      for (final e in data.entries.where(
        (e) => switch (kind) {
          CardKind.income => e.kind == EntryKind.income,
          CardKind.wallet => e.kind == EntryKind.transfer,
          CardKind.expense => e.kind == EntryKind.expense,
        },
      )) {
        rows.add([
          sections[kind.index],
          'Операция',
          e.id,
          '',
          decimalMoney(e.amount),
          '',
          '',
          e.date.toIso8601String(),
          e.walletId,
          e.targetId,
          e.kind.name,
          e.note,
        ]);
      }
    }
    return '\uFEFF${rows.map((r) => r.map(_escape).join(';')).join('\r\n')}\r\n';
  }

  String template({bool empty = false}) =>
      '\uFEFFДата;Доход: Зарплата;Доход: Фриланс;Кошелек: Наличные;Кошелек: Карта;Расход: Продукты;Расход: Такси\r\n${DateTime.now().toIso8601String().substring(0, 10)};${empty ? '0;0;0;0;0;0' : '80000;15000;5000;42000;12500;2300'}\r\n';

  FinanceData parse(String input) {
    if (utf8.encode(input).length > 5 * 1024 * 1024) {
      throw const FormatException('Максимальный размер CSV — 5 МБ');
    }
    final rows = _decode(input.replaceFirst('\uFEFF', ''));
    if (rows.isEmpty) {
      throw const FormatException(
        'CSV должен содержать заголовки и хотя бы одну строку',
      );
    }
    final head = rows.first.map((s) => s.trim()).toList();
    if (head.toSet().length != head.length) {
      throw const FormatException('Повторяющиеся названия столбцов');
    }
    for (var i = 1; i < rows.length; i++) {
      if (rows[i].length != head.length) {
        throw FormatException(
          'Строка ${i + 1}: число значений не совпадает с заголовками',
        );
      }
    }
    final data = head.contains('Раздел')
        ? _normalized(head, rows.skip(1).toList())
        : _wide(head, rows.skip(1).toList());
    if (data.cards.isEmpty && !head.contains('Раздел')) {
      throw const FormatException('В файле нет карточек');
    }
    data.validate();
    return data;
  }

  FinanceData _normalized(List<String> head, List<List<String>> rows) {
    if (!headers.every(head.contains)) {
      throw const FormatException(
        'Отсутствуют обязательные столбцы резервной копии',
      );
    }
    final cards = <MoneyCard>[];
    final entries = <MoneyEntry>[];
    for (var i = 0; i < rows.length; i++) {
      String get(String key) => rows[i][head.indexOf(key)];
      try {
        final section = sections.indexOf(get('Раздел'));
        if (section < 0) {
          throw const FormatException('Неизвестный раздел');
        }
        if (get('Запись') == 'Карточка') {
          cards.add(
            MoneyCard(
              id: get('ID'),
              name: get('Название').trim(),
              kind: CardKind.values[section],
              opening: parseMoney(get('Сумма')),
              budget: parseMoney(get('Лимит')),
              icon: get('Иконка'),
              openingDate: parseFinanceDate(get('Дата')),
            ),
          );
        } else if (get('Запись') == 'Операция') {
          final kind = EntryKind.values.byName(get('Тип'));
          final expected = switch (kind) {
            EntryKind.income => 0,
            EntryKind.transfer => 1,
            EntryKind.expense => 2,
          };
          if (section != expected) {
            throw const FormatException(
              'Тип операции не соответствует разделу',
            );
          }
          entries.add(
            MoneyEntry(
              id: get('ID'),
              kind: kind,
              walletId: get('Кошелек'),
              targetId: get('Категория'),
              amount: parseMoney(get('Сумма')),
              date: parseFinanceDate(get('Дата')),
              note: get('Комментарий'),
            ),
          );
        } else {
          throw const FormatException('Неизвестный тип записи');
        }
      } on Object catch (e) {
        throw FormatException('Строка ${i + 2}: $e');
      }
    }
    return FinanceData(cards: cards, entries: entries);
  }

  /// Wide CSV is a snapshot, not transactions: one row, arbitrary named columns.
  FinanceData _wide(List<String> head, List<List<String>> rows) {
    if (rows.length != 1) {
      throw const FormatException(
        'Шаблон с именами в колонках — снимок остатков. Оставьте одну строку данных. Для истории используйте формат резервной копии.',
      );
    }
    final dateIndex = head.indexOf('Дата');
    final date = dateIndex < 0
        ? DateTime.now()
        : parseFinanceDate(rows[0][dateIndex]);
    final cards = <MoneyCard>[];
    for (var i = 0; i < head.length; i++) {
      if (head[i] == 'Дата') {
        continue;
      }
      final match = RegExp(
        r'^(Доход|Кошелек|Кошелёк|Расход)\s*:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(head[i]);
      if (match == null) {
        throw FormatException(
          'Неизвестный столбец «${head[i]}». Пример: Расход: Продукты',
        );
      }
      final prefix = match[1]!.toLowerCase();
      final kind = prefix == 'доход'
          ? CardKind.income
          : prefix == 'расход'
          ? CardKind.expense
          : CardKind.wallet;
      cards.add(
        MoneyCard(
          id: newId(),
          name: match[2]!.trim(),
          kind: kind,
          opening: rows[0][i].trim().isEmpty ? 0 : parseMoney(rows[0][i]),
          openingDate: date,
          icon: kind == CardKind.wallet
              ? 'wallet'
              : kind == CardKind.income
              ? 'coins'
              : 'bag',
        ),
      );
    }
    return FinanceData(cards: cards, entries: []);
  }

  static String _escape(String s) => '"${s.replaceAll('"', '""')}"';
  static String _separator(String input) {
    var inQuotes = false;
    var semicolons = 0;
    var commas = 0;
    var hasHeader = false;
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if (ch.trim().isNotEmpty) hasHeader = true;
      if (ch == '"') {
        if (inQuotes && i + 1 < input.length && input[i + 1] == '"') {
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (!inQuotes) {
        if (ch == ';') semicolons++;
        if (ch == ',') commas++;
        if (ch == '\n' || ch == '\r') {
          if (hasHeader) break;
        }
      }
    }
    return semicolons >= commas ? ';' : ',';
  }

  static List<List<String>> _decode(String input) {
    final separator = _separator(input);
    final result = <List<String>>[];
    var row = <String>[];
    var cell = StringBuffer();
    var quoted = false;
    var closedQuote = false;
    void finishCell() {
      row.add(cell.toString());
      cell = StringBuffer();
      closedQuote = false;
    }

    void finishRow() {
      finishCell();
      if (row.any((s) => s.trim().isNotEmpty)) {
        result.add(row);
      }
      row = [];
    }

    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if (quoted) {
        if (ch == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            quoted = false;
            closedQuote = true;
          }
        } else {
          cell.write(ch);
        }
      } else if (ch == separator) {
        finishCell();
      } else if (ch == '\n' || ch == '\r') {
        if (ch == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
          i++;
        }
        finishRow();
      } else if (ch == '"' && cell.isEmpty && !closedQuote) {
        quoted = true;
      } else {
        if (closedQuote || ch == '"') {
          throw const FormatException('Некорректные кавычки в CSV');
        }
        cell.write(ch);
      }
    }
    if (quoted) {
      throw const FormatException('Незакрытая кавычка в CSV');
    }
    if (cell.isNotEmpty || row.isNotEmpty || closedQuote) {
      finishRow();
    }
    return result;
  }
}
