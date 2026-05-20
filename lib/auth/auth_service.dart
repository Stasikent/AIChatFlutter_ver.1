import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _apiKeyKey = 'api_key';
  static const String _pinKey = 'pin_code';
  static const String _providerKey = 'provider';
  static const String _balanceKey = 'balance';

  Future<bool> hasSavedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString(_apiKeyKey);
    final pin = prefs.getString(_pinKey);

    return apiKey != null &&
        apiKey.isNotEmpty &&
        pin != null &&
        pin.isNotEmpty;
  }

  String? detectProvider(String apiKey) {
    if (apiKey.startsWith('sk-or-v1-')) {
      return 'OpenRouter';
    }

    if (apiKey.startsWith('sk-or-vv-')) {
      return 'VSEGPT';
    }

    return null;
  }

  Future<double> checkBalance(String apiKey) async {
    final provider = detectProvider(apiKey);

    if (provider == null) {
      throw Exception('Неизвестный тип ключа');
    }

    if (provider == 'OpenRouter') {
      return _checkOpenRouterBalance(apiKey);
    }

    if (provider == 'VSEGPT') {
      return _checkVseGptBalance(apiKey);
    }

    throw Exception('Провайдер не поддерживается');
  }

  Future<double> _checkOpenRouterBalance(String apiKey) async {
    final response = await http.get(
      Uri.parse('https://openrouter.ai/api/v1/auth/key'),
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Ключ OpenRouter недействителен');
    }

    final data = jsonDecode(response.body);

    final usage = (data['data']?['usage'] ?? 0).toDouble();
    final limit = data['data']?['limit'];

    if (limit == null) {
      throw Exception('Баланс OpenRouter недоступен');
    }

    final balance = limit.toDouble() - usage;

    if (balance <= 0) {
      throw Exception('Баланс OpenRouter нулевой или отрицательный');
    }

    return balance;
  }

  Future<double> _checkVseGptBalance(String apiKey) async {
    final response = await http.get(
      Uri.parse('https://api.vsegpt.ru/v1/balance'),
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    debugPrint('VSEGPT status code: ${response.statusCode}');
    debugPrint('VSEGPT balance response: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Ключ VSEGPT недействителен или баланс недоступен');
    }

    final data = jsonDecode(response.body);

    final dynamic rawBalance =
      data['balance'] ??
      data['amount'] ??
      data['money'] ??
      data['credits'] ??
      data['data']?['balance'] ??
      data['data']?['amount'] ??
      data['data']?['money'] ??
      data['data']?['credits'];

    final balance = double.tryParse(rawBalance.toString()) ?? 0;

    if (balance <= 0) {
      throw Exception('Баланс VSEGPT нулевой или отрицательный');
    }

    return balance;
  }

  Future<String> saveApiKeyAndGeneratePin(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    final provider = detectProvider(apiKey);

    if (provider == null) {
      throw Exception('Неизвестный тип ключа');
    }

    final balance = await checkBalance(apiKey);

    final pin = _generatePin();

    await prefs.setString(_apiKeyKey, apiKey);
    await prefs.setString(_pinKey, pin);
    await prefs.setString(_providerKey, provider);
    await prefs.setDouble(_balanceKey, balance);

    return pin;
  }

  Future<bool> checkPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString(_pinKey);

    return savedPin == pin;
  }

  Future<void> resetAuth() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_apiKeyKey);
    await prefs.remove(_pinKey);
    await prefs.remove(_providerKey);
    await prefs.remove(_balanceKey);
  }

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey);
  }

  Future<String?> getProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_providerKey);
  }

  Future<double?> getBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_balanceKey);
  }

  String _generatePin() {
    final random = Random();
    final pin = 1000 + random.nextInt(9000);
    return pin.toString();
  }
}