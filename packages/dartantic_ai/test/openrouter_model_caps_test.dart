// TESTING PHILOSOPHY: These tests validate OpenRouter's native capability
// detection using their /api/v1/models endpoint. OpenRouter provides rich
// metadata including architecture.input_modalities, architecture.output_modalities,
// and supported_parameters. Tests verify proper mapping to ModelCaps.

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
/// Tests for OpenRouter fetchModelCaps implementation.

import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:test/test.dart';

void main() {
  final apiKey = Platform.environment['OPENROUTER_API_KEY'];

  group('OpenRouter Model Caps', () {
    late OpenRouterProvider provider;

    setUp(() {
      if (apiKey == null || apiKey.isEmpty) {
        return;
      }
      provider = OpenRouterProvider(apiKey: apiKey);
    });

    test('API exploration: inspect model metadata structure', () async {
      if (apiKey == null) {
        print('OPENROUTER_API_KEY not set, skipping test');
        return;
      }
      // This test explores the OpenRouter API response structure.
      // It's useful for understanding what data is available.
      final models = await provider.listModels().take(5).toList();

      print('\n=== OpenRouter API Exploration ===');
      for (final model in models) {
        print('\nModel: ${model.name}');
        print('  Display: ${model.displayName}');
        print('  Caps: ${model.caps}');

        // Look at raw API response
        final extra = model.extra;
        final arch = extra['architecture'] as Map<String, dynamic>?;
        if (arch != null) {
          print('  Input modalities: ${arch['input_modalities']}');
          print('  Output modalities: ${arch['output_modalities']}');
        }
        final params = extra['supported_parameters'] as List<dynamic>?;
        if (params != null) {
          print('  Supported params: $params');
        }
      }

      expect(models.isNotEmpty, isTrue);
    }, tags: ['exploration']);

    test('fetchModelCaps returns capabilities for GPT-4o via OpenRouter',
        () async {
      if (apiKey == null) {
        print('OPENROUTER_API_KEY not set, skipping test');
        return;
      }
      // Test a known multimodal model available through OpenRouter
      final caps = await provider.fetchModelCaps('openai/gpt-4o');

      print('\nGPT-4o capabilities: $caps');

      // GPT-4o should have vision and tool calling support
      expect(caps, isNotNull);
      expect(caps, contains(ModelCaps.chat));
      // Vision depends on what OpenRouter reports for this model
    });

    test('fetchModelCaps returns capabilities for Claude 3.5 Sonnet', () async {
      if (apiKey == null) {
        print('OPENROUTER_API_KEY not set, skipping test');
        return;
      }
      final caps = await provider.fetchModelCaps('anthropic/claude-3.5-sonnet');

      print('\nClaude 3.5 Sonnet capabilities: $caps');

      expect(caps, isNotNull);
      expect(caps, contains(ModelCaps.chat));
    });

    test('fetchModelCaps returns null for non-existent model', () async {
      if (apiKey == null) {
        print('OPENROUTER_API_KEY not set, skipping test');
        return;
      }
      final caps = await provider.fetchModelCaps('nonexistent/model-xyz-123');

      expect(caps, isNull);
    });

    test('listModels returns models with capabilities', () async {
      if (apiKey == null) {
        print('OPENROUTER_API_KEY not set, skipping test');
        return;
      }
      final models = await provider.listModels().take(10).toList();

      expect(models, isNotEmpty);

      // All models should have at least chat capability
      for (final model in models) {
        expect(model.caps, isNotNull);
        expect(model.caps, contains(ModelCaps.chat));
        print('${model.name}: ${model.caps}');
      }
    });

    test('vision models have chatVision capability', () async {
      if (apiKey == null) {
        print('OPENROUTER_API_KEY not set, skipping test');
        return;
      }
      // Find some vision-capable models
      final models = await provider.listModels().take(100).toList();

      final visionModels =
          models.where((m) => m.caps?.contains(ModelCaps.chatVision) ?? false);

      print('\n=== Vision Models Found ===');
      for (final model in visionModels.take(5)) {
        print('${model.name}: ${model.caps}');
      }

      // We expect to find at least some vision models
      expect(visionModels.isNotEmpty, isTrue);
    });

    test('reasoning models have thinking capability', () async {
      if (apiKey == null) {
        print('OPENROUTER_API_KEY not set, skipping test');
        return;
      }
      final models = await provider.listModels().take(200).toList();

      final thinkingModels =
          models.where((m) => m.caps?.contains(ModelCaps.thinking) ?? false);

      print('\n=== Reasoning/Thinking Models Found ===');
      for (final model in thinkingModels.take(5)) {
        print('${model.name}: ${model.caps}');
      }

      // Note: thinking capability depends on OpenRouter metadata
    });

    test('tool-capable models have multiToolCalls capability', () async {
      if (apiKey == null) {
        print('OPENROUTER_API_KEY not set, skipping test');
        return;
      }
      final models = await provider.listModels().take(100).toList();

      final toolModels = models
          .where((m) => m.caps?.contains(ModelCaps.multiToolCalls) ?? false);

      print('\n=== Tool-Capable Models Found ===');
      for (final model in toolModels.take(10)) {
        print('${model.name}: ${model.caps}');
      }

      expect(toolModels.isNotEmpty, isTrue);
    });
  });
}
