import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';

class TokenStatisticsPage extends StatelessWidget {
  const TokenStatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0F0A),
      appBar: AppBar(
        title: const Text('Статистика токенов'),
        backgroundColor: const Color(0xFF2A1208),
        foregroundColor: Colors.white,
      ),
      body: Consumer<ChatProvider>(
        builder: (context, provider, child) {
          final modelStats = <String, Map<String, dynamic>>{};

          for (final msg in provider.messages) {
            if (msg.modelId == null) continue;

            modelStats.putIfAbsent(
              msg.modelId!,
              () => {
                'count': 0,
                'tokens': 0,
                'cost': 0.0,
              },
            );

            modelStats[msg.modelId]!['count'] += 1;

            if (msg.tokens != null) {
              modelStats[msg.modelId]!['tokens'] +=
                  msg.tokens!;
            }

            if (msg.cost != null) {
              modelStats[msg.modelId]!['cost'] +=
                  msg.cost!;
            }
          }

          if (modelStats.isEmpty) {
            return const Center(
              child: Text(
                'Нет данных',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: modelStats.entries.map((entry) {
              return Card(
                color: const Color(0xFF2A1208),
                margin: const EdgeInsets.only(
                  bottom: 14,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'Сообщений: ${entry.value['count']}',
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),

                      Text(
                        'Токенов: ${entry.value['tokens']}',
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),

                      Text(
                        'Стоимость: ${entry.value['cost'].toStringAsFixed(4)}',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}