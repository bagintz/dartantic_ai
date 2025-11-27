// ignore_for_file: avoid_print
/// Test file to explore Google API model capabilities
/// and document what we need for implementing fetchModelCaps
///
/// Run with: dart test test/google_model_caps_test.dart -r expanded
///
/// Prerequisites:
/// - Set GEMINI_API_KEY environment variable

import 'dart:convert';
import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  final apiKey = Platform.environment['GEMINI_API_KEY'];

  group('Google Model Caps Discovery', () {
    test('List all models and their supportedGenerationMethods', () async {
      if (apiKey == null) {
        print('⚠️  GEMINI_API_KEY not set, skipping test');
        return;
      }

      final provider = GoogleProvider(apiKey: apiKey);
      final models = await provider.listModels().toList();

      print('\n${'=' * 80}');
      print('GOOGLE MODELS DISCOVERY');
      print('Total models found: ${models.length}');
      print('=' * 80);

      for (final model in models) {
        print('\n📦 Model: ${model.name}');
        print('   Display Name: ${model.displayName ?? 'N/A'}');
        print('   Kinds: ${model.kinds.map((k) => k.name).join(', ')}');
        print('   Caps: ${model.caps?.map((c) => c.name).join(', ') ?? 'Not set'}');

        final extra = model.extra;
        if (extra.isNotEmpty) {
          final methods = extra['supportedGenerationMethods'];
          if (methods != null) {
            print('   Supported Methods: ${(methods as List).join(', ')}');
          }

          final contextWindow = extra['contextWindow'];
          if (contextWindow != null) {
            print('   Context Window: $contextWindow tokens');
          }

          final outputLimit = extra['outputTokenLimit'];
          if (outputLimit != null) {
            print('   Output Limit: $outputLimit tokens');
          }
        }
      }

      print('\n${'=' * 80}');
      print('ANALYSIS: Methods -> ModelCaps Mapping');
      print('=' * 80);

      // Collect all unique methods across all models
      final allMethods = <String>{};
      for (final model in models) {
        final methods = model.extra['supportedGenerationMethods'] as List?;
        if (methods != null) {
          allMethods.addAll(methods.cast<String>());
        }
      }

      print('\nUnique supportedGenerationMethods found:');
      for (final method in allMethods.toList()..sort()) {
        print('  - $method');
      }

      print('\n${'=' * 80}');
      print('PROPOSED MAPPING:');
      print('=' * 80);
      print('''
supportedGenerationMethods -> ModelCaps:
  - generateContent     -> chat
  - generateMessage     -> chat (deprecated?)
  - embedContent        -> embeddings
  - embedText           -> embeddings (deprecated?)
  - countTokens         -> countTokens
  - createCachedContent -> (no direct mapping, caching support)
  - batchEmbedContents  -> embeddings (batch)

Additional heuristics needed:
  - Vision support: Check if model name contains "vision" or model accepts image input
  - Tool calling: Most Gemini models support this, but need to verify
  - Typed output: Check if generateContent supports JSON mode
  - Thinking: Check for models like gemini-2.0-flash-thinking-exp
''');
    });

    test('Get single model details via REST API', () async {
      if (apiKey == null) {
        print('⚠️  GEMINI_API_KEY not set, skipping test');
        return;
      }

      // Test getting a specific model's details
      final modelsToTest = [
        'models/gemini-2.0-flash',
        'models/gemini-2.5-flash',
        'models/gemini-1.5-pro',
        'models/gemini-2.0-flash-thinking-exp-01-21',
        'models/text-embedding-004',
      ];

      print('\n${'=' * 80}');
      print('SINGLE MODEL API CALLS');
      print('=' * 80);

      for (final modelName in modelsToTest) {
        print('\n🔍 Fetching: $modelName');

        try {
          // Google's models.get endpoint
          final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/$modelName?key=$apiKey',
          );
          final response = await http.get(url);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;

            print('   ✅ Success!');
            print('   Name: ${data['name']}');
            print('   Display Name: ${data['displayName']}');
            print('   Description: ${_truncate(data['description'] as String? ?? '', 100)}');
            print('   Supported Methods: ${data['supportedGenerationMethods']}');
            print('   Input Token Limit: ${data['inputTokenLimit']}');
            print('   Output Token Limit: ${data['outputTokenLimit']}');

            // Check for any additional fields we might have missed
            final knownFields = {
              'name',
              'displayName',
              'description',
              'supportedGenerationMethods',
              'inputTokenLimit',
              'outputTokenLimit',
              'version',
              'baseModelId',
              'temperature',
              'maxTemperature',
              'topP',
              'topK',
            };

            final unknownFields = data.keys.where((k) => !knownFields.contains(k)).toList();
            if (unknownFields.isNotEmpty) {
              print('   ⚠️  Additional fields: $unknownFields');
              for (final field in unknownFields) {
                print('      $field: ${data[field]}');
              }
            }
          } else {
            print('   ❌ Failed: HTTP ${response.statusCode}');
            print('   Body: ${response.body}');
          }
        } catch (e) {
          print('   ❌ Error: $e');
        }
      }
    });

    test('Determine ModelCaps for common Gemini models', () async {
      if (apiKey == null) {
        print('⚠️  GEMINI_API_KEY not set, skipping test');
        return;
      }

      print('\n${'=' * 80}');
      print('MODEL CAPS DETERMINATION');
      print('=' * 80);

      final modelsToAnalyze = [
        'models/gemini-2.0-flash',
        'models/gemini-2.5-flash',
        'models/gemini-1.5-pro',
        'models/gemini-2.0-flash-thinking-exp-01-21',
        'models/text-embedding-004',
      ];

      for (final modelName in modelsToAnalyze) {
        print('\n📊 Analyzing: $modelName');

        try {
          final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/$modelName?key=$apiKey',
          );
          final response = await http.get(url);

          if (response.statusCode != 200) {
            print('   ❌ Could not fetch model');
            continue;
          }

          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final methods = (data['supportedGenerationMethods'] as List?)?.cast<String>() ?? [];
          final name = (data['name'] as String?) ?? '';
          final description = (data['description'] as String?) ?? '';

          final caps = <ModelCaps>[];

          // Method-based capabilities
          if (methods.any((m) => m.toLowerCase().contains('generatecontent'))) {
            caps.add(ModelCaps.chat);
          }
          if (methods.any((m) => m.toLowerCase().contains('embed'))) {
            caps.add(ModelCaps.embeddings);
          }
          if (methods.any((m) => m.toLowerCase().contains('counttokens'))) {
            caps.add(ModelCaps.countTokens);
          }

          // Name/description-based heuristics
          final lowerName = name.toLowerCase();
          final lowerDesc = description.toLowerCase();

          // Vision - Gemini Pro Vision or models that mention vision/image
          if (lowerName.contains('vision') ||
              lowerDesc.contains('vision') ||
              lowerDesc.contains('image')) {
            caps.add(ModelCaps.chatVision);
          }

          // Thinking models
          if (lowerName.contains('thinking') || lowerDesc.contains('thinking')) {
            caps.add(ModelCaps.thinking);
          }

          // Tool calling - Most Gemini chat models support this
          // We assume chat models support tools unless explicitly stated otherwise
          if (caps.contains(ModelCaps.chat) && !lowerName.contains('embed')) {
            caps.add(ModelCaps.multiToolCalls);
            caps.add(ModelCaps.typedOutput);
            caps.add(ModelCaps.typedOutputWithTools);
          }

          print('   Methods: ${methods.join(', ')}');
          print('   Derived Caps: ${caps.map((c) => c.name).join(', ')}');
        } catch (e) {
          print('   ❌ Error: $e');
        }
      }

      print('\n${'=' * 80}');
      print('IMPLEMENTATION NOTES');
      print('=' * 80);
      print('''
1. Google API provides supportedGenerationMethods which maps to:
   - generateContent -> chat
   - embedContent/embedText -> embeddings
   - countTokens -> countTokens

2. Additional caps require heuristics:
   - chatVision: Check model name/description for "vision" or image support
   - thinking: Check for "thinking" in model name
   - multiToolCalls: Assume true for chat models (Gemini supports this)
   - typedOutput: Assume true for chat models (Gemini supports JSON mode)
   - typedOutputWithTools: Assume true for chat models

3. Google doesn't seem to have explicit "capabilities" field like Ollama,
   so we need to derive from supportedGenerationMethods + heuristics.

4. Implementation approach:
   - Use the models.get REST endpoint to fetch single model details
   - Parse supportedGenerationMethods for base capabilities
   - Apply heuristics based on model name/description
   - Cache results in the provider's modelCapsCache
''');
    });

    test('Check if Gemini 2.0+ models support vision by default', () async {
      if (apiKey == null) {
        print('⚠️  GEMINI_API_KEY not set, skipping test');
        return;
      }

      print('\n${'=' * 80}');
      print('VISION CAPABILITY CHECK');
      print('=' * 80);

      // Gemini 1.5 and 2.x models are multimodal by default
      // Let's verify this by checking the descriptions

      final provider = GoogleProvider(apiKey: apiKey);
      final models = await provider.listModels().toList();

      final geminiModels = models.where(
        (m) => m.name.toLowerCase().contains('gemini'),
      );

      print('\nGemini models and their vision capability:');
      for (final model in geminiModels) {
        final desc = model.description?.toLowerCase() ?? '';
        final hasVision = desc.contains('image') ||
            desc.contains('vision') ||
            desc.contains('multimodal') ||
            desc.contains('video');

        print('  ${model.name}:');
        print('    Vision indicators: $hasVision');
        print('    Description snippet: ${_truncate(model.description ?? '', 80)}');
      }
    });
  });
}

String _truncate(String s, int maxLength) {
  if (s.length <= maxLength) return s;
  return '${s.substring(0, maxLength)}...';
}
