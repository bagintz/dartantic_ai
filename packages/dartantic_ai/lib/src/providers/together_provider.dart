import 'dart:convert';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../chat_models/openai_chat/openai_chat_model.dart';
import '../chat_models/openai_chat/openai_chat_options.dart';
import '../platform/platform.dart';
import 'openai_provider_base.dart';

/// Provider for Together AI API with capability detection via heuristics.
///
/// Together AI's /v1/models endpoint returns basic metadata (id, type,
/// context_length) but doesn't include explicit capability flags. We use
/// heuristics based on:
/// - Model `type` field: "chat", "image", "audio", "embedding", etc.
/// - Model naming patterns: "VL" suffix for vision-language models
/// - Documented function-calling support for specific models
///
/// See https://docs.together.ai/docs/function-calling for supported models.
class TogetherProvider extends OpenAIProviderBase<OpenAIChatOptions, MediaGenerationModelOptions> {
  /// Creates a new Together AI provider instance.
  TogetherProvider({
    String? apiKey,
    super.name = 'together',
    super.displayName = 'Together AI',
    super.defaultModelNames = const {
      ModelKind.chat: 'meta-llama/Llama-3.2-3B-Instruct-Turbo',
    },
    super.aliases,
  }) : super(
         apiKey: apiKey ?? tryGetEnv(defaultApiKeyName),
         baseUrl: defaultBaseUrl,
         apiKeyName: defaultApiKeyName,
       );

  static final Logger _logger = Logger('dartantic.chat.providers.together');

  @override
  Logger get logger => _logger;

  /// The environment variable for the API key.
  static const defaultApiKeyName = 'TOGETHER_API_KEY';

  /// The default base URL for the Together AI API.
  static final defaultBaseUrl = Uri.parse('https://api.together.xyz/v1');

  /// Models documented to support function calling.
  /// From: https://docs.together.ai/docs/function-calling#supported-models
  static const _functionCallingModels = <String>{
    'openai/gpt-oss-120b',
    'openai/gpt-oss-20b',
    'moonshotai/Kimi-K2-Thinking',
    'moonshotai/Kimi-K2-Instruct-0905',
    'moonshotai/Kimi-K2-Instruct',
    'zai-org/GLM-4.5-Air-FP8',
    'zai-org/GLM-4.6',
    'Qwen/Qwen3-Next-80B-A3B-Instruct',
    'Qwen/Qwen3-Next-80B-A3B-Thinking',
    'Qwen/Qwen3-235B-A22B-Thinking-2507',
    'Qwen/Qwen3-Coder-480B-A35B-Instruct-FP8',
    'Qwen/Qwen3-235B-A22B-fp8-tput',
    'Qwen/Qwen3-235B-A22B-Instruct-2507-tput',
    'deepseek-ai/DeepSeek-R1',
    'deepseek-ai/DeepSeek-R1-0528-tput',
    'deepseek-ai/DeepSeek-V3',
    'deepseek-ai/DeepSeek-V3.1',
    'meta-llama/Llama-4-Maverick-17B-128E-Instruct-FP8',
    'meta-llama/Llama-4-Scout-17B-16E-Instruct',
    'meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo',
    'meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo',
    'meta-llama/Meta-Llama-3.1-405B-Instruct-Turbo',
    'meta-llama/Llama-3.3-70B-Instruct-Turbo',
    'meta-llama/Llama-3.2-3B-Instruct-Turbo',
    'Qwen/Qwen2.5-7B-Instruct-Turbo',
    'Qwen/Qwen2.5-72B-Instruct-Turbo',
    'mistralai/Mistral-Small-24B-Instruct-2501',
    'mistralai/Magistral-Small-2506',
    'arcee-ai/virtuoso-large',
    'arcee-ai/virtuoso-medium-v2',
    'arcee-ai/caller',
    'arcee-ai/arcee-blitz',
  };

  /// Vision-language models (support image input).
  /// From: https://docs.together.ai/docs/serverless-models#vision-models
  static const _visionModels = <String>{
    'meta-llama/Llama-4-Maverick-17B-128E-Instruct-FP8',
    'meta-llama/Llama-4-Scout-17B-16E-Instruct',
    'Qwen/Qwen2.5-VL-72B-Instruct',
  };

