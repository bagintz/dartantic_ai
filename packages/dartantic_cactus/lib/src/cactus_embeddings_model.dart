import 'package:dartantic_interface/dartantic_interface.dart';
import 'cactus_chat_options.dart';

/// Cactus embeddings model implementation.
///
/// Provides text embedding generation using on-device GGUF models
/// through the Cactus framework.
class CactusEmbeddingsModel extends EmbeddingsModel<CactusEmbeddingsModelOptions> {
  /// Creates a new Cactus embeddings model instance.
  CactusEmbeddingsModel({
    required String name,
    CactusEmbeddingsModelOptions? options,
  }) : super(
          name: name,
          defaultOptions: options ?? 
            const CactusEmbeddingsModelOptions(modelUrl: 'default'),
        );

  @override
  Future<EmbeddingsResult> embedQuery(
    String query, {
    CactusEmbeddingsModelOptions? options,
  }) {
    // TODO: Implement single query embedding
    throw UnimplementedError('Query embedding not yet implemented');
  }

  @override
  Future<BatchEmbeddingsResult> embedDocuments(
    List<String> texts, {
    CactusEmbeddingsModelOptions? options,
  }) {
    // TODO: Implement batch document embedding
    throw UnimplementedError('Document embedding not yet implemented');
  }

  @override
  void dispose() {
    // TODO: Implement model disposal
    // This should clean up the underlying Cactus model resources
  }
}