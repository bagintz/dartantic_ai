import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import '../chat_models/chat_utils.dart';
import '../embeddings_models/openai_embeddings/openai_embeddings_model.dart';
import '../embeddings_models/openai_embeddings/openai_embeddings_model_options.dart';
import '../platform/platform.dart';
import '../shared/openai_utils.dart';

/// Shared OpenAI provider functionality for canonical and Responses variants.
abstract class OpenAIProviderBase<
  TChatOptions extends ChatModelOptions,
  TMediaOptions extends MediaGenerationModelOptions
>
    extends
        Provider<TChatOptions, OpenAIEmbeddingsModelOptions, TMediaOptions> {
  /// Common constructor for OpenAI providers.
  OpenAIProviderBase({
    required super.name,
    required super.displayName,
    required super.defaultModelNames,
    super.baseUrl,
    super.apiKeyName,
    super.apiKey,
    super.aliases,
    super.headers,
  });

  /// Logger used by subclasses for shared operations.
  Logger get logger;

  /// Base URL used when an explicit embeddings endpoint is not provided.
  Uri get defaultRestBaseUrl => Uri.parse('https://api.openai.com/v1');

  /// Resolved base URL for embeddings API calls.
  ///
  /// Subclasses may override to point at a different endpoint than [baseUrl].
  @protected
  Uri get embeddingsApiBaseUrl => baseUrl ?? defaultRestBaseUrl;

  /// Resolved base URL for listing models.
  @protected
  Uri get modelsApiBaseUrl => baseUrl ?? defaultRestBaseUrl;

  @override
  EmbeddingsModel<OpenAIEmbeddingsModelOptions> createEmbeddingsModel({
    String? name,
    OpenAIEmbeddingsModelOptions? options,
  }) {
    validateApiKeyPresence();

    final modelName = name ?? defaultModelNames[ModelKind.embeddings]!;
    logger.info('Creating $displayName embeddings model: $modelName');

    final resolvedOptions = OpenAIEmbeddingsModelOptions(
      dimensions: options?.dimensions,
      batchSize: options?.batchSize,
      user: options?.user,
    );

    return OpenAIEmbeddingsModel(
      name: modelName,
      apiKey: apiKey,
      baseUrl: embeddingsApiBaseUrl,
      headers: headers,
      dimensions: options?.dimensions,
      batchSize: options?.batchSize,
      options: resolvedOptions,
    );
  }

  @override
  MediaGenerationModel<TMediaOptions> createMediaModel({
    String? name,
    List<Tool>? tools,
    TMediaOptions? options,
  }) {
    throw UnsupportedError('$displayName does not support media generation.');
  }

  @override
  Future<List<ModelCaps>?> fetchModelCaps(String modelName, [Map<String, dynamic>? modelData]) async {
    if (modelData != null && modelData.isNotEmpty) {
      return _parseModelCaps(modelData);
    }

    try {
      validateApiKeyPresence();
      final resolvedApiKey = apiKey ?? tryGetEnv(apiKeyName);
      if (resolvedApiKey == null || resolvedApiKey.isEmpty) {
        return null;
      }

      final resolvedBaseUrl = modelsApiBaseUrl;
      final url = appendPath(resolvedBaseUrl, 'models/$modelName');
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $resolvedApiKey',
        ...headers,
      });

      if (response.statusCode != 200) {
        logger.warning('Failed to get model details for $modelName: HTTP ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return _parseModelCaps(data);
      return null;
    } on Exception catch (e) {
      logger.warning('Error fetching model caps for $modelName: $e');
      return null;
    }
  }

  List<ModelCaps> _parseModelCaps(Map<String, dynamic> data) {
    final caps = <ModelCaps>{};
    // Some APIs return a direct model object, others include a 'data' map
    final model = data['data'] is Map<String, dynamic> ? data['data'] as Map<String, dynamic> : data;
    final id = (model['id'] as String?)?.toLowerCase() ?? '';
    final description = (model['description'] as String?)?.toLowerCase() ?? '';

    // Heuristic checks
    if (id.contains('embed') || description.contains('embed')) {
      caps.add(ModelCaps.embeddings);
    }
    if (id.contains('vision') || id.contains('image') || description.contains('vision') || description.contains('image')) {
      caps.add(ModelCaps.chatVision);
    }
    // Known GPT-4o / multimodal models are vision-capable even if the
    // model description doesn't include explicit keywords.
    if (id.contains('gpt-4o') || id.contains('gpt-4.1') || id.contains('gpt-4-turbo') || id.contains('gpt-5')) {
      caps.add(ModelCaps.chatVision);
    }
    if (id.contains('audio') || description.contains('audio') || id.contains('whisper')) {
      caps.add(ModelCaps.audio);
    }
    if (id.contains('count-tokens') || description.contains('count tokens')) {
      caps.add(ModelCaps.countTokens);
    }

    // Chat-capable models by pattern
    if (!caps.contains(ModelCaps.embeddings)) {
      if (id.contains('gpt') || id.contains('chat') || id.contains('turbo') || id.contains('command')) {
        caps.add(ModelCaps.chat);
      }
    }

    // Tools and typed output: many OpenAI chat models support function-calling
    // and structured outputs; we add these heuristically for chat models.
    if (caps.contains(ModelCaps.chat)) {
      caps.add(ModelCaps.multiToolCalls);
      caps.add(ModelCaps.typedOutput);
      caps.add(ModelCaps.typedOutputWithTools);
    }

    // Reasoning / thinking heuristics
    if (id.contains('reason') || id.contains('think') || description.contains('reason')) {
      caps.add(ModelCaps.thinking);
    }

    return caps.toList();
  }

  @override
  Stream<ModelInfo> listModels() async* {
    validateApiKeyPresence();
    yield* OpenAIUtils.listOpenAIModels(
      baseUrl: modelsApiBaseUrl,
      providerName: name,
      logger: logger,
      apiKey: apiKey,
      headers: headers,
    );
  }

  /// Throws if an API key is required but missing.
  @protected
  void validateApiKeyPresence() {
    if (apiKeyName != null && (apiKey == null || apiKey!.isEmpty)) {
      throw ArgumentError('$apiKeyName is required for $displayName provider');
    }
  }
}
