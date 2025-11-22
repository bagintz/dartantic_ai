# VSCode Implementation Prompt: Dartantic Phase 2A - Corrected Architecture

## Context

I need to implement Phase 2A extensions following the **correct dartantic ecosystem pattern**. This involves extending `dartantic_interface` with provider interfaces and creating separate implementation packages for SQLite and ObjectBox, then adding orchestrator nodes that use these interfaces.

**Corrected Architecture Pattern:**
- **Provider interfaces** go in `dartantic_interface` (like existing ChatModel, Provider interfaces)
- **Provider implementations** get separate packages (like dartantic_ai implements interfaces)
- **Orchestrator nodes** use interfaces only (dependency injection pattern)

## Primary Objectives

1. **Extend `dartantic_interface`** with database and vector provider interfaces
2. **Create `dartantic_sqlite`** package implementing DatabaseProvider  
3. **Create `dartantic_objectbox`** package implementing VectorProvider
4. **Add orchestrator nodes** that use provider interfaces via dependency injection
5. **Enable pluggable ecosystem** where third parties can create new providers

## Implementation Plan

### **Phase 1: Interface Extensions (Week 1)**

**Location**: `/Users/bryangintz/development/packages/dartantic_ai/packages/dartantic_interface`

#### Step 1.1: Add Data Provider Interfaces

Create `lib/src/data/` directory structure:
```
lib/src/data/
├── data.dart                    # Main export file
├── database_provider.dart       # DatabaseProvider interface 
├── vector_provider.dart         # VectorProvider interface
└── data_types.dart             # Shared types (Document, QueryResult, etc.)
```

#### Step 1.2: Core Interface Definitions

**`lib/src/data/database_provider.dart`:**
```dart
abstract interface class DatabaseProvider {
  String get connectionId;
  Future<void> initialize();
  Future<QueryResult> executeQuery(String sql, [List<dynamic>? parameters]);
  Future<String> generateSql(String naturalLanguageQuery, {String? context});
  Future<DatabaseSchema> getSchema();
  Future<void> dispose();
}
```

**`lib/src/data/vector_provider.dart`:**
```dart
abstract interface class VectorProvider {
  String get providerId;
  Future<void> initialize();
  Future<void> storeDocuments(List<Document> documents);
  Future<List<SearchResult>> similaritySearch(String query, {int limit = 5, double threshold = 0.7});
  Future<List<double>> generateEmbedding(String text);
  Future<void> deleteDocuments({List<String>? ids, Map<String, dynamic>? filters});
  Future<void> dispose();
}
```

#### Step 1.3: Update Main Interface Export

Add to `lib/dartantic_interface.dart`:
```dart
export 'src/data/data.dart';        // NEW
```

### **Phase 2: SQLite Implementation Package (Week 2)**

**Location**: `/Users/bryangintz/development/packages/dartantic_ai/packages/dartantic_sqlite`

#### Step 2.1: Package Setup

Create package structure:
```
dartantic_sqlite/
├── lib/
│   ├── dartantic_sqlite.dart
│   └── src/
│       ├── sqlite_provider.dart
│       ├── sql_generator.dart
│       └── utils/
├── pubspec.yaml
├── test/
│   └── sqlite_provider_test.dart
└── example/
    └── basic_usage.dart
```

#### Step 2.2: Dependencies

**`pubspec.yaml`:**
```yaml
name: dartantic_sqlite
description: SQLite implementation for dartantic database providers
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

#### Step 2.3: SQLiteProvider Implementation

Implement full `DatabaseProvider` interface with:
- SQLite database connection and management
- SQL query execution with proper error handling
- Natural language to SQL conversion via Agent
- Database schema introspection
- Connection lifecycle management

### **Phase 3: ObjectBox Implementation Package (Week 3)**

**Location**: `/Users/bryangintz/development/packages/dartantic_ai/packages/dartantic_objectbox`

#### Step 3.1: Package Setup

Create package structure with ObjectBox code generation support:
```
dartantic_objectbox/
├── lib/
│   ├── dartantic_objectbox.dart
│   └── src/
│       ├── objectbox_provider.dart
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
description: ObjectBox implementation for dartantic vector providers  
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

#### Step 3.3: ObjectBoxProvider Implementation

Implement full `VectorProvider` interface with:
- ObjectBox entity for document storage
- Vector embedding generation via Agent
- Cosine similarity search algorithm
- Document CRUD operations
- Store lifecycle management

