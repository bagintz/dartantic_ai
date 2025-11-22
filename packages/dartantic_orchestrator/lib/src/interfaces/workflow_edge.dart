import '../state/graph_state_impl.dart';

/// Condition function for edges
typedef EdgeCondition = bool Function(GraphState state);

/// Edge connecting two nodes in the workflow graph
class WorkflowEdge {
  final String fromNode;
  final String toNode;
  final EdgeCondition? condition;
  final Map<String, dynamic> metadata;
  
  const WorkflowEdge({
    required this.fromNode,
    required this.toNode,
    this.condition,
    this.metadata = const {},
  });
}
