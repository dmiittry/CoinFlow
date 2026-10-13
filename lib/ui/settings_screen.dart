import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../application/app_controller.dart';
import '../data/csv_service.dart';
import '../domain/models.dart';
import 'style.dart';

class SettingsScreen extends StatefulWidget {
  final AppController controller;
  const SettingsScreen({super.key, required this.controller});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool working = false;
  final csv = CsvService();
  Future<void> saveFile(
    bool template, {
    bool empty = true,
    bool full = false,
  }) async {
    if (working || widget.controller.busy) return;
    setState(() => working = true);
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: template ? 'Сохранить шаблон' : 'Экспорт базы данных',
        fileName: template
            ? 'coinflow_${full
                  ? 'full'
                  : empty
                  ? 'empty'
                  : 'example'}_template.csv'
            : 'coinflow_backup_${DateTime.now().toIso8601String().substring(0, 10)}.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: Uint8List.fromList(
          utf8.encode(
            template
                ? (full
                      ? csv.export(csv.parse(csv.template(empty: true)))
                      : csv.template(empty: empty))
                : csv.export(widget.controller.data),
          ),
        ),
      );
      if (mounted && (path != null || kIsWeb)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb ? 'CSV передан браузеру для скачивания' : 'CSV сохранён',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => working = false);
      }
    }
  }

  Future<void> importFile() async {
    if (working || widget.controller.busy) return;
    final before = widget.controller.data;
    setState(() => working = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null) {
        return;
      }
      final file = result.files.single;
      if (file.size > 5 * 1024 * 1024) {
        throw const FormatException('Файл больше 5 МБ');
      }
      if (file.bytes == null) {
        throw const FormatException('Не удалось прочитать файл');
      }
      String text;
      try {
        text = utf8.decode(file.bytes!);
      } on FormatException {
        throw const FormatException(
          'Неизвестная кодировка. Сохраните CSV в UTF-8.',
        );
      }
      final next = csv.parse(text);
      if (!mounted) {
        return;
      }
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Импорт базы данных'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                for (final kind in CardKind.values)
                  Text(
                    '${CsvService.sections[kind.index]}: ${next.cards.where((c) => c.kind == kind).length} карточек',
                  ),
                Text('Операций: ${next.entries.length}'),
                const SizedBox(height: 16),
                Text(
                  next.cards.map((c) => c.name).join(' · '),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Текущая база будет полностью заменена. Перед импортом можно сохранить резервную копию через «Экспорт CSV».',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Заменить и импортировать'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) {
        return;
      }
      if (!identical(before, widget.controller.data)) {
        throw StateError(
          'За время выбора файла база изменилась. Повторите импорт.',
        );
      }
      await widget.controller.replace(next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Данные импортированы. Карточки созданы.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => working = false);
      }
    }
  }

  Future<void> chooseTemplate() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Выберите шаблон'),
        children: [
          for (final item in {
            'empty': 'Пустые остатки',
            'example': 'Пример с суммами',
            'full': 'Формат полной копии',
          }.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, item.key),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(item.value),
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    await saveFile(true, empty: choice != 'example', full: choice == 'full');
  }

  Future<void> replaceData({required bool restore}) async {
    if (working || widget.controller.busy) return;
    final previous = widget.controller.previousData;
    if (restore && previous == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          restore ? 'Восстановить предыдущую версию?' : 'Начать с пустой базы?',
        ),
        content: Text(
          restore
              ? 'Текущие карточки и операции будут заменены предыдущей сохранённой версией. Сначала можно экспортировать текущие данные в CSV.'
              : 'Все карточки и операции будут убраны из текущей базы. Перед началом сохраните CSV. Предыдущая версия останется для восстановления до следующего изменения.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(restore ? 'Восстановить' : 'Очистить базу'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => working = true);
    try {
      if (restore) {
        await widget.controller.replace(previous!);
      } else {
        await widget.controller.clearData();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              restore
                  ? 'Предыдущая версия восстановлена'
                  : 'Можно начать свой учёт с нуля',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: mint,
                child: Icon(Icons.person_outline, color: Colors.white),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Демо-профиль',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'demo · Локальное хранилище',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.verified_user_outlined, color: mint),
            ],
          ),
        ),
        const SectionHeading('Оформление', ''),
        for (final mode in ThemeMode.values)
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            tileColor: c.themeMode == mode ? mint.withValues(alpha: .09) : null,
            leading: Icon(switch (mode) {
              ThemeMode.system => Icons.brightness_auto_outlined,
              ThemeMode.light => Icons.light_mode_outlined,
              ThemeMode.dark => Icons.dark_mode_outlined,
            }),
            title: Text(switch (mode) {
              ThemeMode.system => 'Как на устройстве',
              ThemeMode.light => 'Светлая тема',
              ThemeMode.dark => 'Темная тема',
            }),
            trailing: c.themeMode == mode
                ? const Icon(Icons.check_circle, color: mint)
                : null,
            onTap: c.preferencesBusy
                ? null
                : () async {
                    try {
                      await c.setTheme(mode);
                    } catch (e) {
                      if (context.mounted) {
                        showError(context, e);
                      }
                    }
                  },
          ),
        const SizedBox(height: 16),
        const SectionHeading('Данные и резервные копии', ''),
        Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.file_upload_outlined, color: mint),
                title: const Text('Экспорт CSV'),
                subtitle: const Text('Все карточки и история операций'),
                trailing: const Icon(Icons.chevron_right),
                onTap: working || c.busy ? null : () => saveFile(false),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.file_download_outlined, color: cyan),
                title: const Text('Импорт CSV'),
                subtitle: const Text('Проверка файла и создание карточек'),
                trailing: const Icon(Icons.chevron_right),
                onTap: working || c.busy ? null : importFile,
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(
                  Icons.description_outlined,
                  color: Color(0xFFCAA000),
                ),
                title: const Text('Скачать шаблон'),
                subtitle: const Text('Доходы · Кошельки · Расходы'),
                trailing: const Icon(Icons.chevron_right),
                onTap: working || c.busy ? null : chooseTemplate,
              ),
            ],
          ),
        ),
        if (working)
          const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(),
          ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'В шаблоне одна строка остатков. Добавляйте колонки «Доход: Название», «Кошелек: Название», «Расход: Название» — карточки появятся автоматически.\n\nПолный экспорт сохраняет также историю и лимиты. Формат: UTF-8, разделитель «;».',
            style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.6),
          ),
        ),
        const SectionHeading('Приложение', ''),
        ListTile(
          leading: const Icon(Icons.restore),
          title: const Text('Восстановить предыдущую версию'),
          subtitle: const Text('Вернуть базу до последнего изменения'),
          enabled: !working && !c.busy && c.previousData != null,
          onTap: () => replaceData(restore: true),
        ),
        ListTile(
          leading: const Icon(Icons.restart_alt),
          title: const Text('Начать с пустой базы'),
          subtitle: const Text('Убрать демонстрационные или текущие данные'),
          enabled: !working && !c.busy,
          onTap: () => replaceData(restore: false),
        ),
        const ListTile(
          leading: Icon(Icons.cloud_off_outlined),
          title: Text('Работает без интернета'),
          subtitle: Text('Синхронизация пока не подключена'),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Выйти из профиля'),
          subtitle: const Text('Данные останутся на устройстве'),
          onTap: working || c.busy || c.preferencesBusy
              ? null
              : () async {
                  try {
                    await c.logout();
                  } catch (error) {
                    if (context.mounted) showError(context, error);
                  }
                },
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            'CoinFlow 1.0.0 · Сделано для ваших планов',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
