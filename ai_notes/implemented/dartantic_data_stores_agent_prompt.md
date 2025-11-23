# AI Agent Prompt: Dartantic Data Stores Implementation

## Context

I need to implement data store capabilities for the dartantic ecosystem following the corrected terminology alignment. This involves creating store interfaces in `dartantic_interface` and separate implementation packages for SQLite and ObjectBox, then adding workflow nodes that use these stores.

**Critical Requirements:**
- **Use "Store" terminology** to avoid conflicts with existing Provider pattern
- **Provider = LLM services** (OpenAI, Anthropic), **Store = Data storage** (SQLite, ObjectBox)
- **Follow exact dartantic interface patterns** established for Provider system
- **Separate capability system** (`StoreCaps` vs `ProviderCaps`)
- **Clean integration** with `dartantic_workflows` nodes

## Primary Objectives

1. **Extend `dartantic_interface`** with store interfaces using same patterns as Provider
2. **Create `dartantic_sqlite`** package implementing `DatabaseStore`  
3. **Create `dartantic_objectbox`** package implementing `VectorStore`
4. **Add workflow nodes** that use store interfaces via dependency injection
5. **Enable pluggable ecosystem** where third parties can create new stores

## Implementation Plan

### **Phase 1: Interface Extensions (Week 1)**

**Location**: `/Users/bryangintz/development/packages/dartantic_ai/packages/dartantic_interface`

#### Step 1.1: Add Data Store Interfaces

Create `lib/src/data/` directory structure following Provider pattern:
```
lib/src/data/
├── data.dart                    # Main export file
├── database_store.dart          # DatabaseStore interface 
├── vector_store.dart            # VectorStore interface
├── store_caps.dart              # StoreCaps enum (separate from ProviderCaps)
└── data_types.dart              # Shared types (Document, QueryResult, etc.)
```

#### Step 1.2: Core Store Interface Definitions

**`lib/src/data/database_store.dart`:**
```dart
abstract interface class DatabaseStore {
  String get storeId;
  Future<void> initialize();
  Future<QueryResult> executeQuery(String sql, [List<dynamic>? parameters]);
  Future<String> generateSql(String naturalLanguageQuery, {String? context});
  Future<DatabaseSchema> getSchema();
  Future<void> dispose();
  Set<StoreCaps> get caps;
}
```

**`lib/src/data/vector_store.dart`:**
```dart
abstract interface class VectorStore {
  String get storeId;
  Future<void> initialize();
  Future<void> storeDocuments(List<Document> documents);
  Future<List<SearchResult>> similaritySearch(String query, {int limit = 5, double threshold = 0.7});
  Future<List<double>> generateEmbedding(String text);
  Future<void> deleteDocuments({List<String>? ids, Map<String, dynamic>? filters});
  Future<void> dispose();
  Set<StoreCaps> get caps;
}
```

**`lib/src/data/store_caps.dart`:**
```dart
enum StoreCaps {
  sqlDatabase,
  vectorStorage,
  documentProcessing,
  fullTextSearch,
  graphQueries,
  naturalLanguageToSql,
  embeddingGeneration,
  batchOperations,
}
```

#### Step 1.3: Update Main Interface Export

Add to `lib/dartantic_interface.dart`:
```dart
export 'src/data/data.dart';        // NEW - data store interfaces
```

### **Phase 2: SQLite Store Implementation (Week 2)**

**Location**: `/Users/bryangintz/development/packages/dartantic_ai/packages/dartantic_sqlite`

#### Step 2.1: Package Setup

Create package structure:
```
dartantic_sqlite/
├── lib/
│   ├── dartantic_sqlite.dart
│   └── src/
│       ├── sqlite_store.dart
│       ├── sql_generator.dart
│       └── utils/
├── pubspec.yaml
├── test/
│   └── sqlite_store_test.dart
└── example/
    └── basic_usage.dart
```

