import 'dart:convert';
import 'package:json_schema/json_schema.dart';

/// Validates JSON strings against JSON Schema.
///
/// Provides utilities to parse JSON and validate it matches a schema,
/// with detailed error messages for debugging.
class JsonValidator {
  /// Validates a JSON string against a schema.
  ///
  /// Returns a [JsonValidationResult] containing:
  /// - [isValid]: Whether the JSON is valid
  /// - [data]: Parsed JSON data if valid
  /// - [error]: Error message if invalid
  static JsonValidationResult validate(String jsonString, JsonSchema schema) {
    // Step 1: Try to parse the JSON
    dynamic parsedData;
    try {
      parsedData = jsonDecode(jsonString);
    } catch (e) {
      return JsonValidationResult(
        isValid: false,
        error: 'Failed to parse JSON: $e',
      );
    }
    
    // Step 2: Validate against schema
    try {
      final validationResult = schema.validate(parsedData);
      
      if (!validationResult.isValid) {
        final errors = validationResult.errors.map((e) {
          return '${e.instancePath}: ${e.message}';
        }).join(', ');
        
        return JsonValidationResult(
          isValid: false,
          error: 'Schema validation failed: $errors',
          data: parsedData,
        );
      }
      
      return JsonValidationResult(
        isValid: true,
        data: parsedData,
      );
      
    } catch (e) {
      return JsonValidationResult(
        isValid: false,
        error: 'Validation error: $e',
        data: parsedData,
      );
    }
  }
  
  /// Extracts JSON from text that may contain markdown code blocks or extra text.
  ///
  /// Tries multiple strategies:
  /// 1. Look for JSON in markdown code blocks (```json ... ```)
  /// 2. Look for JSON between curly braces
  /// 3. Use the text as-is
  static String extractJson(String text) {
    final trimmed = text.trim();
    
    // Strategy 1: Extract from markdown code block
    final markdownPattern = RegExp(
      r'```(?:json)?\s*\n?(.*?)\n?```',
      dotAll: true,
      multiLine: true,
    );
    final markdownMatch = markdownPattern.firstMatch(trimmed);
    if (markdownMatch != null) {
      return markdownMatch.group(1)?.trim() ?? trimmed;
    }
    
    // Strategy 2: Find JSON object or array
    final jsonObjectPattern = RegExp(r'\{.*\}', dotAll: true);
    final jsonArrayPattern = RegExp(r'\[.*\]', dotAll: true);
    
    final objectMatch = jsonObjectPattern.firstMatch(trimmed);
    if (objectMatch != null) {
      return objectMatch.group(0)!;
    }
    
    final arrayMatch = jsonArrayPattern.firstMatch(trimmed);
    if (arrayMatch != null) {
      return arrayMatch.group(0)!;
    }
    
    // Strategy 3: Return as-is
    return trimmed;
  }
  
  /// Validates JSON with extraction - tries to extract JSON from text first.
  static JsonValidationResult validateWithExtraction(
    String text,
    JsonSchema schema,
  ) {
    final extracted = extractJson(text);
    return validate(extracted, schema);
  }
}

/// Result of JSON validation.
class JsonValidationResult {
  /// Whether the JSON is valid according to the schema.
  final bool isValid;
  
  /// Parsed JSON data (available even if validation failed).
  final dynamic data;
  
  /// Error message if validation failed.
  final String? error;
  
  const JsonValidationResult({
    required this.isValid,
    this.data,
    this.error,
  });
  
  @override
  String toString() {
    if (isValid) {
      return 'JsonValidationResult(isValid: true)';
    } else {
      return 'JsonValidationResult(isValid: false, error: $error)';
    }
  }
}
