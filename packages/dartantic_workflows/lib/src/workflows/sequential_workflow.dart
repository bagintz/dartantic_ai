import '../interfaces/workflow_node.dart';
import 'workflow.dart';

/// Defines a sequential workflow (chain of nodes)
class SequentialWorkflow implements Workflow {
  final List<WorkflowNode> _nodes;
  
  SequentialWorkflow(List<WorkflowNode> nodes) : _nodes = List.unmodifiable(nodes);
  
  /// Get all nodes in sequence
  List<WorkflowNode> get nodes => _nodes;
  
  @override
  bool validate() {
    return _nodes.isNotEmpty && _nodes.every((n) => n.validate());
  }
}
