import 'dart:async';
import 'package:uuid/uuid.dart';
import '../interfaces/workflow_node.dart';
import '../state/node_context.dart';
import '../state/workflow_state.dart';

/// Function to evaluate condition
typedef ConditionEvaluator = FutureOr<bool> Function(NodeContext context, WorkflowState state);

/// Node that routes execution based on a condition
class ConditionalNode implements WorkflowNode {
  @override
  final String id;
  
  final ConditionEvaluator condition;
  final String trueNextNodeId;
  final String falseNextNodeId;
  final List<String> _dependencies;
  
  ConditionalNode({
    required this.condition,
    required this.trueNextNodeId,
    required this.falseNextNodeId,
    String? id,
    List<String> dependencies = const [],
  }) : id = id ?? const Uuid().v4(),
       _dependencies = dependencies;
  
  @override
  String get type => 'conditional';
  
  @override
  String get description => 'Conditional routing -> $trueNextNodeId or $falseNextNodeId';
  
  @override
  List<String> get dependencies => List.unmodifiable(_dependencies);
  
  @override
  Stream<NodeResult> execute(NodeContext context, WorkflowState state) async* {
    try {
      final result = await condition(context, state);
      final nextNodeId = result ? trueNextNodeId : falseNextNodeId;
      
      yield NodeResult.success(
        output: 'Condition evaluated to $result. Next node: $nextNodeId',
        messages: [],
        data: {
          'condition_result': result,
          'next_node': nextNodeId,
        },
        metadata: {
          'true_path': trueNextNodeId,
          'false_path': falseNextNodeId,
        },
      );
      
      // Note: The graph orchestrator needs to handle dynamic routing based on this result
      // Currently the DefaultGraphOrchestrator uses static topological sort
      // We might need to enhance DefaultGraphOrchestrator to support dynamic next steps
      // or use shared state to signal the next step.
      
      // For now, we'll store the decision in shared state so the orchestrator (if enhanced) 
      // or subsequent nodes can react.
      state.setSharedData('${id}_decision', nextNodeId);
      
    } catch (error) {
      yield NodeResult.error(
        error: 'Condition evaluation failed: $error',
      );
    }
  }
  
  @override
  bool validate() {
    return trueNextNodeId.isNotEmpty && falseNextNodeId.isNotEmpty;
  }
}
