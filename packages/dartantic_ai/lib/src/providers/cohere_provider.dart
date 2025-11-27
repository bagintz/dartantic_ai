import 'dart:convert';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../chat_models/cohere_chat/cohere_chat_model.dart';
import '../chat_models/cohere_chat/cohere_chat_options.dart';
import '../platform/platform.dart';
import 'openai_provider.dart';

/// Provider for Cohere OpenAI-compatible API.
class CohereProvider extends OpenAIProvider {
  /// Creates a new Cohere OpenAI provider instance.
  ///
  /// [apiKey]: The API key for the Cohere provider.
  CohereProvider({String? apiKey})
    : super(
        apiKey: apiKey ?? tryGetEnv(defaultApiKeyName),
        apiKeyName: defaultApiKeyName,
        name: 'cohere',
        displayName: 'Cohere',
        defaultModelNames: {
          ModelKind.chat: 'command-r-08-2024',
          ModelKind.embeddings: 'embed-v4.0',
        },
        caps: {
          ProviderCaps.chat,
          ProviderCaps.embeddings,
          ProviderCaps.multiToolCalls,
          ProviderCaps.typedOutput,
        },
        baseUrl: cohereDefaultBaseUrl,
      );

  /// Logger for Cohere chat provider operations.
  static final Logger _logger = Logger('dartantic.chat.providers.cohere');

  /// The default base URL for Cohere's OpenAI-compatible API.
  static final Uri cohereDefaultBaseUrl = Uri.parse(
    'https://api.cohere.com/compatibility/v1',
  );

  /// The default API key name for Cohere.
  static const defaultApiKeyName = 'COHERE_API_KEY';

  @override
  ChatModel<CohereChatOptions> createChatModel({
    String? name,
    List<Tool>? tools,
    double? temperature,
    CohereChatOptions? options,
  }) {
    final modelName = name ?? defaultModelNames[ModelKind.chat]!;
    _logger.info(
      'Creating Cohere model: $modelName with ${tools?.length ?? 0} tools, '
      'temp: $temperature',
    );

    if (apiKeyName != null && (apiKey == null || apiKey!.isEmpty)) {
      throw ArgumentError('$apiKeyName is required for $displayName provider');
    }

    return CohereChatModel(
      name: modelName,
      tools: tools,
      temperature: temperature,
      apiKey: apiKey ?? tryGetEnv(apiKeyName),
      baseUrl: baseUrl,
      defaultOptions: CohereChatOptions(
        frequencyPenalty: options?.frequencyPenalty,
        logitBias: options?.logitBias,
        maxTokens: options?.maxTokens,
        n: options?.n,
        presencePenalty: options?.presencePenalty,
        responseFormat: options?.responseFormat,
        seed: options?.seed,
        stop: options?.stop,
        temperature: temperature ?? options?.temperature,
        topP: options?.topP,
        parallelToolCalls: options?.parallelToolCalls,
        serviceTier: options?.serviceTier,
        user: options?.user,
        streamOptions: null, // Cohere requires streamOptions to be null
      ),
    );
  }

  @override
  Future<List<ModelCaps>?> fetchModelCaps(
    String modelName, [
    Map<String, dynamic>? modelData,
  ]) async {
    // If we already have model data (from listModels), use it directly
    if (modelData != null) {
      return _extractCapsFromModelData(modelData);
    }

    // Otherwise, fetch from native Cohere API which returns
    // rich capability data
    final url = Uri.parse('https://api.cohere.com/v1/models');
    _logger.info('Fetching model capabilities from Cohere API: $url');

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
    final modelsList = data['models'] as List?;
    if (modelsList == null) {
      return _heuristicCaps(modelName);
    }

    // Find the matching model
    for (final m in modelsList.cast<Map<String, dynamic>>()) {
      final name = m['name'] as String? ?? '';
      if (name == modelName || name.toLowerCase() == modelName.toLowerCase()) {
        return _extractCapsFromModelData(m);
      }
    }

    // Model not found in API response, fall back to heuristics
    return _heuristicCaps(modelName);
  }

