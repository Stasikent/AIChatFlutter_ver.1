import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/openrouter_client.dart';
import '../models/message.dart';
import '../models/chat_session.dart';
import '../services/analytics_service.dart';
import '../services/database_service.dart';
import '../services/usage_stats_service.dart';
import '../services/vsegpt_access_service.dart';

class ChatProvider with ChangeNotifier {
  final OpenRouterClient _api = OpenRouterClient();

  static const String _chatsStorageKey = 'chat_sessions';
  static const String _currentChatIdKey = 'current_chat_id';

  final List<String> _debugLogs = [];

  List<ChatSession> _chats = [];
  String? _currentChatId;

  List<Map<String, dynamic>> _allModels = [];
  List<Map<String, dynamic>> _availableModels = [];

  String? _currentModel;
  String _balance = '\$0.00';
  bool _isLoading = false;

  String _modelSearchQuery = '';
  String _modelFamilyFilter = 'Все';
  String _modelSortMode = 'name_asc';

  final Set<String> _favoriteModelIds = {};
  bool _showOnlyFavorites = false;

  final DatabaseService _db = DatabaseService();
  final AnalyticsService _analytics = AnalyticsService();
  final UsageStatsService _usageStats = UsageStatsService();
  final VsegptAccessService _vsegptAccess = VsegptAccessService();

final String _subscriptionLevel = 'basic';

bool _showOnlyAvailableModels = false;

  List<ChatSession> get chats => List.unmodifiable(_chats);

  ChatSession? get currentChat {
    if (_currentChatId == null || _chats.isEmpty) {
      return null;
    }

    try {
      return _chats.firstWhere((chat) => chat.id == _currentChatId);
    } catch (_) {
      return _chats.isNotEmpty ? _chats.first : null;
    }
  }

  List<ChatMessage> get messages =>
      List.unmodifiable(currentChat?.messages ?? []);

  List<Map<String, dynamic>> get availableModels => _availableModels;

  String? get currentModel => _currentModel;
  String get balance => _balance;
  bool get isLoading => _isLoading;
  String? get baseUrl => _api.baseUrl;

  String get modelSearchQuery => _modelSearchQuery;
  String get modelFamilyFilter => _modelFamilyFilter;
  String get modelSortMode => _modelSortMode;

  bool get showOnlyFavorites => _showOnlyFavorites;

  bool get showOnlyAvailableModels =>
    _showOnlyAvailableModels;

  String get subscriptionLevel =>
    _subscriptionLevel;

  bool isModelAvailable(String modelId) {
    return _vsegptAccess.isModelAvailable(
      modelId: modelId,
      subscriptionLevel: _subscriptionLevel,
    );
  }

  String modelAccessLabel(String modelId) {
    return _vsegptAccess.accessLabel(
      modelId: modelId,
      subscriptionLevel: _subscriptionLevel,
    );
  }

  bool isFavoriteModel(String modelId) {
    return _favoriteModelIds.contains(modelId);
  }

  List<String> get modelFamilies {
    final families = _allModels
        .map((model) => _detectModelFamily(model['id']?.toString() ?? ''))
        .toSet()
        .toList();

    families.sort();

    return ['Все', ...families];
  }

  ChatProvider() {
    _initializeProvider();
  }

  void _log(String message) {
    _debugLogs.add('${DateTime.now()}: $message');
    debugPrint(message);
  }

  Future<void> _initializeProvider() async {
    try {
      _log('Initializing provider...');

      await _loadChats();

      await _vsegptAccess.loadModels();

      await _loadModels();
      _log('Models loaded: $_availableModels');

      await _loadBalance();
      _log('Balance loaded: $_balance');

      notifyListeners();
    } catch (e, stackTrace) {
      _log('Error initializing provider: $e');
      _log('Stack trace: $stackTrace');
    }
  }

