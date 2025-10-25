import 'package:dartantic_cactus/dartantic_cactus.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';

void main() {
  group('CactusProvider', () {
    late CactusProvider provider;

    setUp(() {
      provider = CactusProvider();
    });

    test('has correct provider metadata', () {
      expect(provider.name, 'cactus');
      expect(provider.displayName, 'Cactus AI');
      expect(provider.apiKey, isNull);
      expect(provider.apiKeyName, isNull);
    });

    test('has correct capabilities', () {
      expect(provider.caps, contains(ProviderCaps.chat));
      expect(provider.caps, contains(ProviderCaps.embeddings));
      expect(provider.caps, contains(ProviderCaps.thinking));
      expect(provider.caps, contains(ProviderCaps.multiToolCalls));
      expect(provider.caps, contains(ProviderCaps.typedOutput));
      
      // Should NOT have vision or TTS after main branch migration
      expect(provider.caps, isNot(contains(ProviderCaps.chatVision)));
      expect(provider.caps, isNot(contains(ProviderCaps.textToSpeech)));
    });

    test('has default model name for chat', () {
      expect(provider.defaultModelNames[ModelKind.chat], 
             equals('phi-3-mini-4k-instruct'));
    });

    test('createChatModel returns CactusChatModel', () {
      final model = provider.createChatModel(
        name: 'test-model',
        options: const CactusChatModelOptions(modelUrl: 'qwen3-0.6'),
      );
      
      expect(model, isA<CactusChatModel>());
      expect(model.name, 'test-model');
    });

    test('createChatModel uses default model name when not specified', () {
      final model = provider.createChatModel();
      
      expect(model, isA<CactusChatModel>());
      expect(model.name, 'phi-3-mini-4k-instruct');
    });

    test('createChatModel accepts tools', () {
      final tool = Tool(
        name: 'test_tool',
        description: 'A test tool',
        inputSchema: JsonSchema.create(const {}),
        onCall: (args) async => 'result',
      );
      
      final model = provider.createChatModel(
        tools: [tool],
        options: const CactusChatModelOptions(modelUrl: 'qwen3-0.6'),
      );
      
      expect(model, isA<CactusChatModel>());
      expect(model.tools, isNotNull);
      expect(model.tools!.length, 1);
    });

    test('createChatModel accepts temperature', () {
      final model = provider.createChatModel(
        temperature: 0.5,
        options: const CactusChatModelOptions(modelUrl: 'qwen3-0.6'),
      );
      
      expect(model, isA<CactusChatModel>());
      expect(model.temperature, 0.5);
    });

    test('createEmbeddingsModel returns CactusEmbeddingsModel', () {
      final model = provider.createEmbeddingsModel(
        name: 'test-embeddings',
        options: const CactusEmbeddingsModelOptions(modelUrl: 'qwen3-0.6'),
      );
      
      expect(model, isA<CactusEmbeddingsModel>());
      expect(model.name, 'test-embeddings');
    });

    test('createEmbeddingsModel uses default name when not specified', () {
      final model = provider.createEmbeddingsModel(
        options: const CactusEmbeddingsModelOptions(modelUrl: 'qwen3-0.6'),
      );
      
      expect(model, isA<CactusEmbeddingsModel>());
      expect(model.name, 'default');
    });

    test('listModels returns empty stream', () async {
      final models = await provider.listModels().toList();
      expect(models, isEmpty);
    });
  });
}
