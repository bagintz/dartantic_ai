/// Multi-agent workflow execution engine for the Dartantic ecosystem.
///
/// This package provides capabilities for defining and executing complex workflows
/// involving multiple agents, conditional routing, and shared state.
library dartantic_workflows;

// Core interfaces
export 'src/interfaces/workflow_engine.dart';
export 'src/interfaces/workflow_node.dart';
export 'src/interfaces/workflow_edge.dart';

// Workflows
export 'src/workflows/workflow.dart';
export 'src/workflows/sequential_workflow.dart';

// Engines
export 'src/engines/graph_engine.dart';
export 'src/engines/sequential_engine.dart';
export 'src/engines/graph_streaming_orchestrator.dart';

// State and results
export 'src/state/workflow_state.dart';
export 'src/state/node_context.dart';
export 'src/results/workflow_result.dart';

// Nodes
export 'src/nodes/agent_node.dart';
export 'src/nodes/conditional_node.dart';
export 'src/nodes/parallel_node.dart';
