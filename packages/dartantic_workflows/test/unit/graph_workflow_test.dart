import 'package:test/test.dart';
import 'package:dartantic_workflows/dartantic_workflows.dart';

class MockNode implements WorkflowNode {
  @override
  final String id;
  
  MockNode(this.id);
  
  @override
  String get type => 'mock';
  
  @override
  String get description => 'Mock node';
  
  @override
  List<String> get dependencies => [];
  
  @override
  Stream<NodeResult> execute(NodeContext context, WorkflowState state) async* {
    yield NodeResult.success(
      output: 'Mock output from $id',
      messages: [],
      data: {'id': id},
    );
  }
  
  @override
  bool validate() => true;
}

void main() {
  group('GraphWorkflow', () {
    test('builds simple graph', () {
      final graph = GraphWorkflow.builder()
        .addNode('node1', MockNode('node1'))
        .addNode('node2', MockNode('node2'))
        .addEdge('node1', 'node2')
        .build();
      
      expect(graph.nodes.length, equals(2));
      expect(graph.getEdges('node1').length, equals(1));
      expect(graph.entryPoint, equals('node1'));
    });
    
    test('validates against cycles', () {
      expect(
        () => GraphWorkflow.builder()
          .addNode('a', MockNode('a'))
          .addNode('b', MockNode('b'))
          .addEdge('a', 'b')
          .addEdge('b', 'a')  // Creates cycle
          .build(),
        throwsStateError,
      );
    });
  });
}