  Future<void> _loadChats() async {
    final prefs = await SharedPreferences.getInstance();

    final rawChats = prefs.getString(_chatsStorageKey);
    final savedCurrentChatId = prefs.getString(_currentChatIdKey);

    if (rawChats == null || rawChats.isEmpty) {
      final firstChat = _createEmptyChat(title: 'Новый чат');

      _chats = [firstChat];
      _currentChatId = firstChat.id;

      await _saveChats();
      return;
    }

    try {
      final decoded = jsonDecode(rawChats) as List;

      _chats = decoded
          .map(
            (item) => ChatSession.fromJson(item as Map<String, dynamic>),
          )
          .toList();

      if (_chats.isEmpty) {
        final firstChat = _createEmptyChat(title: 'Новый чат');
        _chats = [firstChat];
        _currentChatId = firstChat.id;
      } else if (savedCurrentChatId != null &&
          _chats.any((chat) => chat.id == savedCurrentChatId)) {
        _currentChatId = savedCurrentChatId;
      } else {
        _currentChatId = _chats.first.id;
      }
    } catch (e) {
      _log('Error loading chats: $e');

      final firstChat = _createEmptyChat(title: 'Новый чат');
      _chats = [firstChat];
      _currentChatId = firstChat.id;
    }
  }

  Future<void> _saveChats() async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = jsonEncode(
      _chats.map((chat) => chat.toJson()).toList(),
    );

    await prefs.setString(_chatsStorageKey, encoded);

