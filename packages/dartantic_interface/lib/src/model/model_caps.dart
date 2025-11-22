/// Model capabilities that can be queried per-model rather than per-provider.
///
/// This enum represents specific capabilities that individual models may or may
/// not support, allowing for more granular capability reporting than provider-wide
/// capabilities.
enum ModelCaps {
  /// Basic chat/text generation capability
  chat,

  /// Chat with vision/image input capability
  chatVision,

  /// Support for multiple tool calls in a single request
  multiToolCalls,

  /// Support for typed/structured output
  typedOutput,

  /// Support for typed output combined with tool calling
  typedOutputWithTools,

  /// Support for thinking/reasoning capabilities (e.g., o1 models)
  thinking,

  /// Support for embeddings generation
  embeddings,

  /// Support for audio input/output
  audio,

  /// Support for image generation
  image,

  /// Support for text-to-speech
  tts,

  /// Support for token counting
  countTokens,
}
