import 'dart:async';
import 'package:logging/logging.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import '../interfaces/workflow_engine.dart';
import '../state/workflow_state.dart';
import '../state/node_context.dart';
import '../workflows/workflow.dart';
import '../workflows/sequential_workflow.dart';
import '../results/workflow_result.dart';

/// Sequential workflow execution engine
class SequentialEngine implements WorkflowEngine {
  static final Logger _logger = Logger('dartantic.workflows.sequential');
  
  @override
  String get engineType => 'sequential';
  
  @override
  void initialize(WorkflowState state) {
    _logger.info('Initializing sequential engine');
    state.setSharedData('engine', engineType);
    state.setSharedData('start_time', DateTime.now());
  }
  
  @override
  Stream<WorkflowResult> execute(
    Workflow workflow,
    WorkflowState state,
  ) async* {
    if (workflow is! SequentialWorkflow) {
      throw ArgumentError('SequentialEngine requires a SequentialWorkflow');
    }
    
    final seqWorkflow = workflow;
    _logger.info('Starting sequential execution with ${seqWorkflow.nodes.length} steps');
    
    for (final node in seqWorkflow.nodes) {
      _logger.fine('Executing step: ${node.id} (${node.type})');
      
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
            state.addNodeResult(node.id, result.data);
            
            final duration = DateTime.now().difference(startTime);
            state.recordNodeExecution(
              node.id, 
              duration,
              metadata: result.metadata,
            );
            
            yield WorkflowResult(
              output: result.output,
              messages: result.messages,
              shouldContinue: true,
              finishReason: FinishReason.unspecified,
              metadata: {
                'node_id': node.id,
                'step_index': seqWorkflow.nodes.indexOf(node),
                ...result.metadata,
              },
              usage: null,
              id: node.id,
            );
          } else {
            state.markNodeFailed(node.id, result.error!);
            throw StateError('Step ${node.id} failed: ${result.error}');
          }
        }
      } catch (error) {
        state.markNodeFailed(node.id, error.toString());
        rethrow;
      }
    }
    
    yield WorkflowResult(
      output: 'Sequential workflow completed',
      messages: [],
      shouldContinue: false,
      finishReason: FinishReason.stop,
      metadata: {
        'total_steps': seqWorkflow.nodes.length,
      },
      usage: null,
      id: 'final',
    );
  }
  
  @override
  void finalize(WorkflowState state) {
    final endTime = DateTime.now();
    final startTime = state.getSharedData<DateTime>('start_time')!;
    final duration = endTime.difference(startTime);
    
    _logger.info('Sequential execution completed in ${duration.inMilliseconds}ms');
    
    state.setSharedData('end_time', endTime);
    state.setSharedData('total_duration', duration);
  }
}
