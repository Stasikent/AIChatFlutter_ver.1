import 'package:flutter/material.dart';

import '../auth/auth_service.dart';

class ProviderSettingsPage extends StatefulWidget {
  const ProviderSettingsPage({super.key});

  @override
  State<ProviderSettingsPage> createState() => _ProviderSettingsPageState();
}

class _ProviderSettingsPageState extends State<ProviderSettingsPage> {
  final AuthService _authService = AuthService();

  String _provider = 'Не определён';
  String _balance = 'Не проверен';
  String _maskedKey = 'Не найден';

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProviderData();
  }

  Future<void> _loadProviderData() async {
    final provider = await _authService.getProvider();
    final balance = await _authService.getBalance();
    final apiKey = await _authService.getApiKey();

    if (!mounted) return;

    setState(() {
      _provider = provider ?? 'Не определён';
      _balance = balance != null ? balance.toStringAsFixed(2) : 'Не проверен';
      _maskedKey = _maskApiKey(apiKey);
      _isLoading = false;
    });
  }

  String _maskApiKey(String? key) {
    if (key == null || key.isEmpty) {
      return 'Не найден';
    }

    if (key.length <= 12) {
      return '${key.substring(0, 4)}****';
    }

    return '${key.substring(0, 8)}****${key.substring(key.length - 4)}';
  }

  Future<void> _resetAuth() async {
    await _authService.resetAuth();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ключ и PIN сброшены. Перезапустите приложение.'),
      ),
    );

    await _loadProviderData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0F0A),
      appBar: AppBar(
        title: const Text('Настройки провайдера'),
        backgroundColor: const Color(0xFF2A1208),
        foregroundColor: Colors.white,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4A160A),
              Color(0xFF2A0E07),
              Color(0xFF120A07),
            ],
          ),
        ),
        child: Center(
          child: Container(
            width: 520,
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.orange),
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Провайдер и ключи',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Текущий провайдер: $_provider',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'API-ключ: $_maskedKey',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Сохранённый баланс: $_balance',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Ключ хранится локально в SharedPreferences. '
                        'Для смены провайдера или API-ключа необходимо сбросить текущие данные '
                        'и пройти авторизацию заново.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _resetAuth,
                          child: const Text('Сбросить ключ и PIN'),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}