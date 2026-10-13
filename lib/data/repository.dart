import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models.dart';
import 'demo_data.dart';

/// UI depends on this boundary. A future Django implementation uses the same DTOs.
abstract interface class FinanceRepository {
  Future<FinanceData> load();
  Future<void> save(FinanceData data);
}

class LocalFinanceRepository implements FinanceRepository {
  final SharedPreferences preferences;
  LocalFinanceRepository(this.preferences);
  static const key = 'coin_flow_database_v1';
  static const backupKey = 'coin_flow_database_previous_v1';
  String? recoveryNotice;
  FinanceData? get previousData {
    final raw = preferences.getString(backupKey);
    if (raw == null) return null;
    try {
      return FinanceData.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<FinanceData> load() async {
    await preferences.reload();
    recoveryNotice = null;
    final raw = preferences.getString(key);
    if (raw != null) {
      try {
        return FinanceData.fromJson(jsonDecode(raw));
      } catch (_) {
        final backup = preferences.getString(backupKey);
        if (backup == null) rethrow;
        final recovered = FinanceData.fromJson(jsonDecode(backup));
        recoveryNotice =
            'Основная база не читается. Загружена предыдущая '
            'сохранённая версия: последние изменения могут отсутствовать. '
            'Проверьте операции и экспортируйте CSV.';
        return recovered;
      }
    }
    final backup = preferences.getString(backupKey);
    if (backup != null) {
      final recovered = FinanceData.fromJson(jsonDecode(backup));
      recoveryNotice =
          'Основная база отсутствует. Загружена предыдущая '
          'сохранённая версия. Проверьте операции и экспортируйте CSV.';
      return recovered;
    }
    final data = demoData();
    await save(data);
    return data;
  }

  @override
  Future<void> save(FinanceData data) async {
    data.validate();
    // Refresh before using the cached value as a backup, including after failures.
    await preferences.reload();
    try {
      await _save(data);
    } catch (_) {
      try {
        await preferences.reload();
      } catch (_) {
        // Keep the original write error. The next save must reload successfully.
      }
      rethrow;
    }
  }

  Future<void> _save(FinanceData data) async {
    final previous = preferences.getString(key);
    if (previous != null) {
      var valid = false;
      try {
        FinanceData.fromJson(jsonDecode(previous));
        valid = true;
      } catch (_) {
        // Preserve the last valid backup when repairing a corrupt primary.
      }
      if (valid && !await preferences.setString(backupKey, previous)) {
        throw StateError('Не удалось сохранить предыдущую версию базы');
      }
    }
    final success = await preferences.setString(key, jsonEncode(data.toJson()));
    if (!success) {
      throw StateError('Не удалось сохранить данные на устройстве');
    }
  }
}
