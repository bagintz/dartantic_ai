# VSCode Implementation Prompt: Dartantic Orchestrator Phase 2A - Database & Vector Storage

## Context

I need to implement Phase 2A extensions to the existing `dartantic_orchestrator` package, adding **DatabaseNode** and **VectorStorageNode** capabilities for SQL querying and document retrieval within graph workflows.

**Key Technologies:**
- **SQLite** for local SQL database support
- **ObjectBox** for local vector storage with embeddings  
- **Extensions to existing orchestrator** - No breaking changes to current implementation

## Primary Objectives

1. **DatabaseNode Implementation** - Enable SQL querying within workflows with natural language support
2. **VectorStorageNode Implementation** - Document storage, embedding, and semantic search capabilities
3. **Provider Architecture** - Clean abstraction layer for database and vector storage
4. **Seamless Integration** - Extend existing orchestrator without breaking changes

## Implementation Requirements

### New Dependencies to Add

Update `pubspec.yaml`:
```yaml
dependencies:
  # Existing dependencies remain...
  
  # Database support
  sqlite3: ^2.4.0
  path: ^1.9.0
  
  # Vector storage  
  objectbox: ^4.0.0
  objectbox_flutter_libs: ^4.0.0
  
  # Text processing
  text_splitter: ^0.0.2
  html: ^0.15.4
  
  # Utilities
  crypto: ^3.0.3
  http: ^1.2.0

dev_dependencies:
  # Existing dev dependencies remain...
  
  # Code generation for ObjectBox
  build_runner: ^2.4.7
  objectbox_generator: ^4.0.0
```

### New File Structure

Add these files to existing `packages/dartantic_orchestrator/`:
```
lib/src/
├── nodes/
│   ├── database_node.dart          # NEW - SQL execution node
│   ├── vector_storage_node.dart    # NEW - Document retrieval node
│   └── data_processing_node.dart   # NEW - Document chunking/preprocessing
├── providers/
│   ├── database_provider.dart      # NEW - Database abstraction interface
│   ├── sqlite_provider.dart        # NEW - SQLite implementation
│   ├── vector_provider.dart        # NEW - Vector storage abstraction interface
│   └── objectbox_provider.dart     # NEW - ObjectBox implementation
└── utils/
    ├── sql_generator.dart          # NEW - NL to SQL conversion
    ├── document_chunker.dart       # NEW - Text chunking utilities
    └── embedding_utils.dart        # NEW - Embedding generation helpers
```

### Update Main Export File

Add to `lib/dartantic_orchestrator.dart`:
```dart
// New Phase 2A exports
export 'src/providers/database_provider.dart';
export 'src/providers/sqlite_provider.dart';
export 'src/providers/vector_provider.dart';  
export 'src/providers/objectbox_provider.dart';
export 'src/nodes/database_node.dart';
export 'src/nodes/vector_storage_node.dart';
export 'src/utils/sql_generator.dart';
export 'src/utils/document_chunker.dart';
```

## Core Implementation Tasks

### Phase 1: Database Provider (Week 1)

**1. Database Provider Interface**
- `DatabaseProvider` abstract interface
- `QueryResult`, `DatabaseSchema`, `TableSchema` classes
- SQL execution and schema introspection methods

**2. SQLite Provider Implementation** 
- `SQLiteProvider` class implementing `DatabaseProvider`
- Connection management, query execution, error handling
- Natural language to SQL conversion integration

**3. SQL Generation Utilities**
- `SqlGenerator` helper class
- Prompt building for NL-to-SQL conversion
- SQL extraction and validation

**4. DatabaseNode Implementation**
- `DatabaseNode` implementing `WorkflowNode`
- Query template processing with context replacement
- Result formatting and error handling

### Phase 2: Vector Storage Provider (Week 2)

**1. Vector Provider Interface**
- `VectorProvider` abstract interface
- `Document`, `SearchResult` data classes  
- Embedding generation and similarity search methods

**2. ObjectBox Provider Implementation**
- `DocumentEntity` ObjectBox entity for storage
- `ObjectBoxProvider` class implementing `VectorProvider`
- Cosine similarity calculation and search ranking

