import 'package:cactus/cactus.dart' as cactus;
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:json_schema/json_schema.dart';
import 'package:logging/logging.dart';

/// Converts dartantic [Tool] objects to Cactus CactusAgent format
class ToolConverters {
  static final Logger _logger = Logger('dartantic.cactus.tool_converters');

  /// Registers multiple dartantic Tools with a CactusAgent
  static void registerTools(cactus.CactusAgent agent, List<Tool> dartanticTools) {
    _logger.info('Registering ${dartanticTools.length} dartantic tools with CactusAgent');
    
    for (final tool in dartanticTools) {
      registerTool(agent, tool);
    }
  }

  /// Registers a single dartantic Tool with CactusAgent
  static void registerTool(cactus.CactusAgent agent, Tool dartanticTool) {
    _logger.fine('Registering tool: ${dartanticTool.name}');
    
    try {
      final toolExecutor = DartanticToolExecutor(dartanticTool);
      final parameters = _convertToolParameters(dartanticTool.inputSchema);
      
      // Use the correct addTool signature from Cactus 0.2.7
      agent.addTool(
        dartanticTool.name,           // String name
        toolExecutor,                 // ToolExecutor instance
        dartanticTool.description,    // String description
        parameters,                   // Map<String, Parameter>
      );
      
      _logger.info('Successfully registered tool: ${dartanticTool.name}');
    } catch (error, stackTrace) {
      _logger.severe('Failed to register tool ${dartanticTool.name}', error, stackTrace);
      rethrow;
    }
  }

  /// Converts dartantic Tool JsonSchema to Cactus Parameter map
  static Map<String, cactus.Parameter> _convertToolParameters(JsonSchema schema) {
    final parameters = <String, cactus.Parameter>{};

    // Handle schema properties
    if (schema.properties.isNotEmpty) {
      for (final entry in schema.properties.entries) {
        final paramName = entry.key;
        final paramSchema = entry.value;
        
        // Convert each parameter to Cactus Parameter
        parameters[paramName] = cactus.Parameter(
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

/// ToolExecutor implementation that wraps a dartantic Tool
class DartanticToolExecutor extends cactus.ToolExecutor {
  final Tool _dartanticTool;
  static final Logger _logger = Logger('dartantic.cactus.tool_executor');

  DartanticToolExecutor(this._dartanticTool);

  @override
  Future<dynamic> execute(Map<String, dynamic> args) async {
    try {
      _logger.info('Executing dartantic tool ${_dartanticTool.name} with arguments: $args');
      
      // Execute the dartantic tool
      final result = await _dartanticTool.call(args);
      
      _logger.fine('Tool ${_dartanticTool.name} executed successfully');
      return result;
      
    } catch (error, stackTrace) {
      _logger.severe('Tool ${_dartanticTool.name} execution failed', error, stackTrace);
      // Return error message that the model can understand
      return 'Error executing ${_dartanticTool.name}: $error';
    }
  }
}