import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../application/app_controller.dart';
import '../domain/models.dart';
import 'editors.dart';
import 'settings_screen.dart';
import 'style.dart';

class HomeScreen extends StatefulWidget {
  final AppController controller;
  const HomeScreen({super.key, required this.controller});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int page = 0;
  bool showIncome = true;
  AppController get c => widget.controller;
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              Container(
                width: 230,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    right: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 36, 16, 36),
                      child: Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_rounded,
                            color: mint,
                            size: 30,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'CoinFlow',
                                style: TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final item in [
                      (Icons.grid_view_rounded, 'Обзор'),
                      (Icons.receipt_long_outlined, 'Операции'),
                      (Icons.settings_outlined, 'Настройки'),
                    ].asMap().entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            selected: page == item.key,
                            selectedTileColor: mint.withValues(alpha: .1),
                            leading: Icon(item.value.$1),
                            title: Text(item.value.$2),
                            onTap: () => setState(() => page = item.key),
                          ),
                        ),
                      ),
                    if (MediaQuery.sizeOf(context).height >= 600)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Chip(
                              avatar: Icon(
                                Icons.offline_bolt_outlined,
                                size: 16,
                              ),
                              label: Text('Локальная версия'),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Все финансы.\nВ одном месте.',
                              style: TextStyle(color: Colors.grey, height: 1.6),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          wide ? 32 : 20,
                          wide ? 26 : 12,
                          16,
                          8,
                        ),
                        child: Row(
                          children: [
                            if (!wide)
                              const Padding(
                                padding: EdgeInsets.only(right: 10),
                                child: Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: mint,
                                  size: 27,
                                ),
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    page == 0
                                        ? (wide ? 'Мои финансы' : 'CoinFlow')
                                        : page == 1
                                        ? 'Операции'
                                        : 'Настройки',
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.8,
                                    ),
                                  ),
                                  if (wide)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Каждый день — ближе к своим целям',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (page != 2)
                              IconButton(
                                tooltip: 'Настройки',
                                onPressed: () => setState(() => page = 2),
                                icon: const Icon(Icons.tune_rounded),
                              ),
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: mint.withValues(alpha: .12),
                              child: const Text(
                                'Д',
                                style: TextStyle(
                                  color: mint,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (c.busy) const LinearProgressIndicator(minHeight: 2),
                      if (c.recoveryNotice != null)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height * .3,
                          ),
                          child: SingleChildScrollView(
                            child: MaterialBanner(
                              content: Text(c.recoveryNotice!),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      setState(() => c.recoveryNotice = null),
                                  child: const Text('Понятно'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Expanded(
                        child: switch (page) {
                          0 => overview(wide),
                          1 => HistoryView(controller: c),
                          _ => SettingsScreen(controller: c),
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: page == 2
          ? null
          : FloatingActionButton.extended(
              backgroundColor: mint,
              foregroundColor: Colors.white,
              onPressed: c.busy ? null : () => openEntry(context, c),
              icon: const Icon(Icons.add),
              label: const Text('Операция'),
            ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              height: 66,
              selectedIndex: page,
              onDestinationSelected: (i) => setState(() => page = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view_rounded),
                  label: 'Обзор',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  label: 'Операции',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_rounded),
                  label: 'Настройки',
                ),
              ],
            ),
    );
  }

  Widget overview(bool wide) {
    final balance = c.data.total(CardKind.wallet, c.month);
    final expenses = c.data.total(CardKind.expense, c.month);
    final plan = c.data.cards
        .where((x) => x.kind == CardKind.expense)
        .fold<int>(0, (s, x) => s + x.budget);
    return ListView(
      padding: EdgeInsets.fromLTRB(wide ? 14 : 0, 4, wide ? 14 : 0, 100),
      children: [
        MonthSelector(controller: c),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              summary(
                'Баланс сейчас',
                balance,
                Icons.account_balance_wallet_outlined,
                const Color(0xFFBD9600),
              ),
              summary('Расходы', expenses, Icons.south_west_rounded, mint),
              summary('Лимит', plan, Icons.flag_outlined, cyan),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: SectionHeading(
                      'Доходы',
                      'за месяц',
                      onAdd: () => openCardEditor(context, c, CardKind.income),
                    ),
                  ),
                  IconButton(
                    tooltip: showIncome ? 'Скрыть доходы' : 'Показать доходы',
                    onPressed: () => setState(() => showIncome = !showIncome),
                    icon: Icon(
                      showIncome
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              if (showIncome) cardGrid(CardKind.income),
              const Divider(height: 1),
              SectionHeading(
                'Кошельки',
                'текущий остаток',
                onAdd: () => openCardEditor(context, c, CardKind.wallet),
              ),
              cardGrid(CardKind.wallet),
              const Divider(height: 1),
              SectionHeading(
                'Расходы',
                'за месяц',
                onAdd: () => openCardEditor(context, c, CardKind.expense),
              ),
              cardGrid(CardKind.expense),
              const SizedBox(height: 12),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 18, 24, 0),
          child: Text(
            'Нажмите на карточку, чтобы добавить операцию. Карандаш открывает настройки.\nУдерживайте кошелек или доход, чтобы перетащить на другую карточку.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.6),
          ),
        ),
      ],
    );
  }

  Widget summary(String label, int value, IconData icon, Color color) =>
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 13, color: color),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 9),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  money(value),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.7,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget cardGrid(CardKind kind) {
    final cards = c.data.cards.where((card) => card.kind == kind).toList();
    if (cards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: TextButton.icon(
          onPressed: () => openCardEditor(context, c, kind),
          icon: const Icon(Icons.add),
          label: const Text('Добавить первую карточку'),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 340 ? 3 : 4;
        final cellWidth = (constraints.maxWidth - 16) / columns;
        final circle = math.min(cellWidth - 20, 94.0);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent:
                circle + 86 * MediaQuery.textScalerOf(context).scale(1),
            mainAxisSpacing: 7,
          ),
          itemCount: cards.length,
          itemBuilder: (context, i) {
            final card = cards[i];
            final tile = MoneyTile(
              card: card,
              value: c.data.value(card, c.month),
              size: circle,
              onTap: () {
                if (!c.busy) openEntry(context, c, card: card);
              },
              onEdit: () {
                if (!c.busy) openCardEditor(context, c, kind, card: card);
              },
            );
            if (kind == CardKind.wallet || kind == CardKind.income) {
              return LongPressDraggable<MoneyCard>(
                maxSimultaneousDrags: c.busy ? 0 : 1,
                data: card,
                feedback: Material(
                  color: Colors.transparent,
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: kindColor(kind),
                    child: Icon(
                      cardIcons[card.icon],
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                childWhenDragging: Opacity(opacity: .4, child: tile),
                child: DragTarget<MoneyCard>(
                  onWillAcceptWithDetails: (d) =>
                      d.data.id != card.id &&
                      kind == CardKind.wallet &&
                      (d.data.kind == CardKind.income ||
                          d.data.kind == CardKind.wallet) &&
                      !c.busy,
                  onAcceptWithDetails: (d) => d.data.kind == CardKind.wallet
                      ? openEntry(context, c, card: card, wallet: d.data)
                      : openEntry(context, c, card: d.data, wallet: card),
                  builder: (_, candidates, rejected) => tile,
                ),
              );
            }
            return DragTarget<MoneyCard>(
              onWillAcceptWithDetails: (d) =>
                  d.data.kind == CardKind.wallet && !c.busy,
              onAcceptWithDetails: (d) =>
                  openEntry(context, c, card: card, wallet: d.data),
              builder: (_, candidates, rejected) => AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  color: candidates.isEmpty
                      ? Colors.transparent
                      : mint.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: tile,
              ),
            );
          },
        );
      },
    );
  }
}

