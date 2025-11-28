// ignore_for_file: avoid_print
/// TESTING PHILOSOPHY:
/// 1. DO NOT catch exceptions - let them bubble up for diagnosis
/// 2. DO NOT add provider filtering except by capabilities
/// 3. DO NOT add performance tests
/// 4. DO NOT add regression tests
/// 5. 80% cases = common usage patterns tested across ALL capable providers
/// 6. Edge cases = rare scenarios tested on Google only to avoid timeouts
/// 7. Each functionality should only be tested in ONE file - no duplication
///
/// Tests for Ollama fetchModelCaps implementation.
/// Ollama runs locally and provides native capability detection via /api/show.
///
/// Prerequisites:
/// - Ollama must be running locally (default: http://localhost:11434)
/// - At least one model must be pulled

import 'dart:convert';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  // Check if Ollama is running
  Future<bool> isOllamaRunning() async {
    try {
      final response = await http
          .get(Uri.parse('http://localhost:11434/api/tags'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  group('Ollama Models API Exploration', () {
    test('List all models and examine capabilities', () async {
      if (!await isOllamaRunning()) {
        print('⚠️  Ollama not running, skipping test');
        return;
      }

      final response = await http.get(
        Uri.parse('http://localhost:11434/api/tags'),
      );

      expect(response.statusCode, 200);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final models = data['models'] as List;

      print('Total models: ${models.length}\n');

      for (final model in models.cast<Map<String, dynamic>>()) {
        final name = model['name'] as String;
        print('=== $name ===');

        // Get detailed info for each model
        final showResponse = await http.post(
          Uri.parse('http://localhost:11434/api/show'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'name': name}),
        );

        if (showResponse.statusCode == 200) {
          final showData =
              jsonDecode(showResponse.body) as Map<String, dynamic>;
          final caps = showData['capabilities'] as List?;
          print('  Capabilities: ${caps ?? 'none'}');

          final details = showData['details'] as Map<String, dynamic>?;
          if (details != null) {
            print('  Family: ${details['family']}');
            print('  Parameter Size: ${details['parameter_size']}');
          }
        }
        print('');
      }
    });

    test('Check capability values returned by Ollama', () async {
      if (!await isOllamaRunning()) {
        print('⚠️  Ollama not running, skipping test');
        return;
      }

      final response = await http.get(
        Uri.parse('http://localhost:11434/api/tags'),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final models = data['models'] as List;

      // Collect all unique capabilities across all models
      final allCaps = <String>{};

      for (final model in models.cast<Map<String, dynamic>>()) {
        final name = model['name'] as String;
        final showResponse = await http.post(
          Uri.parse('http://localhost:11434/api/show'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'name': name}),
        );

        if (showResponse.statusCode == 200) {
          final showData =
              jsonDecode(showResponse.body) as Map<String, dynamic>;
          final caps = showData['capabilities'] as List?;
          if (caps != null) {
            allCaps.addAll(caps.cast<String>());
          }
        }
      }

      print('All unique capabilities found in Ollama models:');
      for (final cap in allCaps.toList()..sort()) {
        print('  - $cap');
      }

      print('\nExpected capability mappings:');
      print('  completion -> ModelCaps.chat');
      print('  insert -> ModelCaps.chat');
      print('  vision -> ModelCaps.chatVision');
      print(
        '  tools -> ModelCaps.multiToolCalls, typedOutput, typedOutputWithTools',
      );
      print('  thinking -> ModelCaps.thinking');
      print('  embedding -> ModelCaps.embeddings');
    });
  });

  group('Ollama Provider ModelCaps', () {
    test('fetchModelCaps returns correct capabilities from API', () async {
      if (!await isOllamaRunning()) {
        print('⚠️  Ollama not running, skipping test');
        return;
      }

      final provider = OllamaProvider();

      // Get first available model
      final tagsResponse = await http.get(
        Uri.parse('http://localhost:11434/api/tags'),
      );
      final tagsData = jsonDecode(tagsResponse.body) as Map<String, dynamic>;
      final models = tagsData['models'] as List;

      if (models.isEmpty) {
        print('⚠️  No models available, skipping test');
        return;
      }

      print('Testing fetchModelCaps for available models:\n');

      for (final model in models.cast<Map<String, dynamic>>().take(5)) {
        final name = model['name'] as String;

        // Get expected caps from raw API
        final showResponse = await http.post(
          Uri.parse('http://localhost:11434/api/show'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'name': name}),
        );
        final showData = jsonDecode(showResponse.body) as Map<String, dynamic>;
        final rawCaps =
            (showData['capabilities'] as List?)?.cast<String>() ?? [];

        // Get caps from provider
        final caps = await provider.fetchModelCaps(name);
        final actualCaps = caps?.toSet() ?? <ModelCaps>{};

        print('$name');
        print('  Raw API caps: $rawCaps');
        print(
          '  Mapped caps: ${actualCaps.map((c) => c.name).toList()..sort()}',
        );

        // Verify mapping is correct
        if (rawCaps.contains('completion') || rawCaps.contains('insert')) {
          expect(
            actualCaps.contains(ModelCaps.chat),
            isTrue,
            reason: '$name should have chat capability',
          );
        }
        if (rawCaps.contains('vision')) {
          expect(
            actualCaps.contains(ModelCaps.chatVision),
            isTrue,
            reason: '$name should have chatVision capability',
          );
        }
        if (rawCaps.contains('tools')) {
          expect(
            actualCaps.contains(ModelCaps.multiToolCalls),
            isTrue,
            reason: '$name should have multiToolCalls capability',
          );
        }
        if (rawCaps.contains('thinking')) {
          expect(
            actualCaps.contains(ModelCaps.thinking),
            isTrue,
            reason: '$name should have thinking capability',
          );
        }
        if (rawCaps.contains('embedding')) {
          expect(
            actualCaps.contains(ModelCaps.embeddings),
            isTrue,
            reason: '$name should have embeddings capability',
          );
        }
        print('');
      }
    });

    test('listModels returns models with capabilities', () async {
      if (!await isOllamaRunning()) {
        print('⚠️  Ollama not running, skipping test');
        return;
      }

      final provider = OllamaProvider();

      print('Listing models with capabilities:\n');

      var count = 0;
      await for (final model in provider.listModels()) {
        count++;
        if (count > 10) continue; // Just print first 10 for brevity

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
  });
}
