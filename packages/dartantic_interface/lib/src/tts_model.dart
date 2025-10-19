import 'dart:typed_data';

/// Result of text-to-speech generation
class TTSResult {
  /// Generated audio data
  final Uint8List audioData;
  
  /// Audio format (wav, mp3, pcm, etc.)
  final String format;
  
  /// Sample rate in Hz (e.g., 22050, 44100)
  final int sampleRate;
  
  /// Number of audio channels (1 = mono, 2 = stereo)
  final int channels;
  
  /// Duration in milliseconds
  final int durationMs;
  
  /// Original input text
  final String inputText;
  
  /// Generated text tokens (if available)
  final String? generatedText;
  
  /// Generation metadata
  final Map<String, dynamic> metadata;

  TTSResult({
    required this.audioData,
    required this.format,
    required this.sampleRate,
    required this.channels,
    required this.durationMs,
    required this.inputText,
    this.generatedText,
    this.metadata = const {},
  });
}

/// Options for TTS generation
class TTSOptions {
  /// Voice ID or name (model-specific)
  final String? voice;
  
  /// Speaking rate (0.5 = half speed, 2.0 = double speed)
  final double? speed;
  
  /// Voice pitch (-1.0 to 1.0)
  final double? pitch;
  
  /// Audio volume (0.0 to 1.0)
  final double? volume;
  
  /// Maximum audio length in seconds
  final int? maxDuration;
  
  /// Audio format preference (wav, mp3, pcm)
  final String? preferredFormat;
  
  /// Sample rate preference
  final int? preferredSampleRate;

  const TTSOptions({
    this.voice,
    this.speed,
    this.pitch,
    this.volume,
    this.maxDuration,
    this.preferredFormat,
    this.preferredSampleRate,
  });
}

/// Streaming audio chunk
class TTSChunk {
  /// Audio data for this chunk
  final Uint8List audioData;
  
  /// Chunk sequence number
  final int sequence;
  
  /// Whether this is the final chunk
  final bool isLast;
  
  /// Text portion this chunk represents
  final String? textSegment;

  TTSChunk({
    required this.audioData,
    required this.sequence,
    required this.isLast,
    this.textSegment,
  });
}

/// Abstract base class for text-to-speech models
abstract class TTSModel {
  /// Model name/identifier
  String get name;
  
  /// Whether this model supports streaming audio generation
  bool get supportsStreaming;
  
  /// Available voices for this model
  Future<List<String>> get availableVoices;
  
  /// Default audio format for this model
  String get defaultFormat;
  
  /// Generate speech from text
  Future<TTSResult> generateSpeech(
    String text, {
    TTSOptions? options,
  });
  
  /// Generate speech with streaming output
  Stream<TTSChunk> generateSpeechStream(
    String text, {
    TTSOptions? options,
  });
  
  /// Check if model supports audio generation
  Future<bool> get supportsAudio;
  
  /// Dispose of model resources
  Future<void> dispose();
}