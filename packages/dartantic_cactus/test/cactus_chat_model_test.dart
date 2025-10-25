import 'package:dartantic_cactus/src/cactus_chat_model.dart';
import 'package:dartantic_cactus/src/cactus_chat_options.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';

void main() {
  group('CactusChatModel Unit Tests', () {
    group('Constructor and Properties', () {
      test('creates model with default options', () {
        final model = CactusChatModel(name: 'test-model');
        expect(model.name, 'test-model');
        expect(model.defaultOptions, isA<CactusChatModelOptions>());
      });

      test('creates model with custom options', () {
        final model = CactusChatModel(
          name: 'custom-model',
          options: const CactusChatModelOptions(
            modelUrl: 'custom-url',
            contextSize: 4096,
          ),
        );
        expect(model.name, 'custom-model');
        expect(model.defaultOptions.modelUrl, 'custom-url');
      });

      test('creates model with tools', () {
        final tools = [
          Tool(
            name: 'test_tool',
            description: 'A test tool',
            onCall: (args) async => 'result',
            inputSchema: JsonSchema.create(const {}),
          ),
        ];
        final model = CactusChatModel(name: 'tool-model', tools: tools);
        expect(model.tools, tools);
      });
    });

    group('Tool and Schema Validation', () {
      test('rejects tools with outputSchema', () async {
        final tools = [
          Tool(
            name: 'test',
            description: 'Test',
            onCall: (args) async => 'result',
            inputSchema: JsonSchema.create(const {}),
          ),
        ];
        final model = CactusChatModel(name: 'test-model', tools: tools);
        final schema = JsonSchema.create(const {'type': 'object'});
        final messages = [ChatMessage.user('Test')];
        
        // The error is thrown when we try to consume the stream
        final stream = model.sendStream(messages, outputSchema: schema);
        expect(
          () => stream.toList(),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Dispose', () {
      test('dispose completes without error', () {
        final model = CactusChatModel(name: 'test');
        expect(() => model.dispose(), returnsNormally);
      });
    });
  });
}