### **Phase 4: Orchestrator Node Extensions (Week 4)**

**Location**: `/Users/bryangintz/development/packages/dartantic_ai/packages/dartantic_orchestrator`

#### Step 4.1: Add New Dependencies

Update `pubspec.yaml`:
```yaml
dependencies:
  # Existing dependencies remain...
  dartantic_interface:
    path: ../dartantic_interface  # Already exists, may need version update
```

#### Step 4.2: Add Database and Vector Nodes

Create new node implementations:
- `lib/src/nodes/database_node.dart` - Uses `DatabaseProvider` interface
- `lib/src/nodes/vector_storage_node.dart` - Uses `VectorProvider` interface

#### Step 4.3: Update Orchestrator Exports

Add to `lib/dartantic_orchestrator.dart`:
```dart
// New Phase 2A exports
export 'src/nodes/database_node.dart';
export 'src/nodes/vector_storage_node.dart';
```

## Key Design Principles

### **1. Interface-Only Dependencies**
```dart
// Orchestrator nodes use interfaces only
class DatabaseNode implements WorkflowNode {
  final DatabaseProvider provider;  // Interface dependency
  
  DatabaseNode(this.provider, {required String queryTemplate});
}
```

### **2. Provider Injection Pattern**
```dart
// Users inject concrete providers
final sqliteProvider = SQLiteProvider('./database.db');
final databaseNode = DatabaseNode(sqliteProvider, queryTemplate: 'SELECT * FROM users');
```

### **3. Pluggable Ecosystem**
```dart
// Third parties can create new providers
class PostgreSQLProvider implements DatabaseProvider { }
class PineconeProvider implements VectorProvider { }
```

### **4. Clean Separation**
- **Interfaces**: Pure abstractions in `dartantic_interface`
- **Implementations**: Concrete providers in separate packages  
- **Orchestrator**: Uses interfaces only, no implementation dependencies

## Example Target Usage

```dart
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_orchestrator/dartantic_orchestrator.dart';
import 'package:dartantic_sqlite/dartantic_sqlite.dart';
import 'package:dartantic_objectbox/dartantic_objectbox.dart';

// Initialize providers
final dbProvider = SQLiteProvider('./research.db');
final vectorProvider = ObjectBoxProvider(embeddingAgent: embeddingAgent);

// Create workflow with injected providers
final workflow = WorkflowGraph.builder()
  .addNode('research', AgentNode(agent, prompt: 'Research query'))
  .addNode('db_search', DatabaseNode(dbProvider, queryTemplate: 'SELECT * FROM papers WHERE topic = "{research}"'))
  .addNode('vector_search', VectorStorageNode(vectorProvider, queryTemplate: '{research}'))
  .addNode('synthesis', AgentNode(agent, prompt: 'Synthesize results'))
  .addEdge('research', 'db_search')
  .addEdge('research', 'vector_search')
  .addEdge('db_search', 'synthesis')
  .addEdge('vector_search', 'synthesis')
  .build();
```

## Success Criteria

- [ ] **Provider interfaces** in `dartantic_interface` enable clean abstraction
- [ ] **SQLite provider** fully implements `DatabaseProvider` interface
- [ ] **ObjectBox provider** fully implements `VectorProvider` interface
- [ ] **Orchestrator nodes** use dependency injection with provider interfaces
- [ ] **Third-party extensibility** - clean path for new provider implementations
- [ ] **All tests pass** including integration tests with real providers
- [ ] **Example workflows** demonstrate end-to-end capabilities
- [ ] **No breaking changes** to existing dartantic ecosystem

## Working Directory

Start in: `/Users/bryangintz/development/packages/dartantic_ai/packages/`

## Implementation Order

1. **Extend interfaces first** - Get abstractions right before implementations
2. **SQLite provider** - Simpler to implement and test
3. **ObjectBox provider** - More complex with code generation
4. **Orchestrator nodes** - Integration layer using interfaces
5. **Testing & examples** - Validate end-to-end functionality

## Reference Documentation

- Detailed implementation guide: `/Users/bryangintz/development/greach/ideas/dartantic_orchestrator_phase2a_implementation_revised.md`
- Current orchestrator patterns: existing `dartantic_orchestrator` codebase
- Interface patterns: existing `dartantic_interface` structure

**Focus on following the exact dartantic pattern established by the existing ecosystem** - provider interfaces in `dartantic_interface`, separate implementation packages, and clean dependency injection throughout.