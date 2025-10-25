import 'package:dartantic_cactus/src/tool_mappers.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';

void main() {
  group('ToolConverters', () {
    group('toCactusTool', () {
      test('converts simple tool without parameters', () {
        final tool = Tool(
          name: 'get_weather',
          description: 'Gets current weather',
          inputSchema: JsonSchema.create(const {}),
          onCall: (args) async => 'Sunny, 72°F',
        );
        
        final cactusTool = ToolConverters.toCactusTool(tool);
        
        expect(cactusTool.name, 'get_weather');
        expect(cactusTool.description, 'Gets current weather');
        expect(cactusTool.parameters.properties, isEmpty);
      });

      test('converts tool with string parameter', () {
        final schema = JsonSchema.create({
          'type': 'object',
          'properties': {
            'location': {
              'type': 'string',
              'description': 'City name',
            },
          },
          'required': ['location'],
        });
        
        final tool = Tool(
          name: 'get_weather',
          description: 'Gets weather for a location',
          inputSchema: schema,
          onCall: (args) async => 'Weather data',
        );
        
        final cactusTool = ToolConverters.toCactusTool(tool);
        
        expect(cactusTool.name, 'get_weather');
        expect(cactusTool.parameters.properties.length, 1);
        expect(cactusTool.parameters.properties['location']?.type, 'string');
        expect(cactusTool.parameters.properties['location']?.description, 
               'City name');
        expect(cactusTool.parameters.properties['location']?.required, isTrue);
      });

      test('converts tool with multiple parameters', () {
        final schema = JsonSchema.create({
          'type': 'object',
          'properties': {
            'city': {'type': 'string', 'description': 'City name'},
            'units': {'type': 'string', 'description': 'Temperature units'},
            'include_forecast': {'type': 'boolean', 'description': 'Include 5-day forecast'},
          },
          'required': ['city'],
        });
        
        final tool = Tool(
          name: 'get_weather',
          description: 'Gets weather',
          inputSchema: schema,
          onCall: (args) async => 'Weather',
        );
        
        final cactusTool = ToolConverters.toCactusTool(tool);
        
        expect(cactusTool.parameters.properties.length, 3);
        expect(cactusTool.parameters.properties['city']?.required, isTrue);
        expect(cactusTool.parameters.properties['units']?.required, isFalse);
        expect(cactusTool.parameters.properties['include_forecast']?.required, 
               isFalse);
      });

      test('handles various parameter types', () {
        final schema = JsonSchema.create({
          'type': 'object',
          'properties': {
            'text': {'type': 'string'},
            'count': {'type': 'integer'},
            'price': {'type': 'number'},
            'enabled': {'type': 'boolean'},
            'tags': {'type': 'array'},
            'metadata': {'type': 'object'},
          },
        });
        
        final tool = Tool(
          name: 'test_tool',
          description: 'Test',
          inputSchema: schema,
          onCall: (args) async => 'result',
        );
        
        final cactusTool = ToolConverters.toCactusTool(tool);
        
        expect(cactusTool.parameters.properties['text']?.type, 'string');
        expect(cactusTool.parameters.properties['count']?.type, 'integer');
        expect(cactusTool.parameters.properties['price']?.type, 'number');
        expect(cactusTool.parameters.properties['enabled']?.type, 'boolean');
        expect(cactusTool.parameters.properties['tags']?.type, 'array');
        expect(cactusTool.parameters.properties['metadata']?.type, 'object');
      });

      test('uses default description when not provided', () {
        final schema = JsonSchema.create({
          'type': 'object',
          'properties': {
            'param1': {'type': 'string'},
          },
        });
        
        final tool = Tool(
          name: 'test_tool',
          description: 'Test',
          inputSchema: schema,
          onCall: (args) async => 'result',
        );
        
        final cactusTool = ToolConverters.toCactusTool(tool);
        
        expect(cactusTool.parameters.properties['param1']?.description, 
               contains('param1'));
      });
    });

    group('toCactusTools', () {
      test('converts multiple tools', () {
        final tools = [
          Tool(
            name: 'tool1',
            description: 'First tool',
            inputSchema: JsonSchema.create(const {}),
            onCall: (args) async => 'result1',
          ),
          Tool(
            name: 'tool2',
            description: 'Second tool',
            inputSchema: JsonSchema.create(const {}),
            onCall: (args) async => 'result2',
          ),
        ];
        
        final cactusTools = ToolConverters.toCactusTools(tools);
        
        expect(cactusTools.length, 2);
        expect(cactusTools[0].name, 'tool1');
        expect(cactusTools[1].name, 'tool2');
      });

      test('returns empty list for no tools', () {
        final cactusTools = ToolConverters.toCactusTools([]);
        
        expect(cactusTools, isEmpty);
      });
    });
  });
}
