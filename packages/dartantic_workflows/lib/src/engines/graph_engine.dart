import 'dart:async';
import 'package:logging/logging.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import '../interfaces/workflow_engine.dart';
import '../interfaces/workflow_node.dart';
import '../state/workflow_state.dart';
import '../state/node_context.dart';
import '../workflows/workflow.dart';
import '../results/workflow_result.dart';

/// Graph-based workflow execution engine
class GraphEngine implements WorkflowEngine {
  static final Logger _logger = Logger('dartantic.workflows.graph');
  
  @override
  String get engineType => 'graph';
  
  @override
  void initialize(WorkflowState state) {
    _logger.info('Initializing graph engine');
    state.setSharedData('engine', engineType);
    state.setSharedData('start_time', DateTime.now());
  }
  
  @override
  Stream<WorkflowResult> execute(
    Workflow workflow,
    WorkflowState state,
  ) async* {
    if (workflow is! GraphWorkflow) {
      throw ArgumentError('GraphEngine requires a GraphWorkflow');
    }
    
    final graph = workflow;
    _logger.info('Starting graph execution with ${graph.nodes.length} nodes');
    
    // Get execution order (topological sort)
    final executionOrder = _getExecutionOrder(graph);
    _logger.fine('Execution order: ${executionOrder.join(' -> ')}');
    
    // Execute nodes in order
    for (final nodeId in executionOrder) {
      final node = graph.getNode(nodeId)!;
      
      // Wait for dependencies
      await _waitForDependencies(node, state);
      
      // Execute node
      yield* _executeNode(node, graph, state);
    }
    
    // Final result
    yield WorkflowResult(
      output: _buildFinalOutput(state),
      messages: [],
      shouldContinue: false,
      finishReason: FinishReason.stop,
      metadata: _buildFinalMetadata(state),
      usage: null,
      id: 'final',
    );
  }
  
  @override
  void finalize(WorkflowState state) {
    final endTime = DateTime.now();
    final startTime = state.getSharedData<DateTime>('start_time')!;
    final duration = endTime.difference(startTime);
    
    _logger.info(
      'Graph execution completed in ${duration.inMilliseconds}ms. '
      'Executed ${state.executionHistory.length} nodes.',
    );
    
    state.setSharedData('end_time', endTime);
    state.setSharedData('total_duration', duration);
  }
  
  /// Get topological execution order
  List<String> _getExecutionOrder(GraphWorkflow graph) {
    final inDegree = <String, int>{};
    for (final node in graph.nodes.keys) {
      inDegree[node] = 0;
    }
    
    for (final node in graph.nodes.keys) {
      for (final edge in graph.getEdges(node)) {
        inDegree[edge.toNode] = (inDegree[edge.toNode] ?? 0) + 1;
      }
    }
    
    final queue = <String>[];
    for (final entry in inDegree.entries) {
      if (entry.value == 0) {
        queue.add(entry.key);
      }
    }
    
    final result = <String>[];
    while (queue.isNotEmpty) {
      final u = queue.removeAt(0);
      result.add(u);
      
      for (final edge in graph.getEdges(u)) {
        final v = edge.toNode;
        inDegree[v] = (inDegree[v] ?? 0) - 1;
        if (inDegree[v] == 0) {
          queue.add(v);
        }
      }
    }
    
    return result;
  }
  
  /// Wait for node dependencies to complete
  Future<void> _waitForDependencies(WorkflowNode node, WorkflowState state) async {
    for (final depId in node.dependencies) {
      while (!state.hasNodeExecuted(depId) && !state.hasNodeFailed(depId)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      
      if (state.hasNodeFailed(depId)) {
        throw StateError('Dependency node $depId failed');
      }
    }
  }
  
  /// Execute a single node
  Stream<WorkflowResult> _executeNode(
    WorkflowNode node,
    GraphWorkflow graph,
    WorkflowState state,
  ) async* {
    _logger.fine('Executing node: ${node.id} (${node.type})');
    
    state.markNodeStarted(node.id);
    final startTime = DateTime.now();
    
    try {
      final context = NodeContext(
        nodeId: node.id,
        conversationHistory: state.conversationHistory,
        sharedData: Map.from(state.sharedData),
      );
      
      await for (final result in node.execute(context, state)) {
        if (result.isSuccess) {
          // Store result and mark complete
          state.addNodeResult(node.id, result.data);
          
          final duration = DateTime.now().difference(startTime);
          state.recordNodeExecution(
            node.id, 
            duration,
            metadata: result.metadata,
          );
          
          _logger.info('Node ${node.id} completed successfully in ${duration.inMilliseconds}ms');
          
          // Yield result
          yield WorkflowResult(
            output: result.output,
            messages: result.messages,
            shouldContinue: true,
            finishReason: FinishReason.unspecified,
            metadata: {
              'node_id': node.id,
              'node_type': node.type,
              'execution_time_ms': duration.inMilliseconds,
              ...result.metadata,
            },
            usage: null,
            id: node.id,
          );
        } else {
          // Mark as failed
          state.markNodeFailed(node.id, result.error!);
          
          _logger.warning('Node ${node.id} failed: ${result.error}');
          
          yield WorkflowResult(
            output: '',
            messages: [],
            shouldContinue: false,
            finishReason: FinishReason.stop, // Changed from error to stop as error is not in enum
            metadata: {
              'node_id': node.id,
              'node_type': node.type,
              'error': result.error,
              ...result.metadata,
            },
            usage: null,
            id: node.id,
          );
          
          throw StateError('Node ${node.id} failed: ${result.error}');
        }
      }
    } catch (error) {
      state.markNodeFailed(node.id, error.toString());
      rethrow;
    }
  }
  
  String _buildFinalOutput(WorkflowState state) {
    final buffer = StringBuffer('Graph execution completed.\n\n');
    
    for (final execution in state.executionHistory) {
      if (execution.success) {
        buffer.writeln('✅ ${execution.nodeId}: ${execution.duration.inMilliseconds}ms');
      }
    }
    
    return buffer.toString();
  }
  
  Map<String, dynamic> _buildFinalMetadata(WorkflowState state) {
    return {
      'total_nodes': state.executionHistory.length,
      'successful_nodes': state.executionHistory.where((e) => e.success).length,
      'failed_nodes': state.failedNodes.length,
      'execution_history': state.executionHistory.map((e) => {
        'node_id': e.nodeId,
        'duration_ms': e.duration.inMilliseconds,
        'success': e.success,
        if (e.error != null) 'error': e.error,
      }).toList(),
    };
  }
}