**3. Document Processing Utilities**
- `DocumentChunker` for text segmentation
- `EmbeddingUtils` for embedding generation helpers
- Content preprocessing and metadata handling

**4. VectorStorageNode Implementation**
- `VectorStorageNode` implementing `WorkflowNode`
- Query building with context integration
- Search result formatting and ranking

### Phase 3: Integration & Testing (Week 3)

**1. Comprehensive Testing**
- Unit tests for all provider implementations
- Integration tests with real database and vector operations
- Example workflows demonstrating capabilities

**2. Documentation & Examples**
- Usage examples for both node types
- Integration patterns with existing orchestrator
- Performance guidelines and best practices

## Key Design Principles

**1. Provider Pattern Consistency**
- Follow existing dartantic provider architecture patterns
- Clean interfaces with multiple implementation support
- Dependency injection friendly design

**2. Backward Compatibility** 
- All changes are additive - no breaking changes to existing orchestrator
- Existing workflows continue to work unchanged
- New capabilities available via opt-in node addition

**3. Context Integration**
- Seamless data passing between nodes using dependencies
- Template-based query building with context substitution
- Shared state management for cross-node coordination

**4. Error Handling & Validation**
- Robust error handling with detailed error messages
- Input validation and sanitization
- Graceful degradation for missing dependencies

## Example Target Usage

```dart
// Research workflow combining database and vector search
final workflow = WorkflowGraph.builder()
  .addNode('research_query', AgentNode(
    researchAgent,
    prompt: 'Analyze research question and identify key terms',
  ))
  .addNode('literature_search', VectorStorageNode(
    vectorProvider,
    queryTemplate: '{research_query}', 
    maxResults: 10,
    dependencies: ['research_query'],
  ))
  .addNode('data_analysis', DatabaseNode(
    sqliteProvider,
    queryTemplate: 'SELECT * FROM studies WHERE topic LIKE "%{research_query}%"',
    dependencies: ['research_query'],
  ))
  .addNode('synthesis', AgentNode(
    analysisAgent,
    prompt: 'Synthesize findings from literature and database',
    dependencies: ['literature_search', 'data_analysis'],
  ))
  .addEdge('research_query', 'literature_search')
  .addEdge('research_query', 'data_analysis') 
  .addEdge('literature_search', 'synthesis')
  .addEdge('data_analysis', 'synthesis')
  .build();
```

## Success Criteria

- [ ] **DatabaseNode** executes SQL queries and returns formatted results
- [ ] **VectorStorageNode** performs semantic search with relevant results  
- [ ] **Provider interfaces** enable clean abstraction and future extensibility
- [ ] **Natural language to SQL** conversion works for basic queries
- [ ] **Document embedding and search** delivers accurate similarity results
- [ ] **Integration tests** pass with real database and vector operations
- [ ] **Existing functionality** remains unaffected (no regressions)
- [ ] **Example workflows** demonstrate end-to-end capabilities

## Working Directory

`/Users/bryangintz/development/packages/dartantic_ai/packages/dartantic_orchestrator`

## Reference Documentation

- Detailed implementation guide: `/Users/bryangintz/development/greach/ideas/dartantic_orchestrator_phase2a_implementation.md`
- Original orchestrator architecture: existing codebase
- Phase 1 success patterns: current working implementation

## Implementation Strategy

1. **Start with interfaces** - Define clean provider abstractions first
2. **Implement SQLite provider** - Database functionality is more straightforward  
3. **Add DatabaseNode** - Test database integration in workflow context
4. **Implement ObjectBox provider** - Vector storage with embedding support
5. **Add VectorStorageNode** - Test document retrieval in workflow context
6. **Integration testing** - End-to-end workflows with both capabilities
7. **Documentation and examples** - Usage patterns and best practices

**Focus on getting basic functionality working before optimizing for performance or adding advanced features.** The goal is to enable database queries and document retrieval within existing graph workflows while maintaining the clean architecture established in Phase 1.