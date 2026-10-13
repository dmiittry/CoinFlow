import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../domain/models.dart';

const mint = Color(0xFF00C99A);
const cyan = Color(0xFF03BADB);
const gold = Color(0xFFFFCE00);
const ink = Color(0xFF202E3A);
Color kindColor(CardKind kind) => switch (kind) {
  CardKind.income => cyan,
  CardKind.wallet => gold,
  CardKind.expense => mint,
};
String money(int cents, {bool symbol = true}) {
  final whole = NumberFormat('#,##0', 'ru').format(cents.abs() ~/ 100);
  final fraction = cents.abs() % 100;
  return '${cents < 0 ? '−' : ''}$whole${fraction == 0 ? '' : ',${fraction.toString().padLeft(2, '0')}'}${symbol ? ' ₽' : ''}';
}

String monthName(DateTime date) => DateFormat('LLLL yyyy', 'ru').format(date);

ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(seedColor: mint, brightness: brightness)
        .copyWith(
          primary: dark ? mint : const Color(0xFF009975),
          surface: dark ? const Color(0xFF18232D) : Colors.white,
        ),
    scaffoldBackgroundColor: dark
        ? const Color(0xFF101920)
        : const Color(0xFFF5F7F8),
    fontFamily: 'Roboto',
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF101920) : const Color(0xFFF5F7F8),
      centerTitle: false,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF23313D) : const Color(0xFFF3F6F7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerColor: dark ? Colors.white10 : const Color(0xFFE9EEF0),
    dividerTheme: DividerThemeData(
      color: dark ? Colors.white10 : const Color(0xFFE9EEF0),
    ),
  );
}

const cardIcons = <String, IconData>{
  'wallet': Icons.account_balance_wallet_outlined,
  'bank': Icons.bar_chart_rounded,
  'building': Icons.account_balance_outlined,
  'chart': Icons.insert_chart_outlined,
  'coins': Icons.payments_outlined,
  'percent': Icons.percent_rounded,
  'globe': Icons.language,
  'groceries': Icons.local_grocery_store_outlined,
  'cafe': Icons.fastfood_outlined,
  'bus': Icons.directions_bus_outlined,
  'bag': Icons.shopping_bag_outlined,
  'circle': Icons.donut_small_outlined,
  'home': Icons.home_outlined,
  'movie': Icons.theaters_outlined,
  'school': Icons.school_outlined,
  'glass': Icons.local_bar_outlined,
  'heart': Icons.favorite_border,
  'clothes': Icons.checkroom_outlined,
  'wifi': Icons.wifi_tethering,
  'trophy': Icons.emoji_events_outlined,
};

String errorMessage(Object error) => error.toString().replaceFirst(
  RegExp(r'^(Bad state: |FormatException: )'),
  '',
);

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(errorMessage(error))));
}

const cardIconLabels = <String, String>{
  'wallet': 'Кошелек',
  'bank': 'Банк',
  'building': 'Счет',
  'chart': 'График',
  'coins': 'Деньги',
  'percent': 'Проценты',
  'globe': 'Работа',
  'groceries': 'Продукты',
  'cafe': 'Кафе',
  'bus': 'Транспорт',
  'bag': 'Покупки',
  'circle': 'Разное',
  'home': 'Дом',
  'movie': 'Кино',
  'school': 'Образование',
  'glass': 'Напитки',
  'heart': 'Семья',
  'clothes': 'Одежда',
  'wifi': 'Связь',
  'trophy': 'Спорт',
};

class SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onAdd;
  const SectionHeading(this.title, this.subtitle, {super.key, this.onAdd});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
    child: Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  TextSpan(
                    text: '  $subtitle',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (onAdd != null)
          IconButton(
            tooltip: 'Добавить карточку: $title',
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle_outline, size: 21),
          ),
      ],
    ),
  );
}
