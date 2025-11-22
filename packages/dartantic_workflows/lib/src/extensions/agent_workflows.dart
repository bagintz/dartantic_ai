import 'package:dartantic_ai/dartantic_ai.dart';
import '../../dartantic_workflows.dart';

extension AgentWorkflows on Agent {
  /// Run a workflow using the specified engine
  Future<WorkflowResult> runWorkflow(
    Workflow workflow, {
    WorkflowEngine? engine,
  }) async {
    final workflowEngine = engine ?? _selectEngine(workflow);
    
    // Create state
    // Note: Ideally we would pass tools from the agent, but they might not be exposed
    final state = WorkflowState(
      conversationHistory: [], 
      toolMap: {},
    );
    
    workflowEngine.initialize(state);
    
    try {
      final results = await workflowEngine.execute(workflow, state).toList();
      
      if (results.isEmpty) {
        throw StateError('Workflow produced no results');
      }
      
      return results.last;
    } finally {
      workflowEngine.finalize(state);
    }
  }
  
  /// Run a graph workflow (convenience method)
  Future<WorkflowResult> runGraph(GraphWorkflow workflow) async {
    return await runWorkflow(workflow, engine: GraphEngine());
  }
  
  /// Run a sequential workflow (convenience method)
  Future<WorkflowResult> runSequential(List<WorkflowNode> steps) async {
    final workflow = SequentialWorkflow(steps);
    return await runWorkflow(workflow, engine: SequentialEngine());
  }
  
  WorkflowEngine _selectEngine(Workflow workflow) {
    if (workflow is GraphWorkflow) return GraphEngine();
    if (workflow is SequentialWorkflow) return SequentialEngine();
    return GraphEngine(); // Default
  }
}
