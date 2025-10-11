# Dartantic Cactus AI Provider - Development Plan

## Overview

This document outlines the development plan for `dartantic_cactus`, a provider for the dartantic_ai framework that integrates with the [Cactus package](https://pub.dev/packages/cactus) to enable on-device AI model execution in Flutter applications.

## Cactus Package Capabilities

Based on the documentation analysis, Cactus provides:

### Core Model Types
1. **CactusLM (Language Models)**
   - Text completion and chat functionality
   - Embedding generation
   - Streaming token output
   - GGUF model format support
   - GPU acceleration support

2. **CactusVLM (Vision Language Models)**
   - Multimodal image and text processing
   - Image description and analysis
   - Supports local image file paths

3. **CactusTTS (Text-to-Speech Models)**
   - Text-to-speech generation
   - GGUF TTS model support

### Key Features
- **On-device execution**: Models run locally without network dependency
- **Cloud fallback**: Enterprise features for hybrid local/cloud execution
- **GPU acceleration**: Configurable GPU layer offloading
- **Progress callbacks**: Model download and initialization progress
- **Resource management**: Explicit model disposal and context clearing
- **Streaming support**: Real-time token streaming for chat applications

## Architecture Design

### Package Structure
```
dartantic_cactus/
├── lib/
│   ├── dartantic_cactus.dart                    # Main export file
│   └── src/
│       ├── cactus_provider.dart                 # Main provider implementation
│       ├── cactus_chat_model.dart               # Chat model wrapper
│       ├── cactus_chat_options.dart             # Model configuration options
│       ├── cactus_embeddings_model.dart         # Embeddings model wrapper
│       ├── cactus_multimodal_utils.dart         # Vision/multimodal support
│       ├── cactus_streaming_accumulator.dart    # Streaming response handler
│       ├── cactus_thinking_utils.dart           # Thinking/reasoning support
│       └── cactus_message_mappers.dart          # Message format conversion
├── example/
│   ├── lib/
│   │   ├── main.dart                            # Demo application
│   │   ├── console_demo.dart                    # Console-based demo
│   │   └── vision_demo.dart                     # Vision model demo
│   └── pubspec.yaml
├── test/
│   ├── cactus_provider_test.dart
│   ├── cactus_chat_model_test.dart
│   ├── cactus_embeddings_model_test.dart
│   ├── cactus_multimodal_utils_test.dart
│   ├── cactus_streaming_accumulator_test.dart
│   ├── cactus_thinking_utils_test.dart
│   └── mock_cactus.dart                         # Mock implementations for testing
├── pubspec.yaml
├── README.md
├── CHANGELOG.md
├── LICENSE
└── DEVELOPMENT_PLAN.md                          # This file
```

## Implementation Strategy

### Phase 1: Core Infrastructure (MVP)

#### 1.1 Provider Foundation
- [ ] Create `CactusProvider` class extending `Provider<CactusChatModelOptions, CactusEmbeddingsModelOptions>`
- [ ] Implement model discovery and validation
- [ ] Support for local model file paths and HuggingFace URLs
- [ ] Basic configuration management

#### 1.2 Chat Model Implementation
- [ ] Create `CactusChatModel` extending `ChatModel`
- [ ] Implement basic text completion using `CactusLM`
- [ ] Support for streaming responses with `onToken` callback
- [ ] Message format conversion (dartantic ↔ Cactus)
- [ ] Model lifecycle management (init/dispose)

#### 1.3 Configuration Options
- [ ] Create `CactusChatModelOptions` class
- [ ] Support for:
  - Model URL/path configuration
  - Context size settings
  - GPU layer configuration
  - Thread count optimization
  - Temperature and token limits

#### 1.4 Basic Testing
- [ ] Unit tests for core functionality
- [ ] Mock Cactus implementations for testing
- [ ] Integration tests with sample models

### Phase 2: Advanced Features

#### 2.1 Embeddings Support
- [ ] Create `CactusEmbeddingsModel` extending `EmbeddingsModel`
- [ ] Implement text embedding generation
- [ ] Support for batch embedding processing
- [ ] Configuration for embedding-enabled models

#### 2.2 Multimodal/Vision Support
- [ ] Implement `CactusVLM` integration
- [ ] Support for image input in chat messages
- [ ] Image path resolution and validation
- [ ] Vision-specific model configuration

#### 2.3 Streaming Enhancements
- [ ] Advanced streaming accumulator
- [ ] Support for tool calling streams (if applicable)
- [ ] Error handling in streaming contexts
- [ ] Backpressure management

#### 2.4 Performance Optimization
- [ ] Model caching and reuse strategies
- [ ] Memory management optimizations
- [ ] GPU utilization monitoring
- [ ] Performance metrics and logging

### Phase 3: Enterprise Features

#### 3.1 Cloud Fallback Integration
- [ ] Support for Cactus enterprise tokens
- [ ] Local-first with cloud fallback mode
- [ ] Remote-first with local fallback mode
- [ ] Hybrid execution strategies

#### 3.2 Advanced Model Management
- [ ] Model versioning and updates
- [ ] LoRA adapter support (if available in Cactus)
- [ ] Model quantization options
- [ ] Dynamic model loading/unloading

#### 3.3 Production Features
- [ ] Comprehensive error handling
- [ ] Detailed logging and diagnostics
- [ ] Performance monitoring
- [ ] Resource usage tracking

## Technical Considerations

### Model Format Support
- **Primary**: GGUF format models from HuggingFace
- **Local**: Support for local file paths
- **Remote**: HuggingFace model URLs with automatic downloading
- **Vision**: Separate mmproj models for vision capabilities

### Memory Management
- **Explicit disposal**: All models must be explicitly disposed
- **Context management**: Support for context clearing/rewinding
- **Resource tracking**: Monitor GPU/CPU memory usage
- **Lifecycle**: Proper Flutter widget lifecycle integration

### Performance Considerations
- **GPU Acceleration**: Configurable GPU layer offloading
- **Thread Optimization**: CPU thread count configuration
- **Context Size**: Balancing memory usage vs capability
- **Quantization**: Support for different model quantization levels

### Error Handling
- **Model Loading**: Handle download failures and corruption
- **Runtime Errors**: GPU memory exhaustion, context overflow
- **Network Issues**: For cloud fallback scenarios
- **Resource Constraints**: Device-specific limitations

## Integration with Dartantic AI

### Provider Registration
```dart
// Register the Cactus provider
DartanticAI.registerProvider(CactusProvider());

// Use with model string format
final agent = Agent(
  model: 'cactus:llama-3.1-8b-instruct',  // Provider:model format
  // ... other configuration
);
```

### Model Configuration Examples
```dart
// Basic chat model
final chatOptions = CactusChatModelOptions(
  modelUrl: 'https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf',
  contextSize: 4096,
  gpuLayers: 20,
  temperature: 0.7,
);

// Vision model
final visionOptions = CactusChatModelOptions(
  modelUrl: 'https://huggingface.co/xtuner/llava-phi-3-mini-gguf',
  mmprojUrl: 'https://huggingface.co/xtuner/llava-phi-3-mini-gguf/mmproj.gguf',
  contextSize: 4096,
  supportVision: true,
);

// Embeddings model
final embeddingOptions = CactusEmbeddingsModelOptions(
  modelUrl: 'https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2',
  generateEmbeddings: true,
);
```

## Dependencies

### Required Dependencies
```yaml
dependencies:
  dartantic_interface: ^1.1.0
  cactus: ^0.2.0  # Core Cactus package
  flutter:
    sdk: flutter
  logging: ^1.3.0
  meta: ^1.16.0
  path: ^1.8.0  # For local file path handling
  http: ^1.4.0  # For model downloading
```

### Development Dependencies
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  test: ^1.24.0
  mocktail: ^1.0.0  # For mocking in tests
  all_lint_rules_community: ^0.0.43
```

## Example Applications

### 1. Basic Chat Application
- Simple chat interface using local LLM
- Streaming response display
- Model switching capability
- Performance metrics display

### 2. Vision Chat Application
- Image picker integration
- Multimodal chat with images
- Image analysis and description
- Vision model comparison

### 3. Embeddings Demo
- Text similarity search
- Semantic search implementation
- Document clustering
- Embedding visualization

## Testing Strategy

### Unit Testing
- [ ] Provider initialization and configuration
- [ ] Model lifecycle management
- [ ] Message format conversion
- [ ] Streaming accumulator logic
- [ ] Error handling scenarios

### Integration Testing
- [ ] End-to-end chat functionality
- [ ] Vision model integration
- [ ] Embeddings generation
- [ ] Performance benchmarks

### Mock Strategy
- [ ] Mock Cactus implementations for CI/CD
- [ ] Simulate different model types
- [ ] Error condition simulation
- [ ] Performance testing mocks

## Documentation Plan

### API Documentation
- [ ] Comprehensive dartdoc comments
- [ ] Usage examples for all classes
- [ ] Configuration guides
- [ ] Performance tuning tips

### User Guides
- [ ] Quick start guide
- [ ] Model selection guide
- [ ] Performance optimization guide
- [ ] Troubleshooting guide

### Examples
- [ ] Basic chat application
- [ ] Vision/multimodal examples
- [ ] Embeddings usage
- [ ] Enterprise/cloud integration

## Security Considerations

### Local Model Security
- [ ] Model file verification
- [ ] Secure model storage
- [ ] Permission handling for file access
- [ ] Privacy-first design (no data leaves device by default)

### Enterprise Features
- [ ] Secure token management
- [ ] Cloud communication security
- [ ] Data privacy controls
- [ ] Audit logging capabilities

## Performance Benchmarks

### Target Performance Metrics
- [ ] Model loading time < 30 seconds for typical models
- [ ] First token latency < 2 seconds
- [ ] Sustained token generation > 10 tokens/second
- [ ] Memory usage < 2GB for 7B parameter models
- [ ] GPU utilization > 80% when available

### Benchmarking Suite
- [ ] Model loading performance tests
- [ ] Inference speed benchmarks
- [ ] Memory usage profiling
- [ ] Battery impact assessment
- [ ] Cross-platform performance comparison

## Questions for Clarification

1. **Model Repository Strategy**: Should we provide a curated list of recommended models, or allow any GGUF model?

2. **Cloud Integration**: What level of cloud fallback integration should we prioritize? Enterprise-only or general availability?

3. **Platform Support**: Should we target all Flutter platforms (iOS, Android, Web, Desktop) or focus on mobile-first?

4. **Model Size Limits**: What are reasonable model size limits for different device categories?

5. **Backwards Compatibility**: How important is backwards compatibility with older Cactus versions?

6. **Tool Calling**: Does Cactus support function calling, or should we implement this at the dartantic level?

7. **Custom Model Support**: Should we support custom/fine-tuned models beyond standard HuggingFace offerings?

8. **Resource Management**: Should we implement automatic model cleanup/LRU eviction, or leave this to the developer?

## Success Criteria

### MVP (Phase 1)
- [ ] Basic text chat functionality working
- [ ] Streaming responses implemented
- [ ] Model loading from URLs and local paths
- [ ] Core tests passing
- [ ] Basic documentation complete

### Full Release (Phase 2-3)
- [ ] All model types supported (LM, VLM, TTS)
- [ ] Embeddings functionality complete
- [ ] Vision/multimodal capabilities working
- [ ] Performance benchmarks met
- [ ] Comprehensive test coverage (>90%)
- [ ] Production-ready error handling
- [ ] Complete documentation suite

## Timeline Estimate

### Phase 1 (MVP): 2-3 weeks
- Core provider and chat model implementation
- Basic configuration and testing
- Simple example application

### Phase 2 (Advanced): 2-3 weeks  
- Embeddings and vision support
- Enhanced streaming and performance optimization
- Comprehensive testing suite

### Phase 3 (Enterprise): 1-2 weeks
- Cloud fallback integration
- Advanced model management
- Production hardening

**Total Estimated Timeline: 5-8 weeks**

---

This plan provides a comprehensive roadmap for implementing the `dartantic_cactus` provider. The modular approach allows for incremental development and testing, while the phased timeline ensures we can deliver value early with the MVP while building toward a full-featured provider.