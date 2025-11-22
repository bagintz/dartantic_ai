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
  group('SequentialWorkflow', () {
    test('executes nodes in sequence', () async {
      final nodes = [
        MockNode('step1'),
        MockNode('step2'),
        MockNode('step3'),
      ];
      
      final workflow = SequentialWorkflow(nodes);
      final state = WorkflowState(conversationHistory: [], toolMap: {});
      final engine = SequentialEngine();
      
      engine.initialize(state);
      final results = await engine.execute(workflow, state).toList();
      engine.finalize(state);
      
      expect(results.length, equals(4)); // 3 steps + 1 final
      expect(state.hasNodeExecuted('step1'), isTrue);
      expect(state.hasNodeExecuted('step2'), isTrue);
      expect(state.hasNodeExecuted('step3'), isTrue);
      
      // Verify order
      final history = state.executionHistory;
      expect(history[0].nodeId, equals('step1'));
      expect(history[1].nodeId, equals('step2'));
      expect(history[2].nodeId, equals('step3'));
    });
  });
}
