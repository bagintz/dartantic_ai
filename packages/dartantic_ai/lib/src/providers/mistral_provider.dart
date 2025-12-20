import 'dart:convert';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../chat_models/chat_utils.dart';
import '../chat_models/mistral_chat/mistral_chat_model.dart';
import '../chat_models/mistral_chat/mistral_chat_options.dart';
import '../embeddings_models/mistral_embeddings/mistral_embeddings.dart';
import '../platform/platform.dart';
import '../retry_http_client.dart';

/// Provider for Mistral AI (OpenAI-compatible).
class MistralProvider
    extends
        Provider<
          MistralChatModelOptions,
          MistralEmbeddingsModelOptions,
          MediaGenerationModelOptions
        > {
  /// Creates a new Mistral provider instance.
  ///
  /// [apiKey]: The API key for the Mistral provider.
  MistralProvider({String? apiKey, super.headers})
    : super(
        apiKey: apiKey ?? tryGetEnv(defaultApiKeyName),
        name: 'mistral',
        displayName: 'Mistral',
        defaultModelNames: {
          ModelKind.chat: 'open-mistral-7b',
          ModelKind.embeddings: 'mistral-embed',
        },
        baseUrl: null,
        aliases: ['mistralai'],
      );

  static final Logger _logger = Logger('dartantic.chat.providers.mistral');

  /// The default API key name for Mistral.
  static const defaultApiKeyName = 'MISTRAL_API_KEY';

  /// The default base URL for the Mistral API.
  static final defaultBaseUrl = Uri.parse('https://api.mistral.ai/v1');

  @override
  ChatModel<MistralChatModelOptions> createChatModel({
    String? name,
    List<Tool>? tools,
    double? temperature,
    bool enableThinking = false,
    MistralChatModelOptions? options,
  }) {
    if (enableThinking) {
      throw UnsupportedError(
        'Extended thinking is not supported by the $displayName provider. '
        'Only OpenAI Responses, Anthropic, and Google providers support '
        'thinking. Set enableThinking=false or use a provider that supports '
        'this feature.',
      );
    }

    final modelName = name ?? defaultModelNames[ModelKind.chat]!;
    _logger.info(
      'Creating Mistral model: $modelName with ${tools?.length ?? 0} tools, '
      'temp: $temperature',
    );

    if (apiKeyName != null && (apiKey == null || apiKey!.isEmpty)) {
      throw ArgumentError('$apiKeyName is required for $displayName provider');
    }

    return MistralChatModel(
      name: modelName,
      tools: tools,
      temperature: temperature,
      apiKey: apiKey!,
      baseUrl: baseUrl,
      headers: headers,
      defaultOptions: MistralChatModelOptions(
        topP: options?.topP,
        maxTokens: options?.maxTokens,
        safePrompt: options?.safePrompt,
        randomSeed: options?.randomSeed,
      ),
    );
  }

  @override
  EmbeddingsModel<MistralEmbeddingsModelOptions> createEmbeddingsModel({
    String? name,
    MistralEmbeddingsModelOptions? options,
  }) {
    final modelName = name ?? defaultModelNames[ModelKind.embeddings]!;
    _logger.info('Creating Mistral embeddings model: $modelName');

    if (apiKeyName != null && (apiKey == null || apiKey!.isEmpty)) {
      throw ArgumentError('$apiKeyName is required for $displayName provider');
    }

    return MistralEmbeddingsModel(
      name: modelName,
      apiKey: apiKey!,
      baseUrl: baseUrl,
      headers: headers,
      dimensions: options?.dimensions,
      batchSize: options?.batchSize,
      options: options,
    );
  }

  @override
  Future<List<ModelCaps>?> fetchModelCaps(
    String modelName, [
    Map<String, dynamic>? modelData,
  ]) async {
    // If we already have model data (from listModels), use it directly
    if (modelData != null) {
      return _extractCapsFromModelData(modelName, modelData);
    }

    // Otherwise, fetch from Mistral API which returns rich capability data
    final resolvedBaseUrl = baseUrl ?? defaultBaseUrl;
    final url = appendPath(resolvedBaseUrl, 'models');
    _logger.info('Fetching model capabilities from Mistral API: $url');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $apiKey'},
    );

    if (response.statusCode != 200) {
      _logger.warning(
        'Failed to fetch models: HTTP ${response.statusCode}, '
        'body: ${response.body}',
      );
      // Fall back to heuristics
      return _heuristicCaps(modelName);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final modelsList = data['data'] as List?;
    if (modelsList == null) {
      return _heuristicCaps(modelName);
    }

    // Find the matching model
    for (final m in modelsList.cast<Map<String, dynamic>>()) {
      final id = m['id'] as String? ?? '';
      if (id == modelName || id.toLowerCase() == modelName.toLowerCase()) {
        return _extractCapsFromModelData(modelName, m);
      }
    }

    // Model not found in API response, fall back to heuristics
    return _heuristicCaps(modelName);
  }

  /// Extract capabilities from Mistral model data.
  ///
  /// Mistral's API returns a capabilities object with boolean fields:
  /// - completion_chat: Chat completion support
  /// - function_calling: Tool/function calling support
  /// - vision: Image/vision input support
  /// - audio: Audio input/output support
  /// - completion_fim: Fill-in-the-middle support
  /// - fine_tuning: Fine-tuning support
  /// - ocr: OCR support
  /// - classification: Classification support
  /// - moderation: Content moderation support
  List<ModelCaps> _extractCapsFromModelData(
    String modelName,
    Map<String, dynamic> modelData,
  ) {
    final caps = <ModelCaps>{};
    final capabilities =
        modelData['capabilities'] as Map<String, dynamic>? ?? {};
    final id = (modelData['id'] as String? ?? modelName).toLowerCase();
    // Chat capability
    if (capabilities['completion_chat'] == true) {
      caps.add(ModelCaps.chat);
    }

    // Vision capability
    if (capabilities['vision'] == true) {
      caps.add(ModelCaps.chatVision);
    }

    // Tool calling capability
    if (capabilities['function_calling'] == true) {
      caps.add(ModelCaps.multiToolCalls);
      // Mistral models with function calling generally support typed output
      caps.add(ModelCaps.typedOutput);
      caps.add(ModelCaps.typedOutputWithTools);
    }

    // Audio capability
    if (capabilities['audio'] == true) {
      caps.add(ModelCaps.audio);
    }

    // Embedding models (completion_chat is false but model name contains embed)
    if (capabilities['completion_chat'] != true && id.contains('embed')) {
      caps.add(ModelCaps.embeddings);
    }

    // Reasoning/thinking capability for Magistral models
    // Mistral doesn't expose a "reasoning" capability flag, but Magistral
    // models are their reasoning-focused models
    if (id.contains('magistral')) {
      caps.add(ModelCaps.thinking);
    }

    return caps.toList();
  }

  /// Heuristic-based capability detection for when API data is unavailable.
  List<ModelCaps> _heuristicCaps(String modelName) {
    final id = modelName.toLowerCase();
    final caps = <ModelCaps>{};

    // Embedding models
    if (id.contains('embed')) {
      caps.add(ModelCaps.embeddings);
      return caps.toList();
    }

    // Chat models (mistral, mixtral, codestral, ministral, pixtral, magistral)
    if (id.contains('mistral') ||
        id.contains('mixtral') ||
        id.contains('codestral') ||
        id.contains('ministral') ||
        id.contains('pixtral') ||
        id.contains('magistral')) {
      caps.add(ModelCaps.chat);
      caps.add(ModelCaps.multiToolCalls);
      caps.add(ModelCaps.typedOutput);
      caps.add(ModelCaps.typedOutputWithTools);

      // Vision models (pixtral, and newer mistral-large/medium with vision)
      if (id.contains('pixtral') ||
          id.contains('vision') ||
          id.contains('large') ||
          id.contains('medium')) {
        caps.add(ModelCaps.chatVision);
      }

      // Reasoning models (magistral)
      if (id.contains('magistral')) {
        caps.add(ModelCaps.thinking);
      }
    }

    return caps.toList();
  }

  @override
  Stream<ModelInfo> listModels() async* {
    final resolvedBaseUrl = baseUrl ?? defaultBaseUrl;
    final url = appendPath(resolvedBaseUrl, 'models');
    _logger.info('Fetching models from Mistral API: $url');
    final client = RetryHttpClient(inner: http.Client());
    try {
      final response = await client.get(
        url,
        headers: {'Authorization': 'Bearer $apiKey', ...headers},
      );
      if (response.statusCode != 200) {
        _logger.warning(
          'Failed to fetch models: HTTP ${response.statusCode}, '
          'body: ${response.body}',
        );
        throw Exception('Failed to fetch Mistral models: ${response.body}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final modelCount = (data['data'] as List).length;
      _logger.info('Successfully fetched $modelCount models from Mistral API');
      for (final m in (data['data'] as List).cast<Map<String, dynamic>>()) {
        final idField = m['id'];
        if (idField is! String || idField.isEmpty) {
          _logger.warning(
            'Mistral model has missing or invalid id field '
            '(expected non-empty String): $m',
          );
        }
        final id = idField is String ? idField : '';
        final desc = m['description'] as String? ?? '';
        final kinds = <ModelKind>{};
        // Embedding models
        if (id.contains('embed') || desc.contains('embed')) {
          kinds.add(ModelKind.embeddings);
        }
        // Magistral: always chat unless embedding
        if (id.contains('magistral') && !kinds.contains(ModelKind.embeddings)) {
          kinds.add(ModelKind.chat);
        }
        // Mistral, Mixtral, Codestral: chat unless embedding
        if ((id.contains('mistral') ||
                id.contains('mixtral') ||
                id.contains('codestral')) &&
            !id.contains('embed') &&
            !kinds.contains(ModelKind.embeddings)) {
          kinds.add(ModelKind.chat);
        }
        // Moderation and OCR: treat as chat
        if (id.contains('moderation') || id.contains('ocr')) {
          kinds.add(ModelKind.chat);
        }
        // Ministral: not officially documented, mark as other
        if (id.contains('ministral')) {
          kinds
            ..clear()
            ..add(ModelKind.other);
        }

        // Pixtral: not officially documented, mark as other
        if (id.contains('pixtral')) {
          kinds
            ..clear()
            ..add(ModelKind.other);
        }
        if (kinds.isEmpty) kinds.add(ModelKind.other);
        assert(kinds.isNotEmpty, 'Model $id returned with empty kinds set');
        yield ModelInfo(
          name: id,
          providerName: name,
          kinds: kinds,
          displayName: m['name'] as String?,
          description: desc.isNotEmpty ? desc : null,
          extra: {
            ...m,
            if (m.containsKey('context_length'))
              'contextWindow': m['context_length'],
          }..removeWhere((k, _) => ['id', 'name', 'description'].contains(k)),
        );
      }
    } finally {
      client.close();
    }
  }

  @override
  MediaGenerationModel<MediaGenerationModelOptions> createMediaModel({
    String? name,
    List<Tool>? tools,
    MediaGenerationModelOptions? options,
  }) {
    throw UnsupportedError(
      'Mistral provider does not support media generation',
    );
  }
}
