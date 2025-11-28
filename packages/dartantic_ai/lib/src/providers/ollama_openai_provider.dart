import 'dart:convert';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../chat_models/openai_chat/openai_chat_model.dart';
import '../chat_models/openai_chat/openai_chat_options.dart';
import 'openai_provider_base.dart';

/// Provider for Ollama via OpenAI-compatible API with native capability lookup.
///
/// This provider uses Ollama's OpenAI-compatible endpoint at `/v1` but
/// delegates capability detection to Ollama's native `/api/show` endpoint
/// which provides model metadata including capabilities.
class OllamaOpenAIProvider extends OpenAIProviderBase<OpenAIChatOptions> {
  /// Creates a new Ollama OpenAI-compatible provider instance.
  OllamaOpenAIProvider({
    super.name = 'ollama-openai',
    super.displayName = 'Ollama (OpenAI-compatible)',
    super.defaultModelNames = const {ModelKind.chat: 'llama3.2'},
    super.caps = const {ProviderCaps.chat},
    super.aliases,
    Uri? baseUrl,
  }) : super(
         apiKey: null,
         baseUrl: baseUrl ?? defaultBaseUrl,
         apiKeyName: null,
       );

  static final Logger _logger =
      Logger('dartantic.chat.providers.ollama_openai');

  @override
  Logger get logger => _logger;

  /// The default base URL for the Ollama OpenAI-compatible API.
  static final defaultBaseUrl = Uri.parse('http://localhost:11434/v1');

  /// The base URL for Ollama's native API (for capability lookup).
  Uri get _ollamaNativeBaseUrl =>
      baseUrl!.replace(path: '', pathSegments: ['api']);

  @override
  ChatModel<OpenAIChatOptions> createChatModel({
    String? name,
    List<Tool>? tools,
    double? temperature,
    OpenAIChatOptions? options,
  }) {
    final modelName = name ?? defaultModelNames[ModelKind.chat]!;

    _logger.info(
      'Creating Ollama OpenAI-compatible model: $modelName with '
      '${tools?.length ?? 0} tools, '
      'temperature: $temperature',
    );

    return OpenAIChatModel(
      name: modelName,
      tools: tools,
      temperature: temperature,
      apiKey: null, // Ollama doesn't require API key
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
    // Use Ollama's native /api/show endpoint to get model capabilities.
    // This provides the same metadata as the native Ollama provider.
    final showUrl = _ollamaNativeBaseUrl.replace(
      path: '${_ollamaNativeBaseUrl.path}/show',
    );

    try {
      final response = await http.post(
        showUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': modelName}),
      );

      if (response.statusCode != 200) {
        _logger.warning(
          'Ollama /api/show request failed for $modelName: '
          '${response.statusCode}',
        );
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _extractCapsFromShowResponse(data);
    } on Exception catch (e) {
      _logger.warning('Error fetching Ollama model caps for $modelName: $e');
      return null;
    }
  }

  /// Extracts ModelCaps from Ollama's /api/show response.
  List<ModelCaps> _extractCapsFromShowResponse(Map<String, dynamic> data) {
    final caps = <ModelCaps>{};

    // All Ollama models support chat
    caps.add(ModelCaps.chat);

    // Check model_info for capabilities array (added in recent Ollama)
    final modelInfo = data['model_info'] as Map<String, dynamic>?;
    if (modelInfo != null) {
      final capabilities =
          (modelInfo['capabilities'] as List<dynamic>?)?.cast<String>() ?? [];

      for (final cap in capabilities) {
        switch (cap.toLowerCase()) {
          case 'vision':
            caps.add(ModelCaps.chatVision);
          case 'tools':
            caps.add(ModelCaps.multiToolCalls);
          case 'embedding':
            caps.add(ModelCaps.embeddings);
          case 'completion':
            // Already added chat
            break;
        }
      }
    }

    // Check details for model family hints
    final details = data['details'] as Map<String, dynamic>?;
    if (details != null) {
      final family = (details['family'] as String?)?.toLowerCase() ?? '';
      final families =
          (details['families'] as List<dynamic>?)?.cast<String>() ?? [];

      // Vision model detection
      if (family.contains('llava') ||
          families.any((f) => f.toLowerCase().contains('llava')) ||
          families.any((f) => f.toLowerCase().contains('clip'))) {
        caps.add(ModelCaps.chatVision);
      }
    }

    // Check template for tool support hints
    final template = data['template'] as String? ?? '';
    if (template.contains('tools') || template.contains('function')) {
      caps.add(ModelCaps.multiToolCalls);
    }

    // If tools are supported, add typed output capabilities
    if (caps.contains(ModelCaps.multiToolCalls)) {
      caps.add(ModelCaps.typedOutput);
      caps.add(ModelCaps.typedOutputWithTools);
    }

    return caps.toList();
  }

  @override
  Stream<ModelInfo> listModels() async* {
    // Use Ollama's native /api/tags endpoint to list models
    final tagsUrl = _ollamaNativeBaseUrl.replace(
      path: '${_ollamaNativeBaseUrl.path}/tags',
    );

    http.Response response;
    try {
      response = await http.get(tagsUrl);
    } on Exception catch (e) {
      _logger.warning('Error listing Ollama models: $e');
      return;
    }

    if (response.statusCode != 200) {
      _logger.warning(
        'Ollama /api/tags request failed: ${response.statusCode}',
      );
      return;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final models = data['models'] as List<dynamic>? ?? [];

    for (final model in models.cast<Map<String, dynamic>>()) {
      final modelName = model['name'] as String;
      final caps = await fetchModelCaps(modelName);

      yield ModelInfo(
        name: modelName,
        providerName: name,
        kinds: {ModelKind.chat},
        displayName: modelName,
        caps: caps,
        extra: model,
      );
    }
  }
}
