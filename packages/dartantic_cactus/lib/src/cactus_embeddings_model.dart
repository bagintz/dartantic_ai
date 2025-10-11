import 'package:cactus/cactus.dart' as cactus;
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:logging/logging.dart';
import 'cactus_chat_options.dart';

/// Cactus embeddings model implementation using Cactus Dart API.
///
/// Provides text embedding generation using on-device GGUF models
/// through the Cactus Flutter package.
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

  static final Logger _logger = Logger('dartantic.cactus.embeddings_model');
  
  cactus.CactusLM? _lm;
  bool _isInitialized = false;

  /// Initializes the underlying Cactus model for embeddings.
  Future<void> _ensureInitialized(CactusEmbeddingsModelOptions options) async {
    if (_isInitialized) return;

    try {
      _logger.info('Initializing Cactus embeddings model: ${options.modelUrl}');
      
      _lm = cactus.CactusLM();
      
      // Download model if URL is provided
      await _lm!.download(
        modelUrl: options.modelUrl,
        modelFilename: options.modelFilename,
        onProgress: (double? progress, String status, bool isError) {
          _logger.info('Download: $status ${progress != null ? '${(progress * 100).toInt()}%' : ''}');
        },
      );
      
      // Initialize with embeddings enabled
      final success = await _lm!.init(
        contextSize: options.contextSize,
        gpuLayers: options.gpuLayers,
        threads: options.threads,
        generateEmbeddings: true, // Enable embeddings
        modelFilename: options.modelFilename,
      );
      
      if (!success) {
        throw Exception('Failed to initialize Cactus embeddings model');
      }
      
      _isInitialized = true;
      _logger.info('Cactus embeddings model initialized successfully');
      
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize Cactus embeddings model', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<EmbeddingsResult> embedQuery(
    String query, {
    CactusEmbeddingsModelOptions? options,
  }) async {
    final opts = options ?? defaultOptions;
    await _ensureInitialized(opts);

    if (!_isInitialized || _lm == null) {
      throw StateError('Model not initialized');
    }

    try {
      // Get embeddings from Cactus
      final embeddings = await _lm!.embedding(query);
      
      // Count tokens (rough estimate)
      final tokenCount = query.split(' ').length;
      
      return EmbeddingsResult(
        output: embeddings,
        finishReason: FinishReason.stop,
        metadata: {'model': name, 'input_tokens': tokenCount},
        usage: LanguageModelUsage(
          promptTokens: tokenCount,
          totalTokens: tokenCount,
        ),
      );
      
    } catch (e, stackTrace) {
      _logger.severe('Error during embedding generation', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<BatchEmbeddingsResult> embedDocuments(
    List<String> texts, {
    CactusEmbeddingsModelOptions? options,
  }) async {
    // For now, process documents one by one
    // TODO: Optimize with batch processing if Cactus supports it
    final embeddings = <List<double>>[];
    int totalTokens = 0;
    
    for (final text in texts) {
      final result = await embedQuery(text, options: options);
      embeddings.add(result.embeddings);
      totalTokens += result.usage?.totalTokens ?? 0;
    }
    
    return BatchEmbeddingsResult(
      output: embeddings,
      finishReason: FinishReason.stop,
      metadata: {'model': name, 'batch_size': texts.length},
      usage: LanguageModelUsage(
        promptTokens: totalTokens, 
        totalTokens: totalTokens
      ),
    );
  }

  @override
  void dispose() {
    try {
      _lm?.dispose();
      _lm = null;
      _isInitialized = false;
      _logger.info('Cactus embeddings model disposed');
    } catch (e, stackTrace) {
      _logger.warning('Error disposing embeddings model', e, stackTrace);
    }
  }
}