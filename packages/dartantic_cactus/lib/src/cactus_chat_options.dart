import 'package:dartantic_interface/dartantic_interface.dart';

/// Configuration options for Cactus chat models (main branch API).
/// 
/// Uses model slugs from the Cactus catalog instead of direct URLs.
/// Vision and TTS support removed in main branch.
class CactusChatModelOptions extends ChatModelOptions {
  /// Model slug from Cactus catalog (e.g., 'qwen3-0.6', 'phi-3-mini-4k-instruct').
  /// 
  /// See available models at https://github.com/topoteretes/cactus-flutter
  final String modelUrl;  // TODO: Rename to modelSlug in next major version to avoid breaking changes

  /// Context window size in tokens.
  /// 
  /// Larger context windows require more memory. Default: 2048
  final int contextSize;

  /// Temperature for controlling randomness in generation (0.0-2.0).
  /// 
  /// Lower values (0.1-0.3) are more deterministic.
  /// Higher values (0.7-1.0) are more creative.
  final double temperature;

  /// Maximum number of tokens to generate.
  final int maxTokens;

  /// List of stop sequences to halt generation.
  /// 
  /// The model will stop generating when any of these sequences appear.
  final List<String> stopSequences;

  /// Enterprise token for cloud/hybrid completion mode (optional).
  /// 
  /// When provided, enables fallback to cloud-based completion if local fails.
  final String? cactusToken;

  /// Creates new Cactus chat model options.
  const CactusChatModelOptions({
    required this.modelUrl,
    this.contextSize = 2048,
    this.temperature = 0.7,
    this.maxTokens = 2048,
    this.stopSequences = const [],
    this.cactusToken,
  });
}

/// Configuration options for Cactus embeddings models (main branch API).
/// 
/// Uses model slugs from the Cactus catalog instead of direct URLs.
class CactusEmbeddingsModelOptions extends EmbeddingsModelOptions {
  /// Model slug from Cactus catalog (e.g., 'qwen3-0.6').
  /// 
  /// See available models at https://github.com/topoteretes/cactus-flutter
  final String modelUrl;  // TODO: Rename to modelSlug in next major version to avoid breaking changes

  /// Context window size in tokens.
  /// 
  /// Larger context windows require more memory. Default: 2048
  final int contextSize;

  /// Enterprise token for cloud/hybrid features (optional).
  /// 
  /// When provided, enables fallback to cloud-based embeddings if local fails.
  final String? cactusToken;

  /// Creates new Cactus embeddings model options.
  const CactusEmbeddingsModelOptions({
    required this.modelUrl,
    this.contextSize = 2048,
    this.cactusToken,
  });
}