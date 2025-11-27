import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import '../embeddings_models/openai_embeddings/openai_embeddings_model.dart';
import '../embeddings_models/openai_embeddings/openai_embeddings_model_options.dart';
import '../shared/openai_utils.dart';

/// Shared OpenAI provider functionality for canonical and Responses variants.
abstract class OpenAIProviderBase<TChatOptions extends ChatModelOptions>
    extends Provider<TChatOptions, OpenAIEmbeddingsModelOptions> {
  /// Common constructor for OpenAI providers.
  OpenAIProviderBase({
    required super.name,
    required super.displayName,
    required super.defaultModelNames,
    required super.caps,
    super.baseUrl,
    super.apiKeyName,
    super.apiKey,
    super.aliases,
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
      dimensions: options?.dimensions,
      batchSize: options?.batchSize,
      options: resolvedOptions,
    );
  }

  @override
  Stream<ModelInfo> listModels() async* {
    validateApiKeyPresence();
    await for (final modelInfo in OpenAIUtils.listOpenAIModels(
      baseUrl: modelsApiBaseUrl,
      providerName: name,
      logger: logger,
      apiKey: apiKey,
    )) {
      // Enrich each model with capability information
      final caps = await getModelCaps(modelInfo.name, modelInfo.extra);
      yield ModelInfo(
        name: modelInfo.name,
        providerName: modelInfo.providerName,
        kinds: modelInfo.kinds,
        displayName: modelInfo.displayName,
        description: modelInfo.description,
        caps: caps,
        extra: modelInfo.extra,
      );
    }
  }

  /// Throws if an API key is required but missing.
  @protected
  void validateApiKeyPresence() {
    if (apiKeyName != null && (apiKey == null || apiKey!.isEmpty)) {
      throw ArgumentError('$apiKeyName is required for $displayName provider');
    }
  }

  @override
  Future<List<ModelCaps>?> fetchModelCaps(
    String modelName, [
    Map<String, dynamic>? modelData,
  ]) async {
    // OpenAI's /v1/models endpoint only returns basic metadata (id, object,
    // created, owned_by) - no capability information. We use heuristics based
    // on model ID patterns which is the industry standard approach.
    final id = modelName.toLowerCase();
    final caps = <ModelCaps>{};

    // Embedding models
    if (id.contains('embedding')) {
      caps.add(ModelCaps.embeddings);
      return caps.toList();
    }

    // TTS (text-to-speech) models
    if (id.startsWith('tts-') || id.contains('-tts')) {
      caps.add(ModelCaps.tts);
      return caps.toList();
    }

    // Whisper (speech-to-text/transcription) models
    if (id.contains('whisper')) {
      caps.add(ModelCaps.audio);
      return caps.toList();
    }

    // DALL-E and GPT-Image (image generation) models
    if (id.contains('dall-e') || id.startsWith('gpt-image')) {
      caps.add(ModelCaps.image);
      return caps.toList();
    }

    // Moderation models - not really a "capability" we track
    if (id.contains('moderation')) {
      return caps.toList();
    }

    // Sora (video) models - not a capability we track yet
    if (id.startsWith('sora')) {
      return caps.toList();
    }

    // O-series reasoning models (o1, o3, o4)
    if (RegExp('^o[134]').hasMatch(id)) {
      caps.add(ModelCaps.chat);
      caps.add(ModelCaps.thinking);
      // O-series models support tools and structured outputs
      caps.add(ModelCaps.multiToolCalls);
      caps.add(ModelCaps.typedOutput);
      caps.add(ModelCaps.typedOutputWithTools);
      return caps.toList();
    }

    // GPT-5 models (with reasoning capabilities)
    if (id.startsWith('gpt-5')) {
      caps.add(ModelCaps.chat);
      caps.add(ModelCaps.chatVision);
      caps.add(ModelCaps.thinking);
      caps.add(ModelCaps.multiToolCalls);
      caps.add(ModelCaps.typedOutput);
      caps.add(ModelCaps.typedOutputWithTools);
      return caps.toList();
    }

    // Audio-capable models (gpt-4o-audio, gpt-audio, realtime)
    if (id.contains('audio') || id.contains('realtime')) {
      caps.add(ModelCaps.chat);
      caps.add(ModelCaps.audio);
      caps.add(ModelCaps.multiToolCalls);
      caps.add(ModelCaps.typedOutput);
      caps.add(ModelCaps.typedOutputWithTools);
      return caps.toList();
    }

    // Transcribe models (gpt-4o-transcribe)
    if (id.contains('transcribe')) {
      caps.add(ModelCaps.audio);
      return caps.toList();
    }

    // GPT-4o and GPT-4.1 models (multimodal with vision)
    if (id.startsWith('gpt-4o') ||
        id.startsWith('gpt-4.1') ||
        id.startsWith('chatgpt-4o')) {
      caps.add(ModelCaps.chat);
      caps.add(ModelCaps.chatVision);
      caps.add(ModelCaps.multiToolCalls);
      caps.add(ModelCaps.typedOutput);
      caps.add(ModelCaps.typedOutputWithTools);
      return caps.toList();
    }

    // GPT-4 Turbo models (vision capable)
    if (id.startsWith('gpt-4-turbo') || id == 'gpt-4-vision-preview') {
      caps.add(ModelCaps.chat);
      caps.add(ModelCaps.chatVision);
      caps.add(ModelCaps.multiToolCalls);
      caps.add(ModelCaps.typedOutput);
      caps.add(ModelCaps.typedOutputWithTools);
      return caps.toList();
    }

    // GPT-4 base models (text only, but with tools)
    if (id.startsWith('gpt-4')) {
      caps.add(ModelCaps.chat);
      caps.add(ModelCaps.multiToolCalls);
      caps.add(ModelCaps.typedOutput);
      caps.add(ModelCaps.typedOutputWithTools);
      return caps.toList();
    }

    // GPT-3.5 models
    if (id.startsWith('gpt-3.5')) {
      caps.add(ModelCaps.chat);
      caps.add(ModelCaps.multiToolCalls);
      caps.add(ModelCaps.typedOutput);
      caps.add(ModelCaps.typedOutputWithTools);
      return caps.toList();
    }

    // Codex models (code generation)
    if (id.contains('codex')) {
      caps.add(ModelCaps.chat);
      caps.add(ModelCaps.multiToolCalls);
      caps.add(ModelCaps.typedOutput);
      caps.add(ModelCaps.typedOutputWithTools);
      return caps.toList();
    }

    // Legacy completion models (davinci, babbage, etc.)
    if (id.startsWith('davinci') ||
        id.startsWith('babbage') ||
        id.startsWith('curie') ||
        id.startsWith('ada')) {
      caps.add(ModelCaps.chat);
      return caps.toList();
    }

    // Default: assume it's a chat model if we don't recognize it
    // This handles fine-tuned models and new models we haven't categorized
    logger.fine(
      'Unknown OpenAI model pattern: $modelName, assuming chat capability',
    );
    caps.add(ModelCaps.chat);
    return caps.toList();
  }
}
