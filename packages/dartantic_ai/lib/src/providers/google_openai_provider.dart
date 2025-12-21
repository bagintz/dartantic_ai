import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:logging/logging.dart';

import '../chat_models/openai_chat/openai_chat_model.dart';
import '../chat_models/openai_chat/openai_chat_options.dart';
import '../platform/platform.dart';
import 'google_provider.dart';
import 'openai_provider_base.dart';

/// Provider for Google Gemini via OpenAI-compatible API.
///
/// This provider uses Google's OpenAI-compatible endpoint at
/// `https://generativelanguage.googleapis.com/v1beta/openai` but serves
/// Gemini models. Since the OpenAI heuristics don't work for Gemini model
/// names, we use Gemini-specific heuristics for capability detection.
class GoogleOpenAIProvider extends OpenAIProviderBase<OpenAIChatOptions, MediaGenerationModelOptions> {
  /// Creates a new Google OpenAI-compatible provider instance.
  GoogleOpenAIProvider({
    String? apiKey,
    super.name = 'google-openai',
    super.displayName = 'Google AI (OpenAI-compatible)',
    super.defaultModelNames = const {
      ModelKind.chat: 'gemini-2.5-flash',
      ModelKind.embeddings: 'text-embedding-004',
    },
    super.aliases,
  }) : super(
         apiKey: apiKey ?? tryGetEnv(GoogleProvider.defaultApiKeyName),
         baseUrl: defaultBaseUrl,
         apiKeyName: GoogleProvider.defaultApiKeyName,
       );

  static final Logger _logger =
      Logger('dartantic.chat.providers.google_openai');

  @override
  Logger get logger => _logger;

  /// The default base URL for the Google OpenAI-compatible API.
  static final defaultBaseUrl = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/openai',
  );

  @override
  ChatModel<OpenAIChatOptions> createChatModel({
    String? name,
    List<Tool>? tools,
    double? temperature,
    bool enableThinking = false,
    OpenAIChatOptions? options,
  }) {
    validateApiKeyPresence();
    final modelName = name ?? defaultModelNames[ModelKind.chat]!;

    _logger.info(
      'Creating Google OpenAI-compatible model: $modelName with '
      '${tools?.length ?? 0} tools, '
      'temperature: $temperature',
    );

    return OpenAIChatModel(
      name: modelName,
      tools: tools,
      temperature: temperature,
      apiKey: apiKey ?? tryGetEnv(apiKeyName),
      baseUrl: baseUrl,
      defaultOptions: OpenAIChatOptions(
        temperature: temperature ?? options?.temperature,
        topP: options?.topP,
        n: options?.n,
        maxTokens: options?.maxTokens,
        presencePenalty: options?.presencePenalty,
        frequencyPenalty: options?.frequencyPenalty,
        logitBias: options?.logitBias,
        stop: options?.stop,
        user: options?.user,
        responseFormat: options?.responseFormat,
        seed: options?.seed,
        parallelToolCalls: options?.parallelToolCalls,
        streamOptions: options?.streamOptions,
        serviceTier: options?.serviceTier,
      ),
    );
  }

  @override
  Future<List<ModelCaps>?> fetchModelCaps(
    String modelName, [
    Map<String, dynamic>? modelData,
  ]) async {
    // Use heuristics based on Gemini model naming patterns since
    // Google's OpenAI-compatible endpoint doesn't expose capability metadata.
    final id = modelName.toLowerCase();
    final caps = <ModelCaps>{};

    // Embedding models
    if (id.contains('embedding')) {
      caps.add(ModelCaps.embeddings);
      return caps.toList();
    }

    // Text-to-Speech models (if any)
    if (id.contains('tts')) {
      caps.add(ModelCaps.tts);
      return caps.toList();
    }

    // Image generation models (Imagen)
    if (id.contains('imagen')) {
      caps.add(ModelCaps.image);
      return caps.toList();
    }

    // All Gemini chat models
    if (id.contains('gemini')) {
      caps.add(ModelCaps.chat);

      // All Gemini models support vision (multimodal)
      caps.add(ModelCaps.chatVision);

      // All Gemini models support tool calling
      caps.add(ModelCaps.multiToolCalls);

      // All Gemini models support structured output
      caps.add(ModelCaps.typedOutput);
      caps.add(ModelCaps.typedOutputWithTools);

      // Gemini 2.5+ Flash/Pro with thinking mode
      if (id.contains('2.5') || id.contains('2.0')) {
        // Most 2.0+ models support thinking
        if (id.contains('flash') || id.contains('pro')) {
          caps.add(ModelCaps.thinking);
        }
      }

      // Audio support for specific models
      if (id.contains('audio') || id.contains('live')) {
        caps.add(ModelCaps.audio);
      }

      return caps.toList();
    }

    // LearnLM models (educational)
    if (id.contains('learnlm')) {
      caps.add(ModelCaps.chat);
      caps.add(ModelCaps.chatVision);
      caps.add(ModelCaps.multiToolCalls);
      caps.add(ModelCaps.typedOutput);
      caps.add(ModelCaps.typedOutputWithTools);
      return caps.toList();
    }

    // AQA (Attributed Question Answering) models
    if (id.contains('aqa')) {
      caps.add(ModelCaps.chat);
      return caps.toList();
    }

    // Default: assume chat capability
    caps.add(ModelCaps.chat);
    return caps.toList();
  }
}
