import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:json_schema/json_schema.dart';
import 'cactus_chat_options.dart';

/// Cactus chat model implementation.
///
/// Provides text generation and chat functionality using on-device GGUF models
/// through the Cactus framework.
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

  @override
  Stream<ChatResult<ChatMessage>> sendStream(
    List<ChatMessage> messages, {
    CactusChatModelOptions? options,
    JsonSchema? outputSchema,
  }) {
    // TODO: Implement streaming chat
    throw UnimplementedError('Streaming chat not yet implemented');
  }

  @override
  void dispose() {
    // TODO: Implement model disposal
    // This should clean up the underlying Cactus model resources
  }
}