#### Step 2.2: Dependencies

**`pubspec.yaml`:**
```yaml
name: dartantic_sqlite
description: SQLite store implementation for dartantic data stores
version: 0.1.0

environment:
  sdk: ^3.9.0

dependencies:
  dartantic_interface:
    path: ../dartantic_interface
  dartantic_ai:
    path: ../dartantic_ai  
  sqlite3: ^2.4.0
  path: ^1.9.0
  logging: ^1.3.0

dev_dependencies:
  test: ^1.24.0
```

#### Step 2.3: SQLiteStore Implementation

Implement full `DatabaseStore` interface with:
- SQLite database connection and management
- SQL query execution with proper error handling
- Natural language to SQL conversion via Agent (optional capability)
- Database schema introspection
- Connection lifecycle management

**Key Implementation Points:**
- Use `storeId` property (not `providerId`)
- Implement `StoreCaps` capability checking
- Optional natural language support based on Agent availability
- Proper error handling and resource disposal

### **Phase 3: ObjectBox Store Implementation (Week 3)**

**Location**: `/Users/bryangintz/development/packages/dartantic_ai/packages/dartantic_objectbox`

#### Step 3.1: Package Setup

Create package structure with ObjectBox code generation support:
```
dartantic_objectbox/
├── lib/
│   ├── dartantic_objectbox.dart
│   └── src/
│       ├── objectbox_store.dart
│       ├── document_entity.dart
│       └── utils/
├── pubspec.yaml
├── test/
└── example/
```

#### Step 3.2: Dependencies with Code Generation

**`pubspec.yaml`:**
```yaml
name: dartantic_objectbox
description: ObjectBox store implementation for dartantic vector stores  
version: 0.1.0

environment:
  sdk: ^3.9.0

dependencies:
  dartantic_interface:
    path: ../dartantic_interface
  dartantic_ai:
    path: ../dartantic_ai
  objectbox: ^4.0.0
  objectbox_flutter_libs: ^4.0.0

dev_dependencies:
  test: ^1.24.0
  build_runner: ^2.4.7
  objectbox_generator: ^4.0.0
```

#### Step 3.3: ObjectBoxStore Implementation

Implement full `VectorStore` interface with:
- ObjectBox entity for document storage
- Vector embedding generation via Agent (optional capability)
- Cosine similarity search algorithm
- Document CRUD operations
- Store lifecycle management

**Key Implementation Points:**
- Use `storeId` property (not `providerId`)
- Implement `StoreCaps` capability checking
- Optional embedding generation based on Agent availability
- Efficient similarity search with ObjectBox queries

### **Phase 4: Workflow Node Extensions (Week 4)**

**Location**: `/Users/bryangintz/development/packages/dartantic_ai/packages/dartantic_workflows`

#### Step 4.1: Add New Dependencies

Update `pubspec.yaml` to reference store interfaces:
```yaml
dependencies:
  # Existing dependencies remain...
  dartantic_interface:
    path: ../dartantic_interface  # Already exists
```

#### Step 4.2: Add Database and Vector Nodes

Create new node implementations:
- `lib/src/nodes/database_node.dart` - Uses `DatabaseStore` interface
- `lib/src/nodes/vector_search_node.dart` - Uses `VectorStore` interface

**Key Implementation Points:**
- Accept store via constructor dependency injection
- Validate store capabilities before execution
- Build queries using context and dependencies
- Format results appropriately for workflow use
- Proper error handling and metadata tracking

#### Step 4.3: Update Workflows Exports

Add to `lib/dartantic_workflows.dart`:
```dart
// New data store nodes
export 'src/nodes/database_node.dart';
export 'src/nodes/vector_search_node.dart';
```

## Key Design Principles

### **1. Interface-Only Dependencies**
```dart
// Workflow nodes use store interfaces only
class DatabaseNode implements WorkflowNode {
  final DatabaseStore store;  // Interface dependency
  
  DatabaseNode(this.store, {required String queryTemplate});
}
```

