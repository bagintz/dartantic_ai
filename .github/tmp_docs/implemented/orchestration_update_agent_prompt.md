# AI Agent Prompt: Dartantic Orchestration Architecture Update

## Context

I need to implement a comprehensive architectural update to the dartantic ecosystem to properly separate **conversation control** (single-agent management) from **workflow execution** (multi-agent orchestration). This involves renaming packages, restructuring interfaces, and enabling multiple workflow patterns while maintaining backward compatibility.

## Primary Objectives

1. **Rename and restructure** `dartantic_orchestrator` to `dartantic_workflows`
2. **Clarify architectural distinction** between conversation control and workflow execution
3. **Enable multiple workflow patterns** (sequential, graph, reactive, pipeline)
4. **Implement extension methods** for seamless Agent integration
5. **Maintain progressive enhancement** - simple cases stay simple, complex cases become powerful

## Core Problem Being Solved

**Current Issue**: We're conflating two different "orchestration" concepts:
- `StreamingOrchestrator` (dartantic_ai) = Single-agent conversation flow control
- `GraphOrchestrator` (our system) = Multi-agent workflow execution

**Solution**: Clear separation with proper naming and distinct responsibilities.

## Architecture Changes Required

### **1. Package Renaming (Week 1)**

**Current Structure:**
```
packages/dartantic_orchestrator/
```

**New Structure:**
```
packages/dartantic_workflows/
```

**Key File Changes:**
- `pubspec.yaml` - Update name, description
- `lib/dartantic_orchestrator.dart` → `lib/dartantic_workflows.dart`
- Update all imports throughout codebase
- Update README and documentation

### **2. Interface Renaming (Week 1)**

**Current Interfaces:**
```dart
abstract interface class GraphOrchestrator {
  Stream<GraphIterationResult> executeGraph(WorkflowGraph graph, GraphState state);
}

abstract interface class WorkflowNode { }
class WorkflowGraph { }
class GraphState { }
```

**New Interfaces:**
```dart
abstract interface class WorkflowEngine {
  Stream<WorkflowResult> execute(Workflow workflow, WorkflowState state);
  void initialize(WorkflowState state);
  void finalize(WorkflowState state);
  String get engineType;
}

abstract interface class WorkflowNode { }  // Keep same
class Workflow { }                         // Renamed from WorkflowGraph
class WorkflowState { }                   // Renamed from GraphState
```

### **3. Multiple Engine Implementation (Week 2)**

**Create Multiple Workflow Engines:**

```dart
// Graph-based workflows (current implementation)
class GraphEngine implements WorkflowEngine {
  @override
  String get engineType => 'graph';
  
  @override
  Stream<WorkflowResult> execute(Workflow workflow, WorkflowState state) {
    // Current graph execution logic
  }
}

// Sequential workflows (new - LangChain style)
class SequentialEngine implements WorkflowEngine {
  @override
  String get engineType => 'sequential';
  
  @override
  Stream<WorkflowResult> execute(Workflow workflow, WorkflowState state) {
    // Execute nodes in sequence, passing output from previous to next
  }
}

// Reactive workflows (new - event-driven)
class ReactiveEngine implements WorkflowEngine {
  @override
  String get engineType => 'reactive';
  
  @override
  Stream<WorkflowResult> execute(Workflow workflow, WorkflowState state) {
    // Event-driven execution based on triggers
  }
}
```

### **4. Workflow Builder Patterns (Week 2)**

**Create Engine-Specific Builders:**

```dart
// Graph workflow builder (existing logic)
class GraphWorkflow extends Workflow {
  static GraphWorkflowBuilder builder() => GraphWorkflowBuilder();
}

// Sequential workflow builder (new)
class SequentialWorkflow extends Workflow {
  SequentialWorkflow(List<String> steps);
  SequentialWorkflow.fromNodes(List<WorkflowNode> nodes);
  
  static SequentialWorkflowBuilder builder() => SequentialWorkflowBuilder();
}

// Reactive workflow builder (new)  
class ReactiveWorkflow extends Workflow {
  static ReactiveWorkflowBuilder builder() => ReactiveWorkflowBuilder();
}
```

### **5. Agent Extension Integration (Week 3)**

**Add Extension Methods to Agent:**

```dart
// Create new file: lib/src/extensions/agent_workflows.dart
extension AgentWorkflows on Agent {
  /// Run a workflow using the specified engine
  Future<AgentResult> runWorkflow(
    Workflow workflow, {
    WorkflowEngine? engine,
  }) async {
    final workflowEngine = engine ?? _selectEngine(workflow);
    final state = WorkflowState.fromAgent(this);
    
    final results = await workflowEngine.execute(workflow, state).toList();
    return _combineResults(results);
  }
  
  /// Run a sequential workflow (convenience method)
  Future<AgentResult> runSequential(List<String> steps) async {
    final workflow = SequentialWorkflow(steps);
    return await runWorkflow(workflow, engine: SequentialEngine());
  }
  
  /// Run a graph workflow (convenience method)
  Future<AgentResult> runGraph(GraphWorkflow workflow) async {
    return await runWorkflow(workflow, engine: GraphEngine());
  }
  
  WorkflowEngine _selectEngine(Workflow workflow) {
    if (workflow is GraphWorkflow) return GraphEngine();
    if (workflow is SequentialWorkflow) return SequentialEngine();
    if (workflow is ReactiveWorkflow) return ReactiveEngine();
    return GraphEngine(); // Default
  }
  
  AgentResult _combineResults(List<WorkflowResult> results) {
    // Combine workflow results into single AgentResult
  }
}
```

### **6. Updated Package Exports (Week 3)**

**Update Main Export File:**

