import 'dart:async';
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:json_schema/json_schema.dart';
import '../interfaces/graph_orchestrator.dart';
import '../graph/workflow_graph.dart';
import '../state/graph_state_impl.dart';

/// Bridge between graph orchestration and streaming orchestration
class GraphStreamingOrchestrator implements StreamingOrchestrator {
  final GraphOrchestrator _graphOrchestrator;
  final WorkflowGraph _graph;
  
  const GraphStreamingOrchestrator(this._graphOrchestrator, this._graph);
  
  @override
  String get providerHint => 'graph-${_graphOrchestrator.orchestratorHint}';
  
  @override
  void initialize(StreamingState state) {
    // Convert StreamingState to GraphState
    final graphState = _createGraphState(state);
    _graphOrchestrator.initialize(graphState);
    
    // Store graph state reference in original state
    state.metadata['graph_state'] = graphState;
  }
  
  @override
  Stream<StreamingIterationResult> processIteration(
    ChatModel model,
    StreamingState state, {
    JsonSchema? outputSchema,
  }) async* {
    final graphState = state.metadata['graph_state'] as GraphState;
    
    // Execute graph and convert results to streaming format
    await for (final result in _graphOrchestrator.executeGraph(
      _graph,
      graphState,
      {
        'model': model,
        'outputSchema': outputSchema,
        'original_prompt': state.conversationHistory.last.text,
      },
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
    final graphState = state.metadata['graph_state'] as GraphState;
    _graphOrchestrator.finalize(graphState);
  }
  
  GraphState _createGraphState(StreamingState state) {
    return GraphState(
      conversationHistory: state.conversationHistory,
      toolMap: state.toolMap,
    );
  }
}
