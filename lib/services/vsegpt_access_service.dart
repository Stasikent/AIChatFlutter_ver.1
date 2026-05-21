class VsegptAccessService {
  String detectSubscriptionLevel({
    required String? subscriptionStatus,
    required int? userStatus,
    required String? userStatusText,
  }) {
    if (subscriptionStatus == 'ok') {
      return 'subscription';
    }

    if (userStatus != null && userStatus > 0) {
      return 'subscription';
    }

    if (userStatusText != null && userStatusText.trim().isNotEmpty) {
      return userStatusText;
    }

    return 'basic';
  }

  bool isModelAvailable({
    required String modelId,
    required String subscriptionLevel,
  }) {
    final id = modelId.toLowerCase();

    if (subscriptionLevel == 'subscription') {
      return true;
    }

    final freeOrBasicModels = [
      'gpt-4.1-nano',
      'gpt-4o-mini',
      'deepseek',
      'qwen',
      'llama',
      'gemini-flash',
    ];

    return freeOrBasicModels.any((allowed) => id.contains(allowed));
  }

  String accessLabel({
    required String modelId,
    required String subscriptionLevel,
  }) {
    final isAvailable = isModelAvailable(
      modelId: modelId,
      subscriptionLevel: subscriptionLevel,
    );

    if (isAvailable) {
      return 'Доступно';
    }

    return 'Недоступно для текущей подписки';
  }
}