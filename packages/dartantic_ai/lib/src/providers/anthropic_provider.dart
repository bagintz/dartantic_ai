import 'dart:convert';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:http/http.dart' as http;
import 'package:json_schema/json_schema.dart';
import 'package:logging/logging.dart';

import '../agent/orchestrators/default_streaming_orchestrator.dart';
import '../agent/orchestrators/streaming_orchestrator.dart';
import '../chat_models/anthropic_chat/anthropic_chat.dart';
import '../chat_models/anthropic_chat/anthropic_typed_output_orchestrator.dart';
import '../chat_models/chat_utils.dart';
import '../media_gen_models/anthropic/anthropic_media_gen_model.dart';
import '../media_gen_models/anthropic/anthropic_media_gen_model_options.dart';
import '../platform/platform.dart';
import '../retry_http_client.dart';
import 'chat_orchestrator_provider.dart';

/// Provider for Anthropic Claude native API.
class AnthropicProvider
    extends
        Provider<
          AnthropicChatOptions,
          EmbeddingsModelOptions,
          AnthropicMediaGenerationModelOptions
        >
    implements ChatOrchestratorProvider {
  /// Creates a new Anthropic provider instance.
  ///
  /// [apiKey]: The API key to use for the Anthropic API.
  AnthropicProvider({String? apiKey, super.headers})
    : super(
        apiKey:
            apiKey ??
            tryGetEnv(_defaultApiTestKeyName) ??
            tryGetEnv(defaultApiKeyName),
        apiKeyName: defaultApiKeyName,
        name: 'anthropic',
        displayName: 'Anthropic',
        defaultModelNames: {
          ModelKind.chat: 'claude-sonnet-4-0',
          ModelKind.media: 'claude-sonnet-4-5',
        },
        aliases: ['claude'],
        baseUrl: null,
      );

  static final Logger _logger = Logger('dartantic.chat.providers.anthropic');
  static const _defaultApiTestKeyName = 'ANTHROPIC_API_TEST_KEY';

  /// The default base URL to use unless another is specified.
  static final defaultBaseUrl = Uri.parse('https://api.anthropic.com/v1');

  /// The environment variable for the API key
  static const defaultApiKeyName = 'ANTHROPIC_API_KEY';

  @override
  ChatModel<AnthropicChatOptions> createChatModel({
    String? name,
    List<Tool>? tools,
    double? temperature,
    bool enableThinking = false,
    AnthropicChatOptions? options,
  }) {
    final modelName = name ?? defaultModelNames[ModelKind.chat]!;

    _logger.info(
      'Creating Anthropic model: '
      '$modelName with ${tools?.length ?? 0} tools, temp: $temperature',
    );

    if (apiKeyName != null && (apiKey == null || apiKey!.isEmpty)) {
      throw ArgumentError('$apiKeyName is required for $displayName provider');
    }

    return AnthropicChatModel(
      name: modelName,
      tools: tools,
      temperature: temperature,
      enableThinking: enableThinking,
      apiKey: apiKey!,
      baseUrl: baseUrl,
      headers: headers,
      defaultOptions: () {
        final defaultOptions = AnthropicChatOptions(
          temperature: temperature ?? options?.temperature,
          topP: options?.topP,
          topK: options?.topK,
          maxTokens: options?.maxTokens,
          stopSequences: options?.stopSequences,
          userId: options?.userId,
          thinkingBudgetTokens: options?.thinkingBudgetTokens,
          serverTools: options?.serverTools,
          serverSideTools: options?.serverSideTools,
          toolChoice: options?.toolChoice,
        );
        return defaultOptions;
      }(),
      betaFeatures: betaFeaturesForAnthropicTools(
        manualConfigs: options?.serverTools,
        serverSideTools: options?.serverSideTools,
      ),
    );
  }

  @override
  EmbeddingsModel<EmbeddingsModelOptions> createEmbeddingsModel({
    String? name,
    EmbeddingsModelOptions? options,
  }) => throw Exception('Anthropic does not support embeddings models');

  @override
  Future<List<ModelCaps>?> fetchModelCaps(
    String modelName, [
    Map<String, dynamic>? modelData,
  ]) async {
    // Anthropic's /v1/models endpoint only returns basic metadata (id, type,
    // display_name, created_at) - no capability information. We use heuristics
    // based on model ID patterns.
    final id = modelName.toLowerCase();
    final caps = <ModelCaps>{};

    // All Claude models are chat models with vision, tools, and typed output
    if (id.startsWith('claude')) {
      caps.add(ModelCaps.chat);
      caps.add(ModelCaps.chatVision);
      caps.add(ModelCaps.multiToolCalls);
      caps.add(ModelCaps.typedOutput);
      caps.add(ModelCaps.typedOutputWithTools);

      // Extended thinking support for Claude 3.5+ and Claude 4+
      // Claude 3.5 Sonnet (claude-3-5-sonnet) and all Claude 4+ models
      // Pattern: claude-3-5-*, claude-3.5-*, claude-3.7-*, claude-4*,
      //          claude-sonnet-4*, claude-opus-4*, claude-haiku-4*
      if (_supportsThinking(id)) {
        caps.add(ModelCaps.thinking);
      }

      return caps.toList();
    }

    // Unknown Anthropic model - return empty capabilities
    return caps.toList();
  }

  /// Determines if a Claude model supports extended thinking.
  ///
  /// Thinking is supported on:
  /// - Claude 3.5 Sonnet and newer (claude-3-5-sonnet, claude-3.5-sonnet)
  /// - Claude 3.7 models (claude-3.7-sonnet, claude-3-7-sonnet)
  /// - All Claude 4+ models (claude-4, claude-sonnet-4, claude-opus-4, etc.)
  static bool _supportsThinking(String id) {
    // Claude 4+ models (various naming patterns)
    // claude-4, claude-sonnet-4, claude-opus-4, claude-haiku-4
    if (RegExp('claude-[a-z]*-?4').hasMatch(id)) return true;

    // Claude 3.5+ models (claude-3-5-sonnet, claude-3.5-sonnet)
    if (id.contains('claude-3-5') || id.contains('claude-3.5')) return true;

    // Claude 3.7 models (claude-3-7-sonnet, claude-3.7-sonnet)
    if (id.contains('claude-3-7') || id.contains('claude-3.7')) return true;

    return false;
  }

  @override
  Stream<ModelInfo> listModels() async* {
    final resolvedBaseUrl = baseUrl ?? defaultBaseUrl;
    final url = appendPath(resolvedBaseUrl, 'models');
    final client = RetryHttpClient(inner: http.Client());

    try {
      final response = await client.get(
        url,
        headers: {
          'x-api-key': apiKey!,
          'anthropic-version': '2023-06-01',
          ...headers,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch Anthropic models: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final modelsList = data['data'] as List?;
      if (modelsList == null) {
        throw Exception('Anthropic API response missing "data" field.');
      }

      for (final m in modelsList.cast<Map<String, dynamic>>()) {
        final idField = m['id'];
        if (idField is! String || idField.isEmpty) {
          _logger.warning(
            'Anthropic model has missing or invalid id field '
            '(expected non-empty String): $m',
          );
        }
        final id = idField is String ? idField : '';
        final displayName = m['display_name'] as String?;
        final kind = id.startsWith('claude') ? ModelKind.chat : ModelKind.other;
        // Only include extra fields not mapped to ModelInfo
        final extra = <String, dynamic>{
          if (m.containsKey('created_at')) 'createdAt': m['created_at'],
          if (m.containsKey('type')) 'type': m['type'],
        };
        yield ModelInfo(
          name: id,
          providerName: name,
          kinds: {kind},
          displayName: displayName,
          description: null,
          extra: extra,
        );
      }
    } finally {
      client.close();
    }
  }

  /// The name of the return_result tool.
  static const kAnthropicReturnResultTool = 'return_result';

  @override
  (StreamingOrchestrator, List<Tool>?) getChatOrchestratorAndTools({
    required JsonSchema? outputSchema,
    required List<Tool>? tools,
  }) => (
    outputSchema == null
        ? const DefaultStreamingOrchestrator()
        : const AnthropicTypedOutputOrchestrator(),
    _toolsToUse(outputSchema: outputSchema, tools: tools),
  );

  // If outputSchema is provided, add the return_result tool to the tools list
  // otherwise return the tools list unchanged. The return_result tool is
  // required for typed output and it's what the orchestrator will use to
  // return the final result.
  static List<Tool>? _toolsToUse({
    required JsonSchema? outputSchema,
    required List<Tool>? tools,
  }) {
    if (outputSchema == null) return tools;

    // Check for tool name collision
    if (tools?.any((t) => t.name == kAnthropicReturnResultTool) ?? false) {
      throw ArgumentError(
        'Tool name "$kAnthropicReturnResultTool" is reserved by '
        'Anthropic provider for typed output. '
        'Please use a different tool name.',
      );
    }

    return [
      ...?tools,
      Tool<Map<String, dynamic>>(
        name: kAnthropicReturnResultTool,
        description:
            'CRITICAL: You MUST ALWAYS call this tool to return ANY response. '
            'Never respond with plain text - ONLY use this tool. '
            'Every single response must go through return_result with data '
            'matching the JSON schema. This applies to initial responses AND '
            'follow-up requests. Call this tool whether or not you use other '
            'tools first.',
        inputSchema: outputSchema,
        onCall: (input) async => input,
      ),
    ];
  }

  /// Code execution tool configuration for media generation.
  static const _codeExecutionTool = AnthropicServerToolConfig(
    type: 'code_execution_20250825',
    name: 'code_execution',
  );

  @override
  MediaGenerationModel<AnthropicMediaGenerationModelOptions> createMediaModel({
    String? name,
    List<Tool>? tools,
    AnthropicMediaGenerationModelOptions? options,
  }) {
    if (apiKeyName != null && (apiKey == null || apiKey!.isEmpty)) {
      throw ArgumentError('$apiKeyName is required for $displayName provider');
    }

    final modelName =
        name ??
        defaultModelNames[ModelKind.media] ??
        defaultModelNames[ModelKind.chat]!;
    final resolvedOptions =
        options ?? const AnthropicMediaGenerationModelOptions();

    _logger.info(
      'Creating Anthropic media model: $modelName with '
      '${tools?.length ?? 0} tools',
    );

    // Build server tools list with code execution enabled
    final serverTools = <AnthropicServerToolConfig>[
      _codeExecutionTool,
      ...?resolvedOptions.serverTools,
    ];

    // Create chat options directly with code execution enabled
    final chatOptions = AnthropicChatOptions(
      maxTokens: resolvedOptions.maxTokens ?? 4096,
      stopSequences: resolvedOptions.stopSequences,
      temperature: resolvedOptions.temperature,
      topK: resolvedOptions.topK,
      topP: resolvedOptions.topP,
      userId: resolvedOptions.userId,
      thinkingBudgetTokens: resolvedOptions.thinkingBudgetTokens,
      serverTools: serverTools,
      toolChoice: const AnthropicToolChoice.auto(),
    );

    final betaFeatures = betaFeaturesForAnthropicTools(
      manualConfigs: chatOptions.serverTools,
      serverSideTools: chatOptions.serverSideTools,
    );

    final chatModel = AnthropicChatModel(
      name: modelName,
      tools: tools,
      apiKey: apiKey!,
      baseUrl: baseUrl,
      headers: headers,
      defaultOptions: chatOptions,
      betaFeatures: betaFeatures,
    );

    return AnthropicMediaGenerationModel(
      name: modelName,
      defaultOptions: resolvedOptions,
      chatModel: chatModel,
      apiKey: apiKey!,
      baseUrl: baseUrl,
      headers: headers,
      betaFeatures: betaFeatures,
    );
  }
}
