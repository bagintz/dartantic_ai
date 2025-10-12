import 'dart:io';
import 'package:cactus/cactus.dart' as cactus;
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:path/path.dart' as path;

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
  /// 
  /// Converts DataPart images to temporary files and collects file paths.
  static Future<List<String>> extractImagePaths(List<ChatMessage> messages) async {
    final imagePaths = <String>[];
    
    for (final message in messages) {
      for (final part in message.parts) {
        if (part is DataPart && part.mimeType.startsWith('image/')) {
          // Convert DataPart bytes to temporary file
          final tempPath = await _saveDataPartToTempFile(part);
          if (tempPath != null) {
            imagePaths.add(tempPath);
          }
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

  /// Saves a DataPart to a temporary file and returns the path.
  static Future<String?> _saveDataPartToTempFile(DataPart dataPart) async {
    try {
      // Get temp directory
      final tempDir = Directory.systemTemp;
      
      // Generate filename with proper extension
      final extension = _getExtensionFromMimeType(dataPart.mimeType);
      final fileName = 'cactus_image_${DateTime.now().millisecondsSinceEpoch}$extension';
      final tempFile = File(path.join(tempDir.path, fileName));
      
      // Write bytes to file
      await tempFile.writeAsBytes(dataPart.bytes);
      
      return tempFile.path;
    } catch (e) {
      // If saving fails, return null
      return null;
    }
  }

  /// Gets file extension from MIME type.
  static String _getExtensionFromMimeType(String mimeType) {
    switch (mimeType.toLowerCase()) {
      case 'image/jpeg':
      case 'image/jpg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/gif':
        return '.gif';
      case 'image/webp':
        return '.webp';
      case 'image/bmp':
        return '.bmp';
      case 'image/tiff':
        return '.tiff';
      default:
        return '.jpg'; // Default fallback
    }
  }

  /// Creates a dartantic ChatMessage from Cactus response text.
  static ChatMessage fromCactusResponse(String responseText) {
    return ChatMessage.model(responseText);
  }
}