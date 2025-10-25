import 'package:dartantic_cactus/dartantic_cactus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CactusChatModelOptions', () {
    test('creates with required parameters', () {
      const options = CactusChatModelOptions(
        modelUrl: 'qwen3-0.6',
      );
      
      expect(options.modelUrl, 'qwen3-0.6');
      expect(options.contextSize, 2048); // default
      expect(options.temperature, 0.7); // default
      expect(options.maxTokens, 2048); // default
      expect(options.stopSequences, ['<|im_end|>', '<end_of_turn>']); // default now matches SDK
      expect(options.cactusToken, isNull); // default
    });

    test('creates with all parameters', () {
      const options = CactusChatModelOptions(
        modelUrl: 'phi-3-mini',
        contextSize: 4096,
        temperature: 0.5,
        maxTokens: 1024,
        stopSequences: ['<|im_end|>', '<|end|>'],
        cactusToken: 'test-token-123',
      );
      
      expect(options.modelUrl, 'phi-3-mini');
      expect(options.contextSize, 4096);
      expect(options.temperature, 0.5);
      expect(options.maxTokens, 1024);
      expect(options.stopSequences, ['<|im_end|>', '<|end|>']);
      expect(options.cactusToken, 'test-token-123');
    });

    test('uses default values correctly', () {
      const options = CactusChatModelOptions(
        modelUrl: 'test-model',
      );
      
      // Verify defaults match documentation and SDK
      expect(options.contextSize, 2048);
      expect(options.temperature, 0.7);
      expect(options.maxTokens, 2048);
      expect(options.stopSequences, ['<|im_end|>', '<end_of_turn>']);
    });

    test('is immutable', () {
      const options1 = CactusChatModelOptions(
        modelUrl: 'qwen3-0.6',
        temperature: 0.8,
      );
      
      const options2 = CactusChatModelOptions(
        modelUrl: 'qwen3-0.6',
        temperature: 0.8,
      );
      
      // Should be equal since const
      expect(options1.modelUrl, options2.modelUrl);
      expect(options1.temperature, options2.temperature);
    });
  });

  group('CactusEmbeddingsModelOptions', () {
    test('creates with required parameters', () {
      const options = CactusEmbeddingsModelOptions(
        modelUrl: 'qwen3-0.6',
      );
      
      expect(options.modelUrl, 'qwen3-0.6');
      expect(options.contextSize, 2048); // default
      expect(options.cactusToken, isNull); // default
    });

    test('creates with all parameters', () {
      const options = CactusEmbeddingsModelOptions(
        modelUrl: 'all-MiniLM-L6-v2',
        contextSize: 4096,
        cactusToken: 'test-token-456',
      );
      
      expect(options.modelUrl, 'all-MiniLM-L6-v2');
      expect(options.contextSize, 4096);
      expect(options.cactusToken, 'test-token-456');
    });

    test('uses default context size', () {
      const options = CactusEmbeddingsModelOptions(
        modelUrl: 'test-model',
      );
      
      expect(options.contextSize, 2048);
    });

    test('is immutable', () {
      const options1 = CactusEmbeddingsModelOptions(
        modelUrl: 'qwen3-0.6',
        contextSize: 4096,
      );
      
      const options2 = CactusEmbeddingsModelOptions(
        modelUrl: 'qwen3-0.6',
        contextSize: 4096,
      );
      
      expect(options1.modelUrl, options2.modelUrl);
      expect(options1.contextSize, options2.contextSize);
    });
  });
}
