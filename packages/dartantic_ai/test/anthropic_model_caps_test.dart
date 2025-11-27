// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'package:dartantic_ai/dartantic_ai.dart';

/// Exploratory test to understand Anthropic's models API structure
/// for implementing fetchModelCaps
void main() {
  final apiKey = Platform.environment['ANTHROPIC_API_KEY'];

  group('Anthropic Models API Exploration', () {
    test('List all models and examine structure', () async {
      if (apiKey == null) {
        print('ANTHROPIC_API_KEY not set, skipping test');
        return;
      }

      final response = await http.get(
        Uri.parse('https://api.anthropic.com/v1/models'),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
      );

      print('Status: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('Error: ${response.body}');
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      print('Response keys: ${data.keys.toList()}');
      print('');
      
      final models = data['data'] as List?;
      if (models == null) {
        print('No models data found');
        return;
      }

      print('Total models: ${models.length}');
      print('');

      // Print each model's full structure
      for (final model in models) {
        print('Model: ${model['id']}');
        print(const JsonEncoder.withIndent('  ').convert(model));
        print('');
      }

      // Group by model family
      final modelsByFamily = <String, List<String>>{};
      for (final model in models) {
        final id = model['id'] as String;
        // Extract family (e.g., claude-3-5-sonnet -> claude-3-5)
        final parts = id.split('-');
        final family = parts.length >= 3 ? parts.sublist(0, 3).join('-') : id;
        modelsByFamily.putIfAbsent(family, () => []).add(id);
      }

      print('Models by family:');
      for (final entry in modelsByFamily.entries) {
        print('  ${entry.key}: ${entry.value}');
      }
    });

    test('Check for model details endpoint', () async {
      if (apiKey == null) {
        print('ANTHROPIC_API_KEY not set, skipping test');
        return;
      }

      // Try to get details for a specific model
      final modelsToCheck = [
        'claude-sonnet-4-0',
        'claude-3-5-sonnet-20241022',
        'claude-3-opus-20240229',
      ];

      for (final modelId in modelsToCheck) {
        final response = await http.get(
          Uri.parse('https://api.anthropic.com/v1/models/$modelId'),
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          },
        );

        print('Model $modelId: ${response.statusCode}');
        if (response.statusCode == 200) {
          final model = jsonDecode(response.body) as Map<String, dynamic>;
          print(const JsonEncoder.withIndent('  ').convert(model));
        } else {
          print('  Error: ${response.body}');
        }
        print('');
      }
    });
  });

  group('Anthropic Provider ModelCaps', () {
    test('fetchModelCaps returns correct capabilities for various models', () async {
      if (apiKey == null) {
        print('ANTHROPIC_API_KEY not set, skipping test');
        return;
      }

      final provider = AnthropicProvider(apiKey: apiKey);

      // Test various model patterns - adjust based on what we learn from exploration
      final testCases = <String, List<ModelCaps>>{
        // Claude 4 models (latest with extended thinking)
        'claude-sonnet-4-0': [ModelCaps.chat, ModelCaps.chatVision, ModelCaps.multiToolCalls, ModelCaps.typedOutput, ModelCaps.typedOutputWithTools, ModelCaps.thinking],
        'claude-opus-4-0': [ModelCaps.chat, ModelCaps.chatVision, ModelCaps.multiToolCalls, ModelCaps.typedOutput, ModelCaps.typedOutputWithTools, ModelCaps.thinking],
        'claude-haiku-4-0': [ModelCaps.chat, ModelCaps.chatVision, ModelCaps.multiToolCalls, ModelCaps.typedOutput, ModelCaps.typedOutputWithTools, ModelCaps.thinking],
        
        // Claude 3.7 models (with extended thinking)
        'claude-3-7-sonnet-20250219': [ModelCaps.chat, ModelCaps.chatVision, ModelCaps.multiToolCalls, ModelCaps.typedOutput, ModelCaps.typedOutputWithTools, ModelCaps.thinking],
        'claude-3.7-sonnet': [ModelCaps.chat, ModelCaps.chatVision, ModelCaps.multiToolCalls, ModelCaps.typedOutput, ModelCaps.typedOutputWithTools, ModelCaps.thinking],
        
        // Claude 3.5 models (with extended thinking)
        'claude-3-5-sonnet-20241022': [ModelCaps.chat, ModelCaps.chatVision, ModelCaps.multiToolCalls, ModelCaps.typedOutput, ModelCaps.typedOutputWithTools, ModelCaps.thinking],
        'claude-3-5-haiku-20241022': [ModelCaps.chat, ModelCaps.chatVision, ModelCaps.multiToolCalls, ModelCaps.typedOutput, ModelCaps.typedOutputWithTools, ModelCaps.thinking],
        'claude-3.5-sonnet-latest': [ModelCaps.chat, ModelCaps.chatVision, ModelCaps.multiToolCalls, ModelCaps.typedOutput, ModelCaps.typedOutputWithTools, ModelCaps.thinking],
        
        // Claude 3 models (no extended thinking)
        'claude-3-opus-20240229': [ModelCaps.chat, ModelCaps.chatVision, ModelCaps.multiToolCalls, ModelCaps.typedOutput, ModelCaps.typedOutputWithTools],
        'claude-3-sonnet-20240229': [ModelCaps.chat, ModelCaps.chatVision, ModelCaps.multiToolCalls, ModelCaps.typedOutput, ModelCaps.typedOutputWithTools],
        'claude-3-haiku-20240307': [ModelCaps.chat, ModelCaps.chatVision, ModelCaps.multiToolCalls, ModelCaps.typedOutput, ModelCaps.typedOutputWithTools],
      };

      print('Testing fetchModelCaps for various model patterns:\n');
      
      for (final entry in testCases.entries) {
        final modelName = entry.key;
        final expectedCaps = entry.value.toSet();
        
        final caps = await provider.fetchModelCaps(modelName);
        final actualCaps = caps?.toSet() ?? <ModelCaps>{};
        
        final match = actualCaps.containsAll(expectedCaps) && expectedCaps.containsAll(actualCaps);
        final status = match ? '✓' : '✗';
        
        print('$status $modelName');
        print('  Expected: ${expectedCaps.map((c) => c.name).toList()..sort()}');
        print('  Actual:   ${actualCaps.map((c) => c.name).toList()..sort()}');
        if (!match) {
          print('  Missing:  ${expectedCaps.difference(actualCaps).map((c) => c.name).toList()}');
          print('  Extra:    ${actualCaps.difference(expectedCaps).map((c) => c.name).toList()}');
        }
        print('');
        
        // Don't assert yet - let's see what we get first
        // expect(actualCaps, equals(expectedCaps), reason: 'Caps mismatch for $modelName');
      }
    });

    test('listModels returns models', () async {
      if (apiKey == null) {
        print('ANTHROPIC_API_KEY not set, skipping test');
        return;
      }

      final provider = AnthropicProvider(apiKey: apiKey);
      
      print('Listing models:\n');
      
      var count = 0;
      await for (final model in provider.listModels()) {
        count++;
        final capsStr = model.caps?.map((c) => c.name).join(', ') ?? 'none';
        print('${model.name}: [$capsStr]');
        print('  displayName: ${model.displayName}');
        print('  extra: ${model.extra}');
        print('');
      }
      
      print('Total models: $count');
      expect(count, greaterThan(0));
    });
  });
}