    if (_currentChatId != null) {
      await prefs.setString(_currentChatIdKey, _currentChatId!);
    }
  }

  ChatSession _createEmptyChat({required String title}) {
    final now = DateTime.now();

    return ChatSession(
      id: now.microsecondsSinceEpoch.toString(),
      title: title,
      createdAt: now,
      messages: [],
    );
  }

  Future<void> createNewChat() async {
    final chat = _createEmptyChat(title: 'Новый чат');

    _chats.insert(0, chat);
    _currentChatId = chat.id;

    await _saveChats();

    notifyListeners();
  }

  Future<void> switchChat(String chatId) async {
    if (!_chats.any((chat) => chat.id == chatId)) {
      return;
    }

    _currentChatId = chatId;

    await _saveChats();

    notifyListeners();
  }

  Future<void> deleteChat(String chatId) async {
    _chats.removeWhere((chat) => chat.id == chatId);

    if (_chats.isEmpty) {
      final chat = _createEmptyChat(title: 'Новый чат');
      _chats.add(chat);
      _currentChatId = chat.id;
    } else if (_currentChatId == chatId) {
      _currentChatId = _chats.first.id;
    }

    await _saveChats();

    notifyListeners();
  }

  Future<void> renameCurrentChat(String title) async {
    final chat = currentChat;

    if (chat == null) {
      return;
    }

    final cleanTitle = title.trim();

    if (cleanTitle.isEmpty) {
      return;
    }

    chat.title = cleanTitle;

    await _saveChats();

    notifyListeners();
  }

  void _autoRenameChatIfNeeded(String userMessage) {
    final chat = currentChat;

    if (chat == null) {
      return;
    }

    if (chat.title != 'Новый чат') {
      return;
    }

    final title = userMessage.trim();

    if (title.isEmpty) {
      return;
    }

    chat.title = title.length > 32 ? '${title.substring(0, 32)}...' : title;
  }

  Future<void> _loadModels() async {
    try {
      _allModels = await _api.getModels();
      _applyModelFilters();

      if (_availableModels.isNotEmpty && _currentModel == null) {
        _currentModel = _availableModels[0]['id'];
      }

      notifyListeners();
    } catch (e) {
      _log('Error loading models: $e');
    }
  }

  void setModelSearchQuery(String query) {
    _modelSearchQuery = query.trim().toLowerCase();
    _applyModelFilters();
    notifyListeners();
  }

  void setModelFamilyFilter(String family) {
    _modelFamilyFilter = family;
    _applyModelFilters();
    notifyListeners();
  }

  void setModelSortMode(String sortMode) {
    _modelSortMode = sortMode;
    _applyModelFilters();
    notifyListeners();
  }

  void resetModelFilters() {
    _modelSearchQuery = '';
    _modelFamilyFilter = 'Все';
    _modelSortMode = 'name_asc';
    _applyModelFilters();
    notifyListeners();
  }

  void toggleFavoriteModel(String modelId) {
    if (_favoriteModelIds.contains(modelId)) {
      _favoriteModelIds.remove(modelId);
    } else {
      _favoriteModelIds.add(modelId);
    }

    _applyModelFilters();

    notifyListeners();
  }

  void toggleShowOnlyFavorites() {
    _showOnlyFavorites = !_showOnlyFavorites;
    _applyModelFilters();
    notifyListeners();
  }

  void toggleShowOnlyAvailableModels() {
    _showOnlyAvailableModels =
        !_showOnlyAvailableModels;

    _applyModelFilters();

    notifyListeners();
  }

  void _applyModelFilters() {
    var filtered = List<Map<String, dynamic>>.from(_allModels);

    if (_modelSearchQuery.isNotEmpty) {
      filtered = filtered.where((model) {
        final id = model['id']?.toString().toLowerCase() ?? '';
        final name = model['name']?.toString().toLowerCase() ?? '';

        return id.contains(_modelSearchQuery) || name.contains(_modelSearchQuery);
      }).toList();
    }

    if (_modelFamilyFilter != 'Все') {
      filtered = filtered.where((model) {
        final family = _detectModelFamily(model['id']?.toString() ?? '');
        return family == _modelFamilyFilter;
      }).toList();
    }

    if (_showOnlyFavorites) {
      filtered = filtered.where((model) {
        final id = model['id']?.toString() ?? '';
        return _favoriteModelIds.contains(id);
      }).toList();
    }

    if (_showOnlyAvailableModels) {
      filtered = filtered.where((model) {

        final id =
            model['id']?.toString() ?? '';

        return isModelAvailable(id);

      }).toList();
    }

    filtered.sort((a, b) {
      switch (_modelSortMode) {
        case 'name_desc':
          return (b['name']?.toString() ?? '')
              .compareTo(a['name']?.toString() ?? '');

        case 'price_asc':
          return _getModelAveragePrice(a).compareTo(_getModelAveragePrice(b));

        case 'price_desc':
          return _getModelAveragePrice(b).compareTo(_getModelAveragePrice(a));

        case 'context_asc':
          return _getContextLength(a).compareTo(_getContextLength(b));

        case 'context_desc':
          return _getContextLength(b).compareTo(_getContextLength(a));

        case 'name_asc':
        default:
          return (a['name']?.toString() ?? '')
              .compareTo(b['name']?.toString() ?? '');
      }
    });

    _availableModels = filtered;

    if (_currentModel != null &&
        !_availableModels.any((model) => model['id'] == _currentModel)) {
      _currentModel =
          _availableModels.isNotEmpty ? _availableModels[0]['id'] : null;
    }
  }

  String _detectModelFamily(String modelId) {
    final id = modelId.toLowerCase();

    if (id.contains('openai') || id.contains('gpt')) return 'OpenAI';
    if (id.contains('deepseek')) return 'DeepSeek';
    if (id.contains('anthropic') || id.contains('claude')) return 'Anthropic';
    if (id.contains('google') || id.contains('gemini')) return 'Google';
    if (id.contains('nvidia')) return 'NVIDIA';
    if (id.contains('meta') || id.contains('llama')) return 'Meta';
    if (id.contains('mistral') || id.contains('mixtral')) return 'Mistral';
    if (id.contains('qwen') || id.contains('alibaba')) return 'Qwen';
    if (id.contains('x-ai') || id.contains('grok')) return 'xAI';
    if (id.contains('cohere')) return 'Cohere';
    if (id.contains('moonshot') || id.contains('kimi')) return 'Moonshot';
    if (id.contains('perplexity')) return 'Perplexity';

    return 'Другое';
  }

  double _getModelAveragePrice(Map<String, dynamic> model) {
    final prompt = double.tryParse(
          model['pricing']?['prompt']?.toString() ?? '0',
        ) ??
        0.0;

    final completion = double.tryParse(
          model['pricing']?['completion']?.toString() ?? '0',
        ) ??
        0.0;

    return (prompt + completion) / 2;
  }

  int _getContextLength(Map<String, dynamic> model) {
    return int.tryParse(model['context_length']?.toString() ?? '0') ?? 0;
  }

  Future<void> _loadBalance() async {
    try {
      _balance = await _api.getBalance();
      notifyListeners();
    } catch (e) {
      _log('Error loading balance: $e');
    }
  }

  Future<void> _saveMessage(ChatMessage message) async {
    try {
      await _db.saveMessage(message);
    } catch (e) {
      _log('Error saving message: $e');
    }
  }

  String _extractAiContent(Map<String, dynamic> response) {
    try {
      final choices = response['choices'];

      if (choices is List && choices.isNotEmpty) {
        final firstChoice = choices[0];

        if (firstChoice is Map) {
          final message = firstChoice['message'];

          if (message is Map) {
            final content = message['content'];

            if (content != null && content.toString().trim().isNotEmpty) {
              return content.toString();
            }

            final reasoning = message['reasoning'];

            if (reasoning != null && reasoning.toString().trim().isNotEmpty) {
              return reasoning.toString();
            }

            final refusal = message['refusal'];

            if (refusal != null && refusal.toString().trim().isNotEmpty) {
              return refusal.toString();
            }
          }

          final text = firstChoice['text'];

          if (text != null && text.toString().trim().isNotEmpty) {
            return text.toString();
          }
        }
      }

      return 'Модель вернула пустой ответ.';
    } catch (e) {
      return 'Не удалось прочитать ответ модели: $e';
    }
  }

  double _calculateCost({
    required Map<String, dynamic> response,
    required int promptTokens,
    required int completionTokens,
  }) {
    final totalCost = (response['usage']?['total_cost'] as num?)?.toDouble();

    if (totalCost != null) {
      return totalCost;
    }

    Map<String, dynamic> model = {
      'pricing': {
        'prompt': '0',
        'completion': '0',
      },
    };

    for (final item in _allModels) {
      if (item['id'] == _currentModel) {
        model = item;
        break;
      }
    }

    final promptPrice = double.tryParse(
          model['pricing']?['prompt']?.toString() ?? '0',
        ) ??
        0.0;

    final completionPrice = double.tryParse(
          model['pricing']?['completion']?.toString() ?? '0',
        ) ??
        0.0;

    return (promptTokens * promptPrice) + (completionTokens * completionPrice);
  }

  Future<void> sendMessage(String content, {bool trackAnalytics = true}) async {
    if (content.trim().isEmpty || _currentModel == null) return;

    final chat = currentChat;

    if (chat == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      content = utf8.decode(utf8.encode(content));

      _autoRenameChatIfNeeded(content);

      final userMessage = ChatMessage(
        content: content,
        isUser: true,
        modelId: _currentModel,
      );

      chat.messages.add(userMessage);
      notifyListeners();

      await _saveMessage(userMessage);
      await _saveChats();

      final startTime = DateTime.now();

      final response = await _api.sendMessage(content, _currentModel!);

      _log('API Response: $response');

      final responseTime =
          DateTime.now().difference(startTime).inMilliseconds / 1000;

      if (response.containsKey('error')) {
        final errorMessage = ChatMessage(
          content: utf8.decode(utf8.encode('Error: ${response['error']}')),
          isUser: false,
          modelId: _currentModel,
        );

        chat.messages.add(errorMessage);
        await _saveMessage(errorMessage);
        await _saveChats();
      } else if (response.containsKey('choices') &&
          response['choices'] is List &&
          response['choices'].isNotEmpty) {
        final aiContent = utf8.decode(
          utf8.encode(
            _extractAiContent(response),
          ),
        );

        final tokens =
            (response['usage']?['total_tokens'] as num?)?.toInt() ?? 0;

        final promptTokens =
            (response['usage']?['prompt_tokens'] as num?)?.toInt() ?? 0;

        final completionTokens =
            (response['usage']?['completion_tokens'] as num?)?.toInt() ?? 0;

        if (trackAnalytics) {
          _analytics.trackMessage(
            model: _currentModel!,
            messageLength: content.length,
            responseTime: responseTime,
            tokensUsed: tokens,
          );
        }

        final cost = _calculateCost(
          response: response,
          promptTokens: promptTokens,
          completionTokens: completionTokens,
        );

        _log('Cost Response: $cost');

        final aiMessage = ChatMessage(
          content: aiContent,
          isUser: false,
          modelId: _currentModel,
          tokens: tokens,
          cost: cost,
        );

        chat.messages.add(aiMessage);

        await _saveMessage(aiMessage);
        await _saveChats();

        await _usageStats.addCost(cost / 1000);

        await _loadBalance();
      } else {
        throw Exception('Invalid API response format');
      }
    } catch (e) {
      _log('Error sending message: $e');

      final errorMessage = ChatMessage(
        content: utf8.decode(utf8.encode('Error: $e')),
        isUser: false,
        modelId: _currentModel,
      );

      chat.messages.add(errorMessage);

      await _saveMessage(errorMessage);
      await _saveChats();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setCurrentModel(String modelId) {

    if (!isModelAvailable(modelId)) {

      _log(
        'Blocked unavailable model: $modelId',
      );

      return;
    }

    _currentModel = modelId;

    notifyListeners();
  }

  Future<void> clearHistory() async {
    final chat = currentChat;

    if (chat != null) {
      chat.messages.clear();
    }

    await _db.clearHistory();
    _analytics.clearData();
    await _saveChats();

    notifyListeners();
  }

  Future<String> exportLogs() async {
    final directory = await getApplicationDocumentsDirectory();
    final now = DateTime.now();

    final fileName =
        'chat_logs_${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.txt';

    final file = File('${directory.path}/$fileName');

    final buffer = StringBuffer();

    buffer.writeln('=== Debug Logs ===\n');

    for (final log in _debugLogs) {
      buffer.writeln(log);
    }

    buffer.writeln('\n=== Chat Logs ===\n');
    buffer.writeln('Generated: ${now.toString()}\n');

    for (final message in messages) {
      buffer.writeln('${message.isUser ? "User" : "AI"} (${message.modelId}):');
      buffer.writeln(message.content);

      if (message.tokens != null) {
        buffer.writeln('Tokens: ${message.tokens}');
      }

      if (message.cost != null) {
        buffer.writeln('Cost: ${message.cost}');
      }

      buffer.writeln('Time: ${message.timestamp}');
      buffer.writeln('---\n');
    }

    await file.writeAsString(buffer.toString());

    return file.path;
  }

  Future<String> exportMessagesAsJson() async {
    final directory = await getApplicationDocumentsDirectory();
    final now = DateTime.now();

    final fileName =
        'chat_history_${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.json';

    final file = File('${directory.path}/$fileName');

    final List<Map<String, dynamic>> messagesJson =
        messages.map((message) => message.toJson()).toList();

    await file.writeAsString(jsonEncode(messagesJson));

    return file.path;
  }

  String formatPricing(double pricing) {
    return _api.formatPricing(pricing);
  }

  Future<Map<String, dynamic>> exportHistory() async {
    final dbStats = await _db.getStatistics();
    final analyticsStats = _analytics.getStatistics();
    final sessionData = _analytics.exportSessionData();
    final modelEfficiency = _analytics.getModelEfficiency();
    final responseTimeStats = _analytics.getResponseTimeStats();
    final messageLengthStats = _analytics.getMessageLengthStats();

    return {
      'database_stats': dbStats,
      'analytics_stats': analyticsStats,
      'session_data': sessionData,
      'model_efficiency': modelEfficiency,
      'response_time_stats': responseTimeStats,
      'message_length_stats': messageLengthStats,
    };
  }
}