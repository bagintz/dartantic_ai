import 'package:dartantic_interface/dartantic_interface.dart';

/// Utilities for handling thinking/reasoning with Cactus models.
class CactusThinkingUtils {
  /// Extracts thinking content from model responses.
  static String? extractThinking(ChatResult<ChatMessage> result) {
    // TODO: Implement thinking extraction
    // Check if the response contains thinking metadata
    return result.metadata['thinking'] as String?;
  }

  /// Processes a response to separate thinking from the actual answer.
  static Map<String, String> separateThinkingAndResponse(String fullResponse) {
    // TODO: Implement thinking/response separation
    // Look for common thinking patterns like <thinking>...</thinking>
    return {
      'thinking': '',
      'response': fullResponse,
    };
  }

  /// Adds thinking metadata to a ChatResult.
  static ChatResult<ChatMessage> addThinkingMetadata(
    ChatResult<ChatMessage> result,
    String thinking,
  ) {
    final newMetadata = Map<String, dynamic>.from(result.metadata);
    newMetadata['thinking'] = thinking;

    return ChatResult(
      output: result.output,
      finishReason: result.finishReason,
      metadata: newMetadata,
      usage: result.usage,
      messages: result.messages,
      id: result.id,
    );
  }
}