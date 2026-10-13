import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/repository.dart';
import '../domain/models.dart';

class AppController extends ChangeNotifier {
  final FinanceRepository repository;
  final SharedPreferences preferences;
  late FinanceData data;
  bool signedIn = false;
  bool busy = false;
  bool preferencesBusy = false;
  String? recoveryNotice;
  ThemeMode themeMode = ThemeMode.system;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  AppController(this.repository, this.preferences);
  Future<void> initialize() async {
    data = await repository.load();
    if (repository is LocalFinanceRepository) {
      recoveryNotice = (repository as LocalFinanceRepository).recoveryNotice;
    }
    signedIn = preferences.getBool('demo_session') ?? false;
    themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == preferences.getString('theme'),
      orElse: () => ThemeMode.system,
    );
  }

  Future<bool> login(String login, String password) async {
    if (login.trim() != 'demo' || password != 'demo123') {
      return false;
    }
    await _savePreference(() async {
      if (!await preferences.setBool('demo_session', true)) {
        throw StateError('Не удалось сохранить вход');
      }
      signedIn = true;
    });
    return true;
  }

  Future<void> logout() async {
    await _savePreference(() async {
      if (!await preferences.remove('demo_session')) {
        throw StateError('Не удалось сохранить выход. Повторите попытку.');
      }
      signedIn = false;
    });
  }

  Future<void> setTheme(ThemeMode mode) async {
    await _savePreference(() async {
      if (!await preferences.setString('theme', mode.name)) {
        throw StateError('Не удалось сохранить тему');
      }
      themeMode = mode;
    });
  }

  Future<void> _savePreference(Future<void> Function() action) async {
    if (preferencesBusy) throw StateError('Дождитесь сохранения настроек');
    preferencesBusy = true;
    notifyListeners();
    try {
      await action();
    } catch (_) {
      try {
        await preferences.reload();
      } catch (_) {
        // Retain the write error; visible settings only change after success.
      }
      rethrow;
    } finally {
      preferencesBusy = false;
      notifyListeners();
    }
  }

  void moveMonth(int delta) {
    selectMonth(DateTime(month.year, month.month + delta));
  }

  void selectMonth(DateTime value) {
    if (value.year < 1 || value.year > 9999) return;
    month = DateTime(value.year, value.month);
    notifyListeners();
  }

  Future<void> replace(FinanceData next) async {
    if (busy) {
      throw StateError('Дождитесь сохранения');
    }
    next.validate();
    busy = true;
    notifyListeners();
    try {
      await repository.save(next);
      data = next;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> saveCard(MoneyCard card) => replace(
    FinanceData(
      cards: data.cards.any((c) => c.id == card.id)
          ? data.cards.map((c) => c.id == card.id ? card : c).toList()
          : [...data.cards, card],
      entries: data.entries,
    ),
  );
  Future<void> deleteCard(MoneyCard card) async {
    if (data.entries.any(
      (e) => e.walletId == card.id || e.targetId == card.id,
    )) {
      throw StateError(
        'У карточки есть операции. Сначала удалите связанные операции в истории.',
      );
    }
    await replace(
      FinanceData(
        cards: data.cards.where((c) => c.id != card.id).toList(),
        entries: data.entries,
      ),
    );
  }

  Future<void> addEntry(MoneyEntry entry) => replace(
    FinanceData(cards: data.cards, entries: [...data.entries, entry]),
  );
  Future<void> updateEntry(MoneyEntry entry) async {
    if (!data.entries.any((e) => e.id == entry.id)) {
      throw StateError('Операция уже удалена');
    }
    await replace(
      FinanceData(
        cards: data.cards,
        entries: [
          for (final current in data.entries)
            current.id == entry.id ? entry : current,
        ],
      ),
    );
  }

  Future<void> clearData() => replace(FinanceData(cards: [], entries: []));

  FinanceData? get previousData => repository is LocalFinanceRepository
      ? (repository as LocalFinanceRepository).previousData
      : null;
  Future<void> deleteEntry(MoneyEntry entry) => replace(
    FinanceData(
      cards: data.cards,
      entries: data.entries.where((e) => e.id != entry.id).toList(),
    ),
  );
}
