import 'package:cactus/cactus.dart' as cactus;
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:json_schema/json_schema.dart';
import 'package:logging/logging.dart';

/// Converts dartantic [Tool] objects to Cactus tool format (main branch API)
class ToolConverters {
  static final Logger _logger = Logger('dartantic.cactus.tool_converters');

  /// Converts multiple dartantic Tools to CactusTool list
  static List<cactus.CactusTool> toCactusTools(List<Tool> dartanticTools) {
    _logger.info('Converting ${dartanticTools.length} dartantic tools to CactusTool format');
    
    return dartanticTools.map((tool) => toCactusTool(tool)).toList();
  }

  /// Converts a single dartantic Tool to CactusTool
  static cactus.CactusTool toCactusTool(Tool dartanticTool) {
    _logger.fine('Converting tool: ${dartanticTool.name}');
    
    try {
      final parameters = _convertToolParameters(dartanticTool.inputSchema);
      
      final tool = cactus.CactusTool(
        name: dartanticTool.name,
        description: dartanticTool.description,
        parameters: cactus.ToolParametersSchema(
          properties: parameters,
        ),
      );
      
      _logger.info('Successfully converted tool: ${dartanticTool.name}');
      return tool;
    } catch (error, stackTrace) {
      _logger.severe('Failed to convert tool ${dartanticTool.name}', error, stackTrace);
      rethrow;
    }
  }

  /// Converts dartantic Tool JsonSchema to Cactus ToolParameter map
  static Map<String, cactus.ToolParameter> _convertToolParameters(JsonSchema schema) {
    final parameters = <String, cactus.ToolParameter>{};

    // Handle schema properties
    if (schema.properties.isNotEmpty) {
      for (final entry in schema.properties.entries) {
        final paramName = entry.key;
        final paramSchema = entry.value;
        
        // Convert each parameter to Cactus ToolParameter
        parameters[paramName] = cactus.ToolParameter(
          type: _mapJsonSchemaType(paramSchema),
          description: paramSchema.description ?? 'Parameter $paramName',
          required: schema.requiredProperties?.contains(paramName) ?? false,
        );
      }
    }

    _logger.fine('Converted ${parameters.length} parameters');
    return parameters;
  }

  /// Maps JsonSchema to Cactus parameter type string
  static String _mapJsonSchemaType(JsonSchema paramSchema) {
    // Get the type from the schema map
    final schemaMap = paramSchema.schemaMap;
    final type = schemaMap?['type'];
    
    if (type is String) {
      switch (type) {
        case 'string':
          return 'string';
        case 'integer':
          return 'integer';
        case 'number':
          return 'number';
        case 'boolean':
          return 'boolean';
        case 'array':
          return 'array';
        case 'object':
          return 'object';
        default:
          _logger.warning('Unknown parameter type: $type, defaulting to string');
          return 'string';
      }
    }
    
    // Default fallback
    _logger.warning('No type specified in schema, defaulting to string');
    return 'string';
  }
}