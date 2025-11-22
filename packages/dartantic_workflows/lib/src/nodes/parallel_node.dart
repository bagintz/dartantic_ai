import 'dart:async';
import 'package:uuid/uuid.dart';
import '../interfaces/workflow_node.dart';
import '../state/node_context.dart';
import '../state/workflow_state.dart';

/// Node that executes multiple sub-nodes in parallel
class ParallelNode implements WorkflowNode {
  @override
  final String id;
  
  final List<WorkflowNode> _nodes;
  final List<String> _dependencies;
  
  ParallelNode(
    this._nodes, {
    String? id,
    List<String> dependencies = const [],
  }) : id = id ?? const Uuid().v4(),
       _dependencies = dependencies;
  
  @override
  String get type => 'parallel';
  
  @override
  String get description => 'Parallel execution of ${_nodes.length} nodes';
  
  @override
  List<String> get dependencies => List.unmodifiable(_dependencies);
  
  @override
  Stream<NodeResult> execute(NodeContext context, WorkflowState state) async* {
    try {
      final futures = _nodes.map((node) => _executeSubNode(node, context, state));
      final results = await Future.wait(futures);
      
      final combinedData = <String, dynamic>{};
      final combinedOutput = StringBuffer();
      
      for (var i = 0; i < results.length; i++) {
        final result = results[i];
        final node = _nodes[i];
        
        if (!result.isSuccess) {
          throw StateError('Sub-node ${node.id} failed: ${result.error}');
        }
        
        combinedData[node.id] = result.data;
        combinedOutput.writeln('--- Output from ${node.id} ---');
        combinedOutput.writeln(result.output);
      }
      
      yield NodeResult.success(
        output: combinedOutput.toString(),
        messages: [],
        data: combinedData,
        metadata: {
          'parallel_nodes': _nodes.map((n) => n.id).toList(),
        },
      );
      
    } catch (error) {
      yield NodeResult.error(
        error: 'Parallel execution failed: $error',
      );
    }
  }
  
  Future<NodeResult> _executeSubNode(
    WorkflowNode node, 
    NodeContext context, 
    WorkflowState state,
  ) async {
    // Create isolated context for sub-node if needed, or pass through
    // For now passing through context
    
    final results = await node.execute(context, state).toList();
    if (results.isEmpty) {
      return NodeResult.error(error: 'Node ${node.id} produced no results');
    }
    
    // Return last result (assuming it's the final one)
    return results.last;
  }
  
  @override
  bool validate() {
    return _nodes.isNotEmpty && _nodes.every((n) => n.validate());
  }
}
