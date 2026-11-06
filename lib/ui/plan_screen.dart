import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import '../domain/models.dart';
import '../domain/reports.dart';
import 'editors.dart';
import 'style.dart';

Future<void> openPlan(BuildContext context, AppController controller) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            PlanScreen(controller: controller, month: controller.month),
      ),
    );

class PlanScreen extends StatefulWidget {
  final AppController controller;
  final DateTime month;
  const PlanScreen({super.key, required this.controller, required this.month});
  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final fields = <String, TextEditingController>{};
  late final TextEditingController reserve;
  bool saving = false;
  String? error;
  AppController get c => widget.controller;
  List<MoneyCard> get categories =>
      c.data.cards.where((c) => c.kind == CardKind.expense).toList();

  @override
  void initState() {
    super.initState();
    final plan = c.data.planFor(widget.month);
    reserve = TextEditingController(text: decimalMoney(plan.reserve));
    for (final card in categories) {
      fields[card.id] = TextEditingController(
        text: decimalMoney(plan.limits[card.id] ?? 0),
      );
    }
  }

  @override
  void dispose() {
    reserve.dispose();
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  MonthlyPlan readPlan() {
    final limits = <String, int>{};
    for (final card in categories) {
      final value = parseMoney(fields[card.id]!.text);
      if (value < 0) {
        throw FormatException(
          'План «${card.name}» не может быть отрицательным',
        );
      }
      if (value > 0) limits[card.id] = value;
    }
    final other = parseMoney(reserve.text);
    if (other < 0) {
      throw const FormatException('Резерв не может быть отрицательным');
    }
    return MonthlyPlan(limits: limits, reserve: other);
  }

  Future<void> save() async {
    if (saving || c.busy) return;
    try {
      final plan = readPlan();
      setState(() {
        saving = true;
        error = null;
      });
      await c.savePlan(widget.month, plan);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = errorMessage(e);
        });
      }
    }
  }

  Future<void> addCategory() async {
    final created = await openCardEditor(context, c, CardKind.expense);
    if (!mounted) return;
    if (created != null) {
      setState(() {
        fields.putIfAbsent(
          created.id,
          () => TextEditingController(text: decimalMoney(created.budget)),
        );
      });
    }
  }

  void copyPrevious() {
    final previous = c.data.planFor(
      DateTime(widget.month.year, widget.month.month - 1),
    );
    setState(() {
      for (final card in categories) {
        fields[card.id]!.text = decimalMoney(previous.limits[card.id] ?? 0);
      }
      reserve.text = decimalMoney(previous.reserve);
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      // A newly created card can notify listeners before its editor returns.
      for (final card in categories) {
        fields.putIfAbsent(
          card.id,
          () => TextEditingController(
            text: decimalMoney(
              c.data.planFor(widget.month).limits[card.id] ?? 0,
            ),
          ),
        );
      }
      final progress = PlanProgress.calculate(c.data, widget.month);
      MonthlyPlan? draft;
      try {
        draft = readPlan();
      } on FormatException {
        /* Display validation on save. */
      }
      final otherSpent = draft == null
          ? 0
          : progress.spending.entries
                .where((e) => !draft!.limits.containsKey(e.key))
                .fold<int>(0, (s, e) => s + e.value);
      final otherNames = draft == null
          ? ''
          : categories
                .where((card) => !draft!.limits.containsKey(card.id))
                .map((c) => c.name)
                .join(', ');
      return PopScope(
        canPop: !saving,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('План расходов'),
            leading: IconButton(
              tooltip: 'Закрыть план',
              onPressed: saving ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    monthName(widget.month),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Укажите суммы на этот месяц. Категории с нулевым планом используют общий резерв «Остальное».',
                  ),
                  const SizedBox(height: 16),
                  if (draft != null)
                    PlanLine(
                      title: 'Всего на месяц',
                      planned: draft.total,
                      spent: progress.spent,
                    ),
                  if (widget.month.year > 1 || widget.month.month > 1)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: saving ? null : copyPrevious,
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Взять план прошлого месяца'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  for (final card in categories)
                    Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              key: ValueKey('plan-${card.id}'),
                              controller: fields[card.id],
                              enabled: !saving,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: card.name,
                                suffixText: '₽',
                                prefixIcon: Icon(
                                  cardIcons[card.icon] ??
                                      Icons.category_outlined,
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 10),
                            if (draft?.limits.containsKey(card.id) ?? false)
                              PlanLine(
                                title: '',
                                planned: draft!.limits[card.id]!,
                                spent: progress.spending[card.id] ?? 0,
                              )
                            else
                              Text(
                                'В резерве «Остальное» · потрачено ${money(progress.spending[card.id] ?? 0)}',
                              ),
                          ],
                        ),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: saving ? null : addCategory,
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить категорию расходов'),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Остальное · непредвиденные',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Один резерв для всех категорий без отдельной суммы. Превышение плана питания или жилья остаётся перерасходом своей категории.',
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            key: const ValueKey('plan-reserve'),
                            controller: reserve,
                            enabled: !saving,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Общий резерв',
                              suffixText: '₽',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          if (draft != null)
                            PlanLine(
                              title: '',
                              planned: draft.reserve,
                              spent: otherSpent,
                            ),
                          const SizedBox(height: 8),
                          Text(
                            otherNames.isEmpty
                                ? 'Пока все категории имеют отдельный план. Новые категории без плана попадут сюда.'
                                : 'В резерве: $otherNames',
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const ValueKey('save-plan'),
                    onPressed: saving || c.busy ? null : save,
                    icon: const Icon(Icons.check),
                    label: Text(saving ? 'Сохраняем…' : 'Сохранить план'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class PlanLine extends StatelessWidget {
  final String title;
  final int planned;
  final int spent;
  const PlanLine({
    super.key,
    required this.title,
    required this.planned,
    required this.spent,
  });
  @override
  Widget build(BuildContext context) {
    final over = spent > planned;
    final color = over
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        Text('${money(spent)} из ${money(planned)}'),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: planned == 0
                ? (spent == 0 ? 0 : 1)
                : (spent / planned).clamp(0, 1),
            color: color,
            minHeight: 7,
            backgroundColor: color.withValues(alpha: .12),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${over ? 'Перерасход' : 'Осталось'}: ${money((planned - spent).abs())}',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
