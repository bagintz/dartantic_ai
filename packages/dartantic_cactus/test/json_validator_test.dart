import 'package:dartantic_cactus/src/json_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';

void main() {
  group('JsonValidator', () {
    group('validateWithExtraction', () {
      test('validates simple valid JSON', () {
        final schema = JsonSchema.create({
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
          },
          'required': ['name'],
        });
        
        const jsonText = '{"name": "John"}';
        
        final result = JsonValidator.validateWithExtraction(jsonText, schema);
        
        expect(result.isValid, isTrue);
        expect(result.data, isNotNull);
        expect(result.data['name'], 'John');
        expect(result.error, isNull);
      });

      test('extracts JSON from markdown code block', () {
        final schema = JsonSchema.create({
          'type': 'object',
          'properties': {
            'value': {'type': 'number'},
          },
        });
        
        const text = '''
Here is the JSON:
```json
{"value": 42}
```
Hope that helps!
''';
        
        final result = JsonValidator.validateWithExtraction(text, schema);
        
        expect(result.isValid, isTrue);
        expect(result.data, isNotNull);
        expect(result.data['value'], 42);
      });

      test('extracts JSON without code block markers', () {
        final schema = JsonSchema.create({
          'type': 'object',
          'properties': {
            'data': {'type': 'string'},
          },
        });
        
        const text = 'The result is {"data": "test"} as requested.';
        
        final result = JsonValidator.validateWithExtraction(text, schema);
        
        expect(result.isValid, isTrue);
        expect(result.data, isNotNull);
        expect(result.data['data'], 'test');
      });

      test('fails validation for invalid JSON structure', () {
        final schema = JsonSchema.create({
          'type': 'object',
          'properties': {
            'age': {'type': 'number'},
          },
          'required': ['age'],
        });
        
        const jsonText = '{"age": "not a number"}';
        
        final result = JsonValidator.validateWithExtraction(jsonText, schema);
        
        expect(result.isValid, isFalse);
        expect(result.error, isNotNull);
      });

      test('fails for missing required fields', () {
        final schema = JsonSchema.create({
          'type': 'object',
          'properties': {
            'required_field': {'type': 'string'},
          },
          'required': ['required_field'],
        });
        
        const jsonText = '{}';
        
        final result = JsonValidator.validateWithExtraction(jsonText, schema);
        
        expect(result.isValid, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('required_field'));
      });

      test('handles malformed JSON', () {
        final schema = JsonSchema.create({'type': 'object'});
        
        const text = 'This is not JSON at all';
        
        final result = JsonValidator.validateWithExtraction(text, schema);
        
        expect(result.isValid, isFalse);
        expect(result.error, contains('JSON'));
      });

      test('validates nested objects', () {
        final schema = JsonSchema.create({
          'type': 'object',
          'properties': {
            'person': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
                'age': {'type': 'number'},
              },
              'required': ['name'],
            },
          },
        });
        
        const jsonText = '{"person": {"name": "Alice", "age": 30}}';
        
        final result = JsonValidator.validateWithExtraction(jsonText, schema);
        
        expect(result.isValid, isTrue);
      });

      test('validates arrays', () {
        final schema = JsonSchema.create({
          'type': 'object',
          'properties': {
            'items': {
              'type': 'array',
              'items': {'type': 'string'},
            },
          },
        });
        
        const jsonText = '{"items": ["a", "b", "c"]}';
        
        final result = JsonValidator.validateWithExtraction(jsonText, schema);
        
        expect(result.isValid, isTrue);
      });
    });
  });

  group('JsonValidationResult', () {
    test('creates valid result', () {
      final result = const JsonValidationResult(
        isValid: true,
        data: {'test': true},
      );
      
      expect(result.isValid, isTrue);
      expect(result.data, isNotNull);
      expect(result.error, isNull);
    });

    test('creates invalid result', () {
      final result = const JsonValidationResult(
        isValid: false,
        error: 'Error message',
      );
      
      expect(result.isValid, isFalse);
      expect(result.data, isNull);
      expect(result.error, 'Error message');
    });

    test('toString shows status', () {
      final validResult = const JsonValidationResult(isValid: true);
      expect(validResult.toString(), contains('true'));
      
      final invalidResult = const JsonValidationResult(
        isValid: false,
        error: 'Test error',
      );
      expect(invalidResult.toString(), contains('false'));
      expect(invalidResult.toString(), contains('Test error'));
    });
  });
}

