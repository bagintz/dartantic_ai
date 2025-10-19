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
    required super.name,
    CactusEmbeddingsModelOptions? options,
  }) : super(
          defaultOptions: options ?? 
            const CactusEmbeddingsModelOptions(modelUrl: 'default'),
        );

  static final Logger _logger = Logger('dartantic.cactus.embeddings_model');
  
  cactus.CactusLM? _lm;
  bool _isInitialized = false;

  /// Initializes the underlying Cactus model for embeddings using new API.
  Future<void> _ensureInitialized(CactusEmbeddingsModelOptions options) async {
    if (_isInitialized) return;

    try {
      _logger.info('Initializing Cactus embeddings model: ${options.modelUrl}');
      
      _lm = cactus.CactusLM();
      
      try {
        // Download model using new API (model slug instead of URL)
        await _lm!.downloadModel(
          model: options.modelUrl, // TODO: This should be modelSlug after Phase 3
          downloadProcessCallback: (double? progress, String status, bool isError) {
            if (isError) {
              _logger.severe('Download error: $status');
            } else {
              _logger.info('Download: $status ${progress != null ? '${(progress * 100).toInt()}%' : ''}');
            }
          },
        );
      } catch (e) {
        throw Exception(
          'Failed to download Cactus embeddings model from ${options.modelUrl}: $e. '
          'Check your network connection and verify the URL is valid.',
        );
      }
      
      try {
        // Initialize using new API
        await _lm!.initializeModel(
          params: cactus.CactusInitParams(
            model: options.modelUrl, // TODO: This should be modelSlug after Phase 3
            contextSize: options.contextSize,
          ),
        );
      } catch (e) {
        throw Exception(
          'Failed to initialize Cactus embeddings model: $e. Check device resources, '
          'reduce contextSize if needed, or verify the model supports embeddings.',
        );
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
    // Validate inputs
    if (query.isEmpty) {
      throw ArgumentError('Query text cannot be empty');
    }
    
    if (query.length > 8000) { // Reasonable text length limit
      throw ArgumentError(
        'Query text is too long (${query.length} characters). '
        'Consider splitting into smaller chunks.',
      );
    }
    
    final opts = options ?? defaultOptions;
    await _ensureInitialized(opts);

    if (!_isInitialized || _lm == null) {
      throw StateError(
        'Cactus embeddings model not initialized. Ensure the model download '
        'and initialization completed successfully.',
      );
    }

    try {
      final queryLength = query.length;
      
      _logger.fine(
        'Embedding query with Cactus model "$name" (length: $queryLength)'
      );
      
      // Get embeddings from Cactus using new API
      final embeddingResult = await _lm!.generateEmbedding(
        text: query,
        modelName: opts.modelUrl, // TODO: This should be modelSlug after Phase 3
      );
      
      if (!embeddingResult.success) {
        throw Exception('Failed to generate embeddings: ${embeddingResult.errorMessage}');
      }
      
      final embeddings = embeddingResult.embeddings;
      
      // Estimate tokens (rough approximation: ~4 chars per token)
      final estimatedTokens = (queryLength / 4).round();
      
      _logger.fine(
        'Cactus embedding query completed '
        '(dimensions: ${embeddings.length}, estimated tokens: $estimatedTokens)'
      );
      
      final result = EmbeddingsResult(
        output: embeddings,
        finishReason: FinishReason.stop,
        metadata: {
          'model': name,
          'dimensions': embeddings.length,
          'query_length': queryLength,
        },
        usage: LanguageModelUsage(
          promptTokens: estimatedTokens,
          promptBillableCharacters: queryLength,
          totalTokens: estimatedTokens,
        ),
      );
      
      _logger.info(
        'Cactus embedding query result: '
        '${result.output.length} dimensions, '
        '${result.usage?.totalTokens ?? 0} estimated tokens'
      );
      
      return result;
      
    } on OutOfMemoryError catch (e, stackTrace) {
      _logger.severe('Out of memory during embedding generation', e, stackTrace);
      throw Exception(
        'Out of memory while processing query (${query.length} characters). '
        'Try splitting the query into smaller chunks.',
      );
    } catch (e, stackTrace) {
      _logger.severe('Error during embedding generation', e, stackTrace);
      
      // Provide helpful error context
      if (e.toString().contains('model') || e.toString().contains('init')) {
        throw Exception(
          'Cactus embeddings model error: $e\n'
          'Try reinitializing the model or checking model compatibility.',
        );
      } else if (e.toString().contains('network') || e.toString().contains('download')) {
        throw Exception(
          'Network error during embedding generation: $e\n'
          'Check your internet connection and try again.',
        );
      }
      
      rethrow;
    }
  }

  @override
  Future<BatchEmbeddingsResult> embedDocuments(
    List<String> texts, {
    CactusEmbeddingsModelOptions? options,
  }) async {
    // Validate inputs
    if (texts.isEmpty) {
      throw ArgumentError('Document list cannot be empty');
    }
    
    if (texts.length > 100) { // Reasonable batch size limit
      throw ArgumentError(
        'Too many documents (${texts.length}). '
        'Consider processing in smaller batches of 100 or fewer.',
      );
    }
    
    // Check for empty documents
    for (int i = 0; i < texts.length; i++) {
      if (texts[i].isEmpty) {
        throw ArgumentError('Document at index $i is empty');
      }
    }
    
    final opts = options ?? defaultOptions;
    await _ensureInitialized(opts);

    if (!_isInitialized || _lm == null) {
      throw StateError(
        'Cactus embeddings model not initialized. Ensure the model download '
        'and initialization completed successfully.',
      );
    }

    try {
      _logger.info('Generating embeddings for ${texts.length} documents');
      
      // Process documents one by one (Cactus doesn't have batch API)
      final embeddings = <List<double>>[];
      int totalPromptTokens = 0;
      
      for (int i = 0; i < texts.length; i++) {
        final text = texts[i];
        _logger.fine('Processing document ${i + 1}/${texts.length}');
        
        try {
          // Get embeddings from Cactus using new API
          final embeddingResult = await _lm!.generateEmbedding(
            text: text,
            modelName: opts.modelUrl, // TODO: This should be modelSlug after Phase 3
          );
          
          if (!embeddingResult.success) {
            throw Exception('Failed to generate embeddings: ${embeddingResult.errorMessage}');
          }
          
          embeddings.add(embeddingResult.embeddings);
          
          // Estimate tokens (rough approximation)
          totalPromptTokens += (text.length / 4).ceil();
        } catch (e) {
          // Provide specific context for which document failed
          final preview = text.length > 50 ? text.substring(0, 50) : text;
          throw Exception(
            'Failed to generate embedding for document ${i + 1}/${texts.length}: $e\n'
            'Document preview: "$preview${text.length > 50 ? '...' : ''}"\n'
            'Consider checking document content or model compatibility.',
          );
        }
      }
      
      _logger.info(
        'Batch embeddings completed: ${embeddings.length} documents, '
        '${embeddings.first.length} dimensions, $totalPromptTokens estimated tokens'
      );
      
      return BatchEmbeddingsResult(
        output: embeddings,
        finishReason: FinishReason.stop,
        metadata: {
          'model': name,
          'batch_size': texts.length,
          'dimensions': embeddings.isNotEmpty ? embeddings.first.length : 0,
        },
        usage: LanguageModelUsage(
          promptTokens: totalPromptTokens, 
          totalTokens: totalPromptTokens,
        ),
      );
      
    } on OutOfMemoryError catch (e, stackTrace) {
      _logger.severe('Out of memory during batch embedding generation', e, stackTrace);
      throw Exception(
        'Out of memory while processing ${texts.length} documents. '
        'Try reducing batch size (current: ${texts.length}, suggested: ${texts.length ~/ 2}) '
        'or document lengths.',
      );
    } catch (e, stackTrace) {
      _logger.severe('Error during batch embedding generation', e, stackTrace);
      
      // Check for common Cactus-specific errors
      if (e.toString().contains('model') || e.toString().contains('init')) {
        throw Exception(
          'Cactus embeddings model error: $e\n'
          'Try reinitializing the model or checking model compatibility.',
        );
      } else if (e.toString().contains('network') || e.toString().contains('download')) {
        throw Exception(
          'Network error during embedding generation: $e\n'
          'Check your internet connection and try again.',
        );
      }
      
      rethrow;
    }
  }

  @override
  void dispose() {
    try {
      _lm?.unload();  // New API uses unload() instead of dispose()
      _lm = null;
      _isInitialized = false;
      _logger.info('Cactus embeddings model disposed');
    } catch (e, stackTrace) {
      _logger.warning('Error disposing embeddings model', e, stackTrace);
    }
  }
}