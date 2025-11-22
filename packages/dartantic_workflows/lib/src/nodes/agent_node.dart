import 'dart:async';
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:uuid/uuid.dart';
import '../interfaces/workflow_node.dart';
import '../state/node_context.dart';
import '../state/workflow_state.dart';

/// Node that wraps a dartantic_ai Agent
class AgentNode implements WorkflowNode {
  @override
  final String id;
  
  final Agent _agent;
  final String _prompt;
  final List<String> _dependencies;
  
  AgentNode(
    this._agent, {
    required String prompt,
    String? id,
    List<String> dependencies = const [],
  }) : id = id ?? const Uuid().v4(),
       _prompt = prompt,
       _dependencies = dependencies;
  
  @override
  String get type => 'agent';
  
  @override
  String get description => 'Agent: ${_agent.displayName} - $_prompt';
  
  @override
  List<String> get dependencies => List.unmodifiable(_dependencies);
  
  @override
  Stream<NodeResult> execute(NodeContext context, WorkflowState state) async* {
    try {
      // Build context-aware prompt
      final contextualPrompt = _buildPrompt(context, state);
      
      // Create conversation history
      final history = [
        ChatMessage.system('You are a specialist agent in a multi-agent workflow.'),
        ...context.conversationHistory,
      ];
      
      // Execute agent
      final result = await _agent.send(
        contextualPrompt,
        history: history,
      );
      
      yield NodeResult.success(
        output: result.output,
        messages: result.messages,
        data: {
          'agent_result': result.output,
          'finish_reason': result.finishReason.toString(),
          'usage': result.usage == null ? <String, dynamic>{} : <String, dynamic>{
            'promptTokens': result.usage!.promptTokens,
            'responseTokens': result.usage!.responseTokens,
            'totalTokens': result.usage!.totalTokens,
          },
        },
        metadata: {
          'agent_name': _agent.displayName,
          'prompt': _prompt,
          'execution_time': DateTime.now().toIso8601String(),
        },
      );
      
    } catch (error) {
      yield NodeResult.error(
        error: 'Agent execution failed: $error',
        metadata: {
          'agent_name': _agent.displayName,
          'error_type': error.runtimeType.toString(),
        },
      );
    }
  }
  
  String _buildPrompt(NodeContext context, WorkflowState state) {
    final buffer = StringBuffer(_prompt);
    
    // Add context from previous nodes
    final dependencyResults = <String>[];
    for (final depId in dependencies) {
      final result = state.getNodeResult<String>(depId);
      if (result != null) {
        dependencyResults.add('From $depId: $result');
      }
    }
    
    if (dependencyResults.isNotEmpty) {
      buffer.write('\n\nContext from previous steps:\n');
      buffer.write(dependencyResults.join('\n'));
    }
    
    // Add shared data if relevant
    final sharedContext = state.getSharedData<String>('global_context');
    if (sharedContext != null) {
      buffer.write('\n\nShared context: $sharedContext');
    }
    
    return buffer.toString();
  }
  
  @override
  bool validate() {
    return _prompt.isNotEmpty;
  }
}
