import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:logging/logging.dart';

import 'cactus_chat_model.dart';
import 'cactus_chat_options.dart';
import 'cactus_embeddings_model.dart';
import 'cactus_tts_model.dart';

/// Cactus provider for dartantic_ai.
///
/// Provides access to on-device AI models using the Cactus framework.
/// Supports language models, vision models, and embeddings through GGUF format.
class CactusProvider extends Provider<CactusChatModelOptions, CactusEmbeddingsModelOptions> {
  /// Creates a new Cactus provider instance.
  CactusProvider()
      : super(
          apiKey: null, // Local provider, no API key required
          apiKeyName: null, // Local provider
          name: 'cactus',
          displayName: 'Cactus AI',
          defaultModelNames: const {
            ModelKind.chat: 'phi-3-mini-4k-instruct',
          },
          caps: const {
          ProviderCaps.chat,
          ProviderCaps.embeddings,
          ProviderCaps.chatVision,
          ProviderCaps.thinking,
          ProviderCaps.multiToolCalls,  // NEW: CactusAgent tool calling
          ProviderCaps.typedOutput,     // NEW: Prompt engineering + JSON validation
          ProviderCaps.textToSpeech,   // NEW: CactusTTS support
        },
        );

  // IMPORTANT: Logger must be private and static final per dartantic patterns
  static final Logger _logger = Logger('dartantic.chat.providers.cactus');

  @override
  Stream<ModelInfo> listModels() {
    // TODO: Implement model listing from Cactus
    // For now, return empty stream
    return const Stream.empty();
  }

  @override
  ChatModel<CactusChatModelOptions> createChatModel({
    String? name,
    List<Tool>? tools,
    double? temperature,
    CactusChatModelOptions? options,
  }) {
    final modelName = name ?? defaultModelNames[ModelKind.chat]!;
    
    _logger.info(
      'Creating Cactus model: $modelName with ${tools?.length ?? 0} tools, '
      'temp: $temperature',
    );

    return CactusChatModel(
      name: modelName,
      options: options,
      temperature: temperature,
      tools: tools,
    );
  }

  @override
  EmbeddingsModel<CactusEmbeddingsModelOptions> createEmbeddingsModel({
    String? name,
    CactusEmbeddingsModelOptions? options,
  }) {
    return CactusEmbeddingsModel(
      name: name ?? 'default',
      options: options,
    );
  }

  @override
  TTSModel? createTTSModel({
    String? name,
    Map<String, dynamic>? options,
  }) {
    final modelUrl = options?['modelUrl'] as String?;
    if (modelUrl == null) {
      _logger.warning('modelUrl is required for CactusTTS models');
      return null;
    }

    try {
      return CactusTTSModel(
        name: name ?? 'cactus-tts',
        options: CactusTTSModelOptions(
          modelUrl: modelUrl,
          modelFilename: options?['modelFilename'] as String?,
          contextSize: options?['contextSize'] as int? ?? 2048,
          gpuLayers: options?['gpuLayers'] as int? ?? 0,
          threads: options?['threads'] as int? ?? 4,
        ),
      );
    } catch (e) {
      _logger.severe('Failed to create CactusTTS model: $e');
      return null;
    }
  }
}