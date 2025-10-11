import 'package:dartantic_interface/dartantic_interface.dart';

/// Accumulator for streaming chat responses from Cactus models.
class CactusStreamingAccumulator {
  String _accumulatedText = '';

  /// Adds a new token to the accumulated response.
  void addToken(String token) {
    _accumulatedText += token;
  }

  /// Gets the current accumulated text.
  String get currentText => _accumulatedText;

  /// Creates a ChatResult from the current accumulated state.
  ChatResult<ChatMessage> toChatResult() {
    final message = ChatMessage.model(_accumulatedText);

    return ChatResult(
      output: message,
      metadata: {},
    );
  }

  /// Resets the accumulator for a new message.
  void reset() {
    _accumulatedText = '';
  }

  /// Whether the accumulator has any content.
  bool get isEmpty => _accumulatedText.isEmpty;

  /// Whether the accumulator has content.
  bool get isNotEmpty => _accumulatedText.isNotEmpty;
}