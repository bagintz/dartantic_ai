# VSCode Implementation Prompt: dartantic_orchestrator Package

## Context

I need to implement a new `dartantic_orchestrator` package that extends the existing dartantic_ai ecosystem to support graph-based multi-agent workflows. This fills a critical gap identified in our analysis for building self-improving agentic RAG systems.

## Primary Objectives

1. Create a new package `dartantic_orchestrator` following dartantic ecosystem patterns
2. Implement graph-based workflow orchestration while maintaining backward compatibility
3. Enable multi-agent collaboration through shared state management
4. Provide extensible node system for different workflow components

## Key Implementation Requirements

### Package Structure
```
packages/dartantic_orchestrator/
├── lib/
│   ├── dartantic_orchestrator.dart (main exports)
│   └── src/
│       ├── core/
│       │   ├── graph_orchestrator.dart (GraphOrchestrator interface)
│       │   ├── graph_state.dart (extends StreamingState) 
│       │   ├── workflow_graph.dart (graph definition)
│       │   └── graph_streaming_orchestrator.dart (bridge implementation)
│       ├── nodes/
│       │   ├── workflow_node.dart (base interface)
│       │   ├── agent_node.dart (wraps dartantic_ai Agent)
│       │   └── tool_node.dart (direct tool execution)
│       ├── execution/
│       │   ├── graph_executor.dart (execution engine)
│       │   └── node_context.dart (execution context)
│       └── builders/
│           └── workflow_builder.dart (fluent builder)
├── pubspec.yaml
├── test/
└── example/
```

### Core Interfaces to Implement

1. **GraphOrchestrator** - Main orchestration interface extending dartantic patterns
2. **WorkflowNode** - Base interface for all graph nodes  
3. **GraphState** - Shared state management extending StreamingState
4. **WorkflowGraph** - Graph definition with nodes and edges
5. **GraphStreamingOrchestrator** - Bridge to existing StreamingOrchestrator

### Critical Dependencies

- `dartantic_interface: ^0.0.8` (for base interfaces)
- `dartantic_ai: ^0.5.0` (for Agent class integration)

### Phase 1 Implementation Plan (Week 1)

1. Set up package structure and dependencies
2. Implement core interfaces (GraphOrchestrator, WorkflowNode, GraphState)
3. Create WorkflowGraph with builder pattern
4. Implement basic GraphStreamingOrchestrator bridge
5. Add AgentNode wrapper for dartantic_ai Agent integration

### Success Criteria

- [ ] Package builds without errors
- [ ] Basic graph creation and execution works
- [ ] AgentNode successfully wraps and executes dartantic_ai Agent
- [ ] GraphState properly extends StreamingState
- [ ] Bridge pattern maintains backward compatibility with existing StreamingOrchestrator

### Reference Documentation

- Full implementation guide: `/Users/bryangintz/development/greach/ideas/dartantic_orchestrator_implementation_guide.md`
- Architecture analysis: `/Users/bryangintz/development/greach/ideas/dartantic_orchestrator_proposal.md`
- Gaps analysis: `/Users/bryangintz/development/greach/ideas/dartantic_ai_gaps_analysis.md`

### Example Usage Target

```dart
// Target API we're building toward
final graph = WorkflowGraph.builder()
  .addNode('researcher', AgentNode(medicalAgent))
  .addNode('analyst', AgentNode(cohortAgent))
  .addEdge('researcher', 'analyst')
  .build();

final orchestrator = GraphStreamingOrchestrator(graph);
final agent = Agent('anthropic', orchestrator: orchestrator);
```

## Working Directory

`/Users/bryangintz/development/packages/dartantic_ai/packages/`

## Next Steps

1. Create the `dartantic_orchestrator` package directory
2. Set up `pubspec.yaml` with proper dependencies
3. Implement the core interfaces starting with `WorkflowNode` and `GraphState`
4. Focus on getting a minimal working example running before adding advanced features

Please implement this step-by-step, ensuring each phase works before moving to the next. The detailed implementation guide contains complete code examples and specifications for each component.

## Key Design Principles

- **Extend, Don't Replace**: Build on existing dartantic_ai architecture
- **Backward Compatibility**: Existing Agent usage should continue working
- **Interface-First**: Follow dartantic pattern of interface-based design
- **Incremental Development**: Get basic functionality working before advanced features

## Testing Strategy

Start with simple integration tests:
1. Graph creation and validation
2. Single agent node execution
3. Multi-node workflow execution
4. State sharing between nodes
5. Error handling and recovery

The implementation should prioritize getting a working proof-of-concept before optimizing for performance or adding advanced features.