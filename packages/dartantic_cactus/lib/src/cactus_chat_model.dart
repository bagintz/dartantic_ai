import 'dart:async';

import 'package:cactus/cactus.dart' as cactus;
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:json_schema/json_schema.dart';
import 'package:logging/logging.dart';

import 'cactus_chat_options.dart';
import 'cactus_message_mappers.dart';
import 'cactus_streaming_accumulator.dart';

/// Cactus chat model implementation using Cactus Dart API.
///
/// Provides text generation and chat functionality using on-device GGUF models
/// through the Cactus Flutter package.
class CactusChatModel extends ChatModel<CactusChatModelOptions> {
  /// Creates a new Cactus chat model instance.
  CactusChatModel({
    required String name,
    CactusChatModelOptions? options,
    double? temperature,
    List<Tool>? tools,
  }) : super(
          name: name,
          defaultOptions: options ?? 
            const CactusChatModelOptions(modelUrl: 'default'),
          temperature: temperature,
          tools: tools,
        );

  static final Logger _logger = Logger('dartantic.cactus.chat_model');
  
  cactus.CactusLM? _lm;
  cactus.CactusVLM? _vlm;
  bool _isInitialized = false;

  /// Initializes the underlying Cactus model.
  Future<void> _ensureInitialized(CactusChatModelOptions options) async {
    if (_isInitialized) return;

    try {
      _logger.info('Initializing Cactus model: ${options.modelUrl}');
      
      if (options.supportVision && options.mmprojUrl != null) {
        // Initialize Vision Language Model
        _vlm = cactus.CactusVLM();
        
        // Download models if URL is provided
        await _vlm!.download(
          modelUrl: options.modelUrl,
          mmprojUrl: options.mmprojUrl!,
          modelFilename: options.modelFilename,
          mmprojFilename: options.mmprojFilename,
          onProgress: (double? progress, String status, bool isError) {
            _logger.info('Download: $status ${progress != null ? '${(progress * 100).toInt()}%' : ''}');
          },
        );
        
        // Initialize the model
        final success = await _vlm!.init(
          contextSize: options.contextSize,
          gpuLayers: options.gpuLayers,
          threads: options.threads,
          modelFilename: options.modelFilename,
          mmprojFilename: options.mmprojFilename,
          chatTemplate: options.chatTemplate,
        );
        
        if (!success) {
          throw Exception('Failed to initialize Cactus VLM');
        }
      } else {
        // Initialize Language Model
        _lm = cactus.CactusLM();
        
        // Download model if URL is provided
        await _lm!.download(
          modelUrl: options.modelUrl,
          modelFilename: options.modelFilename,
          onProgress: (double? progress, String status, bool isError) {
            _logger.info('Download: $status ${progress != null ? '${(progress * 100).toInt()}%' : ''}');
          },
        );
        
        // Initialize the model
        final success = await _lm!.init(
          contextSize: options.contextSize,
          gpuLayers: options.gpuLayers,
          threads: options.threads,
          modelFilename: options.modelFilename,
          chatTemplate: options.chatTemplate,
        );
        
        if (!success) {
          throw Exception('Failed to initialize Cactus LM');
        }
      }
      
      _isInitialized = true;
      _logger.info('Cactus model initialized successfully');
      
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize Cactus model', e, stackTrace);
      rethrow;
    }
  }

  @override
  Stream<ChatResult<ChatMessage>> sendStream(
    List<ChatMessage> messages, {
    CactusChatModelOptions? options,
    JsonSchema? outputSchema,
  }) async* {
    final opts = options ?? defaultOptions;
    await _ensureInitialized(opts);

    if (!_isInitialized || (_lm == null && _vlm == null)) {
      throw StateError('Model not initialized');
    }

    try {
      // Convert dartantic messages to Cactus messages
      final cactusMessages = CactusMessageMappers.toCactusMessages(messages);
      
      final accumulator = CactusStreamingAccumulator();
      
      // Generate completion with streaming
      if (_vlm != null) {
        // Use Vision Language Model
        await _vlm!.completion(
          cactusMessages,
          maxTokens: opts.maxTokens,
          temperature: temperature ?? opts.temperature,
          stopSequences: opts.stopSequences,
          onToken: (String token) {
            accumulator.addToken(token);
            // Return true to continue generation
            return true;
          },
        );
      } else {
        // Use Language Model
        await _lm!.completion(
          cactusMessages,
          maxTokens: opts.maxTokens,
          temperature: temperature ?? opts.temperature,
          stopSequences: opts.stopSequences,
          onToken: (String token) {
            accumulator.addToken(token);
            // Return true to continue generation
            return true;
          },
        );
      }
      
      // Yield the final result
      yield accumulator.toChatResult();
      
    } catch (e, stackTrace) {
      _logger.severe('Error during chat completion', e, stackTrace);
      rethrow;
    }
  }

  @override
  void dispose() {
    try {
      _lm?.dispose();
      _vlm?.dispose();
      _lm = null;
      _vlm = null;
      _isInitialized = false;
      _logger.info('Cactus model disposed');
    } catch (e, stackTrace) {
      _logger.warning('Error disposing model', e, stackTrace);
    }
  }
}