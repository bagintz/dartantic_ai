import 'dart:convert';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../chat_models/cohere_chat/cohere_chat_model.dart';
import '../chat_models/cohere_chat/cohere_chat_options.dart';
import '../platform/platform.dart';
import '../retry_http_client.dart';
import 'openai_provider.dart';

/// Provider for Cohere OpenAI-compatible API.
class CohereProvider extends OpenAIProvider {
  /// Creates a new Cohere OpenAI provider instance.
  ///
  /// [apiKey]: The API key for the Cohere provider.
  CohereProvider({String? apiKey, super.headers})
    : super(
        apiKey: apiKey ?? tryGetEnv(defaultApiKeyName),
        apiKeyName: defaultApiKeyName,
        name: 'cohere',
        displayName: 'Cohere',
        defaultModelNames: {
          ModelKind.chat: 'command-r-08-2024',
          ModelKind.embeddings: 'embed-v4.0',
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
    bool enableThinking = false,
    CohereChatOptions? options,
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
      headers: headers,
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

    // Otherwise, fetch from native Cohere API which returns rich capability data
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

  /// Extract capability hints from Cohere's model metadata (when available).
  List<ModelCaps> _extractCapsFromModelData(Map<String, dynamic> data) {
    final caps = <ModelCaps>{};

    // Some Cohere model metadata exposes `capabilities` or `type` fields.
    final capsField = data['capabilities'] ?? data['capability'];
    if (capsField is List) {
      final strCaps = capsField.cast<String>();
      for (final c in strCaps) {
        final lc = c.toLowerCase();
        if (lc.contains('embed')) caps.add(ModelCaps.embeddings);
        if (lc.contains('chat') || lc.contains('generate')) caps.add(ModelCaps.chat);
        if (lc.contains('image') || lc.contains('vision')) caps.add(ModelCaps.image);
        if (lc.contains('audio') || lc.contains('tts')) caps.add(ModelCaps.audio);
        if (lc.contains('tools') || lc.contains('function')) caps.add(ModelCaps.multiToolCalls);
        if (lc.contains('structured') || lc.contains('json')) {
          caps.add(ModelCaps.typedOutput);
          if (caps.contains(ModelCaps.multiToolCalls)) caps.add(ModelCaps.typedOutputWithTools);
        }
      }
    }

    // Try `type` field or `model` name hints
    final type = (data['type'] as String?)?.toLowerCase();
    if (type != null) {
      if (type == 'embedding') caps.add(ModelCaps.embeddings);
      if (type == 'image' || type == 'vision') caps.add(ModelCaps.image);
      if (type == 'audio' || type == 'tts') caps.add(ModelCaps.audio);
      if (type == 'chat' || type == 'generate') caps.add(ModelCaps.chat);
    }

    // Fallback to name-based heuristics
    final name = (data['name'] as String?) ?? '';
    if (name.isNotEmpty) {
      caps.addAll(_heuristicCaps(name));
    }

    return caps.toList();
  }

  /// Simple heuristics for Cohere model names.
  List<ModelCaps> _heuristicCaps(String modelName) {
    final id = modelName.toLowerCase();
    final caps = <ModelCaps>{};
    if (id.contains('embed')) {
      caps.add(ModelCaps.embeddings);
      return caps.toList();
    }

    if (id.contains('command') || id.contains('generate') || id.contains('chat')) {
      caps.add(ModelCaps.chat);
      caps.add(ModelCaps.typedOutput);
      caps.add(ModelCaps.multiToolCalls);
    }

    if (id.contains('vision') || id.contains('image')) caps.add(ModelCaps.image);
    if (id.contains('audio') || id.contains('tts')) caps.add(ModelCaps.audio);

    return caps.toList();
  }
  @override
  Stream<ModelInfo> listModels() async* {
    final url = Uri.parse('https://docs.cohere.com/docs/models');
    _logger.info('Fetching models from Cohere docs: $url');
    final client = RetryHttpClient(inner: http.Client());
    try {
      final response = await client.get(url);
      if (response.statusCode != 200) {
        _logger.warning(
          'Failed to fetch models: HTTP ${response.statusCode}, '
          'body: ${response.body}',
        );
        throw Exception('Failed to fetch Cohere models docs: ${response.body}');
      }
      final doc = html_parser.parse(response.body);
      _logger.info('Successfully fetched Cohere models documentation');
      // Find all tables whose first header cell is 'Model Name'
      for (final table in doc.querySelectorAll('table')) {
        final headerCells = table.querySelectorAll('th');
        if (headerCells.isEmpty) continue;
        final firstHeader = headerCells.first.text.trim().toLowerCase();
        if (firstHeader == 'model name') {
          // Try to determine kind from headers or parse as chat/embedding/other
          final headers = headerCells
              .map((th) => th.text.trim().toLowerCase())
              .toList();
          // Parse the table, passing headers for classification
          yield* _parseCohereTableWithHeaders(table, headers);
        }
      }
    } finally {
      client.close();
    }
  }

  // Parse a Cohere model table, using headers to classify model kind
  Stream<ModelInfo> _parseCohereTableWithHeaders(
    dom.Element table,
    List<String> headers,
  ) async* {
    final rows = table.querySelectorAll('tbody tr');
    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      if (cells.isEmpty) continue;
      final id = cells[0].text.trim();
      final description = cells.length > 1 ? cells[1].text.trim() : null;

      // Only include live models
      if (!_isLiveModel(id, cells, headers)) {
        _logger.info('Skipping non-live model: $id');
        continue;
      }
      final kinds = <ModelKind>{};
      final idLower = id.toLowerCase();
      // Heuristics based on model name
      if (idLower.contains('embed')) {
        kinds.add(ModelKind.embeddings);
      }
      if (idLower.contains('command') ||
          idLower.contains('c4ai-aya') ||
          idLower.contains('vision')) {
        kinds.add(ModelKind.chat);
      }
      if (idLower.contains('rerank')) {
        kinds.add(ModelKind.other); // Consider ModelKind.rerank if you add it
      }
      // Only fall back to Modality column if name is ambiguous
      if (kinds.isEmpty) {
        final modalityIdx = headers.indexWhere(
          (h) => h == 'modality' || h == 'modalities',
        );
        if (modalityIdx != -1 && cells.length > modalityIdx) {
          final modality = cells[modalityIdx].text.trim().toLowerCase();
          if (modality.contains('text') && !modality.contains('embed')) {
            kinds.add(ModelKind.chat);
          } else if (modality.contains('embed')) {
            kinds.add(ModelKind.embeddings);
          } else if (modality.contains('image') ||
              modality.contains('vision')) {
            kinds.add(ModelKind.image);
          } else if (modality.contains('audio')) {
            kinds.add(ModelKind.audio);
          } else if (modality.contains('tts')) {
            kinds.add(ModelKind.tts);
          } else {
            kinds.add(ModelKind.other);
          }
        }
      }

      // Ensure kinds is never empty
      if (kinds.isEmpty) kinds.add(ModelKind.other);
      // Try to get context window if present
      int? contextWindow;
      final contextIdx = headers.indexWhere(
        (h) => h.contains('context length'),
      );

      if (contextIdx != -1 && cells.length > contextIdx) {
        final text = cells[contextIdx].text;
        final match = RegExp(r'(\d+)k').firstMatch(text);
        if (match != null) {
          contextWindow = int.tryParse(match.group(1)!)! * 1000;
        }
      }

      yield ModelInfo(
        name: id,
        providerName: name,
        kinds: kinds,
        displayName: id,
        description: description,
        extra: {
          for (var i = 0; i < headers.length && i < cells.length; i++)
            headers[i]: cells[i].text.trim(),
          'description': description,
          if (contextWindow != null) 'contextWindow': contextWindow,
        },
      );
    }
  }

  // Check if a model is explicitly marked as live in the table
  bool _isLiveModel(
    String modelId,
    List<dom.Element> cells,
    List<String> headers,
  ) {
    // Find the status column
    final statusIndex = headers.indexWhere(
      (h) =>
          h.toLowerCase().contains('status') ||
          h.toLowerCase().contains('availability'),
    );

    if (statusIndex != -1 && cells.length > statusIndex) {
      final statusText = cells[statusIndex].text.trim().toLowerCase();
      // Only return true if explicitly marked as live
      return statusText.contains('live');
    }

    // No status column found - model is not confirmed as live
    return false;
  }
}
