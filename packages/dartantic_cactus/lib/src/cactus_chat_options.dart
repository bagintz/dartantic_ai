import 'package:dartantic_interface/dartantic_interface.dart';

/// Configuration options for Cactus chat models.
class CactusChatModelOptions extends ChatModelOptions {
  /// URL to the GGUF model file (HuggingFace URL or local path).
  final String modelUrl;

  /// Custom filename for cached model (optional).
  final String? modelFilename;

  /// URL to multimodal projection GGUF file for vision models (optional).
  final String? mmprojUrl;

  /// Custom filename for cached mmproj model (optional).
  final String? mmprojFilename;

  /// Custom chat template in Jinja2 format (optional).
  final String? chatTemplate;

  /// Context window size in tokens.
  final int contextSize;

  /// Number of layers to run on GPU (0 = CPU only).
  final int gpuLayers;

  /// Number of CPU threads to use.
  final int threads;

  /// Whether this model supports vision/multimodal input.
  final bool supportVision;

  /// Temperature for controlling randomness in generation.
  final double temperature;

  /// Maximum number of tokens to generate.
  final int maxTokens;

  /// Enterprise token for cloud features (optional).
  final String? cactusToken;

  /// Creates new Cactus chat model options.
  const CactusChatModelOptions({
    required this.modelUrl,
    this.modelFilename,
    this.mmprojUrl,
    this.mmprojFilename,
    this.chatTemplate,
    this.contextSize = 2048,
    this.gpuLayers = 0,
    this.threads = 4,
    this.supportVision = false,
    this.temperature = 0.7,
    this.maxTokens = 2048,
    this.cactusToken,
  });
}

/// Configuration options for Cactus embeddings models.
class CactusEmbeddingsModelOptions extends EmbeddingsModelOptions {
  /// URL to the GGUF model file (HuggingFace URL or local path).
  final String modelUrl;

  /// Custom filename for cached model (optional).
  final String? modelFilename;

  /// Context window size in tokens.
  final int contextSize;

  /// Number of layers to run on GPU (0 = CPU only).
  final int gpuLayers;

  /// Number of CPU threads to use.
  final int threads;

  /// Enterprise token for cloud features (optional).
  final String? cactusToken;

  /// Creates new Cactus embeddings model options.
  const CactusEmbeddingsModelOptions({
    required this.modelUrl,
    this.modelFilename,
    this.contextSize = 2048,
    this.gpuLayers = 0,
    this.threads = 4,
    this.cactusToken,
  });
}