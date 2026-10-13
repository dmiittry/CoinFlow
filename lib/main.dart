import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'application/app_controller.dart';
import 'data/repository.dart';
import 'ui/home_screen.dart';
import 'ui/login_screen.dart';
import 'ui/style.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  runApp(
    StartupScreen(
      loadController: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        final controller = AppController(LocalFinanceRepository(prefs), prefs);
        try {
          await controller.initialize();
          return controller;
        } catch (_) {
          controller.dispose();
          rethrow;
        }
      },
    ),
  );
}

class StartupScreen extends StatefulWidget {
  final Future<AppController> Function() loadController;
  const StartupScreen({super.key, required this.loadController});
  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  AppController? controller;
  Object? error;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.loadController();
      if (!mounted) {
        result.dispose();
        return;
      }
      setState(() => controller = result);
    } catch (failure) {
      if (mounted) setState(() => error = failure);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller != null) return CoinFlowApp(controller: controller!);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: loading
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storage_outlined, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Не удалось прочитать локальные данные. Они сохранены без изменений.',
                      ),
                      const SizedBox(height: 12),
                      SelectableText('$error'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: load,
                        child: const Text('Повторить загрузку'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class CoinFlowApp extends StatelessWidget {
  final AppController controller;
  const CoinFlowApp({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      title: 'CoinFlow',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      themeMode: controller.themeMode,
      home: controller.signedIn
          ? HomeScreen(controller: controller)
          : LoginScreen(controller: controller),
    ),
  );
}
