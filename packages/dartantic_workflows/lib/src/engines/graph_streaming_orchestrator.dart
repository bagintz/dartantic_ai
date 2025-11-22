import 'dart:async';
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:json_schema/json_schema.dart';
import '../interfaces/workflow_engine.dart';
import '../workflows/workflow.dart';
import '../state/workflow_state.dart';

/// Bridge between workflow execution and streaming orchestration
class GraphStreamingOrchestrator implements StreamingOrchestrator {
  final WorkflowEngine _workflowEngine;
  final GraphWorkflow _workflow;
  
  const GraphStreamingOrchestrator(this._workflowEngine, this._workflow);
  
  @override
  String get providerHint => 'workflow-${_workflowEngine.engineType}';
  
  @override
  void initialize(StreamingState state) {
    // Convert StreamingState to WorkflowState
    final workflowState = _createWorkflowState(state);
    _workflowEngine.initialize(workflowState);
    
    // Store workflow state reference in original state
    state.metadata['workflow_state'] = workflowState;
  }
  
  @override
  Stream<StreamingIterationResult> processIteration(
    ChatModel model,
    StreamingState state, {
    JsonSchema? outputSchema,
  }) async* {
    final workflowState = state.metadata['workflow_state'] as WorkflowState;
    
    // Set input data
    workflowState.setSharedData('model', model);
    workflowState.setSharedData('outputSchema', outputSchema);
    if (state.conversationHistory.isNotEmpty) {
      workflowState.setSharedData('original_prompt', state.conversationHistory.last.text);
    }
    
    // Execute workflow and convert results to streaming format
    await for (final result in _workflowEngine.execute(
      _workflow,
      workflowState,
    )) {
      yield StreamingIterationResult(
        output: result.output,
        messages: result.messages,
        shouldContinue: result.shouldContinue,
        finishReason: result.finishReason,
        metadata: result.metadata,
        usage: result.usage,
      );
    }
  }
  
  @override
  void finalize(StreamingState state) {
    final workflowState = state.metadata['workflow_state'] as WorkflowState;
    _workflowEngine.finalize(workflowState);
  }
  
  WorkflowState _createWorkflowState(StreamingState state) {
    return WorkflowState(
      conversationHistory: state.conversationHistory,
      toolMap: state.toolMap,
    );
  }
}
