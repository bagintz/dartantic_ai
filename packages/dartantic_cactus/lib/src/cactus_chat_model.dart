import 'dart:async';

import 'package:cactus/cactus.dart' as cactus;
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:json_schema/json_schema.dart';
import 'package:logging/logging.dart';

import 'cactus_chat_options.dart';
import 'cactus_message_mappers.dart';
import 'json_validator.dart';
import 'schema_prompt_builder.dart';
import 'tool_mappers.dart';

/// Cactus chat model implementation using Cactus Dart API.
///
/// Provides text generation and chat functionality using on-device GGUF models
/// through the Cactus Flutter package.
class CactusChatModel extends ChatModel<CactusChatModelOptions> {
  /// Creates a new Cactus chat model instance.
  CactusChatModel({
    required super.name,
    CactusChatModelOptions? options,
    super.temperature,
    super.tools,
  }) : super(
          defaultOptions: options ?? 
            const CactusChatModelOptions(modelUrl: 'default'),
        );

  static final Logger _logger = Logger('dartantic.cactus.chat_model');
  
  cactus.CactusLM? _lm;
  cactus.CactusVLM? _vlm;
  cactus.CactusAgent? _agent;  // For tool calling support
  bool _isInitialized = false;

  /// Initializes the underlying Cactus model.
  /// 
  /// Determines whether to use text-only (CactusLM) or vision (CactusVLM) 
  /// model based on conversation content and options.
  Future<void> _ensureInitialized(CactusChatModelOptions options, {bool needsVision = false}) async {
    if (_isInitialized) return;

    try {
      _logger.info('Initializing Cactus model: ${options.modelUrl} (vision: ${needsVision || options.supportVision})');
      
      if ((needsVision || options.supportVision) && options.mmprojUrl != null) {
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

  /// Checks if messages contain visual content (images).
  bool _hasVisualContent(List<ChatMessage> messages) {
    for (final message in messages) {
      for (final part in message.parts) {
        if (part is DataPart && part.mimeType.startsWith('image/')) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Stream<ChatResult<ChatMessage>> sendStream(
    List<ChatMessage> messages, {
    CactusChatModelOptions? options,
    JsonSchema? outputSchema,
  }) async* {
    final opts = options ?? defaultOptions;
    final hasTools = tools != null && tools!.isNotEmpty;

    // Validation: Don't allow tools + outputSchema simultaneously
    if (outputSchema != null && hasTools) {
      throw ArgumentError('Cannot use tools and outputSchema together');
    }

    _logger.info('SendStream: hasTools=$hasTools, hasOutputSchema=${outputSchema != null}');

    // Route to appropriate implementation
    if (hasTools) {
      _logger.info('Using CactusAgent for tool calling with ${tools!.length} tools');
      yield* _sendWithCactusAgent(messages, opts, outputSchema);
      return;
    }

    if (outputSchema != null) {
      _logger.info('Using typed output with JSON schema validation');
      yield* _sendWithTypedOutput(messages, opts, outputSchema);
      return;
    }

    // Standard completion flow
    _logger.info('Using standard completion without tools or typed output');
    
    // Check if we need vision model based on message content
    final needsVision = _hasVisualContent(messages) || opts.supportVision;
    
    await _ensureInitialized(opts, needsVision: needsVision);

    if (!_isInitialized || (_lm == null && _vlm == null)) {
      throw StateError('Model not initialized');
    }

    // Use the extracted standard completion method
    yield* _sendStandardCompletion(messages, opts);
  }

  /// Sends completion using CactusAgent for tool calling support.
  Stream<ChatResult<ChatMessage>> _sendWithCactusAgent(
    List<ChatMessage> messages,
    CactusChatModelOptions options,
    JsonSchema? outputSchema,
  ) async* {
    _logger.info('Starting tool calling completion with CactusAgent');
    
    // Ensure agent is initialized
    await _ensureAgentInitialized(options);
    
    // Register tools with the agent
    if (tools != null && tools!.isNotEmpty) {
      ToolConverters.registerTools(_agent!, tools!);
    }
    
    // Convert messages to Cactus format using existing mapper
    final cactusMessages = CactusMessageMappers.toCactusMessages(messages);
    
    try {
      // Use CactusAgent.completionWithTools for tool calling
      // Returns CompletionResult with .result (text) and .toolCalls properties
      final result = await _agent!.completionWithTools(
        cactusMessages,
        maxTokens: options.maxTokens,
        temperature: temperature ?? options.temperature,
      );
      
      _logger.info('CactusAgent completion successful');
      
      // Extract text from result (CompletionResult has .result property)
      final responseText = result.result ?? '';
      
      // Convert result to dartantic format
      final dartanticMessage = ChatMessage.model(responseText);
      
      // Create and yield the final result
      yield ChatResult<ChatMessage>(
        output: dartanticMessage,
        metadata: {
          'model': name,
          'toolCalls': result.toolCalls, // List of tool calls made
        },
      );
      
    } catch (error, stackTrace) {
      _logger.severe('CactusAgent completion failed', error, stackTrace);
      rethrow;
    }
  }

  /// Sends completion with typed output using prompt engineering.
  Stream<ChatResult<ChatMessage>> _sendWithTypedOutput(
    List<ChatMessage> messages,
    CactusChatModelOptions options,
    JsonSchema outputSchema,
  ) async* {
    _logger.info('Starting typed output completion with schema validation');
    
    const maxRetries = 3;
    var attempt = 0;
    String? lastAttempt;
    String? lastError;
    
    // Build schema instructions
    final schemaPrompt = SchemaPromptBuilder.buildSystemPrompt(outputSchema);
    
    // Inject schema into system message
    final enhancedMessages = _injectSchemaPrompt(messages, schemaPrompt);
    
    while (attempt < maxRetries) {
      attempt++;
      _logger.fine('Typed output attempt $attempt/$maxRetries');
      
      try {
        // Get completion using standard flow
        final completion = await _getStandardCompletion(
          attempt > 1 ? _addRetryPrompt(enhancedMessages, lastError!, lastAttempt!) 
                     : enhancedMessages,
          options,
        );
        
        lastAttempt = completion;
        
        // Validate the response
        final validationResult = JsonValidator.validateWithExtraction(
          completion,
          outputSchema,
        );
        
        if (validationResult.isValid) {
          _logger.info('Typed output validation successful on attempt $attempt');
          
          // Return the validated JSON as text in the message
          yield ChatResult<ChatMessage>(
            output: ChatMessage.model(completion),
            metadata: {
              'model': name,
              'attempts': attempt,
              'validated': true,
              'schema': outputSchema.schemaMap,
            },
          );
          return;
        } else {
          lastError = validationResult.error!;
          _logger.warning(
            'Typed output validation failed on attempt $attempt: $lastError',
          );
          
          if (attempt >= maxRetries) {
            throw FormatException(
              'Failed to generate valid JSON after $maxRetries attempts. '
              'Last error: $lastError',
            );
          }
        }
        
      } catch (e, stackTrace) {
        _logger.severe('Error during typed output attempt $attempt', e, stackTrace);
        
        if (attempt >= maxRetries) {
          rethrow;
        }
        
        lastError = e.toString();
      }
    }
  }
  
  /// Injects schema prompt into messages.
  List<ChatMessage> _injectSchemaPrompt(
    List<ChatMessage> messages,
    String schemaPrompt,
  ) {
    final enhanced = <ChatMessage>[];
    
    // Find existing system message or create one
    var hasSystemMessage = false;
    for (final message in messages) {
      if (message.role == ChatMessageRole.system) {
        hasSystemMessage = true;
        // Append schema to existing system message
        enhanced.add(ChatMessage.system('${message.text}\n\n$schemaPrompt'));
      } else {
        enhanced.add(message);
      }
    }
    
    // If no system message, add one at the start
    if (!hasSystemMessage) {
      enhanced.insert(0, ChatMessage.system(schemaPrompt));
    }
    
    return enhanced;
  }
  
  /// Adds retry prompt to messages.
  List<ChatMessage> _addRetryPrompt(
    List<ChatMessage> messages,
    String error,
    String previousAttempt,
  ) {
    final retryPrompt = SchemaPromptBuilder.buildRetryPrompt(
      error,
      previousAttempt,
    );
    
    return [
      ...messages,
      ChatMessage.user(retryPrompt),
    ];
  }
  
  /// Gets standard completion as a single string.
  Future<String> _getStandardCompletion(
    List<ChatMessage> messages,
    CactusChatModelOptions options,
  ) async {
    final buffer = StringBuffer();
    
    // Use standard sendStream but collect all output
    await for (final chunk in _sendStandardCompletion(messages, options)) {
      buffer.write(chunk.output.text);
    }
    
    return buffer.toString();
  }
  
  /// Sends standard completion (existing flow extracted for reuse).
  Stream<ChatResult<ChatMessage>> _sendStandardCompletion(
    List<ChatMessage> messages,
    CactusChatModelOptions options,
  ) async* {
    // Convert messages to Cactus format
    final cactusMessages = CactusMessageMappers.toCactusMessages(messages);
    
    // Extract image paths if vision model (await the Future)
    final imagePaths = await CactusMessageMappers.extractImagePaths(messages);
    
    try {
      // Accumulate tokens for streaming
      var accumulatedText = '';
      
      // Generate completion with streaming
      if (_vlm != null) {
        // Use Vision Language Model with proper imagePaths parameter
        await _vlm!.completion(
          cactusMessages,
          imagePaths: imagePaths,
          maxTokens: options.maxTokens,
          temperature: temperature ?? options.temperature,
          stopSequences: options.stopSequences,
          onToken: (String token) {
            accumulatedText += token;
            return true;
          },
        );
      } else {
        // Use Language Model
        await _lm!.completion(
          cactusMessages,
          maxTokens: options.maxTokens,
          temperature: temperature ?? options.temperature,
          stopSequences: options.stopSequences,
          onToken: (String token) {
            accumulatedText += token;
            return true;
          },
        );
      }
      
      // Yield final result
      yield ChatResult<ChatMessage>(
        output: ChatMessage.model(accumulatedText),
        metadata: {'model': name},
      );
      
    } catch (e, stackTrace) {
      _logger.severe('Error during completion', e, stackTrace);
      rethrow;
    }
  }

  /// Ensures CactusAgent is initialized for tool calling.
  Future<void> _ensureAgentInitialized(CactusChatModelOptions options) async {
    if (_agent != null) return;

    _logger.info('Initializing CactusAgent for tool calling');
    
    try {
      _agent = cactus.CactusAgent();
      
      // Download model if needed
      await _agent!.download(
        modelUrl: options.modelUrl,
        modelFilename: options.modelFilename,
        onProgress: (double? progress, String status, bool isError) {
          if (isError) {
            _logger.severe('Agent download error: $status');
          } else {
            _logger.info('Agent download: $status ${progress != null ? '${(progress * 100).toInt()}%' : ''}');
          }
        },
      );
      
      // Initialize agent
      await _agent!.init(
        contextSize: options.contextSize,
        gpuLayers: options.gpuLayers,
        generateEmbeddings: true,
      );
      
      _logger.info('CactusAgent initialized successfully');
      
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize CactusAgent', e, stackTrace);
      rethrow;
    }
  }

  @override
  void dispose() {
    try {
      _lm?.dispose();
      _vlm?.dispose();
      // CactusAgent doesn't have dispose method, just clear the reference
      // _agent?.dispose();
      _lm = null;
      _vlm = null;
      _agent = null;
      _isInitialized = false;
      _logger.info('Cactus model disposed');
    } catch (e, stackTrace) {
      _logger.warning('Error disposing model', e, stackTrace);
    }
  }
}