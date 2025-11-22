import 'dart:async';
import '../graph/graph_result.dart';
import '../graph/workflow_graph.dart';
import '../state/graph_state_impl.dart';

/// Core interface for graph-based workflow orchestration
abstract interface class GraphOrchestrator {
  /// Hint for orchestrator identification and selection
  String get orchestratorHint;
  
  /// Initialize the graph orchestrator with shared state
  void initialize(GraphState state);
  
  /// Execute the complete graph workflow
  Stream<GraphIterationResult> executeGraph(
    WorkflowGraph graph,
    GraphState state,
    Map<String, dynamic> input,
  );
  
  /// Finalize after graph execution completes  
  void finalize(GraphState state);
}
