import 'dart:async';

import 'package:cactus/cactus.dart' as cactus;
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
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
  bool _isInitialized = false;
  
  /// Visible for testing only - allows tests to inject mock LM
  @visibleForTesting
  set testLM(cactus.CactusLM? lm) {
    _lm = lm;
  }
  
  /// Visible for testing only - allows tests to mark model as initialized
  @visibleForTesting
  set testInitialized(bool initialized) {
    _isInitialized = initialized;
  }

  /// Initializes the underlying Cactus model.
  /// 
  /// Uses the new Cactus main branch API with model slugs and improved initialization.
  Future<void> _ensureInitialized(CactusChatModelOptions options) async {
    if (_isInitialized) return;

    try {
      _logger.info('Initializing Cactus model: ${options.modelUrl}');
      
      // Initialize Language Model
      _lm = cactus.CactusLM();
      
      // Download model using new API (model slug instead of URL)
      await _lm!.downloadModel(
        model: options.modelUrl, // TODO: This should be modelSlug after Phase 3
        downloadProcessCallback: (double? progress, String status, bool isError) {
          _logger.info('Download: $status ${progress != null ? '${(progress * 100).toInt()}%' : ''}');
        },
      );
      
      // Initialize the model using new API
      await _lm!.initializeModel(
        params: cactus.CactusInitParams(
          model: options.modelUrl, // TODO: This should be modelSlug after Phase 3
          contextSize: options.contextSize,
        ),
      );
      
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
    
    await _ensureInitialized(opts);

    if (!_isInitialized || _lm == null) {
      throw StateError('Model not initialized');
    }

    // Use the extracted standard completion method
    yield* _sendStandardCompletion(messages, opts);
  }

  /// Sends completion with tool calling support using the new CactusLM API.
  /// 
  /// Tools are now built into CactusCompletionParams instead of requiring CactusAgent.
  Stream<ChatResult<ChatMessage>> _sendWithCactusAgent(
    List<ChatMessage> messages,
    CactusChatModelOptions options,
    JsonSchema? outputSchema,
  ) async* {
    _logger.info('Starting tool calling completion with CactusLM tools');
    
    // Ensure model is initialized
    await _ensureInitialized(options);
    
    // Convert dartantic tools to Cactus tools format
    final cactusTools = tools != null && tools!.isNotEmpty
        ? ToolConverters.toCactusTools(tools!)
        : null;
    
    // Convert messages to Cactus format using existing mapper
    final cactusMessages = CactusMessageMappers.toCactusMessages(messages);
    
    try {
      // Use generateCompletion with tools parameter
      final result = await _lm!.generateCompletion(
        messages: cactusMessages,
        params: cactus.CactusCompletionParams(
          maxTokens: options.maxTokens,
          temperature: temperature ?? options.temperature,
          stopSequences: options.stopSequences,
          tools: cactusTools,
        ),
      );
      
      _logger.info('Tool calling completion successful');
      
      // Extract text from result
      final responseText = result.response;
      
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
      _logger.severe('Tool calling completion failed', error, stackTrace);
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
    
    try {
      // Generate completion using new API with streaming
      final streamResult = await _lm!.generateCompletionStream(
        messages: cactusMessages,
        params: cactus.CactusCompletionParams(
          maxTokens: options.maxTokens,
          temperature: temperature ?? options.temperature,
          stopSequences: options.stopSequences,
        ),
      );
      
      // Accumulate tokens from stream
      var accumulatedText = '';
      await for (final token in streamResult.stream) {
        accumulatedText += token;
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

  @override
  void dispose() {
    try {
      _lm?.unload();  // New API uses unload() instead of dispose()
      _lm = null;
      _isInitialized = false;
      _logger.info('Cactus model disposed');
    } catch (e, stackTrace) {
      _logger.warning('Error disposing model', e, stackTrace);
    }
  }
}