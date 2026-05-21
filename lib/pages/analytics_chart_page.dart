import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';

class AnalyticsChartPage extends StatelessWidget {
  const AnalyticsChartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0F0A),
      appBar: AppBar(
        title: const Text('График расходов'),
        backgroundColor: const Color(0xFF2A1208),
        foregroundColor: Colors.white,
      ),
      body: Consumer<ChatProvider>(
        builder: (context, provider, child) {
          final totalCost = provider.messages.fold<double>(
            0.0,
            (sum, msg) => sum + ((msg.cost ?? 0.0) / 1000),
          );

          final spots = <FlSpot>[
            FlSpot(1, totalCost),
          ];

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'Расходы за текущий день: ${totalCost.toStringAsFixed(4)}',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 30),
                Expanded(
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: 2,
                      minY: 0,
                      gridData: const FlGridData(show: true),
                      titlesData: const FlTitlesData(show: true),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          barWidth: 4,
                          dotData: const FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}