import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coin_flow/application/app_controller.dart';
import 'package:coin_flow/data/csv_service.dart';
import 'package:coin_flow/data/repository.dart';
import 'package:coin_flow/domain/models.dart';
import 'package:coin_flow/main.dart';
import 'package:coin_flow/ui/editors.dart';
import 'package:coin_flow/ui/home_screen.dart';
import 'package:coin_flow/ui/style.dart';

class TestFilePicker extends FilePicker {
  FilePickerResult? selected;
  Object? failure;
  Uint8List? saved;
  String? savedName;
  int saves = 0;
  bool cancelSave = false;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    if (failure != null) throw failure!;
    return selected;
  }

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    if (failure != null) throw failure!;
    saves++;
    saved = bytes;
    savedName = fileName;
    return cancelSave ? null : fileName;
  }

  void csv(String value, {int? size}) {
    final bytes = Uint8List.fromList(utf8.encode(value));
    selected = FilePickerResult([
      PlatformFile(name: 'test.csv', size: size ?? bytes.length, bytes: bytes),
    ]);
  }
}

class ControlledRepository implements FinanceRepository {
  Completer<void>? pending;
  bool fail = false;
  int saves = 0;
  @override
  Future<FinanceData> load() async => smallData();
  @override
  Future<void> save(FinanceData data) async {
    saves++;
    if (pending != null) await pending!.future;
    if (fail) throw StateError('Ошибка записи на устройство');
  }
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    for (final delta in [300.0, -300.0]) {
      for (var i = 0; i < 25 && finder.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).last, Offset(0, -delta));
        await tester.pump();
      }
      if (finder.evaluate().isNotEmpty) break;
    }
  }
  final button = find.ancestor(of: finder, matching: find.byType(IconButton));
  final target = button.evaluate().length == 1 ? button : finder;
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pump();
  await tester.tap(target, warnIfMissed: true);
  await tester.pump(const Duration(milliseconds: 350));
  if (find.byType(LinearProgressIndicator).evaluate().isEmpty &&
      find.byType(CircularProgressIndicator).evaluate().isEmpty) {
    await tester.pumpAndSettle();
  }
}