  /// Reasoning/thinking models.
  static const _thinkingModels = <String>{
    'deepseek-ai/DeepSeek-R1',
    'deepseek-ai/DeepSeek-R1-0528-tput',
    'deepseek-ai/DeepSeek-R1-Distill-Llama-70B',
    'moonshotai/Kimi-K2-Thinking',
    'Qwen/Qwen3-Next-80B-A3B-Thinking',
    'Qwen/Qwen3-235B-A22B-Thinking-2507',
  };

  @override
  ChatModel<OpenAIChatOptions> createChatModel({
    String? name,
    List<Tool>? tools,
    double? temperature,
    bool enableThinking = false,
    OpenAIChatOptions? options,
  }) {
    if (enableThinking) {
      throw UnsupportedError('Extended thinking is not supported by the $displayName provider.');
    }
    validateApiKeyPresence();
    final modelName = name ?? defaultModelNames[ModelKind.chat]!;

    _logger.info(
      'Creating Together AI model: $modelName with '
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
    // Together's /v1/models endpoint returns basic metadata but no explicit
    // capability flags. We use heuristics based on model type and naming.
    final caps = <ModelCaps>{};

    // Try to get model type from modelData (if provided from listModels)
    final type = modelData?['type'] as String?;

    // Type-based capability detection
    if (type != null) {
      switch (type) {
        case 'chat':
          caps.add(ModelCaps.chat);
          break;
        case 'embedding':
          caps.add(ModelCaps.embeddings);
          break;
        case 'image':
          caps.add(ModelCaps.image);
          break;
        case 'audio':
        case 'transcribe':
          caps.add(ModelCaps.audio);
          break;
        // 'code', 'language', 'moderation', 'video', 'rerank'
        // don't map to our caps
        default:
          break;
      }
    } else {
      // Default to chat if we don't have type info
      caps.add(ModelCaps.chat);
    }

    // Vision model detection (VL = Vision Language)
    if (_visionModels.contains(modelName) ||
        modelName.toUpperCase().contains('-VL-') ||
        modelName.toUpperCase().contains('-VL')) {
      caps.add(ModelCaps.chatVision);
    }

    // Function calling support (from documented list)
    if (_functionCallingModels.contains(modelName)) {
      caps.add(ModelCaps.multiToolCalls);
    }

    // Thinking/reasoning model detection
    if (_thinkingModels.contains(modelName) ||
        modelName.toLowerCase().contains('thinking') ||
        modelName.toLowerCase().contains('-r1')) {
      caps.add(ModelCaps.thinking);
    }

    // Structured output support - generally available for chat models
    // that support function calling
    if (caps.contains(ModelCaps.chat) &&
        caps.contains(ModelCaps.multiToolCalls)) {
      caps.add(ModelCaps.typedOutput);
      caps.add(ModelCaps.typedOutputWithTools);
    } else if (caps.contains(ModelCaps.chat)) {
      // Most Together chat models support JSON mode
      caps.add(ModelCaps.typedOutput);
    }

    return caps.toList();
  }

  @override
  Stream<ModelInfo> listModels() async* {
    validateApiKeyPresence();
    final url = baseUrl!.replace(path: '${baseUrl!.path}/models');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${apiKey!}',
    };

    http.Response response;
    try {
      response = await http.get(url, headers: headers);
    } on Exception catch (e) {
      _logger.warning('Error listing Together AI models: $e');
      return;
    }

    if (response.statusCode != 200) {
      _logger.warning(
        'Together AI /models request failed: ${response.statusCode}',
      );
      return;
    }

    // Together returns an array directly, not wrapped in "data"
    final models = jsonDecode(response.body) as List<dynamic>;

    for (final model in models.cast<Map<String, dynamic>>()) {
      final id = model['id'] as String;
      final type = model['type'] as String?;

      // Determine ModelKind from type
      final kinds = <ModelKind>{};
      switch (type) {
        case 'chat':
        case 'code':
        case 'language':
          kinds.add(ModelKind.chat);
          break;
        case 'embedding':
          kinds.add(ModelKind.embeddings);
          break;
        // 'image', 'audio', 'video', 'moderation', 'transcribe', 'rerank'
        // don't map to model kinds we track
        default:
          // Skip non-chat/embedding models for now
          if (type != 'chat' &&
              type != 'code' &&
              type != 'language' &&
              type != 'embedding') {
            continue;
          }
      }

      if (kinds.isEmpty) continue;

      final caps = await fetchModelCaps(id, model);
      yield ModelInfo(
        name: id,
        providerName: name,
        kinds: kinds,
        displayName: model['display_name'] as String? ?? id,
        caps: caps,
        extra: model,
      );
    }
  }
}
