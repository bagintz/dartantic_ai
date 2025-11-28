import 'dart:convert';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../chat_models/openai_chat/openai_chat_model.dart';
import '../chat_models/openai_chat/openai_chat_options.dart';
import '../platform/platform.dart';
import 'openai_provider_base.dart';

/// Provider for OpenRouter API with native capability detection.
///
/// OpenRouter provides a unified interface to 400+ AI models with rich
/// capability metadata via the /api/v1/models endpoint including:
/// - `architecture.input_modalities`: ["text", "image", "audio", "file"]
/// - `architecture.output_modalities`: ["text", "image"]
/// - `supported_parameters`: ["tools", "reasoning", "structured_outputs", etc.]
class OpenRouterProvider extends OpenAIProviderBase<OpenAIChatOptions> {
  /// Creates a new OpenRouter provider instance.
  OpenRouterProvider({
    String? apiKey,
    super.name = 'openrouter',
    super.displayName = 'OpenRouter',
    super.defaultModelNames = const {
      ModelKind.chat: 'google/gemini-2.5-flash',
    },
    super.caps = const {
      ProviderCaps.chat,
      ProviderCaps.multiToolCalls,
      ProviderCaps.typedOutput,
      ProviderCaps.chatVision,
    },
    super.aliases,
  }) : super(
         apiKey: apiKey ?? tryGetEnv(defaultApiKeyName),
         baseUrl: defaultBaseUrl,
         apiKeyName: defaultApiKeyName,
       );

  static final Logger _logger = Logger('dartantic.chat.providers.openrouter');

  @override
  Logger get logger => _logger;

  /// The environment variable for the API key.
  static const defaultApiKeyName = 'OPENROUTER_API_KEY';

  /// The default base URL for the OpenRouter API.
  static final defaultBaseUrl = Uri.parse('https://openrouter.ai/api/v1');

  @override
  ChatModel<OpenAIChatOptions> createChatModel({
    String? name,
    List<Tool>? tools,
    double? temperature,
    OpenAIChatOptions? options,
  }) {
    validateApiKeyPresence();
    final modelName = name ?? defaultModelNames[ModelKind.chat]!;

    _logger.info(
      'Creating OpenRouter model: $modelName with '
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
    // OpenRouter's /api/v1/models endpoint provides rich capability metadata
    // via architecture.input_modalities, architecture.output_modalities,
    // and supported_parameters fields.
    final url = baseUrl!.replace(path: '${baseUrl!.path}/models');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    // API key is optional for listing models but may provide better results
    final key = apiKey;
    if (key != null && key.isNotEmpty) {
      headers['Authorization'] = 'Bearer $key';
    }

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode != 200) {
        _logger.warning(
          'OpenRouter /models request failed: ${response.statusCode}',
        );
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final models = data['data'] as List<dynamic>?;
      if (models == null) {
        _logger.warning('OpenRouter /models response missing "data" field');
        return null;
      }

      // Find the model by ID
      final model = models.cast<Map<String, dynamic>>().where(
        (m) => m['id'] == modelName,
      );
      if (model.isEmpty) {
        _logger.info('Model $modelName not found in OpenRouter models list');
        return null;
      }

      return _extractCapsFromModel(model.first);
    } on Exception catch (e) {
      _logger.warning('Error fetching OpenRouter model caps: $e');
      return null;
    }
  }

  /// Extracts ModelCaps from OpenRouter model metadata.
  List<ModelCaps> _extractCapsFromModel(Map<String, dynamic> model) {
    final caps = <ModelCaps>{};

    // Extract architecture info
    final architecture = model['architecture'] as Map<String, dynamic>?;
    if (architecture != null) {
      final inputModalities =
          (architecture['input_modalities'] as List<dynamic>?)
              ?.cast<String>() ??
          [];
      final outputModalities =
          (architecture['output_modalities'] as List<dynamic>?)
              ?.cast<String>() ??
          [];

      // Input modalities -> capabilities
      if (inputModalities.contains('text')) {
        caps.add(ModelCaps.chat);
      }
      if (inputModalities.contains('image')) {
        caps.add(ModelCaps.chatVision);
      }
      if (inputModalities.contains('audio')) {
        caps.add(ModelCaps.audio);
      }
      // 'file' modality is interesting but we don't have a cap for it yet

      // Output modalities -> capabilities
      if (outputModalities.contains('image')) {
        caps.add(ModelCaps.image);
      }
      // 'text' output is implied by chat
    }

    // Extract supported parameters
    final supportedParams =
        (model['supported_parameters'] as List<dynamic>?)?.cast<String>() ?? [];

    // Tool calling support
    if (supportedParams.contains('tools')) {
      caps.add(ModelCaps.multiToolCalls);
    }

    // Reasoning/thinking support
    if (supportedParams.contains('reasoning') ||
        supportedParams.contains('include_reasoning')) {
      caps.add(ModelCaps.thinking);
    }

    // Structured output support
    if (supportedParams.contains('structured_outputs') ||
        supportedParams.contains('response_format')) {
      caps.add(ModelCaps.typedOutput);
      // If model has both tools and structured outputs, it likely supports both
      if (caps.contains(ModelCaps.multiToolCalls)) {
        caps.add(ModelCaps.typedOutputWithTools);
      }
    }

    return caps.toList();
  }

  @override
  Stream<ModelInfo> listModels() async* {
    final url = baseUrl!.replace(path: '${baseUrl!.path}/models');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    final key = apiKey;
    if (key != null && key.isNotEmpty) {
      headers['Authorization'] = 'Bearer $key';
    }

    http.Response response;
    try {
      response = await http.get(url, headers: headers);
    } on Exception catch (e) {
      _logger.warning('Error listing OpenRouter models: $e');
      return;
    }

    if (response.statusCode != 200) {
      _logger.warning(
        'OpenRouter /models request failed: ${response.statusCode}',
      );
      return;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final models = data['data'] as List<dynamic>?;
    if (models == null) {
      _logger.warning('OpenRouter /models response missing "data" field');
      return;
    }

    for (final model in models.cast<Map<String, dynamic>>()) {
      final id = model['id'] as String;
      yield ModelInfo(
        name: id,
        providerName: name,
        kinds: {ModelKind.chat}, // OpenRouter is primarily for chat models
        displayName: model['name'] as String? ?? id,
        caps: _extractCapsFromModel(model),
        extra: model,
      );
    }
  }
}
