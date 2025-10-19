import 'package:json_schema/json_schema.dart';

/// Builds prompt instructions from JSON Schema for typed output generation.
///
/// Converts a JsonSchema into natural language instructions that guide
/// the language model to produce JSON output matching the schema.
class SchemaPromptBuilder {
  /// Generates a system prompt that instructs the model to output JSON
  /// matching the given schema.
  static String buildSystemPrompt(JsonSchema schema) {
    final buffer = StringBuffer();
    
    buffer.writeln('You must respond with valid JSON that matches this schema:');
    buffer.writeln();
    buffer.writeln('```json');
    buffer.writeln(_schemaToJson(schema));
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln('IMPORTANT RULES:');
    buffer.writeln('1. Your response must be ONLY valid JSON - no markdown, no explanations');
    buffer.writeln('2. All required fields must be present');
    buffer.writeln('3. Field types must match the schema exactly');
    buffer.writeln('4. Follow any enum constraints specified');
    buffer.writeln('5. Do not include any text before or after the JSON');
    
    return buffer.toString();
  }
  
  /// Generates a retry prompt when JSON parsing or validation fails.
  static String buildRetryPrompt(String error, String previousAttempt) {
    final buffer = StringBuffer();
    
    buffer.writeln('Your previous response was invalid:');
    buffer.writeln();
    buffer.writeln('Previous attempt:');
    buffer.writeln('```');
    buffer.writeln(previousAttempt);
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln('Error: $error');
    buffer.writeln();
    buffer.writeln('Please provide a corrected JSON response that:');
    buffer.writeln('1. Is valid, parseable JSON');
    buffer.writeln('2. Matches the schema exactly');
    buffer.writeln('3. Contains ONLY the JSON (no markdown, no extra text)');
    
    return buffer.toString();
  }
  
  /// Converts JsonSchema to a formatted JSON string representation.
  static String _schemaToJson(JsonSchema schema) {
    final map = <String, dynamic>{};
    
    // Add type
    if (schema.type != null) {
      map['type'] = schema.type.toString().split('.').last;
    }
    
    // Add properties for object types
    if (schema.properties.isNotEmpty) {
      final props = <String, dynamic>{};
      schema.properties.forEach((key, propSchema) {
        props[key] = _schemaPropertyToMap(propSchema);
      });
      map['properties'] = props;
    }
    
    // Add required fields
    if (schema.requiredProperties != null && 
        schema.requiredProperties!.isNotEmpty) {
      map['required'] = schema.requiredProperties;
    }
    
    // Add items for array types
    if (schema.items != null) {
      map['items'] = _schemaPropertyToMap(schema.items!);
    }
    
    // Add enum values
    if (schema.enumValues != null && schema.enumValues!.isNotEmpty) {
      map['enum'] = schema.enumValues;
    }
    
    // Add description
    if (schema.description != null) {
      map['description'] = schema.description;
    }
    
    return _prettyPrintJson(map);
  }
  
  /// Converts a JsonSchema property to a map representation.
  static Map<String, dynamic> _schemaPropertyToMap(JsonSchema schema) {
    final map = <String, dynamic>{};
    
    if (schema.type != null) {
      map['type'] = schema.type.toString().split('.').last;
    }
    
    if (schema.description != null) {
      map['description'] = schema.description;
    }
    
    if (schema.enumValues != null && schema.enumValues!.isNotEmpty) {
      map['enum'] = schema.enumValues;
    }
    
    if (schema.properties.isNotEmpty) {
      final props = <String, dynamic>{};
      schema.properties.forEach((key, propSchema) {
        props[key] = _schemaPropertyToMap(propSchema);
      });
      map['properties'] = props;
    }
    
    if (schema.items != null) {
      map['items'] = _schemaPropertyToMap(schema.items!);
    }
    
    return map;
  }
  
  /// Pretty prints a JSON map with indentation.
  static String _prettyPrintJson(Map<String, dynamic> json, [int indent = 0]) {
    final buffer = StringBuffer();
    final indentStr = '  ' * indent;
    
    buffer.writeln('{');
    
    var isFirst = true;
    json.forEach((key, value) {
      if (!isFirst) buffer.writeln(',');
      isFirst = false;
      
      buffer.write('$indentStr  "$key": ');
      
      if (value is Map<String, dynamic>) {
        buffer.write(_prettyPrintJson(value, indent + 1));
      } else if (value is List) {
        buffer.write('[');
        if (value.isNotEmpty) {
          buffer.writeln();
          for (var i = 0; i < value.length; i++) {
            final item = value[i];
            buffer.write('$indentStr    ');
            if (item is Map<String, dynamic>) {
              buffer.write(_prettyPrintJson(item, indent + 2));
            } else {
              buffer.write(_jsonValue(item));
            }
            if (i < value.length - 1) buffer.write(',');
            buffer.writeln();
          }
          buffer.write('$indentStr  ]');
        } else {
          buffer.write(']');
        }
      } else {
        buffer.write(_jsonValue(value));
      }
    });
    
    buffer.writeln();
    buffer.write('$indentStr}');
    
    return buffer.toString();
  }
  
  /// Converts a value to its JSON representation.
  static String _jsonValue(dynamic value) {
    if (value is String) {
      return '"$value"';
    } else if (value is num || value is bool) {
      return value.toString();
    } else if (value == null) {
      return 'null';
    } else {
      return '"$value"';
    }
  }
}
