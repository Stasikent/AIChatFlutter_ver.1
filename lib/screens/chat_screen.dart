import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../pages/provider_settings_page.dart';
import '../pages/token_statistics_page.dart';
import '../pages/analytics_chart_page.dart';

import '../providers/chat_provider.dart';
import '../models/message.dart';

class ErrorBoundary extends StatelessWidget {
  final Widget child;

  const ErrorBoundary({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        try {
          return child;
        } catch (error, stackTrace) {
          debugPrint('Error in ErrorBoundary: $error');
          debugPrint('Stack trace: $stackTrace');

          return Container(
            padding: const EdgeInsets.all(12),
            color: Colors.red,
            child: Text(
              'Error: $error',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          );
        }
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final List<ChatMessage> messages;
  final int index;

  const _MessageBubble({
    required this.message,
    required this.messages,
    required this.index,
  });

  String _formatCost(ChatProvider chatProvider, double rawCost) {
    final isVsegpt =
        chatProvider.baseUrl?.contains('vsegpt.ru') == true ||
        chatProvider.baseUrl?.contains('vsetgpt.ru') == true;

    final correctedCost = rawCost / 1000;

    if (correctedCost < 0.0001) {
      return isVsegpt ? 'Стоимость: <0.0001₽' : 'Стоимость: <\$0.0001';
    }

    return isVsegpt
        ? 'Стоимость: ${correctedCost.toStringAsFixed(4)}₽'
        : 'Стоимость: \$${correctedCost.toStringAsFixed(4)}';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: message.isUser
                  ? const Color(0xFFFF5722)
                  : const Color(0xFF4A2A20),
              borderRadius: BorderRadius.circular(16),
            ),
            child: SelectableText(
              message.cleanContent,
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: 13,
                locale: const Locale('ru', 'RU'),
              ),
            ),
          ),
          if (message.tokens != null || message.cost != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.tokens != null)
                    Text(
                      'Токенов: ${message.tokens}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  if (message.tokens != null && message.cost != null)
                    const SizedBox(width: 8),
                  if (message.cost != null)
                    Consumer<ChatProvider>(
                      builder: (context, chatProvider, child) {
                        return Text(
                          _formatCost(chatProvider, message.cost!),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    color: Colors.white54,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    onPressed: () {
                      final textToCopy = message.isUser
                          ? message.cleanContent
                          : index > 0
                              ? '${messages[index - 1].cleanContent}\n\n${message.cleanContent}'
                              : message.cleanContent;

                      Clipboard.setData(ClipboardData(text: textToCopy));

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Текст скопирован',
                            style: TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    tooltip: 'Копировать текст',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageInput extends StatefulWidget {
  final void Function(String) onSubmitted;

  const _MessageInput({required this.onSubmitted});

  @override
  State<_MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<_MessageInput> {
  final _controller = TextEditingController();

  bool _isComposing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmitted(String text) {
    _controller.clear();

    setState(() {
      _isComposing = false;
    });

    widget.onSubmitted(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1208),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepOrange,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: (String text) {
                setState(() {
                  _isComposing = text.trim().isNotEmpty;
                });
              },
              onSubmitted: _isComposing ? _handleSubmitted : null,
              decoration: const InputDecoration(
                hintText: 'Введите сообщение...',
                hintStyle: TextStyle(color: Colors.white54, fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, size: 20),
            color: _isComposing ? Colors.deepOrangeAccent : Colors.grey,
            onPressed:
                _isComposing ? () => _handleSubmitted(_controller.text) : null,
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }
}

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  String _formatAnalyticsCost(ChatProvider chatProvider, double rawCost) {
    final isVsegpt =
        chatProvider.baseUrl?.contains('vsegpt.ru') == true ||
        chatProvider.baseUrl?.contains('vsetgpt.ru') == true;

    final correctedCost = rawCost / 1000;

    final formattedCost =
        correctedCost < 1e-8 ? '0.0' : correctedCost.toStringAsFixed(4);

    return isVsegpt ? '$formattedCost₽' : '\$$formattedCost';
  }

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      child: Scaffold(
        backgroundColor: const Color(0xFF1A0F0A),
        appBar: _buildAppBar(context),
        body: Container(
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
          child: SafeArea(
            child: Column(
              children: [
                _buildModelFilters(context),
                Expanded(
                  child: _buildMessagesList(),
                ),
                _buildInputArea(context),
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF2A1208),
      foregroundColor: Colors.white,
      toolbarHeight: 48,
      title: Row(
        children: [
          _buildModelSelector(context),
          const Spacer(),
          _buildBalanceDisplay(context),
          _buildMenuButton(context),
        ],
      ),
    );
  }

  Widget _buildModelFilters(BuildContext context) {
  return Consumer<ChatProvider>(
    builder: (context, chatProvider, child) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        color: const Color(0xFF2A1208),
        child: Column(
          children: [

            // Поиск
            TextField(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
              decoration: InputDecoration(
                hintText: 'Поиск модели...',
                hintStyle: const TextStyle(
                  color: Colors.white54,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.orange,
                ),
                filled: true,
                fillColor: const Color(0xFF4A160A),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                chatProvider
                    .setModelSearchQuery(value);
              },
            ),

            const SizedBox(height: 8),

            Row(
              children: [

                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        chatProvider.modelFamilyFilter,
                    dropdownColor:
                        const Color(0xFF2A1208),

                    decoration:
                        const InputDecoration(
                      labelText: 'Провайдер',
                      labelStyle:
                          TextStyle(
                        color: Colors.white70,
                      ),
                    ),

                    items: chatProvider
                        .modelFamilies
                        .map((family) {
                      return DropdownMenuItem(
                        value: family,
                        child: Text(
                          family,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }).toList(),

                    onChanged: (value) {
                      if (value != null) {
                        chatProvider
                            .setModelFamilyFilter(
                                value);
                      }
                    },
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child:
                      DropdownButtonFormField<
                          String>(
                    initialValue:
                        chatProvider.modelSortMode,

                    dropdownColor:
                        const Color(0xFF2A1208),

                    decoration:
                        const InputDecoration(
                      labelText: 'Сортировка',
                      labelStyle:
                          TextStyle(
                        color: Colors.white70,
                      ),
                    ),

                    items: const [

                      DropdownMenuItem(
                        value:
                            'name_asc',
                        child:
                            Text('А-Я'),
                      ),

                      DropdownMenuItem(
                        value:
                            'name_desc',
                        child:
                            Text('Я-А'),
                      ),

                      DropdownMenuItem(
                        value:
                            'price_asc',
                        child: Text(
                            'Цена ↑'),
                      ),

                      DropdownMenuItem(
                        value:
                            'price_desc',
                        child: Text(
                            'Цена ↓'),
                      ),

                      DropdownMenuItem(
                        value:
                            'context_desc',
                        child: Text(
                            'Контекст ↑'),
                      ),
                    ],

                    onChanged: (value) {
                      if (value != null) {
                        chatProvider
                            .setModelSortMode(
                                value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

  Widget _buildModelSelector(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        return SizedBox(
          width: MediaQuery.of(context).size.width * 0.6,
          child: DropdownButton<String>(
            value: chatProvider.currentModel,
            hint: const Text(
              'Выберите модель',
              style: TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            dropdownColor: const Color(0xFF2A1208),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            isExpanded: true,
            underline: Container(
              height: 1,
              color: Colors.deepOrange,
            ),
            onChanged: (String? newValue) {
              if (newValue != null) {
                chatProvider.setCurrentModel(newValue);
              }
            },
            items: chatProvider.availableModels
                .map<DropdownMenuItem<String>>((Map<String, dynamic> model) {
              return DropdownMenuItem<String>(
                value: model['id'],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [

                        Expanded(
                          child: Text(
                            model['name'] ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                            ),
                          ),
                        ),

                        Consumer<ChatProvider>(
                          builder: (context, chatProvider, child) {

                            final modelId =
                                model['id'] ?? '';

                            final isFavorite =
                                chatProvider
                                    .isFavoriteModel(
                                        modelId);

                            return GestureDetector(
                              onTap: () {
                                chatProvider
                                    .toggleFavoriteModel(
                                        modelId);
                              },

                              child: Icon(
                                isFavorite
                                    ? Icons.star
                                    : Icons.star_border,

                                color: isFavorite
                                    ? Colors.amber
                                    : Colors.white54,

                                size: 16,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Tooltip(
                          message: 'Входные токены',
                          child: Icon(Icons.arrow_upward, size: 12),
                        ),
                        Text(
                          chatProvider.formatPricing(
                            double.tryParse(model['pricing']?['prompt']) ??
                                0.0,
                          ),
                          style: const TextStyle(fontSize: 10),
                        ),
                        const SizedBox(width: 8),
                        const Tooltip(
                          message: 'Генерация',
                          child: Icon(Icons.arrow_downward, size: 12),
                        ),
                        Text(
                          chatProvider.formatPricing(
                            double.tryParse(model['pricing']?['completion']) ??
                                0.0,
                          ),
                          style: const TextStyle(fontSize: 10),
                        ),
                        const SizedBox(width: 8),
                        const Tooltip(
                          message: 'Контекст',
                          child: Icon(Icons.memory, size: 12),
                        ),
                        Text(
                          ' ${model['context_length'] ?? '0'}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildBalanceDisplay(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3.0),
          child: Row(
            children: [
              const Icon(Icons.credit_card, size: 12, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                chatProvider.balance,
                style: const TextStyle(
                  color: Color(0xFF7CFF7C),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white, size: 16),
      color: const Color(0xFF2A1208),
      onSelected: (String choice) async {
        final chatProvider = context.read<ChatProvider>();

        switch (choice) {
          case 'new_chat':
            await chatProvider.createNewChat();
            break;

          case 'chat_list':
            _showChatsDialog(context);
            break;
          case 'settings':
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ProviderSettingsPage(),
              ),
            );
            break;

          case 'tokens':
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const TokenStatisticsPage(),
              ),
            );
            break;

          case 'chart':
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AnalyticsChartPage(),
              ),
            );
            break;
          case 'export':
            final path = await chatProvider.exportMessagesAsJson();

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'История сохранена в: $path',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            }

            break;

          case 'logs':
            final path = await chatProvider.exportLogs();

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Логи сохранены в: $path',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            }

            break;

          case 'clear':
            _showClearHistoryDialog(context);
            break;
        }
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem<String>(
          value: 'new_chat',
          height: 40,
          child: Text(
            '+ Новый чат',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),

        const PopupMenuItem<String>(
          value: 'chat_list',
          height: 40,
          child: Text(
            'Список чатов',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
        
        const PopupMenuItem<String>(
          value: 'settings',
          height: 40,
          child: Text(
            'Настройки',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),

        const PopupMenuItem<String>(
          value: 'tokens',
          height: 40,
          child: Text(
            'Статистика токенов',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),

        const PopupMenuItem<String>(
          value: 'chart',
          height: 40,
          child: Text(
            'График расходов',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
        
        const PopupMenuItem<String>(
          value: 'export',
          height: 40,
          child: Text(
            'Экспорт истории',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'logs',
          height: 40,
          child: Text(
            'Скачать логи',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'clear',
          height: 40,
          child: Text(
            'Очистить историю',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildMessagesList() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          reverse: false,
          itemCount: chatProvider.messages.length,
          itemBuilder: (context, index) {
            final message = chatProvider.messages[index];

            return _MessageBubble(
              message: message,
              messages: chatProvider.messages,
              index: index,
            );
          },
        );
      },
    );
  }

  Widget _buildInputArea(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      color: const Color(0xFF2A1208),
      child: Row(
        children: [
          Expanded(
            child: _MessageInput(
              onSubmitted: (String text) {
                if (text.trim().isNotEmpty) {
                  context.read<ChatProvider>().sendMessage(text);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      color: const Color(0xFF2A1208),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            context: context,
            icon: Icons.save,
            label: 'Сохранить',
            color: const Color(0xFFFF5722),
            onPressed: () async {
              final path =
                  await context.read<ChatProvider>().exportMessagesAsJson();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'История сохранена в: $path',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
          _buildActionButton(
            context: context,
            icon: Icons.analytics,
            label: 'Аналитика',
            color: const Color(0xFFDD6B20),
            onPressed: () => _showAnalyticsDialog(context),
          ),
          _buildActionButton(
            context: context,
            icon: Icons.delete,
            label: 'Очистить',
            color: const Color(0xFFCC3333),
            onPressed: () => _showClearHistoryDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 32,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
        ),
      ),
    );
  }

  void _showAnalyticsDialog(BuildContext context) {
  final chatProvider = context.read<ChatProvider>();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF2A1208),
        title: const Text(
          'Статистика',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Всего сообщений: ${chatProvider.messages.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                'Баланс: ${chatProvider.balance}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              const Text(
                'Использование по моделям:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              ...chatProvider.messages
                  .fold<Map<String, Map<String, dynamic>>>(
                    {},
                    (map, msg) {
                      if (msg.modelId != null) {
                        if (!map.containsKey(msg.modelId)) {
                          map[msg.modelId!] = {
                            'count': 0,
                            'tokens': 0,
                            'cost': 0.0,
                          };
                        }

                        map[msg.modelId]!['count'] =
                            map[msg.modelId]!['count']! + 1;

                        if (msg.tokens != null) {
                          map[msg.modelId]!['tokens'] =
                              map[msg.modelId]!['tokens']! + msg.tokens!;
                        }

                        if (msg.cost != null) {
                          map[msg.modelId]!['cost'] =
                              map[msg.modelId]!['cost']! + msg.cost!;
                        }
                      }

                      return map;
                    },
                  )
                  .entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Сообщений: ${entry.value['count']}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          if (entry.value['tokens'] > 0) ...[
                            Text(
                              'Токенов: ${entry.value['tokens']}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Consumer<ChatProvider>(
                              builder: (context, chatProvider, child) {
                                final rawCost =
                                    (entry.value['cost'] ?? 0.0) as double;

                                return Text(
                                  'Стоимость: ${_formatAnalyticsCost(chatProvider, rawCost)}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Закрыть',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      );
    },
  );
}

void _showChatsDialog(BuildContext context) {
  final chatProvider = context.read<ChatProvider>();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF2A1208),
        title: const Text(
          'Чаты',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        content: SizedBox(
          width: 420,
          child: Consumer<ChatProvider>(
            builder: (context, provider, child) {
              return ListView.builder(
                shrinkWrap: true,
                itemCount: provider.chats.length,
                itemBuilder: (context, index) {
                  final chat = provider.chats[index];

                  final isCurrent =
                      provider.currentChat?.id == chat.id;

                  return ListTile(
                    title: Text(
                      chat.title,
                      style: TextStyle(
                        color: isCurrent
                            ? Colors.orange
                            : Colors.white,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      '${chat.messages.length} сообщений',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    leading: Icon(
                      Icons.chat_bubble_outline,
                      color: isCurrent
                          ? Colors.orange
                          : Colors.white54,
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () async {
                        await provider.deleteChat(chat.id);

                        if (context.mounted &&
                            provider.chats.isEmpty) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    onTap: () async {
                      await provider.switchChat(chat.id);

                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await chatProvider.createNewChat();

              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text(
              '+ Новый чат',
              style: TextStyle(
                color: Colors.orange,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Закрыть',
              style: TextStyle(
                color: Colors.white70,
              ),
            ),
          ),
        ],
      );
    },
  );
}


  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A1208),
          title: const Text(
            'Очистить историю',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          content: const Text(
            'Вы уверены? Это действие нельзя отменить.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Отмена',
                style: TextStyle(fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: () {
                context.read<ChatProvider>().clearHistory();
                Navigator.of(context).pop();
              },
              child: const Text(
                'Очистить',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
  }
}