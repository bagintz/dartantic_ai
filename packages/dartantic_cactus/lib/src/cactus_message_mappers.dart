import 'package:cactus/cactus.dart' as cactus;
import 'package:dartantic_interface/dartantic_interface.dart';

/// Utilities for converting between dartantic and Cactus message formats.
class CactusMessageMappers {
  /// Converts dartantic ChatMessage list to Cactus ChatMessage list.
  static List<cactus.ChatMessage> toCactusMessages(List<ChatMessage> messages) {
    return messages.map((msg) => cactus.ChatMessage(
      role: _mapRole(msg.role),
      content: msg.text,
    )).toList();
  }

  /// Maps dartantic ChatMessageRole to Cactus role string.
  static String _mapRole(ChatMessageRole role) {
    switch (role) {
      case ChatMessageRole.system:
        return 'system';
      case ChatMessageRole.user:
        return 'user';
      case ChatMessageRole.model:
        return 'assistant';
    }
  }

  /// Extracts image paths from dartantic messages for vision models.
  static List<String> extractImagePaths(List<ChatMessage> messages) {
    final imagePaths = <String>[];
    
    for (final message in messages) {
      for (final part in message.parts) {
        if (part is DataPart && part.mimeType.startsWith('image/')) {
          // Handle base64 image data - would need to save to temp file
          // TODO: Implement base64 to file conversion for Cactus VLM
          // For now, skip DataPart images
        } else if (part is LinkPart && part.url.isScheme('file')) {
          // Handle file:// URLs
          final mimeType = part.mimeType;
          if (mimeType != null && mimeType.startsWith('image/')) {
            imagePaths.add(part.url.toFilePath());
          }
        }
      }
    }
    
    return imagePaths;
  }

  /// Creates a dartantic ChatMessage from Cactus response text.
  static ChatMessage fromCactusResponse(String responseText) {
    return ChatMessage.model(responseText);
  }
}