  /// Extract capabilities from Cohere model data.
  ///
  /// Cohere's API returns:
  /// - endpoints: ["chat", "embed", "rerank", "generate", etc.]
  /// - features: ["vision", "json_mode", "json_schema", "tools",
  ///   "reasoning", etc.]
  List<ModelCaps> _extractCapsFromModelData(Map<String, dynamic> modelData) {
    final caps = <ModelCaps>{};

    final endpoints = (modelData['endpoints'] as List?)?.cast<String>() ?? [];
    final features = (modelData['features'] as List?)?.cast<String>() ?? [];

    // Chat capability from endpoints
    if (endpoints.contains('chat') || endpoints.contains('generate')) {
      caps.add(ModelCaps.chat);
    }

    // Embeddings capability
    if (endpoints.contains('embed') || endpoints.contains('embed_image')) {
      caps.add(ModelCaps.embeddings);
    }

    // Vision capability
    if (features.contains('vision')) {
      caps.add(ModelCaps.chatVision);
    }

    // Tool calling capability
    if (features.contains('tools') || features.contains('strict_tools')) {
      caps.add(ModelCaps.multiToolCalls);
    }

    // Typed output (structured outputs / JSON schema)
    if (features.contains('json_schema') || features.contains('json_mode')) {
      caps.add(ModelCaps.typedOutput);
      // If model supports both tools and typed output,
      // it likely supports both together
      if (caps.contains(ModelCaps.multiToolCalls)) {
        caps.add(ModelCaps.typedOutputWithTools);
      }
    }

    // Reasoning/thinking capability
    if (features.contains('reasoning')) {
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

    // Rerank models - not a capability we track
    if (id.contains('rerank')) {
      return caps.toList();
    }

    // Command models (chat)
    if (id.contains('command') || id.contains('c4ai-aya')) {
      caps.add(ModelCaps.chat);
      caps.add(ModelCaps.multiToolCalls);
      caps.add(ModelCaps.typedOutput);
      caps.add(ModelCaps.typedOutputWithTools);

      // Vision models
      if (id.contains('vision')) {
        caps.add(ModelCaps.chatVision);
      }

      // Reasoning models
      if (id.contains('reasoning')) {
        caps.add(ModelCaps.thinking);
      }
    }

    return caps.toList();
  }

  @override
  Stream<ModelInfo> listModels() async* {
    // Use native Cohere API which returns rich model data
    // including capabilities
    final url = Uri.parse('https://api.cohere.com/v1/models');
    _logger.info('Fetching models from Cohere API: $url');

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $apiKey'},
    );

    if (response.statusCode != 200) {
      _logger.warning(
        'Failed to fetch models: HTTP ${response.statusCode}, '
        'body: ${response.body}',
      );
      throw Exception('Failed to fetch Cohere models: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final modelsList = data['models'] as List?;
    if (modelsList == null) {
      throw Exception('Cohere API response missing "models" field.');
    }

    for (final m in modelsList.cast<Map<String, dynamic>>()) {
      final id = m['name'] as String? ?? '';
      final endpoints = (m['endpoints'] as List?)?.cast<String>() ?? [];
      final contextLength = m['context_length'] as int?;

      // Determine model kind from endpoints
      final kinds = <ModelKind>{};
      if (endpoints.contains('chat') || endpoints.contains('generate')) {
        kinds.add(ModelKind.chat);
      }
      if (endpoints.contains('embed') || endpoints.contains('embed_image')) {
        kinds.add(ModelKind.embeddings);
      }
      if (endpoints.contains('rerank')) {
        kinds.add(ModelKind.other);
      }
      if (kinds.isEmpty) kinds.add(ModelKind.other);

      // Extract capabilities from model data
      final caps = _extractCapsFromModelData(m);

      yield ModelInfo(
        name: id,
        providerName: name,
        kinds: kinds,
        displayName: id,
        description: null,
        caps: caps,
        extra: {
          if (contextLength != null) 'contextLength': contextLength,
          if (m.containsKey('features')) 'features': m['features'],
          if (m.containsKey('endpoints')) 'endpoints': endpoints,
          if (m.containsKey('finetuned')) 'finetuned': m['finetuned'],
        },
      );
    }
  }
}
