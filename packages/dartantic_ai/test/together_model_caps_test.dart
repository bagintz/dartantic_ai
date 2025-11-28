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
/// Tests for Together AI fetchModelCaps implementation.
/// Together AI uses heuristics based on model type and documented capabilities.

import 'dart:convert';
import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  final apiKey = Platform.environment['TOGETHER_API_KEY'];

  group('Together AI Models API Exploration', () {
    test('List all model types and examine structure', () async {
      if (apiKey == null) {
        print('TOGETHER_API_KEY not set, skipping test');
        return;
      }

      // Direct API call to explore response structure
      final response = await http.get(
        Uri.parse('https://api.together.xyz/v1/models'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      );

      expect(response.statusCode, equals(200));

      final models = jsonDecode(response.body) as List<dynamic>;
      print('\n=== Together AI API Exploration ===');
      print('Total models: ${models.length}');

      // Group by type
      final typeGroups = <String, int>{};
      for (final model in models.cast<Map<String, dynamic>>()) {
        final type = model['type'] as String? ?? 'unknown';
        typeGroups[type] = (typeGroups[type] ?? 0) + 1;
      }
      print('\nModel types:');
      for (final entry in typeGroups.entries) {
        print('  ${entry.key}: ${entry.value}');
      }

      // Show sample of each type
      print('\n=== Sample Models by Type ===');
      for (final type in typeGroups.keys.take(5)) {
        final sample = models
            .cast<Map<String, dynamic>>()
            .where((m) => m['type'] == type)
            .take(2);
        for (final model in sample) {
          print('\n${model['id']} (type: $type)');
          print('  display_name: ${model['display_name']}');
          print('  context_length: ${model['context_length']}');
        }
      }
    }, tags: ['exploration']);

    test('Examine vision models structure', () async {
      if (apiKey == null) {
        print('TOGETHER_API_KEY not set, skipping test');
        return;
      }

      final response = await http.get(
        Uri.parse('https://api.together.xyz/v1/models'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      );

      final models = jsonDecode(response.body) as List<dynamic>;

      // Look for vision-language models (VL in name)
      final visionModels = models.cast<Map<String, dynamic>>().where((m) {
        final id = m['id'] as String;
        return id.toUpperCase().contains('-VL-') ||
            id.toUpperCase().contains('-VL') ||
            id.contains('Llama-4');
      });

      print('\n=== Vision/Multimodal Models ===');
      for (final model in visionModels.take(10)) {
        print('${model['id']}');
        print('  type: ${model['type']}');
        print('  context_length: ${model['context_length']}');
      }

      expect(visionModels.isNotEmpty, isTrue);
    }, tags: ['exploration']);
  });

  group('Together AI Model Caps', () {
    late TogetherProvider provider;

    setUp(() {
      if (apiKey == null || apiKey.isEmpty) {
        return;
      }
      provider = TogetherProvider(apiKey: apiKey);
    });

    test('fetchModelCaps returns chat for Llama model', () async {
      if (apiKey == null) {
        print('TOGETHER_API_KEY not set, skipping test');
        return;
      }

      final caps = await provider.fetchModelCaps(
        'meta-llama/Llama-3.2-3B-Instruct-Turbo',
        {'type': 'chat'},
      );

      print('\nLlama 3.2 3B capabilities: $caps');

      expect(caps, isNotNull);
      expect(caps, contains(ModelCaps.chat));
      expect(caps, contains(ModelCaps.multiToolCalls)); // Documented support
    });

    test('fetchModelCaps returns vision for VL model', () async {
      if (apiKey == null) {
        print('TOGETHER_API_KEY not set, skipping test');
        return;
      }

      final caps = await provider.fetchModelCaps(
        'Qwen/Qwen2.5-VL-72B-Instruct',
        {'type': 'chat'},
      );

      print('\nQwen2.5-VL-72B capabilities: $caps');

      expect(caps, isNotNull);
      expect(caps, contains(ModelCaps.chat));
      expect(caps, contains(ModelCaps.chatVision));
    });

    test('fetchModelCaps returns thinking for R1 model', () async {
      if (apiKey == null) {
        print('TOGETHER_API_KEY not set, skipping test');
        return;
      }

      final caps = await provider.fetchModelCaps(
        'deepseek-ai/DeepSeek-R1',
        {'type': 'chat'},
      );

      print('\nDeepSeek-R1 capabilities: $caps');

      expect(caps, isNotNull);
      expect(caps, contains(ModelCaps.chat));
      expect(caps, contains(ModelCaps.thinking));
    });

    test('fetchModelCaps returns embeddings for embedding model', () async {
      if (apiKey == null) {
        print('TOGETHER_API_KEY not set, skipping test');
        return;
      }

      final caps = await provider.fetchModelCaps(
        'BAAI/bge-large-en-v1.5',
        {'type': 'embedding'},
      );

      print('\nBGE-Large capabilities: $caps');

      expect(caps, isNotNull);
      expect(caps, contains(ModelCaps.embeddings));
    });

    test('fetchModelCaps returns tools for documented model', () async {
      if (apiKey == null) {
        print('TOGETHER_API_KEY not set, skipping test');
        return;
      }

      final caps = await provider.fetchModelCaps(
        'Qwen/Qwen2.5-72B-Instruct-Turbo',
        {'type': 'chat'},
      );

      print('\nQwen2.5-72B capabilities: $caps');

      expect(caps, isNotNull);
      expect(caps, contains(ModelCaps.chat));
      expect(caps, contains(ModelCaps.multiToolCalls));
      expect(caps, contains(ModelCaps.typedOutput));
    });

    test('listModels returns models with capabilities', () async {
      if (apiKey == null) {
        print('TOGETHER_API_KEY not set, skipping test');
        return;
      }

      final models = await provider.listModels().take(20).toList();

      expect(models, isNotEmpty);

      print('\n=== Together AI Models with Caps ===');
      for (final model in models) {
        print('${model.name}: ${model.caps}');
        expect(model.caps, isNotNull);
      }
    });

    test('Llama 4 models have vision capability', () async {
      if (apiKey == null) {
        print('TOGETHER_API_KEY not set, skipping test');
        return;
      }

      final caps1 = await provider.fetchModelCaps(
        'meta-llama/Llama-4-Scout-17B-16E-Instruct',
        {'type': 'chat'},
      );
      final caps2 = await provider.fetchModelCaps(
        'meta-llama/Llama-4-Maverick-17B-128E-Instruct-FP8',
        {'type': 'chat'},
      );

      print('\nLlama 4 Scout capabilities: $caps1');
      print('Llama 4 Maverick capabilities: $caps2');

      expect(caps1, contains(ModelCaps.chatVision));
      expect(caps2, contains(ModelCaps.chatVision));
      // Both should also have tool calling
      expect(caps1, contains(ModelCaps.multiToolCalls));
      expect(caps2, contains(ModelCaps.multiToolCalls));
    });
  });
}