Future<AppController> app(
  WidgetTester tester, {
  bool signedIn = true,
  FinanceData? data,
  Size size = const Size(390, 844),
  double scale = 1,
  FinanceRepository? repository,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final prefs = await SharedPreferences.getInstance();
  final c = AppController(repository ?? LocalFinanceRepository(prefs), prefs);
  await c.initialize();
  if (data != null) await c.replace(data);
  if (signedIn) await c.login('demo', 'demo123');
  await tester.pumpWidget(CoinFlowApp(controller: c));
  await tester.pumpAndSettle();
  return c;
}

FinanceData smallData() => FinanceData(
  cards: [
    MoneyCard(id: 'salary', name: 'Работа', kind: CardKind.income),
    MoneyCard(
      id: 'cash',
      name: 'Наличные',
      kind: CardKind.wallet,
      opening: 100000,
    ),
    MoneyCard(
      id: 'bank',
      name: 'Карта',
      kind: CardKind.wallet,
      opening: 500000,
    ),
    MoneyCard(
      id: 'food',
      name: 'Продукты',
      kind: CardKind.expense,
      budget: 100000,
    ),
  ],
  entries: [],
);

void main() {
  late TestFilePicker files;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ru');
    files = TestFilePicker();
    FilePicker.platform = files;
  });

  testWidgets('login visibility, invalid credentials and keyboard submit', (
    tester,
  ) async {
    final c = await app(tester, signedIn: false);
    await tap(tester, find.byTooltip('Показать пароль'));
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
      isFalse,
    );
    await tap(tester, find.byTooltip('Скрыть пароль'));
    await tap(tester, find.text('Войти'));
    expect(find.text('Неверный логин или пароль'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'demo');
    await tester.enterText(find.byType(TextField).at(1), 'demo123');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(c.signedIn, isTrue);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets(
    'start from empty database and create wallet/category inside operation',
    (tester) async {
      final c = await app(
        tester,
        data: FinanceData(cards: [], entries: []),
      );
      await tap(tester, find.text('Операция'));
      await tester.enterText(
        find.byKey(const ValueKey('entry-amount')),
        '250,50',
      );
      await tap(tester, find.text('Сохранить операцию'));
      expect(
        find.text('Сначала добавьте кошелек и нужную категорию'),
        findsOneWidget,
      );
      await tap(tester, find.text('Создать кошелек'));
      await tester.enterText(
        find.byKey(const ValueKey('card-name')),
        'Моя карта',
      );
      await tester.enterText(
        find.byKey(const ValueKey('card-opening')),
        '1000',
      );
      await tap(tester, find.text('Сохранить карточку'));
      await tap(tester, find.text('Создать категорию'));
      await tester.enterText(find.byKey(const ValueKey('card-name')), 'Еда');
      await tap(tester, find.byKey(const ValueKey('icon-groceries')));
      await tap(tester, find.text('Сохранить карточку'));
      await tap(tester, find.text('Сохранить операцию'));
      expect(c.data.entries.single.amount, 25050);
      expect(c.data.value(c.data.cards.first, c.month), 74950);
      expect(c.data.cards.last.icon, 'groceries');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('income, expense, transfer and amount validation through form', (
    tester,
  ) async {
    final c = await app(tester, data: smallData());
    for (final pair in {
      'Доход': EntryKind.income,
      'Расход': EntryKind.expense,
      'Перевод': EntryKind.transfer,
    }.entries) {
      await tap(tester, find.text('Операция'));
      await tap(tester, find.widgetWithText(ChoiceChip, pair.key));
      for (final amount in ['0', '-1', '1.001']) {
        await tester.enterText(
          find.byKey(const ValueKey('entry-amount')),
          amount,
        );
        await tap(tester, find.text('Сохранить операцию'));
        expect(find.byType(EntryEditor), findsOneWidget);
      }
      await tester.enterText(
        find.byKey(const ValueKey('entry-amount')),
        '10,25',
      );
      await tester.enterText(
        find.byKey(const ValueKey('entry-note')),
        pair.key,
      );
      await tap(tester, find.text('Сохранить операцию'));
      expect(c.data.entries.last.kind, pair.value);
    }
    expect(c.data.value(c.data.card('cash'), c.month), 98975);
    expect(c.data.value(c.data.card('bank'), c.month), 501025);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'card creation edit duplicate validation delete cancel and linked deletion',
    (tester) async {
      final c = await app(tester, data: smallData());
      await tap(tester, find.byTooltip('Добавить карточку: Кошельки'));
      await tap(tester, find.text('Сохранить карточку'));
      expect(find.text('Введите название'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('card-name')), 'Запас');
      await tester.enterText(
        find.byKey(const ValueKey('card-opening')),
        '-10,50',
      );
      await tap(tester, find.byKey(const ValueKey('icon-bank')));
      await tap(tester, find.text('Сохранить карточку'));
      await tap(tester, find.byTooltip('Изменить карточку: Запас'));
      await tester.enterText(find.byKey(const ValueKey('card-name')), 'Карта');
      await tap(tester, find.text('Сохранить карточку'));
      expect(find.byType(CardEditor), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('card-name')), 'Резерв');
      await tap(tester, find.text('Сохранить карточку'));
      expect(c.data.cards.last.name, 'Резерв');
      await tap(tester, find.byTooltip('Изменить карточку: Резерв'));
      await tap(tester, find.text('Удалить карточку'));
      await tap(tester, find.text('Отмена'));
      expect(c.data.cards.last.name, 'Резерв');
      await tap(tester, find.text('Удалить карточку'));
      await tap(tester, find.widgetWithText(FilledButton, 'Удалить'));
      expect(c.data.cards.length, 4);
      await c.addEntry(
        MoneyEntry(
          id: 'linked',
          kind: EntryKind.expense,
          walletId: 'cash',
          targetId: 'food',
          amount: 100,
          date: DateTime.now(),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.byTooltip('Изменить карточку: Наличные'));
      await tap(tester, find.text('Удалить карточку'));
      await tap(tester, find.widgetWithText(FilledButton, 'Удалить'));
      expect(find.textContaining('У карточки есть операции.'), findsOneWidget);
      await tap(tester, find.byTooltip('Закрыть'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selected month, category opening date and return to current month',
    (tester) async {
      final c = await app(tester, data: smallData());
      c.selectMonth(DateTime(2020, 2));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Операция'));
      await tester.enterText(find.byKey(const ValueKey('entry-amount')), '10');
      await tap(tester, find.text('Сохранить операцию'));
      expect(c.data.entries.single.date.month, 2);
      expect(c.data.entries.single.date.year, 2020);
      await tap(tester, find.byTooltip('Добавить карточку: Доходы'));
      await tester.enterText(find.byKey(const ValueKey('card-name')), 'Премия');
      await tester.enterText(find.byKey(const ValueKey('card-opening')), '50');
      await tap(tester, find.text('Сохранить карточку'));
      expect(c.data.cards.last.openingDate, DateTime(2020, 2));
      expect(c.data.value(c.data.cards.last, c.month), 5000);
      await tap(tester, find.byTooltip('Текущий месяц'));
      expect(sameMonth(c.month, DateTime.now()), isTrue);
      await tap(tester, find.byTooltip('Предыдущий месяц'));
      await tap(tester, find.byTooltip('Следующий месяц'));
      expect(sameMonth(c.month, DateTime.now()), isTrue);
    },
  );

  testWidgets('history edit, search clear, all dates, filters, delete undo', (
    tester,
  ) async {
    final c = await app(tester, data: smallData());
    await c.addEntry(
      MoneyEntry(
        id: 'old',
        kind: EntryKind.income,
        walletId: 'bank',
        targetId: 'salary',
        amount: 2500,
        date: DateTime(1999, 1, 1),
        note: 'old',
      ),
    );
    await c.addEntry(
      MoneyEntry(
        id: 'new',
        kind: EntryKind.expense,
        walletId: 'cash',
        targetId: 'food',
        amount: 500,
        date: DateTime.now(),
        note: 'магазин',
      ),
    );
    await tap(tester, find.text('Операции'));
    await tester.enterText(find.byType(TextField), ' несуществующее ');
    await tester.pumpAndSettle();
    expect(find.text('Ничего не найдено'), findsOneWidget);
    await tap(tester, find.byTooltip('Очистить поиск'));
    await tap(tester, find.widgetWithText(ChoiceChip, 'Доходы'));
    await tap(tester, find.widgetWithText(FilterChip, 'Все даты'));
    expect(find.text('Работа'), findsOneWidget);
    await tap(tester, find.text('Работа'));
    await tester.enterText(find.byKey(const ValueKey('entry-amount')), '40');
    await tap(tester, find.text('1 января 1999'));
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tap(tester, find.text('Отмена'));
    await tap(tester, find.text('Сохранить операцию'));
    expect(c.data.entries.first.amount, 4000);
    expect(c.data.entries.first.id, 'old');
    await tap(tester, find.text('Сбросить фильтры'));
    await tap(tester, find.byTooltip('Действия').first);
    await tap(tester, find.widgetWithText(PopupMenuItem<String>, 'Удалить'));
    await tap(tester, find.text('Отмена'));
    expect(c.data.entries.length, 2);
    await tap(tester, find.byTooltip('Действия').first);
    await tap(tester, find.widgetWithText(PopupMenuItem<String>, 'Удалить'));
    await tap(tester, find.widgetWithText(FilledButton, 'Удалить'));
    expect(c.data.entries.length, 1);
    await tap(tester, find.text('Отменить'));
    expect(c.data.entries.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet drag starts transfer; vertical swipe remains scrolling', (
    tester,
  ) async {
    await app(tester, data: smallData());
    final source = find.byWidgetPredicate(
      (widget) => widget is MoneyTile && widget.card.id == 'cash',
    );
    final target = find.byWidgetPredicate(
      (widget) => widget is MoneyTile && widget.card.id == 'bank',
    );
    await tester.ensureVisible(source);
    final gesture = await tester.startGesture(tester.getCenter(source));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(EntryEditor), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Перевод'))
          .selected,
      isTrue,
    );
    await tap(tester, find.byTooltip('Закрыть'));
    await tester.drag(source, const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(find.byType(EntryEditor), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings export and all three downloadable templates', (
    tester,
  ) async {
    final c = await app(tester);
    await tap(tester, find.text('Настройки'));
    await tap(tester, find.text('Экспорт CSV'));
    expect(
      CsvService().parse(utf8.decode(files.saved!)).toJson(),
      c.data.toJson(),
    );
    for (final label in [
      'Пустые остатки',
      'Пример с суммами',
      'Формат полной копии',
    ]) {
      await tap(tester, find.text('Скачать шаблон'));
      await tap(tester, find.text(label));
      final result = CsvService().parse(utf8.decode(files.saved!));
      expect(result.cards.length, 6);
      expect(
        result.cards.any((card) => card.opening != 0),
        label == 'Пример с суммами',
      );
    }
    expect(files.saves, 4);
  });

  testWidgets(
    'CSV cancellation, malformed input, size check, confirm and recovery',
    (tester) async {
      final c = await app(tester);
      final before = c.data.toJson();
      await tap(tester, find.text('Настройки'));
      await tap(tester, find.text('Импорт CSV')); // native picker cancellation
      expect(c.data.toJson(), before);
      files.csv('Кошелек: Банк\nwrong');
      await tap(tester, find.text('Импорт CSV'));
      expect(c.data.toJson(), before);
      files.csv(CsvService().template(empty: true), size: 6 * 1024 * 1024);
      await tap(tester, find.text('Импорт CSV'));
      expect(c.data.toJson(), before);
      files.csv(CsvService().template(empty: true));
      await tap(tester, find.text('Импорт CSV'));
      await tap(tester, find.text('Отмена'));
      expect(c.data.toJson(), before);
      await tap(tester, find.text('Импорт CSV'));
      await tap(tester, find.text('Заменить и импортировать'));
      expect(c.data.entries, isEmpty);
      expect(c.data.cards.length, 6);
      await tap(tester, find.text('Восстановить предыдущую версию'));
      await tap(tester, find.text('Восстановить'));
      expect(c.data.toJson(), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CoinKeeper preview and cancel leave storage unchanged; confirm imports history',
    (tester) async {
      final c = await app(tester);
      final original = c.data.toJson();
      final stored = c.preferences.getString(LocalFinanceRepository.key);
      files.csv(
        'Date,Type,From,To,Tags,Amount,Currency,Amount converted,Currency of conversion,Recurrence,Note\n'
        '01.10.2026,income,Работа,Банк,,1000,RUB,,,false,Тестовый доход\n'
        '02.10.2026,expense,Банк,Еда,,20.50,RUB,,,false,Тестовый расход\n'
        '03.10.2026,transfer,Банк,Наличные,,100,RUB,,,false,Тестовый перевод',
      );
      await tap(tester, find.text('Настройки'));
      await tap(tester, find.text('Импорт CSV'));
      expect(find.text('Формат: CoinKeeper'), findsOneWidget);
      expect(find.text('Операций: 3'), findsOneWidget);
      expect(
        find.textContaining('нет начальных остатков и лимитов'),
        findsOneWidget,
      );
      expect(c.data.toJson(), original);
      expect(c.preferences.getString(LocalFinanceRepository.key), stored);
      await tap(tester, find.text('Отмена'));
      expect(c.preferences.getString(LocalFinanceRepository.key), stored);
      await tap(tester, find.text('Импорт CSV'));
      await tap(tester, find.text('Заменить и импортировать'));
      expect(c.data.entries.length, 3);
      expect(c.data.cards.length, 4);
      expect(c.data.total(CardKind.wallet, c.month), 97950);
      final restored = await LocalFinanceRepository(c.preferences).load();
      expect(restored.toJson(), c.data.toJson());
      expect(c.previousData!.toJson(), original);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invalid CoinKeeper row never offers to import a partial history',
    (tester) async {
      final c = await app(tester);
      final original = c.data.toJson();
      files.csv(
        'Date,Type,From,To,Amount,Currency\n'
        '01.10.2026,expense,Банк,Еда,10,RUB\n'
        '31.02.2026,expense,Банк,Еда,10,RUB',
      );
      await tap(tester, find.text('Настройки'));
      await tap(tester, find.text('Импорт CSV'));
      expect(c.data.toJson(), original);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('Строка 3 CoinKeeper'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reset confirmation and every theme survive logout and restart', (
    tester,
  ) async {
    final c = await app(tester);
    await tap(tester, find.text('Настройки'));
    for (final item in {
      'Темная тема': ThemeMode.dark,
      'Светлая тема': ThemeMode.light,
      'Как на устройстве': ThemeMode.system,
    }.entries) {
      await tap(tester, find.text(item.key));
      expect(c.themeMode, item.value);
    }
    await tap(tester, find.text('Начать с пустой базы'));
    await tap(tester, find.text('Отмена'));
    expect(c.data.cards, isNotEmpty);
    await tap(tester, find.text('Начать с пустой базы'));
    await tap(tester, find.text('Очистить базу'));
    expect(c.data.cards, isEmpty);
    await tap(tester, find.text('Выйти из профиля'));
    expect(find.byType(HomeScreen), findsNothing);
    final reloaded = AppController(
      LocalFinanceRepository(c.preferences),
      c.preferences,
    );
    await reloaded.initialize();
    expect(reloaded.signedIn, isFalse);
    expect(reloaded.data.cards, isEmpty);
  });

  testWidgets('storage startup failure allows retry without deleting data', (
    tester,
  ) async {
    var calls = 0;
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      StartupScreen(
        loadController: () async {
          if (calls++ == 0) throw StateError('storage unavailable');
          final c = AppController(LocalFinanceRepository(prefs), prefs);
          await c.initialize();
          return c;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Повторить загрузку'), findsOneWidget);
    await tap(tester, find.text('Повторить загрузку'));
    expect(find.text('Войти'), findsOneWidget);
  });

  testWidgets(
    'slow saves block duplicate taps and dismissal; failures keep form input',
    (tester) async {
      final repo = ControlledRepository()..pending = Completer<void>();
      final c = await app(tester, repository: repo);
      await tap(tester, find.text('Операция'));
      await tester.enterText(
        find.byKey(const ValueKey('entry-amount')),
        '12,50',
      );
      final save = find.widgetWithText(FilledButton, 'Сохранить операцию');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.tap(save);
      await tester.pump();
      expect(repo.saves, 1);
      expect(c.data.entries, isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(EntryEditor), findsOneWidget);
      await tester.tapAt(const Offset(2, 20));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(EntryEditor), findsOneWidget);
      final sheet = find.byType(BottomSheet);
      await tester.dragFrom(
        tester.getTopLeft(sheet) + const Offset(195, 10),
        const Offset(0, 600),
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(EntryEditor), findsOneWidget);
      repo.pending!.complete();
      await tester.pumpAndSettle();
      expect(c.data.entries.length, 1);
      expect(find.byType(EntryEditor), findsNothing);
      repo.pending = null;
      repo.fail = true;
      await tap(tester, find.text('Операция'));
      await tester.enterText(find.byKey(const ValueKey('entry-amount')), '25');
      await tap(tester, find.text('Сохранить операцию'));
      expect(find.text('Ошибка записи на устройство'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
      expect(c.data.entries.length, 1);
      repo.fail = false;
      await tap(tester, find.text('Сохранить операцию'));
      expect(c.data.entries.length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'file dialog failures, invalid encoding, export and template cancellation',
    (tester) async {
      final c = await app(tester);
      final before = c.data.toJson();
      await tap(tester, find.text('Настройки'));
      files.cancelSave = true;
      await tap(tester, find.text('Экспорт CSV'));
      expect(find.text('CSV сохранён'), findsNothing);
      files.failure = StateError('Файл недоступен');
      await tap(tester, find.text('Импорт CSV'));
      expect(c.data.toJson(), before);
      expect(find.text('Файл недоступен'), findsOneWidget);
      files.failure = null;
      files.selected = FilePickerResult([
        PlatformFile(
          name: 'broken.csv',
          size: 2,
          bytes: Uint8List.fromList([0xff, 0xfe]),
        ),
      ]);
      await tap(tester, find.text('Импорт CSV'));
      expect(c.data.toJson(), before);
      expect(
        find.text('Неизвестная кодировка. Сохраните CSV в UTF-8.'),
        findsOneWidget,
      );
      final saves = files.saves;
      await tap(tester, find.text('Скачать шаблон'));
      await tap(tester, find.text('Отмена'));
      expect(files.saves, saves);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keyboard leaves operation and card save controls accessible', (
    tester,
  ) async {
    final c = await app(
      tester,
      data: smallData(),
      size: const Size(320, 740),
      scale: 1.5,
    );
    addTearDown(tester.view.resetViewInsets);
    await tap(tester, find.text('Операция'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.enterText(find.byKey(const ValueKey('entry-amount')), '10');
    await tester.pumpAndSettle();
    await tap(tester, find.text('Сохранить операцию'));
    expect(c.data.entries.length, 1);
    await tap(tester, find.byTooltip('Добавить карточку: Кошельки'));
    await tester.enterText(find.byKey(const ValueKey('card-name')), 'Копилка');
    await tester.pumpAndSettle();
    await tap(tester, find.text('Сохранить карточку'));
    expect(c.data.cards.last.name, 'Копилка');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'system theme follows device brightness while manual choice overrides it',
    (tester) async {
      final c = await app(tester);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(HomeScreen))).brightness,
        Brightness.dark,
      );
      await c.setTheme(ThemeMode.light);
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(HomeScreen))).brightness,
        Brightness.light,
      );
    },
  );

  testWidgets(
    'transfer wallet selection excludes itself and history matches both sides',
    (tester) async {
      final c = await app(tester, data: smallData());
      await tap(tester, find.text('Операция'));
      await tap(tester, find.widgetWithText(ChoiceChip, 'Перевод'));
      await tap(tester, find.byKey(const ValueKey('wallet-cash')));
      await tap(tester, find.text('Карта').last);
      final target = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const ValueKey('target-transfer-cash')),
      );
      expect(target.initialValue, 'cash');
      await tester.enterText(find.byKey(const ValueKey('entry-amount')), '100');
      await tap(tester, find.text('Сохранить операцию'));
      expect(c.data.entries.single.walletId, 'bank');
      expect(c.data.entries.single.targetId, 'cash');
      await c.saveCard(
        MoneyCard(id: 'unused', name: 'Резерв', kind: CardKind.wallet),
      );
      await tap(tester, find.text('Операции'));
      await tap(tester, find.widgetWithText(ChoiceChip, 'Переводы'));
      for (final name in ['Наличные', 'Карта', 'Резерв']) {
        await tap(tester, find.byType(DropdownButtonFormField<String>));
        await tap(tester, find.text(name).last);
        expect(
          find.text('Найдено операций: ${name == 'Резерв' ? 0 : 1}'),
          findsOneWidget,
        );
      }
      await tap(tester, find.text('Сбросить фильтры'));
      expect(find.text('Найдено операций: 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'income visibility and both category drag directions prefill correct cards',
    (tester) async {
      final c = await app(
        tester,
        data: smallData(),
        size: const Size(390, 1500),
      );
      Finder tile(String id) =>
          find.byWidgetPredicate((w) => w is MoneyTile && w.card.id == id);
      await tap(tester, find.byTooltip('Скрыть доходы'));
      expect(tile('salary'), findsNothing);
      await tap(tester, find.byTooltip('Показать доходы'));
      for (final ids in [
        ('salary', 'cash', EntryKind.income),
        ('bank', 'food', EntryKind.expense),
      ]) {
        final gesture = await tester.startGesture(
          tester.getCenter(tile(ids.$1)),
        );
        await tester.pump(const Duration(milliseconds: 700));
        await gesture.moveTo(tester.getCenter(tile(ids.$2)));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.byType(EntryEditor), findsOneWidget);
        await tester.enterText(find.byKey(const ValueKey('entry-amount')), '5');
        await tap(tester, find.text('Сохранить операцию'));
        expect(c.data.entries.last.kind, ids.$3);
        expect(
          c.data.entries.last.walletId,
          ids.$3 == EntryKind.income ? 'cash' : 'bank',
        );
        expect(
          c.data.entries.last.targetId,
          ids.$3 == EntryKind.income ? 'salary' : 'food',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'month calendar and category date, limits, icons can be changed',
    (tester) async {
      final c = await app(tester, data: smallData());
      final original = c.month;
      await tap(tester, find.text(monthName(c.month)));
      await tap(tester, find.byTooltip('Следующий месяц').last);
      await tap(tester, find.text('15').last);
      final ok = MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      ).okButtonLabel;
      await tap(tester, find.text(ok));
      expect(c.month, DateTime(original.year, original.month + 1));
      await tap(tester, find.byTooltip('Текущий месяц'));
      await tap(tester, find.byTooltip('Изменить карточку: Продукты'));
      await tester.enterText(find.byKey(const ValueKey('card-budget')), '-1');
      await tap(tester, find.text('Сохранить карточку'));
      expect(
        find.text('Отрицательный лимит или сумма категории'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('card-budget')),
        '1500,50',
      );
      await tap(tester, find.text('Дата начальной суммы'));
      await tap(tester, find.text('1').last);
      await tap(tester, find.text(ok));
      await tap(tester, find.byKey(const ValueKey('icon-bank')));
      await tap(tester, find.text('Сохранить карточку'));
      expect(c.data.card('food').budget, 150050);
      expect(c.data.card('food').openingDate.day, 1);
      expect(c.data.card('food').icon, 'bank');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recovery notice is readable and dismissible at large text size',
    (tester) async {
      final c = await app(tester, size: const Size(320, 740), scale: 2);
      await c.clearData();
      await c.preferences.setString(LocalFinanceRepository.key, '{broken');
      await c.initialize();
      c.selectMonth(DateTime.now());
      await tester.pumpAndSettle();
      expect(find.byType(MaterialBanner), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tap(tester, find.text('Понятно'));
      expect(find.byType(MaterialBanner), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 740),
    const Size(844, 390),
    const Size(1200, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'all screens and editors fit ${size.width}x${size.height} text $scale',
        (tester) async {
          await app(tester, size: size, scale: scale);
          expect(tester.takeException(), isNull);
          await tap(tester, find.text('Операция'));
          await tap(tester, find.widgetWithText(ChoiceChip, 'Перевод'));
          expect(tester.takeException(), isNull);
          await tap(tester, find.byTooltip('Закрыть'));
          await tap(tester, find.byTooltip('Добавить карточку: Кошельки'));
          expect(tester.takeException(), isNull);
          await tap(tester, find.byTooltip('Закрыть'));
          await tap(tester, find.text('Операции').last);
          expect(tester.takeException(), isNull);
          await tap(tester, find.text('Настройки').last);
          await tap(tester, find.text('Темная тема'));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
