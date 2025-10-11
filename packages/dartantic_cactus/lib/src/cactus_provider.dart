import 'package:dartantic_interface/dartantic_interface.dart';
import 'cactus_chat_model.dart';
import 'cactus_chat_options.dart';
import 'cactus_embeddings_model.dart';

/// Cactus provider for dartantic_ai.
///
/// Provides access to on-device AI models using the Cactus framework.
/// Supports language models, vision models, and embeddings through GGUF format.
class CactusProvider extends Provider<CactusChatModelOptions, CactusEmbeddingsModelOptions> {
  /// Creates a new Cactus provider instance.
  CactusProvider()
      : super(
          apiKey: null,
          apiKeyName: null,
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
          },
        );

  @override
  Stream<ModelInfo> listModels() {
    // TODO: Implement model listing
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
    return CactusChatModel(
      name: name ?? defaultModelNames[ModelKind.chat]!,
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
}