### **2. Store Injection Pattern**
```dart
// Users inject concrete stores
final sqliteStore = SQLiteStore('./database.db');
final databaseNode = DatabaseNode(sqliteStore, queryTemplate: 'SELECT * FROM users');
```

### **3. Capability-Driven Validation**
```dart
// Nodes validate store capabilities
class DatabaseNode implements WorkflowNode {
  @override
  bool validate() => store.caps.contains(StoreCaps.sqlDatabase);
}
```

### **4. Clear Terminology Separation**
- **Provider**: LLM services (OpenAI, Anthropic, Ollama)
- **Store**: Data storage (SQLite, ObjectBox, Pinecone)
- **Engine**: Workflow execution (Graph, Sequential, Reactive)

## Example Target Usage

```dart
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_workflows/dartantic_workflows.dart';
import 'package:dartantic_sqlite/dartantic_sqlite.dart';
import 'package:dartantic_objectbox/dartantic_objectbox.dart';

// Initialize stores (NOT providers!)
final sqliteStore = SQLiteStore('./research.db');
final vectorStore = ObjectBoxStore(embeddingAgent: embeddingAgent);

// Create workflow with injected stores
final workflow = GraphWorkflow.builder()
  .addNode('research', AgentNode(agent, prompt: 'Research query'))
  .addNode('db_search', DatabaseNode(
    sqliteStore, 
    queryTemplate: 'SELECT * FROM papers WHERE topic = "{research}"'
  ))
  .addNode('vector_search', VectorSearchNode(
    vectorStore, 
    queryTemplate: '{research}',
    maxResults: 10
  ))
  .addNode('synthesis', AgentNode(agent, prompt: 'Synthesize results'))
  .addEdge('research', 'db_search')
  .addEdge('research', 'vector_search')
  .addEdge('db_search', 'synthesis')
  .addEdge('vector_search', 'synthesis')
  .build();

// Execute via agent workflows extension
final result = await agent.runWorkflow(workflow);
```

## Success Criteria

- [ ] **Store interfaces** in `dartantic_interface` follow exact Provider patterns
- [ ] **SQLite store** fully implements `DatabaseStore` interface
- [ ] **ObjectBox store** fully implements `VectorStore` interface
- [ ] **Workflow nodes** use dependency injection with store interfaces
- [ ] **Capability system** works with separate `StoreCaps` enum
- [ ] **Third-party extensibility** - clean path for new store implementations
- [ ] **No terminology conflicts** with existing Provider pattern
- [ ] **All tests pass** including integration tests with real stores
- [ ] **Example workflows** demonstrate end-to-end capabilities

## Testing Strategy

### **Unit Tests**
- Store interface implementations with mock agents
- Workflow nodes with mock stores
- Capability validation logic
- SQL generation and query execution
- Vector similarity search accuracy

### **Integration Tests**
- End-to-end workflows with real stores
- Agent + Store + Node coordination
- Error handling and resource cleanup
- Performance with realistic data sets

## Working Directory

Start in: `/Users/bryangintz/development/packages/dartantic_ai/packages/`

## Implementation Order

1. **Extend interfaces first** - Get abstractions right before implementations
2. **SQLite store** - Simpler to implement and test database operations
3. **ObjectBox store** - More complex with code generation and embeddings
4. **Workflow nodes** - Integration layer using store interfaces
5. **Testing & examples** - Validate end-to-end functionality

## Reference Documentation

- Detailed implementation guide: `/Users/bryangintz/development/greach/ideas/dartantic_data_stores_implementation.md`
- Interface patterns: existing `dartantic_interface` structure for Provider
- Workflow patterns: existing `dartantic_workflows` codebase

**Focus on following the exact dartantic interface patterns established by the Provider system** - store interfaces in `dartantic_interface`, separate implementation packages, and clean dependency injection throughout.