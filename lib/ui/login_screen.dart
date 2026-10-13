import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import 'style.dart';

class LoginScreen extends StatefulWidget {
  final AppController controller;
  const LoginScreen({super.key, required this.controller});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final login = TextEditingController();
  final password = TextEditingController();
  bool hidden = true;
  bool loading = false;
  String? error;
  @override
  void dispose() {
    login.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final ok = await widget.controller.login(login.text, password.text);
      if (mounted && !ok) {
        setState(() => error = 'Неверный логин или пароль');
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: mint,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'CoinFlow',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Деньги под контролем.\nБольше места для ваших планов.',
                  style: TextStyle(fontSize: 17, height: 1.6),
                ),
                const SizedBox(height: 36),
                TextField(
                  enabled: !loading,
                  autocorrect: false,
                  controller: login,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Логин',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  enabled: !loading,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.password],
                  controller: password,
                  obscureText: hidden,
                  onSubmitted: (_) => loading ? null : submit(),
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: hidden ? 'Показать пароль' : 'Скрыть пароль',
                      onPressed: () => setState(() => hidden = !hidden),
                      icon: Icon(
                        hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: loading ? null : submit,
                    child: Text(
                      loading ? 'Входим…' : 'Войти',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: mint.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.science_outlined, color: mint),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Тестовый доступ\nЛогин: demo  ·  Пароль: demo123',
                          style: TextStyle(height: 1.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Center(
                  child: Text(
                    'Локальная версия · Данные на этом устройстве',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
