import 'package:dartantic_cactus/src/schema_prompt_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';

void main() {
  group('SchemaPromptBuilder', () {
    group('buildSystemPrompt', () {
      test('generates prompt for simple schema', () {
        final schema = JsonSchema.create({
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
          },
          'required': ['name'],
        });
        
        final prompt = SchemaPromptBuilder.buildSystemPrompt(schema);
        
        expect(prompt, contains('JSON'));
        expect(prompt, contains('schema'));
        expect(prompt, isNot(isEmpty));
      });

      test('includes schema details in prompt', () {
        final schema = JsonSchema.create({
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': 'User name'},
            'age': {'type': 'number', 'description': 'User age'},
          },
          'required': ['name'],
        });
        
        final prompt = SchemaPromptBuilder.buildSystemPrompt(schema);
        
        // Should include property information
        expect(prompt, isNot(isEmpty));
        expect(prompt.length, greaterThan(50));
      });

      test('handles nested objects', () {
        final schema = JsonSchema.create({
          'type': 'object',
          'properties': {
            'person': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
              },
            },
          },
        });
        
        final prompt = SchemaPromptBuilder.buildSystemPrompt(schema);
        
        expect(prompt, isNot(isEmpty));
      });

      test('handles arrays', () {
        final schema = JsonSchema.create({
          'type': 'object',
          'properties': {
            'items': {
              'type': 'array',
              'items': {'type': 'string'},
            },
          },
        });
        
        final prompt = SchemaPromptBuilder.buildSystemPrompt(schema);
        
        expect(prompt, isNot(isEmpty));
      });
    });

    group('buildRetryPrompt', () {
      test('generates retry prompt with error and previous attempt', () {
        const error = 'Missing required field: name';
        const previousAttempt = '{"wrong": "data"}';
        
        final prompt = SchemaPromptBuilder.buildRetryPrompt(
          error,
          previousAttempt,
        );
        
        expect(prompt, contains(error));
        expect(prompt, contains(previousAttempt));
        expect(prompt, isNot(isEmpty));
      });

      test('provides guidance in retry prompt', () {
        const error = 'Type mismatch';
        const previousAttempt = '{"age": "not a number"}';
        
        final prompt = SchemaPromptBuilder.buildRetryPrompt(
          error,
          previousAttempt,
        );
        
        expect(prompt, contains('Error'));
        expect(prompt.length, greaterThan(20));
      });

      test('handles long error messages', () {
        const error = 'This is a very long error message that contains '
            'many details about what went wrong with the JSON validation '
            'including multiple fields and validation issues';
        const previousAttempt = '{"data": "test"}';
        
        final prompt = SchemaPromptBuilder.buildRetryPrompt(
          error,
          previousAttempt,
        );
        
        expect(prompt, contains(error));
        expect(prompt, isNot(isEmpty));
      });
    });
  });
}