class MoneyTile extends StatelessWidget {
  final MoneyCard card;
  final int value;
  final double size;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  const MoneyTile({
    super.key,
    required this.card,
    required this.value,
    required this.size,
    required this.onTap,
    required this.onEdit,
  });
  @override
  Widget build(BuildContext context) {
    final color = kindColor(card.kind);
    final limited = card.kind == CardKind.expense && card.budget > 0;
    final over = limited && value > card.budget;
    return Semantics(
      button: true,
      label: '${card.name}, ${money(value)}',
      child: InkWell(
        onTap: onTap,
        onSecondaryTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            SizedBox(
              height: 32 * MediaQuery.textScalerOf(context).scale(1),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          card.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 24,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          tooltip: 'Изменить карточку: ${card.name}',
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: size,
              height: size,
              child: ClipOval(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: limited
                            ? (Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF485663)
                                  : const Color(0xFFC3C9CE))
                            : color,
                      ),
                    ),
                    if (limited)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: size * (value / card.budget).clamp(0, 1),
                        child: ColoredBox(
                          color: over ? const Color(0xFFFF9251) : color,
                        ),
                      ),
                    Center(
                      child: Icon(
                        cardIcons[card.icon] ?? Icons.category_outlined,
                        color: Colors.white,
                        size: size * .47,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 9),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  money(value),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: over
                        ? Colors.deepOrange
                        : card.kind == CardKind.wallet
                        ? const Color(0xFFD4A426)
                        : card.kind == CardKind.income
                        ? const Color(0xFF28A9CF)
                        : const Color(0xFF35AE90),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            if (card.budget > 0)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  money(card.budget, symbol: false),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MonthSelector extends StatelessWidget {
  final AppController controller;
  const MonthSelector({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      IconButton(
        tooltip: 'Предыдущий месяц',
        onPressed: () => controller.moveMonth(-1),
        icon: const Icon(Icons.chevron_left, size: 20),
      ),
      TextButton.icon(
        icon: const Icon(Icons.calendar_today_outlined, size: 14),
        label: Text(monthName(controller.month)),
        onPressed: () async {
          final selected = await showDatePicker(
            context: context,
            initialDate: controller.month,
            firstDate: DateTime(1),
            lastDate: DateTime(9999, 12, 31),
            helpText: 'Выберите дату нужного месяца',
          );
          if (selected != null) controller.selectMonth(selected);
        },
      ),
      if (!sameMonth(controller.month, DateTime.now()))
        IconButton(
          tooltip: 'Текущий месяц',
          onPressed: () => controller.selectMonth(DateTime.now()),
          icon: const Icon(Icons.today_outlined, size: 20),
        ),
      IconButton(
        tooltip: 'Следующий месяц',
        onPressed: () => controller.moveMonth(1),
        icon: const Icon(Icons.chevron_right, size: 20),
      ),
    ],
  );
}

class HistoryView extends StatefulWidget {
  final AppController controller;
  const HistoryView({super.key, required this.controller});
  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  final search = TextEditingController();
  EntryKind? filter;
  String? walletFilter;
  bool allDates = false;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> action(MoneyEntry entry, String action) async {
    final c = widget.controller;
    if (action == 'edit') {
      await openEntry(context, c, entry: entry);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить операцию?'),
        content: const Text(
          'Остаток кошелька и сумма категории будут пересчитаны.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await c.deleteEntry(entry);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Операция удалена'),
          action: SnackBarAction(
            label: 'Отменить',
            onPressed: () async {
              try {
                await c.addEntry(entry);
              } catch (error) {
                if (mounted) showError(context, error);
              }
            },
          ),
        ),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final wallets = c.data.cards
        .where((card) => card.kind == CardKind.wallet)
        .toList();
    if (!wallets.any((card) => card.id == walletFilter)) walletFilter = null;
    final query = search.text.trim().toLowerCase();
    final entries =
        c.data.entries
            .where(
              (e) =>
                  (allDates || sameMonth(e.date, c.month)) &&
                  (filter == null || e.kind == filter) &&
                  (walletFilter == null ||
                      e.walletId == walletFilter ||
                      (e.kind == EntryKind.transfer &&
                          e.targetId == walletFilter)) &&
                  '${c.data.card(e.targetId).name} ${c.data.card(e.walletId).name} ${e.note}'
                      .toLowerCase()
                      .contains(query),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final narrowed = query.isNotEmpty || filter != null || walletFilter != null;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: entries.length + (entries.isEmpty ? 2 : 1),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!allDates) MonthSelector(controller: c),
              TextField(
                controller: search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Категория, кошелек или комментарий',
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Очистить поиск',
                          onPressed: () => setState(search.clear),
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final item in <EntryKind?, String>{
                    null: 'Все',
                    EntryKind.expense: 'Расходы',
                    EntryKind.income: 'Доходы',
                    EntryKind.transfer: 'Переводы',
                  }.entries)
                    ChoiceChip(
                      label: Text(item.value),
                      selected: filter == item.key,
                      onSelected: (_) => setState(() => filter = item.key),
                    ),
                  FilterChip(
                    label: const Text('Все даты'),
                    selected: allDates,
                    onSelected: (value) => setState(() => allDates = value),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('history-wallet-$walletFilter'),
                initialValue: walletFilter,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Кошелек'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Все кошельки'),
                  ),
                  for (final card in wallets)
                    DropdownMenuItem(
                      value: card.id,
                      child: Text(card.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => setState(() => walletFilter = value),
              ),
              if (narrowed)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() {
                      search.clear();
                      filter = null;
                      walletFilter = null;
                    }),
                    child: const Text('Сбросить фильтры'),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Найдено операций: ${entries.length}'),
              ),
              const SizedBox(height: 16),
            ],
          );
        }
        if (entries.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  size: 52,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(narrowed ? 'Ничего не найдено' : 'Пока нет операций'),
                const SizedBox(height: 8),
                Text(
                  narrowed
                      ? 'Измените запрос или сбросьте фильтры.'
                      : 'Добавьте первую с помощью кнопки «Операция».',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        final e = entries[index - 1];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: c.busy ? null : () => openEntry(context, c, entry: e),
            contentPadding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
            leading: CircleAvatar(
              backgroundColor: kindColor(
                c.data.card(e.targetId).kind,
              ).withValues(alpha: .12),
              child: Icon(
                cardIcons[c.data.card(e.targetId).icon] ??
                    Icons.category_outlined,
                color: e.kind == EntryKind.income ? cyan : mint,
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.data.card(e.targetId).name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${e.kind == EntryKind.income
                      ? '+'
                      : e.kind == EntryKind.expense
                      ? '−'
                      : '↔'}${money(e.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: e.kind == EntryKind.income ? mint : null,
                  ),
                ),
              ],
            ),
            subtitle: Text(
              '${c.data.card(e.walletId).name} · ${DateFormat('d MMM yyyy', 'ru').format(e.date)}${e.note.isEmpty ? '' : '\n${e.note}'}',
              style: const TextStyle(fontSize: 12),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: PopupMenuButton<String>(
              tooltip: 'Действия',
              enabled: !c.busy,
              onSelected: (value) => action(e, value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Изменить')),
                PopupMenuItem(value: 'delete', child: Text('Удалить')),
              ],
            ),
          ),
        );
      },
    );
  }
}
