import 'package:dartantic_interface/dartantic_interface.dart';

/// Result from graph execution iteration
class GraphIterationResult {
  /// Text output to stream to user
  final String output;
  
  /// Messages generated during this iteration
  final List<ChatMessage> messages;
  
  /// Whether execution should continue
  final bool shouldContinue;
  
  /// Current execution status
  final FinishReason finishReason;
  
  /// Metadata from this iteration
  final Map<String, dynamic> metadata;
  
  /// Usage statistics
  final LanguageModelUsage? usage;
  
  /// Unique identifier
  final String id;
  
  const GraphIterationResult({
    required this.output,
    required this.messages,
    required this.shouldContinue,
    required this.finishReason,
    required this.metadata,
    required this.usage,
    required this.id,
  });
}
