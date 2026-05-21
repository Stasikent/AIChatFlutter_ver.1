import 'dart:convert';

import 'package:flutter/services.dart';

class VsegptAccessService {
  Set<String> _basicModels = {};
  Set<String> _professionalModels = {};

  bool _isLoaded = false;

  Future<void> loadModels() async {
    if (_isLoaded) return;

    final raw = await rootBundle.loadString(
      'assets/models/vsegpt_models.json',
    );

    final data = jsonDecode(raw);

    _basicModels = (data['basic'] as List)
        .map((model) => model.toString().toLowerCase())
        .toSet();

    _professionalModels = (data['professional'] as List)
        .map((model) => model.toString().toLowerCase())
        .toSet();

    _isLoaded = true;
  }

  String detectSubscriptionLevel({
    required String? subscriptionStatus,
    required int? userStatus,
    required String? userStatusText,
  }) {
    if (subscriptionStatus == 'ok') {
      return 'professional';
    }

    if (userStatus != null && userStatus > 0) {
      return 'professional';
    }

    return 'basic';
  }

  bool isModelAvailable({
    required String modelId,
    required String subscriptionLevel,
  }) {
    final id = modelId.toLowerCase();

    if (subscriptionLevel == 'professional') {
      return _basicModels.contains(id) || _professionalModels.contains(id);
    }

    return _basicModels.contains(id);
  }

  String accessLabel({
    required String modelId,
    required String subscriptionLevel,
  }) {
    final available = isModelAvailable(
      modelId: modelId,
      subscriptionLevel: subscriptionLevel,
    );

    if (available) {
      return 'Доступно';
    }

    return 'Недоступно для текущего тарифа VSEGPT';
  }
}