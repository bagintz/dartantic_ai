/// Graph-based workflow orchestration for multi-agent AI systems.
///
/// This package extends dartantic_ai with capabilities for defining and executing
/// complex workflows involving multiple agents, conditional routing, and shared state.
library dartantic_orchestrator;

export 'src/interfaces/graph_orchestrator.dart';
export 'src/interfaces/workflow_node.dart';
export 'src/interfaces/workflow_edge.dart';
export 'src/graph/workflow_graph.dart';
export 'src/graph/graph_result.dart';
export 'src/graph/graph_streaming_orchestrator.dart';
export 'src/state/graph_state_impl.dart';
export 'src/state/node_context.dart';
export 'src/nodes/agent_node.dart';
export 'src/graph/execution_engine.dart';
export 'src/nodes/parallel_node.dart';
export 'src/nodes/conditional_node.dart';
