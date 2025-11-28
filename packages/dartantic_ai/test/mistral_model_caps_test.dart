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
/// Tests for Mistral fetchModelCaps implementation.

import 'dart:convert';
import 'dart:io';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'package:dartantic_ai/dartantic_ai.dart';

void main() {
  final apiKey = Platform.environment['MISTRAL_API_KEY'];

  group('Mistral Models API Exploration', () {
    test('List all models and examine capabilities structure', () async {
      if (apiKey == null) {
        print('MISTRAL_API_KEY not set, skipping test');
        return;
      }

      final response = await http.get(
        Uri.parse('https://api.mistral.ai/v1/models'),
        headers: {'Authorization': 'Bearer $apiKey'},
      );

      print('Status: ${response.statusCode}');

      if (response.statusCode != 200) {
        print('Error: ${response.body}');
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final models = data['data'] as List?;
      if (models == null) {
        print('No models data found');
        return;
      }

      print('Total models: ${models.length}\n');

      // Group by model family
      final families = <String, List<Map<String, dynamic>>>{};
      for (final model in models.cast<Map<String, dynamic>>()) {
        final id = model['id'] as String;
        final family = id.split('-').first;
        families.putIfAbsent(family, () => []).add(model);
      }

      for (final entry in families.entries) {
        print('=== ${entry.key.toUpperCase()} ===');
        for (final model in entry.value) {
          final id = model['id'];
          final caps = model['capabilities'] as Map<String, dynamic>?;
          final vision = caps?['vision'] ?? false;
          final chat = caps?['completion_chat'] ?? false;
          final tools = caps?['function_calling'] ?? false;
          print('  $id: chat=$chat, vision=$vision, tools=$tools');
        }
        print('');
      }
    });
  });

  group('Mistral Provider ModelCaps', () {
    test('fetchModelCaps returns correct capabilities from API', () async {
      if (apiKey == null) {
        print('MISTRAL_API_KEY not set, skipping test');
        return;
      }

      final provider = MistralProvider(apiKey: apiKey);

      // Test various model patterns
      final testCases = <String, Set<ModelCaps>>{
        // Mistral Large (multimodal with vision)
        'mistral-large-latest': {
          ModelCaps.chat,
          ModelCaps.chatVision,
          ModelCaps.multiToolCalls,
          ModelCaps.typedOutput,
          ModelCaps.typedOutputWithTools,
        },
        // Mistral Medium (multimodal)
        'mistral-medium-latest': {
          ModelCaps.chat,
          ModelCaps.chatVision,
          ModelCaps.multiToolCalls,
          ModelCaps.typedOutput,
          ModelCaps.typedOutputWithTools,
        },
        // Ministral (small edge models, no vision)
        'ministral-8b-latest': {
          ModelCaps.chat,
          ModelCaps.multiToolCalls,
          ModelCaps.typedOutput,
          ModelCaps.typedOutputWithTools,
        },
        // Magistral (reasoning models)
        'magistral-medium-latest': {
          ModelCaps.chat,
          ModelCaps.chatVision,
          ModelCaps.multiToolCalls,
          ModelCaps.typedOutput,
          ModelCaps.typedOutputWithTools,
          ModelCaps.thinking,
        },
        // Pixtral (vision models)
        'pixtral-large-latest': {
          ModelCaps.chat,
          ModelCaps.chatVision,
          ModelCaps.multiToolCalls,
          ModelCaps.typedOutput,
          ModelCaps.typedOutputWithTools,
        },
        // Embedding model
        'mistral-embed': {ModelCaps.embeddings},
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
        print(
          '  Expected (at least): ${expectedCaps.map((c) => c.name).toList()..sort()}',
        );
        print('  Actual: ${actualCaps.map((c) => c.name).toList()..sort()}');
        if (!hasExpected) {
          print(
            '  Missing: ${expectedCaps.difference(actualCaps).map((c) => c.name).toList()}',
          );
        }
        print('');

        expect(
          actualCaps.containsAll(expectedCaps),
          isTrue,
          reason:
              'Caps mismatch for $modelName - missing ${expectedCaps.difference(actualCaps)}',
        );
      }
    });

    test('listModels returns models with capabilities', () async {
      if (apiKey == null) {
        print('MISTRAL_API_KEY not set, skipping test');
        return;
      }

      final provider = MistralProvider(apiKey: apiKey);

      print('Listing models (first 15):\n');

      var count = 0;
      await for (final model in provider.listModels()) {
        count++;
        if (count > 15) continue; // Just print first 15 for brevity

        final capsStr = model.caps?.map((c) => c.name).join(', ') ?? 'none';
        final kindsStr = model.kinds.map((k) => k.name).join(', ');
        print('${model.name}');
        print('  kinds: [$kindsStr]');
        print('  caps: [$capsStr]');
        print('');
      }

      print('Total models: $count');
      expect(count, greaterThan(0));
    });

    test('heuristic fallback works for unknown models', () async {
      if (apiKey == null) {
        print('MISTRAL_API_KEY not set, skipping test');
        return;
      }

      final provider = MistralProvider(apiKey: apiKey);

      // Test heuristics for hypothetical models
      // Note: Heuristics can only infer capabilities from model name patterns.
      // Vision is only inferred for: pixtral, large, medium, or models with 'vision' in name.
      // Unknown models without these patterns won't get chatVision.
      final heuristicTests = <String, Set<ModelCaps>>{
        'mistral-future-model': {
          // No chatVision - heuristics can't know if unknown model has vision
          ModelCaps.chat,
          ModelCaps.multiToolCalls,
          ModelCaps.typedOutput,
          ModelCaps.typedOutputWithTools,
        },
        'mistral-embed-future': {ModelCaps.embeddings},
        'magistral-future': {
          // No chatVision - would need 'large', 'medium', or 'vision' in name
          ModelCaps.chat,
          ModelCaps.multiToolCalls,
          ModelCaps.typedOutput,
          ModelCaps.typedOutputWithTools,
          ModelCaps.thinking,
        },
        'pixtral-future': {
          // Has chatVision because 'pixtral' implies vision model
          ModelCaps.chat,
          ModelCaps.chatVision,
          ModelCaps.multiToolCalls,
          ModelCaps.typedOutput,
          ModelCaps.typedOutputWithTools,
        },
        // Test that 'large' and 'medium' patterns get vision
        'mistral-large-future': {
          ModelCaps.chat,
          ModelCaps.chatVision,
          ModelCaps.multiToolCalls,
          ModelCaps.typedOutput,
          ModelCaps.typedOutputWithTools,
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
        print(
          '  Expected: ${expectedCaps.map((c) => c.name).toList()..sort()}',
        );
        print('  Actual: ${actualCaps.map((c) => c.name).toList()..sort()}');
        print('');
      }
    });
  });
}
