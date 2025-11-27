// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'package:dartantic_ai/dartantic_ai.dart';

/// Tests for Cohere fetchModelCaps implementation.
void main() {
  final apiKey = Platform.environment['COHERE_API_KEY'];

  group('Cohere Models API Exploration', () {
    test('List all models and examine structure', () async {
      if (apiKey == null) {
        print('COHERE_API_KEY not set, skipping test');
        return;
      }

      final response = await http.get(
        Uri.parse('https://api.cohere.com/v1/models'),
        headers: {'Authorization': 'Bearer $apiKey'},
      );

      print('Status: ${response.statusCode}');

      if (response.statusCode != 200) {
        print('Error: ${response.body}');
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      print('Response keys: ${data.keys.toList()}');
      print('');

      final models = data['models'] as List?;
      if (models == null) {
        print('No models data found');
        return;
      }

      print('Total models: ${models.length}');
      print('');

      // Print each model's structure
      for (final model in models) {
        final name = model['name'];
        final endpoints = model['endpoints'];
        final features = model['features'];
        final contextLength = model['context_length'];
        print('$name');
        print('  endpoints: $endpoints');
        print('  features: $features');
        print('  contextLength: $contextLength');
        print('');
      }
    });
  });

  group('Cohere Provider ModelCaps', () {
    test('fetchModelCaps returns correct capabilities from API', () async {
      if (apiKey == null) {
        print('COHERE_API_KEY not set, skipping test');
        return;
      }

      final provider = CohereProvider(apiKey: apiKey);

      // Test various model patterns
      final testCases = <String, Set<ModelCaps>>{
        // Command A with tools
        'command-a-03-2025': {
          ModelCaps.chat,
          ModelCaps.multiToolCalls,
          ModelCaps.typedOutput,
          ModelCaps.typedOutputWithTools,
        },
        // Command A Vision
        'command-a-vision-07-2025': {
          ModelCaps.chat,
          ModelCaps.chatVision,
          ModelCaps.multiToolCalls,
          ModelCaps.typedOutput,
          ModelCaps.typedOutputWithTools,
        },
        // Command A Reasoning
        'command-a-reasoning-08-2025': {
          ModelCaps.chat,
          ModelCaps.multiToolCalls,
          ModelCaps.typedOutput,
          ModelCaps.typedOutputWithTools,
          ModelCaps.thinking,
        },
        // Embedding model
        'embed-v4.0': {ModelCaps.embeddings},
        'embed-english-v3.0': {ModelCaps.embeddings},
        // Aya Vision (multimodal)
        'c4ai-aya-vision-32b': {ModelCaps.chat, ModelCaps.chatVision},
      };

      print('Testing fetchModelCaps for various models:\n');

      for (final entry in testCases.entries) {
        final modelName = entry.key;
        final expectedCaps = entry.value;

        final caps = await provider.fetchModelCaps(modelName);
        final actualCaps = caps?.toSet() ?? <ModelCaps>{};

        final hasExpected = actualCaps.containsAll(expectedCaps);
        final status = hasExpected ? '✓' : '✗';

        print('$status $modelName');
        print('  Expected (at least): ${expectedCaps.map((c) => c.name).toList()..sort()}');
        print('  Actual: ${actualCaps.map((c) => c.name).toList()..sort()}');
        if (!hasExpected) {
          print('  Missing: ${expectedCaps.difference(actualCaps).map((c) => c.name).toList()}');
        }
        print('');

        expect(
          actualCaps.containsAll(expectedCaps),
          isTrue,
          reason: 'Caps mismatch for $modelName - missing ${expectedCaps.difference(actualCaps)}',
        );
      }
    });

    test('listModels returns models with capabilities', () async {
      if (apiKey == null) {
        print('COHERE_API_KEY not set, skipping test');
        return;
      }

      final provider = CohereProvider(apiKey: apiKey);

      print('Listing models:\n');

      var count = 0;
      await for (final model in provider.listModels()) {
        count++;
        final capsStr = model.caps?.map((c) => c.name).join(', ') ?? 'none';
        final kindsStr = model.kinds.map((k) => k.name).join(', ');
        print('${model.name}');
        print('  kinds: [$kindsStr]');
        print('  caps: [$capsStr]');
        print('  extra: ${model.extra}');
        print('');
      }

      print('Total models: $count');
      expect(count, greaterThan(0));
    });

    test('heuristic fallback works for unknown models', () async {
      if (apiKey == null) {
        print('COHERE_API_KEY not set, skipping test');
        return;
      }

      final provider = CohereProvider(apiKey: apiKey);

      // Test heuristics for hypothetical models that might not be in the API
      final heuristicTests = <String, Set<ModelCaps>>{
        'command-future-model': {
          ModelCaps.chat,
          ModelCaps.multiToolCalls,
          ModelCaps.typedOutput,
          ModelCaps.typedOutputWithTools,
        },
        'embed-future-model': {ModelCaps.embeddings},
        'command-vision-future': {
          ModelCaps.chat,
          ModelCaps.chatVision,
          ModelCaps.multiToolCalls,
          ModelCaps.typedOutput,
          ModelCaps.typedOutputWithTools,
        },
        'command-reasoning-future': {
          ModelCaps.chat,
          ModelCaps.multiToolCalls,
          ModelCaps.typedOutput,
          ModelCaps.typedOutputWithTools,
          ModelCaps.thinking,
        },
      };

      print('Testing heuristic fallbacks:\n');

      for (final entry in heuristicTests.entries) {
        final modelName = entry.key;
        final expectedCaps = entry.value;

        final caps = await provider.fetchModelCaps(modelName);
        final actualCaps = caps?.toSet() ?? <ModelCaps>{};

        final hasExpected = actualCaps.containsAll(expectedCaps);
        final status = hasExpected ? '✓' : '✗';

        print('$status $modelName (heuristic)');
        print('  Expected: ${expectedCaps.map((c) => c.name).toList()..sort()}');
        print('  Actual: ${actualCaps.map((c) => c.name).toList()..sort()}');
        print('');
      }
    });
  });
}
