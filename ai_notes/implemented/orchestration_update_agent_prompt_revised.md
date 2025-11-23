# AI Agent Prompt: Dartantic Orchestration Architecture Update (Revised)

## Context

I need to implement a comprehensive architectural update to the dartantic ecosystem to properly separate **conversation control** (single-agent management) from **workflow execution** (multi-agent orchestration). This involves renaming packages, restructuring interfaces, and enabling multiple workflow patterns while maintaining perfect alignment with Chris Sells' existing patterns and roadmap.

**Critical Alignment Requirements:**
- **No terminology conflicts** with existing Provider pattern (Provider = LLM services)
- **Use "Store" pattern** for data access (DatabaseStore, VectorStore)
- **Follow Chris Sells' exact orchestrator patterns** (providerHint, initialize, finalize)
- **Implement his official roadmap** (Custom Orchestrators, Pluggable workflow patterns)

## Primary Objectives

1. **Rename and restructure** `dartantic_orchestrator` to `dartantic_workflows`
2. **Align with dartantic patterns** using Chris Sells' exact interface style
3. **Correct terminology** - Provider/Store/Engine distinction
4. **Enable multiple workflow patterns** (sequential, graph, reactive)
5. **Implement extension methods** for seamless Agent integration
6. **Maintain progressive enhancement** - simple cases stay simple, complex cases become powerful

## Core Problem Being Solved

**Current Issue**: We're conflating two different "orchestration" concepts:
- `StreamingOrchestrator` (dartantic_ai) = Single-agent conversation flow control
- `GraphOrchestrator` (our system) = Multi-agent workflow execution

**Solution**: Clear separation with proper naming, dartantic alignment, and distinct responsibilities.

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
- `pubspec.yaml` - Update name: `dartantic_workflows`, description
- `lib/dartantic_orchestrator.dart` → `lib/dartantic_workflows.dart`
- Update all imports throughout codebase
- Update README and documentation

### **2. Interface Renaming & Alignment (Week 1)**

**Current Interface:**
```dart
abstract interface class GraphOrchestrator {
  Stream<GraphIterationResult> executeGraph(WorkflowGraph graph, GraphState state);
  void initialize(GraphState state);
  void finalize(GraphState state);
  String get orchestratorHint;
}
```

