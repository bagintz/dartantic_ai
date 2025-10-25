# Dartantic Cactus AI Provider

A [dartantic_ai](https://pub.dev/packages/dartantic_interface) provider that enables on-device AI model execution using the [Cactus](https://github.com/cactus-compute/cactus-flutter) framework. Run language models and generate embeddings locally on Flutter devices without network dependencies.

> **⚠️ Migration Notice**: This provider is being updated to use Cactus main branch (0.3.1+). See [MAIN_BRANCH_MIGRATION.md](MAIN_BRANCH_MIGRATION.md) for details.

## Features

- 🏠 **On-Device Execution**: Run AI models locally without internet connectivity
- 🚀 **Language Models**: Support for text generation and chat
- 📱 **Flutter Integration**: Seamless integration with Flutter applications
- 🎯 **GGUF Format**: Support for HuggingFace GGUF models via model catalog
- 🔄 **Streaming**: Real-time token streaming for chat applications
- 🎨 **Embeddings**: Generate text embeddings for semantic search
- ☁️ **Hybrid Mode**: Optional cloud fallback for enhanced capabilities
- 🔧 **Automatic Tool Filtering**: Smart tool selection based on query relevance (Cactus SDK 0.3.1+)
- 🗂️ **Built-in RAG**: Vector search capabilities for retrieval-augmented generation (SDK-level)
- ⚡ **Optimized Defaults**: Temperature 0.7, topK 20 for improved response quality

## Known Limitations

- ❌ **No Vision Support**: Vision/multimodal capabilities not available in current Cactus main branch
- ❌ **No TTS Support**: Text-to-speech removed from main branch
- ⚠️ **GitHub Installation**: Must install from GitHub (not available on pub.dev yet)

For vision capabilities, consider using `dartantic_firebase_ai` or other providers.

## Quick Start

### 1. Add Dependencies

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dartantic_interface: ^1.1.0
  dartantic_cactus:
    git:
      url: https://github.com/csells/dartantic_ai.git
      path: packages/dartantic_cactus
```

> **Note**: Cactus provider must be installed from GitHub until pub.dev release is available.

### 2. Register the Provider

```dart
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:dartantic_cactus/dartantic_cactus.dart';

void main() {
  // Register the Cactus provider
  DartanticAI.registerProvider(CactusProvider());
  
  runApp(MyApp());
}
```

### 3. Use with Agents

```dart
import 'package:dartantic_interface/dartantic_interface.dart';

final agent = Agent(
  model: 'cactus:llama-3.1-8b-instruct',  // provider:model format
  systemMessage: 'You are a helpful AI assistant.',
);

final response = await agent.text('Hello! How are you?');
print(response.text);
```

## Model Configuration

### Basic Language Model

```dart
final agent = Agent(
  model: 'cactus:qwen3-0.6',  // Use model slug from Cactus catalog
  modelOptions: CactusChatModelOptions(
    modelUrl: 'qwen3-0.6',  // Model catalog identifier (will be renamed to modelSlug in next version)
    contextSize: 4096,
  ),
);
```

> **⚠️ Breaking Change**: Model configuration now uses model slugs (catalog identifiers like 'qwen3-0.6') instead of direct HuggingFace URLs. The `modelUrl` parameter name is kept for backward compatibility but now accepts model slugs. See [MAIN_BRANCH_MIGRATION.md](MAIN_BRANCH_MIGRATION.md) for migration guide.

### Embeddings Model

```dart
final embeddingsModel = CactusEmbeddingsModel(
  name: 'all-MiniLM-L6-v2',
  options: CactusEmbeddingsModelOptions(
    modelUrl: 'all-MiniLM-L6-v2',  // Model catalog slug
  ),
);

final result = await embeddingsModel.embedDocuments(['Hello world', 'AI is amazing']);
print('Generated ${result.output.length} embeddings');
```

## Advanced Usage

### Streaming Responses

```dart
final agent = Agent(model: 'cactus:llama-3.1-8b-instruct');

await for (final chunk in agent.stream('Tell me a story')) {
  print(chunk.text);  // Print each token as it arrives
}
```

### Performance Optimization

```dart
final optimizedOptions = CactusChatModelOptions(
  modelUrl: 'qwen3-0.6',    // Lightweight model
  contextSize: 2048,        // Smaller context = faster inference
);
```

## Model Recommendations

### Language Models
- **qwen3-0.6**: Default model, lightweight and fast
- **phi-3-mini**: Good balance of size and capability for mobile devices
- **llama-3.1-8b**: High quality responses, requires more powerful hardware

### Embedding Models
- **all-MiniLM-L6-v2**: Fast and accurate sentence embeddings
- **all-mpnet-base-v2**: Higher quality embeddings, larger model

> **Note**: Available models depend on Cactus model catalog. Vision models not currently supported.

## Platform Support

| Platform | Support Level | Notes |
|----------|--------------|-------|
| Android  | ✅ Full      | Primary supported platform |
| iOS      | ✅ Full      | Primary supported platform |
| macOS    | ❌ Unknown   | Not confirmed by Cactus documentation |
| Windows  | ❌ Unknown   | Not confirmed by Cactus documentation |
| Linux    | ❌ Unknown   | Not confirmed by Cactus documentation |
| Web      | ❌ Not supported | GGUF models not supported in browser |

## Performance Guidelines

### Device Requirements
- **Minimum RAM**: 4GB for 2B parameter models
- **Recommended RAM**: 8GB+ for 7B+ parameter models  
- **Storage**: 2-20GB depending on model size
- **GPU**: Optional but recommended for better performance

### Model Size Guidelines
| Device Class | Recommended Max Model Size | GPU Memory |
|-------------|---------------------------|------------|
| Budget Phone | 2B parameters (~1-2GB) | Not required |
| Mid-range Phone | 3-7B parameters (~2-4GB) | 2GB+ recommended |
| High-end Phone | 7-13B parameters (~4-8GB) | 4GB+ recommended |
| Tablet/Desktop | 13B+ parameters (~8GB+) | 6GB+ recommended |

## Examples

Check out the [example](example/) directory for complete sample applications:

- **Basic Chat**: Simple chat interface with streaming
- **Embeddings Demo**: Semantic search implementation

> **Note**: Examples are being updated for main branch API. Some examples may not work until migration is complete.

## Development

### Running Tests

```bash
cd packages/dartantic_cactus
flutter test
```

### Running Examples

```bash
cd packages/dartantic_cactus/example
flutter run
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Migration Guide

If you're upgrading from an earlier version, see [MAIN_BRANCH_MIGRATION.md](MAIN_BRANCH_MIGRATION.md) for:
- Breaking changes
- API updates
- Feature changes
- Migration checklist

## Links

- [Cactus GitHub](https://github.com/cactus-compute/cactus-flutter)
- [Dartantic AI Framework](https://pub.dev/packages/dartantic_interface)
- [HuggingFace GGUF Models](https://huggingface.co/models?library=gguf)
- [Documentation](https://github.com/csells/dartantic_ai/tree/main/docs)