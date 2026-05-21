import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class UsageStatsService {
  static const String _dailyCostsKey = 'daily_costs';

  Future<void> addCost(double cost) async {
    if (cost <= 0) return;

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final rawData = prefs.getString(_dailyCostsKey);
    final Map<String, dynamic> data =
        rawData == null ? {} : jsonDecode(rawData);

    final currentValue = (data[today] ?? 0.0).toDouble();

    data[today] = currentValue + cost;

    await prefs.setString(_dailyCostsKey, jsonEncode(data));
  }

  Future<Map<String, double>> getDailyCosts() async {
    final prefs = await SharedPreferences.getInstance();
    final rawData = prefs.getString(_dailyCostsKey);

    if (rawData == null) {
      return {};
    }

    final Map<String, dynamic> data = jsonDecode(rawData);

    return data.map(
      (key, value) => MapEntry(
        key,
        double.tryParse(value.toString()) ?? 0.0,
      ),
    );
  }

  Future<void> clearStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dailyCostsKey);
  }
}