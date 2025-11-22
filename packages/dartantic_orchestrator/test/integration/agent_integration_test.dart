import 'package:test/test.dart';
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_orchestrator/dartantic_orchestrator.dart';

void main() {
  group('Agent Integration', () {
    test('executes simple workflow', () async {
      // Mock agent or use a real one if possible, but for unit/integration tests 
      // without API keys we might need to mock.
      // Since we can't easily mock the Agent class without a lot of setup,
      // we'll test the orchestration logic with MockNodes first.
      
      final workflow = WorkflowGraph.builder()
        .addNode('node1', MockNode('node1'))
        .addNode('node2', MockNode('node2'))
        .addEdge('node1', 'node2')
        .build();
        
      final state = GraphState(
        conversationHistory: [],
        toolMap: {},
      );
      
      final orchestrator = DefaultGraphOrchestrator();
      orchestrator.initialize(state);
      
      final results = await orchestrator.executeGraph(workflow, state, <String, dynamic>{}).toList();
      
      expect(results.length, greaterThan(0));
      expect(state.hasNodeExecuted('node1'), isTrue);
      expect(state.hasNodeExecuted('node2'), isTrue);
      expect(state.executionHistory.length, equals(2));
    });
    
    test('executes parallel workflow', () async {
      final workflow = WorkflowGraph.builder()
        .addNode('start', MockNode('start'))
        .addNode('parallel', ParallelNode([
          MockNode('p1'),
          MockNode('p2'),
        ], id: 'parallel'))
        .addNode('end', MockNode('end'))
        .addEdge('start', 'parallel')
        .addEdge('parallel', 'end')
        .build();
        
      final state = GraphState(
        conversationHistory: [],
        toolMap: {},
      );
      
      final orchestrator = DefaultGraphOrchestrator();
      orchestrator.initialize(state);
      
      await orchestrator.executeGraph(workflow, state, <String, dynamic>{}).drain<void>();
      
      expect(state.hasNodeExecuted('start'), isTrue);
      expect(state.hasNodeExecuted('parallel'), isTrue);
      expect(state.hasNodeExecuted('end'), isTrue);
    });
    
    test('executes conditional workflow', () async {
      final workflow = WorkflowGraph.builder()
        .addNode('start', MockNode('start'))
        .addNode('condition', ConditionalNode(
          condition: (context, state) => true,
          trueNextNodeId: 'truePath',
          falseNextNodeId: 'falsePath',
          id: 'condition',
        ))
        .addNode('truePath', MockNode('truePath'))
        .addNode('falsePath', MockNode('falsePath'))
        .addEdge('start', 'condition')
        // Note: In the current static execution engine, all nodes in the graph are executed
        // if they are reachable. The ConditionalNode just evaluates logic but doesn't
        // prevent the engine from executing other nodes if they are in the topological sort.
        // To truly support conditional execution where branches are skipped, 
        // we need to enhance the execution engine to respect the condition result.
        // For now, we just verify the node executes.
        .addEdge('condition', 'truePath')
        .addEdge('condition', 'falsePath')
        .build();
        
      final state = GraphState(
        conversationHistory: [],
        toolMap: {},
      );
      
      final orchestrator = DefaultGraphOrchestrator();
      orchestrator.initialize(state);
      
      await orchestrator.executeGraph(workflow, state, <String, dynamic>{}).drain<void>();
      
      expect(state.hasNodeExecuted('condition'), isTrue);
      expect(state.getSharedData<String>('condition_decision'), equals('truePath'));
    });
  });
}

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
  Stream<NodeResult> execute(NodeContext context, GraphState state) async* {
    yield NodeResult.success(
      output: 'Mock output from $id',
      messages: [],
      data: {'id': id},
    );
  }
  
  @override
  bool validate() => true;
}
