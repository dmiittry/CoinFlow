import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../application/app_controller.dart';
import '../domain/models.dart';
import 'style.dart';

Future<void> openEntry(
  BuildContext context,
  AppController controller, {
  MoneyCard? card,
  MoneyCard? wallet,
  MoneyEntry? entry,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  enableDrag: false,
  showDragHandle: false,
  builder: (_) => EntryEditor(
    controller: controller,
    card: card,
    wallet: wallet,
    entry: entry,
  ),
);

class EntryEditor extends StatefulWidget {
  final AppController controller;
  final MoneyCard? card;
  final MoneyCard? wallet;
  final MoneyEntry? entry;
  const EntryEditor({
    super.key,
    required this.controller,
    this.card,
    this.wallet,
    this.entry,
  });
  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  final amount = TextEditingController();
  final note = TextEditingController();
  late EntryKind kind;
  String? walletId;
  String? targetId;
  DateTime date = DateTime.now();
  bool saving = false;
  String? error;
  List<MoneyCard> get wallets => widget.controller.data.cards
      .where((c) => c.kind == CardKind.wallet)
      .toList();
  List<MoneyCard> get targets => widget.controller.data.cards
      .where(
        (c) =>
            c.kind ==
                switch (kind) {
                  EntryKind.income => CardKind.income,
                  EntryKind.expense => CardKind.expense,
                  EntryKind.transfer => CardKind.wallet,
                } &&
            c.id != walletId,
      )
      .toList();
  @override
  void initState() {
    super.initState();
    final existing = widget.entry;
    if (existing != null) {
      kind = existing.kind;
      walletId = existing.walletId;
      targetId = existing.targetId;
      date = existing.date;
      amount.text = decimalMoney(existing.amount);
      note.text = existing.note;
      return;
    }
    final month = widget.controller.month;
    final today = DateTime.now();
    if (month.isBefore(DateTime(today.year, today.month))) {
      date = DateTime(
        month.year,
        month.month,
        today.day.clamp(1, DateTime(month.year, month.month + 1, 0).day),
      );
    }
    if (widget.wallet != null && widget.card?.kind == CardKind.wallet) {
      kind = EntryKind.transfer;
      walletId = widget.wallet!.id;
      targetId = widget.card!.id;
      return;
    }
    kind = widget.card?.kind == CardKind.income
        ? EntryKind.income
        : EntryKind.expense;
    walletId =
        widget.wallet?.id ??
        (widget.card?.kind == CardKind.wallet
            ? widget.card!.id
            : wallets.firstOrNull?.id);
    targetId = widget.card?.kind != CardKind.wallet ? widget.card?.id : null;
    targetId ??= targets.firstOrNull?.id;
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    try {
      final cents = parseMoney(amount.text);
      if (cents <= 0) {
        throw const FormatException('Сумма должна быть больше нуля');
      }
      if (walletId == null || targetId == null) {
        throw const FormatException(
          'Сначала добавьте кошелек и нужную категорию',
        );
      }
      setState(() {
        saving = true;
        error = null;
      });
      final entry = MoneyEntry(
        id: widget.entry?.id ?? newId(),
        kind: kind,
        walletId: walletId!,
        targetId: targetId!,
        amount: cents,
        date: date,
        note: note.text.trim(),
      );
      if (widget.entry == null) {
        await widget.controller.addEntry(entry);
      } else {
        await widget.controller.updateEntry(entry);
      }
      widget.controller.selectMonth(date);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = errorMessage(e);
        });
      }
    }
  }

  Future<void> addCard(CardKind cardKind, {bool destination = false}) async {
    final card = await openCardEditor(context, widget.controller, cardKind);
    if (!mounted || card == null) return;
    setState(() {
      if (cardKind == CardKind.wallet && !destination) {
        walletId = card.id;
        if (!targets.any((c) => c.id == targetId)) {
          targetId = targets.firstOrNull?.id;
        }
      } else {
        targetId = card.id;
      }
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.entry == null ? 'Новая операция' : 'Изменить операцию',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Закрыть',
                onPressed: saving ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in {
                EntryKind.expense: 'Расход',
                EntryKind.income: 'Доход',
                EntryKind.transfer: 'Перевод',
              }.entries)
                ChoiceChip(
                  label: Text(item.value),
                  selected: kind == item.key,
                  onSelected: saving
                      ? null
                      : (_) => setState(() {
                          kind = item.key;
                          targetId = targets.firstOrNull?.id;
                          error = null;
                        }),
                ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            enabled: !saving,
            key: const ValueKey('entry-amount'),
            controller: amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              labelText: 'Сумма',
              suffixText: '₽',
              hintText: '0',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey('wallet-$walletId'),
            initialValue: walletId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: kind == EntryKind.income
                  ? 'Зачислить в кошелек'
                  : 'Из кошелька',
            ),
            items: wallets
                .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                .toList(),
            onChanged: saving
                ? null
                : (id) => setState(() {
                    walletId = id;
                    if (!targets.any((t) => t.id == targetId)) {
                      targetId = targets.firstOrNull?.id;
                    }
                  }),
          ),
          const SizedBox(height: 14),
          if (wallets.isEmpty)
            TextButton.icon(
              onPressed: saving ? null : () => addCard(CardKind.wallet),
              icon: const Icon(Icons.add),
              label: const Text('Создать кошелек'),
            ),
          DropdownButtonFormField<String>(
            key: ValueKey('target-${kind.name}-$targetId'),
            initialValue: targetId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: kind == EntryKind.transfer ? 'В кошелек' : 'Категория',
            ),
            items: targets
                .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                .toList(),
            onChanged: saving ? null : (id) => setState(() => targetId = id),
          ),
          if (targets.isEmpty)
            TextButton.icon(
              onPressed: saving
                  ? null
                  : () => addCard(switch (kind) {
                      EntryKind.income => CardKind.income,
                      EntryKind.expense => CardKind.expense,
                      EntryKind.transfer => CardKind.wallet,
                    }, destination: true),
              icon: const Icon(Icons.add),
              label: Text(
                kind == EntryKind.transfer
                    ? 'Создать второй кошелек'
                    : 'Создать категорию',
              ),
            ),
          const SizedBox(height: 14),
          TextField(
            enabled: !saving,
            key: const ValueKey('entry-note'),
            controller: note,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Комментарий',
              hintText: 'Необязательно',
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined, size: 21),
            title: Text(DateFormat('d MMMM yyyy', 'ru').format(date)),
            trailing: const Icon(Icons.chevron_right),
            onTap: saving
                ? null
                : () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: date.year < 2000
                          ? DateTime(date.year)
                          : DateTime(2000),
                      lastDate: date.isAfter(DateTime.now())
                          ? date
                          : DateTime.now(),
                    );
                    if (selected != null && mounted) {
                      setState(() => date = selected);
                    }
                  },
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? 'Сохраняем…' : 'Сохранить операцию'),
          ),
        ],
      ),
    ),
  );
}

