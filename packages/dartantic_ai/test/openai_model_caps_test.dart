// ignore_for_file: avoid_print
/// TESTING PHILOSOPHY:
/// 1. DO NOT catch exceptions - let them bubble up for diagnosis
/// 2. DO NOT add provider filtering except by capabilities (e.g. ProviderCaps)
/// 3. DO NOT add performance tests
/// 4. DO NOT add regression tests
/// 5. 80% cases = common usage patterns tested across ALL capable providers
/// 6. Edge cases = rare scenarios tested on Google only to avoid timeouts
/// 7. Each functionality should only be tested in ONE file - no duplication
///
/// Tests for OpenAI fetchModelCaps implementation.

import 'dart:convert';
import 'dart:io';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'package:dartantic_ai/dartantic_ai.dart';

void main() {
  final apiKey = Platform.environment['OPENAI_API_KEY'];

  group('OpenAI Models API Exploration', () {
    test('List all models and examine structure', () async {
      if (apiKey == null) {
        print('OPENAI_API_KEY not set, skipping test');
        return;
      }

      final response = await http.get(
        Uri.parse('https://api.openai.com/v1/models'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      );

      expect(response.statusCode, 200);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final models = data['data'] as List;

      print('Total models: ${models.length}');
      print('');

      // Group models by prefix
      final modelsByPrefix = <String, List<String>>{};
      for (final model in models) {
        final id = model['id'] as String;
        final prefix = id.split('-').first;
        modelsByPrefix.putIfAbsent(prefix, () => []).add(id);
      }

      print('Models by prefix:');
      for (final entry in modelsByPrefix.entries) {
        print('  ${entry.key}: ${entry.value.length} models');
        for (final id in entry.value.take(5)) {
          print('    - $id');
        }
        if (entry.value.length > 5) {
          print('    ... and ${entry.value.length - 5} more');
        }
      }
      print('');

      // Print first model's full structure
      print('Sample model structure (first model):');
      final firstModel = models.first as Map<String, dynamic>;
      print(const JsonEncoder.withIndent('  ').convert(firstModel));
      print('');

      // Look for GPT-4 models specifically
      print('GPT-4 models:');
      for (final model in models) {
        final id = model['id'] as String;
        if (id.contains('gpt-4')) {
          print('  $id');
          print('    owned_by: ${model['owned_by']}');
          print('    object: ${model['object']}');
        }
      }
      print('');

      // Look for o1/o3 models (reasoning)
      print('O-series models (reasoning):');
      for (final model in models) {
        final id = model['id'] as String;
        if (id.startsWith('o1') || id.startsWith('o3') || id.startsWith('o4')) {
          print('  $id');
          print(
            '    Full: ${const JsonEncoder.withIndent('    ').convert(model)}',
          );
        }
      }
      print('');

      // Look for embedding models
      print('Embedding models:');
      for (final model in models) {
        final id = model['id'] as String;
        if (id.contains('embedding')) {
          print('  $id');
        }
      }
      print('');

      // Look for audio models
      print('Audio/TTS/Whisper models:');
      for (final model in models) {
        final id = model['id'] as String;
        if (id.contains('whisper') ||
            id.contains('tts') ||
            id.contains('audio')) {
          print('  $id');
        }
      }
      print('');

      // Look for image models
      print('Image models (dall-e):');
      for (final model in models) {
        final id = model['id'] as String;
        if (id.contains('dall-e')) {
          print('  $id');
        }
      }
    });

    test('Get specific model details', () async {
      if (apiKey == null) {
        print('OPENAI_API_KEY not set, skipping test');
        return;
      }

      // Try to get details for specific models
      final modelsToCheck = [
        'gpt-4o',
        'gpt-4o-mini',
        'gpt-4-turbo',
        'o1',
        'o1-mini',
        'o3-mini',
        'text-embedding-3-small',
        'text-embedding-ada-002',
        'whisper-1',
        'tts-1',
        'dall-e-3',
      ];

      for (final modelId in modelsToCheck) {
        final response = await http.get(
          Uri.parse('https://api.openai.com/v1/models/$modelId'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final model = jsonDecode(response.body) as Map<String, dynamic>;
          print('Model: $modelId');
          print(const JsonEncoder.withIndent('  ').convert(model));
          print('');
        } else {
          print(
            'Model $modelId: ${response.statusCode} - not found or no access',
          );
        }
      }
    });
  }, tags: ['needs-key']);

  group('OpenAI Provider ModelCaps', () {
    test(
      'fetchModelCaps returns correct capabilities for various models',
      () async {
        if (apiKey == null) {
          print('OPENAI_API_KEY not set, skipping test');
          return;
        }

        final provider = OpenAIProvider(apiKey: apiKey);

        // Test various model patterns
        final testCases = <String, List<ModelCaps>>{
          // GPT-4o multimodal models
          'gpt-4o': [
            ModelCaps.chat,
            ModelCaps.chatVision,
            ModelCaps.multiToolCalls,
            ModelCaps.typedOutput,
            ModelCaps.typedOutputWithTools,
          ],
          'gpt-4o-mini': [
            ModelCaps.chat,
            ModelCaps.chatVision,
            ModelCaps.multiToolCalls,
            ModelCaps.typedOutput,
            ModelCaps.typedOutputWithTools,
          ],
          'gpt-4o-2024-11-20': [
            ModelCaps.chat,
            ModelCaps.chatVision,
            ModelCaps.multiToolCalls,
            ModelCaps.typedOutput,
            ModelCaps.typedOutputWithTools,
          ],

          // GPT-4.1 models
          'gpt-4.1': [
            ModelCaps.chat,
            ModelCaps.chatVision,
            ModelCaps.multiToolCalls,
            ModelCaps.typedOutput,
            ModelCaps.typedOutputWithTools,
          ],
          'gpt-4.1-mini': [
            ModelCaps.chat,
            ModelCaps.chatVision,
            ModelCaps.multiToolCalls,
            ModelCaps.typedOutput,
            ModelCaps.typedOutputWithTools,
          ],

          // O-series reasoning models
          'o1': [
            ModelCaps.chat,
            ModelCaps.thinking,
            ModelCaps.multiToolCalls,
            ModelCaps.typedOutput,
            ModelCaps.typedOutputWithTools,
          ],
          'o3-mini': [
            ModelCaps.chat,
            ModelCaps.thinking,
            ModelCaps.multiToolCalls,
            ModelCaps.typedOutput,
            ModelCaps.typedOutputWithTools,
          ],
          'o4-mini': [
            ModelCaps.chat,
            ModelCaps.thinking,
            ModelCaps.multiToolCalls,
            ModelCaps.typedOutput,
            ModelCaps.typedOutputWithTools,
          ],

          // GPT-5 models (reasoning)
          'gpt-5': [
            ModelCaps.chat,
            ModelCaps.chatVision,
            ModelCaps.thinking,
            ModelCaps.multiToolCalls,
            ModelCaps.typedOutput,
            ModelCaps.typedOutputWithTools,
          ],

          // Audio models
          'gpt-4o-audio-preview': [
            ModelCaps.chat,
            ModelCaps.audio,
            ModelCaps.multiToolCalls,
            ModelCaps.typedOutput,
            ModelCaps.typedOutputWithTools,
          ],
          'gpt-4o-realtime-preview': [
            ModelCaps.chat,
            ModelCaps.audio,
            ModelCaps.multiToolCalls,
            ModelCaps.typedOutput,
            ModelCaps.typedOutputWithTools,
          ],

          // Embedding models
          'text-embedding-3-small': [ModelCaps.embeddings],
          'text-embedding-ada-002': [ModelCaps.embeddings],

          // TTS models
          'tts-1': [ModelCaps.tts],
          'tts-1-hd': [ModelCaps.tts],
          'gpt-4o-mini-tts': [ModelCaps.tts],

          // Whisper/transcription
          'whisper-1': [ModelCaps.audio],
          'gpt-4o-transcribe': [ModelCaps.audio],

          // Image models
          'dall-e-3': [ModelCaps.image],
          'dall-e-2': [ModelCaps.image],

          // GPT-4 base (text only)
          'gpt-4': [
            ModelCaps.chat,
            ModelCaps.multiToolCalls,
            ModelCaps.typedOutput,
            ModelCaps.typedOutputWithTools,
          ],
          'gpt-4-0613': [
            ModelCaps.chat,
            ModelCaps.multiToolCalls,
            ModelCaps.typedOutput,
            ModelCaps.typedOutputWithTools,
          ],

          // GPT-4 Turbo (vision capable)
          'gpt-4-turbo': [
            ModelCaps.chat,
            ModelCaps.chatVision,
            ModelCaps.multiToolCalls,
            ModelCaps.typedOutput,
            ModelCaps.typedOutputWithTools,
          ],

          // GPT-3.5
          'gpt-3.5-turbo': [
            ModelCaps.chat,
            ModelCaps.multiToolCalls,
            ModelCaps.typedOutput,
            ModelCaps.typedOutputWithTools,
          ],

          // Legacy
          'davinci-002': [ModelCaps.chat],
        };

        print('Testing fetchModelCaps for various model patterns:\n');

        for (final entry in testCases.entries) {
          final modelName = entry.key;
          final expectedCaps = entry.value.toSet();

          final caps = await provider.fetchModelCaps(modelName);
          final actualCaps = caps?.toSet() ?? <ModelCaps>{};

          final match =
              actualCaps.containsAll(expectedCaps) &&
              expectedCaps.containsAll(actualCaps);
          final status = match ? '✓' : '✗';

          print('$status $modelName');
          print(
            '  Expected: ${expectedCaps.map((c) => c.name).toList()..sort()}',
          );
          print(
            '  Actual:   ${actualCaps.map((c) => c.name).toList()..sort()}',
          );
          if (!match) {
            print(
              '  Missing:  ${expectedCaps.difference(actualCaps).map((c) => c.name).toList()}',
            );
            print(
              '  Extra:    ${actualCaps.difference(expectedCaps).map((c) => c.name).toList()}',
            );
          }
          print('');

          expect(
            actualCaps,
            equals(expectedCaps),
            reason: 'Caps mismatch for $modelName',
          );
        }
      },
    );

    test('listModels includes caps', () async {
      if (apiKey == null) {
        print('OPENAI_API_KEY not set, skipping test');
        return;
      }

      final provider = OpenAIProvider(apiKey: apiKey);

      print('Listing models with capabilities:\n');

      var count = 0;
      await for (final model in provider.listModels()) {
        count++;
        final capsStr = model.caps?.map((c) => c.name).join(', ') ?? 'none';
        print('${model.name}: [$capsStr]');

        // Verify caps is not null for recognized models
        if (model.name.contains('gpt') ||
            model.name.contains('embedding') ||
            model.name.startsWith('o1') ||
            model.name.startsWith('o3') ||
            model.name.startsWith('o4')) {
          expect(
            model.caps,
            isNotNull,
            reason: '${model.name} should have caps',
          );
          expect(
            model.caps,
            isNotEmpty,
            reason: '${model.name} should have at least one cap',
          );
        }
      }

      print('\nTotal models with caps: $count');
      expect(count, greaterThan(0));
    });
  }, tags: ['needs-key']);
}