**New Interface (Aligned with Chris's Patterns):**
```dart
abstract interface class WorkflowEngine {
  String get engineType;                              // Mirrors providerHint pattern
  void initialize(WorkflowState state);               // Exact same lifecycle
  void finalize(WorkflowState state);                 // Exact same lifecycle
  
  Stream<WorkflowResult> execute(Workflow workflow, WorkflowState state);
}

abstract interface class WorkflowNode { }             // Keep same
class Workflow { }                                    // Renamed from WorkflowGraph
class WorkflowState { }                              // Renamed from GraphState
```

### **3. Terminology Corrections (Week 1)**

**CRITICAL: Avoid Provider Terminology Conflicts**

**Current (WRONG - conflicts with LLM Providers):**
```dart
abstract interface class DatabaseProvider { }  // CONFLICTS with OpenAIProvider!
class SQLiteProvider implements DatabaseProvider { }
```

**Corrected (Uses "Store" pattern):**
```dart
abstract interface class DatabaseStore {
  String get storeId;
  Future<void> initialize();
  Future<QueryResult> executeQuery(String sql);
  Future<void> dispose();
}

abstract interface class VectorStore {
  String get storeId;  
  Future<void> initialize();
  Future<List<SearchResult>> similaritySearch(String query);
  Future<void> dispose();
}

// Clear distinction:
// Provider = LLM services (OpenAI, Anthropic, Ollama)
// Store = Data storage (SQLite, ObjectBox, Pinecone) 
// Engine = Workflow execution (Graph, Sequential, Reactive)
```

### **4. Multiple Engine Implementation (Week 2)**

**Create Multiple Workflow Engines Following Chris's Patterns:**

```dart
// Graph-based workflows (current implementation)
class GraphEngine implements WorkflowEngine {
  @override
  String get engineType => 'graph';
  
  @override
  void initialize(WorkflowState state) {
    // Chris's lifecycle pattern
  }
  
  @override
  void finalize(WorkflowState state) {
    // Chris's lifecycle pattern
  }
  
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

### **5. Capability System Integration (Week 2)**

**Separate Capability Systems (No Conflicts):**

```dart
// Existing - for LLM Providers (UNCHANGED)
enum ProviderCaps {
  chat,
  embeddings,
  multiToolCalls,
  typedOutputWithTools,
}

// NEW - for Data Stores (separate enum)
enum StoreCaps {
  sqlDatabase,
  vectorStorage,
  documentProcessing,
  fullTextSearch,
  graphQueries,
}

// Usage in stores
class SQLiteStore implements DatabaseStore {
  Set<StoreCaps> get caps => {StoreCaps.sqlDatabase, StoreCaps.fullTextSearch};
}

class ObjectBoxStore implements VectorStore {
  Set<StoreCaps> get caps => {StoreCaps.vectorStorage, StoreCaps.documentProcessing};
}
```

### **6. Agent Extension Integration (Week 3)**

**Add Extension Methods to Agent (Chris's Integration Style):**

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
    
    // Use Chris's lifecycle patterns
    workflowEngine.initialize(state);
    
    try {
      final results = await workflowEngine.execute(workflow, state).toList();
      return _combineResults(results);
    } finally {
      workflowEngine.finalize(state);
    }
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
}
```

### **7. Updated Package Exports (Week 3)**

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

// Nodes (corrected to use "store" terminology)
export 'src/nodes/agent_node.dart';
export 'src/nodes/database_node.dart';        // Uses DatabaseStore
export 'src/nodes/vector_search_node.dart';   // Uses VectorStore
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

### **Complex Graph Workflow with Data Stores**
```dart
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_workflows/dartantic_workflows.dart';
import 'package:dartantic_sqlite/dartantic_sqlite.dart';
import 'package:dartantic_objectbox/dartantic_objectbox.dart';

// Initialize data stores (NOT providers!)
final sqliteStore = SQLiteStore('./research.db');
final vectorStore = ObjectBoxStore();

final workflow = GraphWorkflow.builder()
  .addNode('researcher', AgentNode(researchAgent, prompt: 'Research the topic'))
  .addNode('data_search', DatabaseNode(sqliteStore, queryTemplate: 'SELECT * FROM papers'))
  .addNode('vector_search', VectorSearchNode(vectorStore, queryTemplate: '{researcher}'))
  .addNode('synthesize', AgentNode(writerAgent, prompt: 'Synthesize findings'))
  .addEdge('researcher', 'data_search')
  .addEdge('researcher', 'vector_search')
  .addEdge('data_search', 'synthesize')
  .addEdge('vector_search', 'synthesize')
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
│       │   ├── workflow_engine.dart          # Aligned with Chris's patterns
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
│       │   ├── database_node.dart            # Uses DatabaseStore
│       │   ├── vector_search_node.dart       # Uses VectorStore
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

### **Week 1: Core Renaming & Alignment**
1. Rename package directory and files
2. Update all interface names with Chris's patterns
3. Correct Provider→Store terminology throughout
4. Update imports throughout codebase
5. Ensure existing tests pass with new names

### **Week 2: Multi-Engine Architecture** 
1. Create `WorkflowEngine` interface with Chris's lifecycle
2. Refactor existing logic as `GraphEngine`
3. Implement `SequentialEngine`
4. Add workflow type hierarchy
5. Integrate with capability system

### **Week 3: Agent Integration**
1. Create `AgentWorkflows` extension
2. Add convenience methods for each workflow type
3. Implement automatic engine selection
4. Update documentation
5. Add comprehensive examples

### **Week 4: Testing and Polish**
1. Comprehensive testing of all workflow patterns
2. Integration testing with agent extensions
3. Example applications
4. Documentation and migration guide

## Alignment Verification Checklist

### **Chris Sells' Pattern Alignment**
- [ ] **Lifecycle methods match exactly** (`initialize`, `finalize`)
- [ ] **Hint property follows pattern** (`engineType` mirrors `providerHint`)
- [ ] **Interface style consistent** with `StreamingOrchestrator`
- [ ] **Implements his "Custom Orchestrators" vision**
- [ ] **Delivers "Pluggable workflow patterns" goal**

### **Terminology Correctness**
- [ ] **Provider = LLM services only** (OpenAI, Anthropic, Ollama)
- [ ] **Store = Data storage only** (SQLite, ObjectBox, Pinecone)
- [ ] **Engine = Workflow execution only** (Graph, Sequential, Reactive)
- [ ] **No terminology conflicts** with existing dartantic patterns

### **Capability System Integration**
- [ ] **ProviderCaps unchanged** for LLM providers
- [ ] **StoreCaps separate** for data stores
- [ ] **Proper capability checking** in workflow nodes
- [ ] **Follows existing discovery patterns**

## Success Criteria

- [ ] **Package successfully renamed** from `dartantic_orchestrator` to `dartantic_workflows`
- [ ] **Perfect Chris Sells alignment** - uses exact same patterns as `StreamingOrchestrator`
- [ ] **Correct terminology throughout** - Provider/Store/Engine distinction maintained
- [ ] **Multiple workflow patterns supported** (sequential, graph, reactive)
- [ ] **Agent extension methods work** seamlessly with existing Agent class
- [ ] **Progressive enhancement maintained** - simple cases remain simple
- [ ] **All existing tests pass** with updated naming
- [ ] **New workflow patterns have test coverage**
- [ ] **Documentation reflects new architecture**
- [ ] **Implements Chris's roadmap vision** for Custom Orchestrators

## Working Directory

Start in: `/Users/bryangintz/development/packages/dartantic_ai/packages/`

## Reference Documentation

- Detailed architecture analysis: `/Users/bryangintz/development/greach/ideas/orchestration_update_revised.md`
- Chris Sells' roadmap: `/Users/bryangintz/development/packages/dartantic_ai/wiki/Home.md`
- Current orchestrator implementation: `dartantic_orchestrator/` package
- Agent integration patterns: `dartantic_ai/lib/src/agent/` directory

## Key Design Principles

1. **Perfect dartantic alignment** - follow all existing patterns exactly
2. **Clear terminology distinction** - Provider≠Store≠Engine
3. **Chris Sells' roadmap implementation** - deliver official future vision
4. **Multiple patterns** supported through pluggable engine architecture  
5. **Progressive enhancement** - complexity added only when needed
6. **Backward compatibility** maintained where possible
7. **Industry alignment** with LangChain/LangGraph concepts

Focus on getting the architectural alignment perfect before optimizing for performance or adding advanced features. The goal is to create a system that feels like a natural extension of the existing dartantic ecosystem while delivering Chris's vision for workflow orchestration.