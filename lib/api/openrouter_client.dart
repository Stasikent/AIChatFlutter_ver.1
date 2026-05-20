import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OpenRouterClient {
  String? apiKey;
  String? baseUrl;
  String? provider;

  Map<String, String> headers = {};

  static final OpenRouterClient _instance = OpenRouterClient._internal();

  factory OpenRouterClient() {
    return _instance;
  }

  OpenRouterClient._internal() {
    _initializeClient();
  }

  Future<void> _initializeClient() async {
    await _loadAuthData();
  }

  Future<void> _loadAuthData() async {
    final prefs = await SharedPreferences.getInstance();

    apiKey = prefs.getString('api_key') ?? dotenv.env['OPENROUTER_API_KEY'];
    provider = prefs.getString('provider');

    if (provider == 'VSEGPT') {
      baseUrl = 'https://api.vsegpt.ru/v1';
    } else {
      baseUrl = dotenv.env['BASE_URL'] ?? 'https://openrouter.ai/api/v1';
    }

    headers = {
      'Authorization': 'Bearer ${apiKey ?? ''}',
      'Content-Type': 'application/json',
      'X-Title': 'AI Chat Flutter',
    };

    if (kDebugMode) {
      print('OpenRouterClient initialized');
      print('Provider: $provider');
      print('Base URL: $baseUrl');
      print('Has API key: ${apiKey != null && apiKey!.isNotEmpty}');
    }
  }

  Future<List<Map<String, dynamic>>> getModels() async {
    try {
      await _loadAuthData();

      final response = await http.get(
        Uri.parse('$baseUrl/models'),
        headers: headers,
      );

      if (kDebugMode) {
        print('Models response status: ${response.statusCode}');
        print('Models response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final modelsData = json.decode(utf8.decode(response.bodyBytes));

        if (modelsData['data'] != null) {
          return (modelsData['data'] as List)
              .map(
                (model) => {
                  'id': model['id']?.toString() ?? '',
                  'name': model['name']?.toString() ??
                      model['id']?.toString() ??
                      'Unknown model',
                  'pricing': {
                    'prompt':
                        model['pricing']?['prompt']?.toString() ?? '0',
                    'completion':
                        model['pricing']?['completion']?.toString() ?? '0',
                  },
                  'context_length': (model['context_length'] ??
                          model['top_provider']?['context_length'] ??
                          0)
                      .toString(),
                },
              )
              .toList();
        }

        throw Exception('Invalid API response format');
      }

      return _defaultModels();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting models: $e');
      }

      return _defaultModels();
    }
  }

  List<Map<String, dynamic>> _defaultModels() {
    return [
      {
        'id': 'openai/gpt-4.1-nano',
        'name': 'OpenAI: GPT-4.1 Nano',
        'pricing': {
          'prompt': '0.0000001',
          'completion': '0.0000004',
        },
        'context_length': '1047576',
      },
      {
        'id': 'deepseek/deepseek-chat-v3-0324',
        'name': 'DeepSeek Chat V3',
        'pricing': {
          'prompt': '0.00000027',
          'completion': '0.0000011',
        },
        'context_length': '64000',
      },
    ];
  }

  Future<Map<String, dynamic>> sendMessage(
    String message,
    String model,
  ) async {
    try {
      await _loadAuthData();

      if (apiKey == null || apiKey!.isEmpty) {
        return {
          'error':
              'API ключ не найден. Сбросьте ключ и пройдите авторизацию заново.'
        };
      }

      final data = {
        'model': model,
        'messages': [
          {
            'role': 'user',
            'content': message,
          }
        ],
        'max_tokens': int.parse(dotenv.env['MAX_TOKENS'] ?? '1000'),
        'temperature': double.parse(dotenv.env['TEMPERATURE'] ?? '0.7'),
        'stream': false,
      };

      if (kDebugMode) {
        print('Sending message to API: ${json.encode(data)}');
        print('Using baseUrl: $baseUrl');
        print('Using provider: $provider');
        print('Has authorization: ${headers['Authorization']!.length > 10}');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/chat/completions'),
        headers: headers,
        body: json.encode(data),
      );

      if (kDebugMode) {
        print('Message response status: ${response.statusCode}');
        print('Message response body: ${utf8.decode(response.bodyBytes)}');
      }

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }

      final errorData = json.decode(utf8.decode(response.bodyBytes));

      return {
        'error': errorData['error']?['message'] ??
            errorData['message'] ??
            'Unknown error occurred'
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error sending message: $e');
      }

      return {
        'error': e.toString(),
      };
    }
  }

  Future<String> getBalance() async {
    try {
      await _loadAuthData();

      if (apiKey == null || apiKey!.isEmpty) {
        return provider == 'VSEGPT' ? '0.00₽' : '\$0.00';
      }

      final balanceUrl = provider == 'VSEGPT'
          ? '$baseUrl/balance'
          : '$baseUrl/credits';

      final response = await http.get(
        Uri.parse(balanceUrl),
        headers: headers,
      );

      if (kDebugMode) {
        print('Balance response status: ${response.statusCode}');
        print('Balance response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (provider == 'VSEGPT') {
          final credits =
              double.tryParse(data['data']?['credits']?.toString() ?? '0') ??
                  0.0;

          return '${credits.toStringAsFixed(2)}₽';
        }

        final credits = data['data']?['total_credits'] ?? 0;
        final usage = data['data']?['total_usage'] ?? 0;

        return '\$${(credits - usage).toStringAsFixed(2)}';
      }

      return provider == 'VSEGPT' ? '0.00₽' : '\$0.00';
    } catch (e) {
      if (kDebugMode) {
        print('Error getting balance: $e');
      }

      return 'Error';
    }
  }

  String formatPricing(double pricing) {
    try {
      if (provider == 'VSEGPT') {
        return '${pricing.toStringAsFixed(3)}₽/K';
      }

      return '\$${(pricing * 1000000).toStringAsFixed(3)}/M';
    } catch (e) {
      if (kDebugMode) {
        print('Error formatting pricing: $e');
      }

      return '0.00';
    }
  }
}