```dart
// lib/dartantic_workflows.dart
library dartantic_workflows;

// Core interfaces
export 'src/interfaces/workflow_engine.dart';
export 'src/interfaces/workflow_node.dart'; 
export 'src/interfaces/workflow_edge.dart';

// Workflow types
export 'src/workflows/workflow.dart';
export 'src/workflows/graph_workflow.dart';
export 'src/workflows/sequential_workflow.dart';
export 'src/workflows/reactive_workflow.dart';

// Engines
export 'src/engines/graph_engine.dart';
export 'src/engines/sequential_engine.dart';
export 'src/engines/reactive_engine.dart';

// State and results
export 'src/state/workflow_state.dart';
export 'src/results/workflow_result.dart';

// Nodes
export 'src/nodes/agent_node.dart';
export 'src/nodes/database_node.dart';
export 'src/nodes/vector_storage_node.dart';
export 'src/nodes/conditional_node.dart';
export 'src/nodes/parallel_node.dart';

// Extensions
export 'src/extensions/agent_workflows.dart';

// Builders
export 'src/builders/graph_builder.dart';
export 'src/builders/sequential_builder.dart';
export 'src/builders/reactive_builder.dart';
```

## Usage Examples to Enable

### **Simple Sequential Workflow**
```dart
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_workflows/dartantic_workflows.dart';

final agent = Agent('anthropic');
final result = await agent.runSequential([
  'Research quantum physics',
  'Explain in simple terms', 
  'Create practice questions'
]);
```

### **Complex Graph Workflow**
```dart
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_workflows/dartantic_workflows.dart';

final workflow = GraphWorkflow.builder()
  .addNode('researcher', AgentNode(researchAgent, prompt: 'Research the topic'))
  .addNode('writer', AgentNode(writerAgent, prompt: 'Write article'))
  .addNode('reviewer', AgentNode(reviewAgent, prompt: 'Review quality'))
  .addEdge('researcher', 'writer')
  .addEdge('writer', 'reviewer')
  .build();

final result = await agent.runWorkflow(workflow);
```

### **Reactive Event-Driven Workflow**
```dart
final workflow = ReactiveWorkflow.builder()
  .onEvent('user_question', AgentNode(qaAgent))
  .onEvent('code_request', AgentNode(codeAgent))
  .onEvent('analysis_request', AgentNode(analysisAgent))
  .build();

final result = await agent.runWorkflow(workflow);
```

## Directory Structure After Changes

```
packages/dartantic_workflows/
├── lib/
│   ├── dartantic_workflows.dart
│   └── src/
│       ├── interfaces/
│       │   ├── workflow_engine.dart
│       │   ├── workflow_node.dart
│       │   └── workflow_edge.dart
│       ├── workflows/
│       │   ├── workflow.dart
│       │   ├── graph_workflow.dart
│       │   ├── sequential_workflow.dart
│       │   └── reactive_workflow.dart
│       ├── engines/
│       │   ├── graph_engine.dart
│       │   ├── sequential_engine.dart
│       │   └── reactive_engine.dart
│       ├── state/
│       │   ├── workflow_state.dart
│       │   └── node_context.dart
│       ├── results/
│       │   └── workflow_result.dart
│       ├── nodes/
│       │   ├── agent_node.dart
│       │   ├── database_node.dart
│       │   ├── vector_storage_node.dart
│       │   ├── conditional_node.dart
│       │   └── parallel_node.dart
│       ├── extensions/
│       │   └── agent_workflows.dart
│       └── builders/
│           ├── graph_builder.dart
│           ├── sequential_builder.dart
│           └── reactive_builder.dart
├── pubspec.yaml
├── test/
└── example/
```

## Implementation Priorities

### **Week 1: Core Renaming**
1. Rename package directory and files
2. Update all interface names
3. Update imports throughout codebase
4. Ensure existing tests pass with new names

### **Week 2: Multi-Engine Architecture** 
1. Create `WorkflowEngine` interface
2. Refactor existing logic as `GraphEngine`
3. Implement `SequentialEngine`
4. Add workflow type hierarchy

### **Week 3: Agent Integration**
1. Create `AgentWorkflows` extension
2. Add convenience methods for each workflow type
3. Implement automatic engine selection
4. Update documentation

### **Week 4: Testing and Polish**
1. Comprehensive testing of all workflow patterns
2. Integration testing with agent extensions
3. Example applications
4. Documentation and migration guide

## Success Criteria

- [ ] **Package successfully renamed** from `dartantic_orchestrator` to `dartantic_workflows`
- [ ] **All interface names updated** (`GraphOrchestrator` → `WorkflowEngine`, etc.)
- [ ] **Multiple workflow patterns supported** (sequential, graph, reactive)
- [ ] **Agent extension methods work** seamlessly with existing Agent class
- [ ] **Progressive enhancement maintained** - simple cases remain simple
- [ ] **All existing tests pass** with updated naming
- [ ] **New workflow patterns have test coverage**
- [ ] **Documentation reflects new architecture**

## Working Directory

Start in: `/Users/bryangintz/development/packages/dartantic_ai/packages/`

## Reference Documentation

- Detailed architecture analysis: `/Users/bryangintz/development/greach/ideas/orchestration_update.md`
- Current orchestrator implementation: `dartantic_orchestrator/` package
- Agent integration patterns: `dartantic_ai/lib/src/agent/` directory

## Key Design Principles

1. **Clear separation** between conversation control and workflow execution
2. **Multiple patterns** supported through pluggable engine architecture  
3. **Progressive enhancement** - complexity added only when needed
4. **Backward compatibility** maintained where possible
5. **Industry alignment** with LangChain/LangGraph terminology and concepts

Focus on getting the architectural foundation right before optimizing for performance or adding advanced features. The goal is to create a clear, extensible system that can grow with user needs while maintaining simplicity for basic use cases.