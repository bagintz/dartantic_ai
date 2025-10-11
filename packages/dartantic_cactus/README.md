# Dartantic Cactus AI Provider

A [dartantic_ai](https://pub.dev/packages/dartantic_interface) provider that enables on-device AI model execution using the [Cactus](https://pub.dev/packages/cactus) framework. Run language models, vision models, and generate embeddings locally on Flutter devices without network dependencies.

## Features

- 🏠 **On-Device Execution**: Run AI models locally without internet connectivity
- 🚀 **Multiple Model Types**: Support for language models (LM), vision language models (VLM), and text-to-speech (TTS)
- 📱 **Flutter Integration**: Seamless integration with Flutter applications
- 🎯 **GGUF Format**: Support for HuggingFace GGUF models
- ⚡ **GPU Acceleration**: Configurable GPU layer offloading for better performance
- 🔄 **Streaming**: Real-time token streaming for chat applications
- 🖼️ **Multimodal**: Vision models for image analysis and description
- 🎨 **Embeddings**: Generate text embeddings for semantic search
- ☁️ **Cloud Fallback**: Enterprise features for hybrid local/cloud execution

## Quick Start

### 1. Add Dependencies

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dartantic_interface: ^1.1.0
  dartantic_cactus: ^0.1.0
```

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
  model: 'cactus:phi-3-mini-4k-instruct',
  modelOptions: CactusChatModelOptions(
    modelUrl: 'https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf',
    contextSize: 4096,
    gpuLayers: 20,  // Use GPU acceleration
    temperature: 0.7,
  ),
);
```

### Vision Language Model

```dart
final visionAgent = Agent(
  model: 'cactus:llava-phi-3-mini',
  modelOptions: CactusChatModelOptions(
    modelUrl: 'https://huggingface.co/xtuner/llava-phi-3-mini-gguf/resolve/main/llava-phi-3-mini-int4.gguf',
    mmprojUrl: 'https://huggingface.co/xtuner/llava-phi-3-mini-gguf/resolve/main/llava-phi-3-mini-mmproj-f16.gguf',
    contextSize: 4096,
    supportVision: true,
  ),
);

// Send image with text
final response = await visionAgent.text(
  'What do you see in this image?',
  images: ['/path/to/image.jpg'],
);
```

### Embeddings Model

```dart
final embeddingsModel = CactusEmbeddingsModel(
  options: CactusEmbeddingsModelOptions(
    modelUrl: 'https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/model.gguf',
    generateEmbeddings: true,
  ),
);

final embeddings = await embeddingsModel.generate(['Hello world', 'AI is amazing']);
```

## Advanced Usage

### Streaming Responses

```dart
final agent = Agent(model: 'cactus:llama-3.1-8b-instruct');

await for (final chunk in agent.stream('Tell me a story')) {
  print(chunk.text);  // Print each token as it arrives
}
```

### Local Model Files

```dart
final agent = Agent(
  model: 'cactus:local-model',
  modelOptions: CactusChatModelOptions(
    modelUrl: '/path/to/local/model.gguf',  // Local file path
    contextSize: 2048,
  ),
);
```

### Performance Optimization

```dart
final optimizedOptions = CactusChatModelOptions(
  modelUrl: 'https://huggingface.co/model.gguf',
  contextSize: 2048,        // Smaller context = faster inference
  gpuLayers: 20,            // Use GPU acceleration
  threads: 4,               // Optimize for device CPU cores
  temperature: 0.3,         // Lower temperature = faster generation
);
```

## Model Recommendations

### Language Models
- **Phi-3 Mini (3.8B)**: Excellent for mobile devices, good balance of size and capability
- **Llama 3.1 8B**: High quality responses, requires more powerful hardware
- **Gemma 2B**: Very lightweight, good for basic tasks

### Vision Models  
- **LLaVA-Phi-3-Mini**: Good mobile vision model with reasonable memory usage
- **MobileVLM**: Optimized specifically for mobile devices

### Embedding Models
- **all-MiniLM-L6-v2**: Fast and accurate sentence embeddings
- **all-mpnet-base-v2**: Higher quality embeddings, larger model

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
- **Vision Chat**: Multimodal chat with image analysis  
- **Embeddings Demo**: Semantic search implementation
- **Performance Monitor**: Real-time performance metrics

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

## Links

- [Cactus Package](https://pub.dev/packages/cactus)
- [Dartantic AI Framework](https://pub.dev/packages/dartantic_interface)
- [HuggingFace GGUF Models](https://huggingface.co/models?library=gguf)
- [Documentation](https://github.com/csells/dartantic_ai/tree/main/docs)