Future<MoneyCard?> openCardEditor(
  BuildContext context,
  AppController controller,
  CardKind kind, {
  MoneyCard? card,
}) => showModalBottomSheet<MoneyCard>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  enableDrag: false,
  showDragHandle: false,
  builder: (_) => CardEditor(controller: controller, kind: kind, card: card),
);

class CardEditor extends StatefulWidget {
  final AppController controller;
  final CardKind kind;
  final MoneyCard? card;
  const CardEditor({
    super.key,
    required this.controller,
    required this.kind,
    this.card,
  });
  @override
  State<CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends State<CardEditor> {
  late final TextEditingController name;
  late final TextEditingController opening;
  late final TextEditingController budget;
  late String icon;
  late DateTime openingDate;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.card?.name ?? '');
    opening = TextEditingController(
      text: decimalMoney(widget.card?.opening ?? 0),
    );
    budget = TextEditingController(
      text: decimalMoney(widget.card?.budget ?? 0),
    );
    icon =
        widget.card?.icon ??
        switch (widget.kind) {
          CardKind.wallet => 'wallet',
          CardKind.income => 'coins',
          CardKind.expense => 'bag',
        };
    openingDate = widget.card?.openingDate ?? widget.controller.month;
  }

  @override
  void dispose() {
    name.dispose();
    opening.dispose();
    budget.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    try {
      if (name.text.trim().isEmpty) {
        throw const FormatException('Введите название');
      }
      final card = MoneyCard(
        id: widget.card?.id ?? newId(),
        name: name.text.trim(),
        kind: widget.kind,
        opening: parseMoney(opening.text),
        budget: parseMoney(budget.text),
        icon: icon,
        openingDate: openingDate,
      );
      setState(() {
        saving = true;
        error = null;
      });
      await widget.controller.saveCard(card);
      if (mounted) {
        Navigator.pop(context, card);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = errorMessage(e);
        });
      }
    }
  }

  Future<void> remove() async {
    if (saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить карточку?'),
        content: Text('«${widget.card!.name}» будет удалена.'),
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
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => saving = true);
    try {
      await widget.controller.deleteCard(widget.card!);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = errorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.card == null ? 'Новая карточка' : 'Настройки карточки',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Закрыть',
                onPressed: saving ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            enabled: !saving,
            key: const ValueKey('card-name'),
            controller: name,
            maxLength: 40,
            decoration: const InputDecoration(labelText: 'Название'),
          ),
          const SizedBox(height: 12),
          TextField(
            enabled: !saving,
            key: const ValueKey('card-opening'),
            controller: opening,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: InputDecoration(
              labelText: widget.kind == CardKind.wallet
                  ? 'Начальный остаток, ₽'
                  : 'Начальная сумма, ₽',
              helperText: 'Операции учитываются дополнительно',
            ),
          ),
          const SizedBox(height: 16),
          if (widget.kind != CardKind.wallet)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Дата начальной суммы'),
              subtitle: Text(
                DateFormat('d MMMM yyyy', 'ru').format(openingDate),
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: saving
                  ? null
                  : () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: openingDate,
                        firstDate: openingDate.year < 2000
                            ? DateTime(openingDate.year)
                            : DateTime(2000),
                        lastDate: openingDate.isAfter(DateTime.now())
                            ? openingDate
                            : DateTime.now(),
                      );
                      if (selected != null && mounted) {
                        setState(() => openingDate = selected);
                      }
                    },
            ),
          if (widget.kind != CardKind.wallet)
            TextField(
              enabled: !saving,
              key: const ValueKey('card-budget'),
              controller: budget,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: widget.kind == CardKind.expense
                    ? 'Лимит на месяц, ₽'
                    : 'План дохода на месяц, ₽',
                helperText: '0 — без лимита',
              ),
            ),
          const SizedBox(height: 20),
          const Text('Иконка', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cardIcons.entries
                .map(
                  (item) => Tooltip(
                    message: cardIconLabels[item.key] ?? item.key,
                    child: Semantics(
                      button: true,
                      selected: icon == item.key,
                      label: cardIconLabels[item.key] ?? item.key,
                      child: InkWell(
                        key: ValueKey('icon-${item.key}'),
                        onTap: saving
                            ? null
                            : () => setState(() => icon = item.key),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: icon == item.key
                                ? kindColor(widget.kind)
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            item.value,
                            color: icon == item.key ? ink : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? 'Сохраняем…' : 'Сохранить карточку'),
          ),
          if (widget.card != null)
            TextButton(
              onPressed: saving ? null : remove,
              child: Text(
                'Удалить карточку',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
  );
}
