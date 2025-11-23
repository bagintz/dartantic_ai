# Dartantic Data Stores Implementation Guide

## Overview

This document provides comprehensive implementation guidance for adding data store capabilities to the dartantic ecosystem. Following the corrected terminology alignment, we use "Store" pattern for data access (DatabaseStore, VectorStore) to avoid conflicts with the existing Provider pattern (LLM services).

**Architecture Approach:**
- **Store interfaces** in `dartantic_interface` (following provider pattern)
- **Store implementations** in separate packages (`dartantic_sqlite`, `dartantic_objectbox`)
- **Workflow nodes** in `dartantic_workflows` use store interfaces only
- **Capability system** uses separate `StoreCaps` enum

## Package Architecture

### 1. **`dartantic_interface` Extensions**

Add new store interfaces to the existing interface package following the exact same pattern as Provider interfaces:

```dart
// Add to dartantic_interface/lib/src/data/
abstract interface class DatabaseStore {
  /// Store identifier for logging/debugging
  String get storeId;
  
  /// Initialize the database connection
  Future<void> initialize();
  
  /// Execute SQL query and return results
  Future<QueryResult> executeQuery(String sql, [List<dynamic>? parameters]);
  
  /// Generate SQL from natural language description (if supported)
  Future<String> generateSql(String naturalLanguageQuery, {String? context});
  
  /// Get database schema information
  Future<DatabaseSchema> getSchema();
  
  /// Dispose database connection
  Future<void> dispose();
  
  /// Store capabilities
  Set<StoreCaps> get caps;
}

abstract interface class VectorStore {
  /// Store identifier for logging/debugging  
  String get storeId;
  
  /// Initialize vector storage
  Future<void> initialize();
  
  /// Store documents with embeddings
  Future<void> storeDocuments(List<Document> documents);
  
  /// Search for similar documents
  Future<List<SearchResult>> similaritySearch(
    String query, {
    int limit = 5,
    double threshold = 0.7,
    Map<String, dynamic>? filters,
  });
  
  /// Generate embedding for text (if supported)
  Future<List<double>> generateEmbedding(String text);
  
  /// Delete documents by ID or filter
  Future<void> deleteDocuments({
    List<String>? ids,
    Map<String, dynamic>? filters,
  });
  
  /// Dispose vector storage
  Future<void> dispose();
  
  /// Store capabilities
  Set<StoreCaps> get caps;
}

// Store capability system (separate from ProviderCaps)
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

// Shared data types
class Document {
  final String id;
  final String content;
  final Map<String, dynamic> metadata;
  final List<double>? embedding;
  
  const Document({
    required this.id,
    required this.content,
    required this.metadata,
    this.embedding,
  });
}

class QueryResult {
  final List<Map<String, dynamic>> rows;
  final List<String> columnNames;
  final int affectedRows;
  final String? error;
  final bool isSuccess;
  
  const QueryResult({
    required this.rows,
    required this.columnNames,
    required this.affectedRows,
    this.error,
    required this.isSuccess,
  });
}

class SearchResult {
  final Document document;
  final double similarity;
  final Map<String, dynamic> metadata;
  
  const SearchResult({
    required this.document,
    required this.similarity,
    required this.metadata,
  });
}

class DatabaseSchema {
  final Map<String, TableSchema> tables;
  
  const DatabaseSchema(this.tables);
}

class TableSchema {
  final String name;
  final Map<String, ColumnInfo> columns;
  final List<String> primaryKeys;
  
  const TableSchema({
    required this.name,
    required this.columns,
    required this.primaryKeys,
  });
}

class ColumnInfo {
  final String name;
  final String type;
  final bool nullable;
  final bool isPrimaryKey;
  
  const ColumnInfo({
    required this.name,
    required this.type,
    required this.nullable,
    required this.isPrimaryKey,
  });
}
```

**Update `dartantic_interface/lib/dartantic_interface.dart`:**
```dart
export 'src/chat/chat.dart';
export 'src/embeddings/embeddings.dart';
export 'src/model/model.dart';
export 'src/provider/provider.dart';
export 'src/data/data.dart';        // NEW - data store interfaces
export 'src/tool.dart';
```

### 2. **`dartantic_sqlite` Package**

Create standalone SQLite store implementation:

**Package Structure:**
```
packages/dartantic_sqlite/
├── lib/
│   ├── dartantic_sqlite.dart
│   └── src/
│       ├── sqlite_store.dart
│       ├── sql_generator.dart
│       └── utils/
│           └── connection_manager.dart
├── pubspec.yaml
├── test/
└── example/
```

**`pubspec.yaml`:**
```yaml
name: dartantic_sqlite
description: SQLite store implementation for dartantic data stores
version: 0.1.0
repository: https://github.com/csells/dartantic_ai

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
  all_lint_rules_community: ^0.0.43
```

**`lib/src/sqlite_store.dart`:**
```dart
import 'dart:io';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as path;
import 'sql_generator.dart';

class SQLiteStore implements DatabaseStore {
  late Database _database;
  final String _dbPath;
  final Agent? _sqlAgent;
  
  SQLiteStore(this._dbPath, {Agent? sqlAgent}) : _sqlAgent = sqlAgent;
  
  @override
  String get storeId => 'sqlite:${path.basename(_dbPath)}';
  
  @override
  Set<StoreCaps> get caps => {
    StoreCaps.sqlDatabase,
    StoreCaps.fullTextSearch,
    if (_sqlAgent != null) StoreCaps.naturalLanguageToSql,
  };
  
  @override
  Future<void> initialize() async {
    final dbFile = File(_dbPath);
    if (!dbFile.parent.existsSync()) {
      await dbFile.parent.create(recursive: true);
    }
    
    _database = sqlite3.open(_dbPath);
    _database.execute('PRAGMA foreign_keys = ON');
  }
  
  @override
  Future<QueryResult> executeQuery(String sql, [List<dynamic>? parameters]) async {
    try {
      final statement = _database.prepare(sql);
      
      if (sql.trim().toLowerCase().startsWith('select')) {
        final rows = statement.select(parameters ?? []);
        final columnNames = statement.columnNames;
        
        return QueryResult(
          rows: rows.map((row) => row.asMap()).toList(),
          columnNames: columnNames,
          affectedRows: 0,
          isSuccess: true,
        );
      } else {
        statement.execute(parameters ?? []);
        final changes = _database.lastInsertRowId;
        
        return QueryResult(
          rows: [],
          columnNames: [],
          affectedRows: changes,
          isSuccess: true,
        );
      }
    } catch (e) {
      return QueryResult(
        rows: [],
        columnNames: [],
        affectedRows: 0,
        error: e.toString(),
        isSuccess: false,
      );
    }
  }
  
  @override
  Future<String> generateSql(String naturalLanguageQuery, {String? context}) async {
    if (!caps.contains(StoreCaps.naturalLanguageToSql)) {
      throw StateError('Natural language to SQL not supported - no SQL agent configured');
    }
    
    final schema = await getSchema();
    final prompt = SqlGenerator.buildPrompt(naturalLanguageQuery, schema, context);
    
    final result = await _sqlAgent!.send(prompt);
    return SqlGenerator.extractSql(result.output);
  }
  
  @override
  Future<DatabaseSchema> getSchema() async {
    final tablesResult = await executeQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
    );
    
    final tables = <String, TableSchema>{};
    
    for (final tableRow in tablesResult.rows) {
      final tableName = tableRow['name'] as String;
      final columnsResult = await executeQuery('PRAGMA table_info($tableName)');
      
      final columns = <String, ColumnInfo>{};
      final primaryKeys = <String>[];
      
      for (final columnRow in columnsResult.rows) {
        final columnName = columnRow['name'] as String;
        final columnType = columnRow['type'] as String;
        final isPrimaryKey = columnRow['pk'] == 1;
        
        columns[columnName] = ColumnInfo(
          name: columnName,
          type: columnType,
          nullable: columnRow['notnull'] == 0,
          isPrimaryKey: isPrimaryKey,
        );
        
        if (isPrimaryKey) primaryKeys.add(columnName);
      }
      
      tables[tableName] = TableSchema(
        name: tableName,
        columns: columns,
        primaryKeys: primaryKeys,
      );
    }
    
    return DatabaseSchema(tables);
  }
  
  @override
  Future<void> dispose() async {
    _database.dispose();
  }
}
```

### 3. **`dartantic_objectbox` Package**

Create standalone ObjectBox store implementation:

**Package Structure:**
```
packages/dartantic_objectbox/
├── lib/
│   ├── dartantic_objectbox.dart
│   └── src/
│       ├── objectbox_store.dart
│       ├── document_entity.dart
│       └── utils/
│           └── similarity_calculator.dart
├── pubspec.yaml
├── test/
└── example/
```

**`pubspec.yaml`:**
```yaml
name: dartantic_objectbox
description: ObjectBox store implementation for dartantic vector stores
version: 0.1.0
repository: https://github.com/csells/dartantic_ai

environment:
  sdk: ^3.9.0

dependencies:
  dartantic_interface:
    path: ../dartantic_interface
  dartantic_ai:
    path: ../dartantic_ai
  objectbox: ^4.0.0
  objectbox_flutter_libs: ^4.0.0
  logging: ^1.3.0

dev_dependencies:
  test: ^1.24.0
  build_runner: ^2.4.7
  objectbox_generator: ^4.0.0
  all_lint_rules_community: ^0.0.43
```

**`lib/src/objectbox_store.dart`:**
```dart
import 'dart:convert';
import 'dart:math';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:objectbox/objectbox.dart';
import 'document_entity.dart';

class ObjectBoxStore implements VectorStore {
  late Store _store;
  late Box<DocumentEntity> _documentBox;
  final Agent? _embeddingAgent;
  
  ObjectBoxStore({Agent? embeddingAgent}) : _embeddingAgent = embeddingAgent;
  
  @override
  String get storeId => 'objectbox';
  
  @override
  Set<StoreCaps> get caps => {
    StoreCaps.vectorStorage,
    StoreCaps.documentProcessing,
    if (_embeddingAgent != null) StoreCaps.embeddingGeneration,
  };
  
  @override
  Future<void> initialize() async {
    _store = await openStore();
    _documentBox = _store.box<DocumentEntity>();
  }
  
  @override
  Future<void> storeDocuments(List<Document> documents) async {
    final entities = <DocumentEntity>[];
    
    for (final doc in documents) {
      var embedding = doc.embedding;
      
      if (embedding == null && caps.contains(StoreCaps.embeddingGeneration)) {
        embedding = await generateEmbedding(doc.content);
      }
      
      final docWithEmbedding = Document(
        id: doc.id,
        content: doc.content,
        metadata: doc.metadata,
        embedding: embedding,
      );
      
      entities.add(DocumentEntity.fromDocument(docWithEmbedding));
    }
    
    _documentBox.putMany(entities);
  }
  
  @override
  Future<List<SearchResult>> similaritySearch(
    String query, {
    int limit = 5,
    double threshold = 0.7,
    Map<String, dynamic>? filters,
  }) async {
    final queryEmbedding = await generateEmbedding(query);
    final allEntities = _documentBox.getAll();
    final results = <SearchResult>[];
    
    for (final entity in allEntities) {
      final doc = entity.toDocument();
      if (doc.embedding == null) continue;
      
      final similarity = _cosineSimilarity(queryEmbedding, doc.embedding!);
      
      if (similarity >= threshold) {
        results.add(SearchResult(
          document: doc,
          similarity: similarity,
          metadata: {'objectbox_id': entity.id},
        ));
      }
    }
    
    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    return results.take(limit).toList();
  }
  
  @override
  Future<List<double>> generateEmbedding(String text) async {
    if (!caps.contains(StoreCaps.embeddingGeneration)) {
      throw StateError('Embedding generation not supported - no embedding agent configured');
    }
    
    return await _embeddingAgent!.embedQuery(text);
  }
  
  @override
  Future<void> deleteDocuments({
    List<String>? ids,
    Map<String, dynamic>? filters,
  }) async {
    if (ids != null) {
      final query = _documentBox.query(DocumentEntity_.documentId.oneOf(ids));
      final entities = query.build().find();
      final entityIds = entities.map((e) => e.id).toList();
      _documentBox.removeMany(entityIds);
    }
  }
  
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    
    var dotProduct = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    
    for (var i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }
  
  @override
  Future<void> dispose() async {
    _store.close();
  }
}
```

### 4. **`dartantic_workflows` Node Extensions**

Add nodes that use the store interfaces:

**`lib/src/nodes/database_node.dart`:**
```dart
import 'dart:async';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:uuid/uuid.dart';
import '../interfaces/workflow_node.dart';
import '../state/node_context.dart';
import '../state/workflow_state.dart';

class DatabaseNode implements WorkflowNode {
  @override
  final String id;
  
  final DatabaseStore _store;
  final String _queryTemplate;
  final bool _useNaturalLanguage;
  final List<String> _dependencies;
  
  DatabaseNode(
    this._store, {
    required String queryTemplate,
    bool useNaturalLanguage = false,
    String? id,
    List<String> dependencies = const [],
  }) : id = id ?? const Uuid().v4(),
       _queryTemplate = queryTemplate,
       _useNaturalLanguage = useNaturalLanguage,
       _dependencies = dependencies;
  
  @override
  String get type => 'database';
  
  @override
  String get description => 'Database Query: $_queryTemplate';
  
  @override
  List<String> get dependencies => List.unmodifiable(_dependencies);
  
  @override
  Stream<NodeResult> execute(NodeContext context, WorkflowState state) async* {
    try {
      final query = await _buildQuery(context, state);
      final result = await _store.executeQuery(query);
      
      if (result.isSuccess) {
        yield NodeResult.success(
          output: _formatResults(result),
          messages: [],
          data: {
            'query_result': result.rows,
            'affected_rows': result.affectedRows,
            'column_names': result.columnNames,
            'executed_query': query,
          },
          metadata: {
            'store_id': _store.storeId,
            'row_count': result.rows.length,
            'execution_time': DateTime.now().toIso8601String(),
          },
        );
      } else {
        yield NodeResult.error(
          error: 'Database query failed: ${result.error}',
          metadata: {'query': query, 'store_id': _store.storeId},
        );
      }
    } catch (e) {
      yield NodeResult.error(
        error: 'Database node execution failed: $e',
        metadata: {'store_id': _store.storeId},
      );
    }
  }
  
  Future<String> _buildQuery(NodeContext context, WorkflowState state) async {
    var query = _queryTemplate;
    
    // Replace placeholders with context data
    for (final depId in dependencies) {
      final depResult = state.getNodeResult<String>(depId);
      if (depResult != null) {
        query = query.replaceAll('{$depId}', depResult);
      }
    }
    
    // Convert natural language to SQL if needed and supported
    if (_useNaturalLanguage && _store.caps.contains(StoreCaps.naturalLanguageToSql)) {
      final schema = await _store.getSchema();
      query = await _store.generateSql(query, context: _buildSchemaContext(schema));
    }
    
    return query;
  }
  
  String _formatResults(QueryResult result) {
    if (result.rows.isEmpty) return 'No results found.';
    
    final buffer = StringBuffer();
    buffer.writeln('Query Results (${result.rows.length} rows):');
    buffer.writeln(result.columnNames.join(' | '));
    buffer.writeln('-' * (result.columnNames.join(' | ').length));
    
    for (final row in result.rows.take(10)) {
      final values = result.columnNames.map((col) => row[col]?.toString() ?? '').toList();
      buffer.writeln(values.join(' | '));
    }
    
    if (result.rows.length > 10) {
      buffer.writeln('... and ${result.rows.length - 10} more rows');
    }
    
    return buffer.toString();
  }
  
  String _buildSchemaContext(DatabaseSchema schema) {
    final buffer = StringBuffer();
    buffer.writeln('Database Schema:');
    
    for (final table in schema.tables.values) {
      buffer.writeln('Table: ${table.name}');
      for (final column in table.columns.values) {
        buffer.writeln('  ${column.name}: ${column.type}${column.isPrimaryKey ? ' (PK)' : ''}');
      }
      buffer.writeln();
    }
    
    return buffer.toString();
  }
  
  @override
  bool validate() => _queryTemplate.isNotEmpty && _store.caps.contains(StoreCaps.sqlDatabase);
}
```

**`lib/src/nodes/vector_search_node.dart`:**
```dart
import 'dart:async';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:uuid/uuid.dart';
import '../interfaces/workflow_node.dart';
import '../state/node_context.dart';
import '../state/workflow_state.dart';

class VectorSearchNode implements WorkflowNode {
  @override
  final String id;
  
  final VectorStore _store;
  final String _queryTemplate;
  final int _maxResults;
  final double _threshold;
  final List<String> _dependencies;
  
  VectorSearchNode(
    this._store, {
    required String queryTemplate,
    int maxResults = 5,
    double threshold = 0.7,
    String? id,
    List<String> dependencies = const [],
  }) : id = id ?? const Uuid().v4(),
       _queryTemplate = queryTemplate,
       _maxResults = maxResults,
       _threshold = threshold,
       _dependencies = dependencies;
  
  @override
  String get type => 'vector_search';
  
  @override
  String get description => 'Vector Search: $_queryTemplate';
  
  @override
  List<String> get dependencies => List.unmodifiable(_dependencies);
  
  @override
  Stream<NodeResult> execute(NodeContext context, WorkflowState state) async* {
    try {
      final searchQuery = _buildSearchQuery(context, state);
      
      final results = await _store.similaritySearch(
        searchQuery,
        limit: _maxResults,
        threshold: _threshold,
      );
      
      yield NodeResult.success(
        output: _formatResults(results),
        messages: [],
        data: {
          'search_results': results.map((r) => {
            'document_id': r.document.id,
            'content': r.document.content,
            'similarity': r.similarity,
            'metadata': r.document.metadata,
          }).toList(),
          'query': searchQuery,
          'result_count': results.length,
        },
        metadata: {
          'store_id': _store.storeId,
          'search_query': searchQuery,
          'max_results': _maxResults,
          'threshold': _threshold,
          'execution_time': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      yield NodeResult.error(
        error: 'Vector search failed: $e',
        metadata: {'store_id': _store.storeId},
      );
    }
  }
  
  String _buildSearchQuery(NodeContext context, WorkflowState state) {
    var query = _queryTemplate;
    
    for (final depId in dependencies) {
      final depResult = state.getNodeResult<String>(depId);
      if (depResult != null) {
        query = query.replaceAll('{$depId}', depResult);
      }
    }
    
    return query;
  }
  
  String _formatResults(List<SearchResult> results) {
    if (results.isEmpty) return 'No relevant documents found.';
    
    final buffer = StringBuffer();
    buffer.writeln('Vector Search Results (${results.length} documents):');
    buffer.writeln();
    
    for (var i = 0; i < results.length; i++) {
      final result = results[i];
      buffer.writeln('${i + 1}. ${result.document.id} (similarity: ${result.similarity.toStringAsFixed(3)})');
      
      final content = result.document.content;
      final preview = content.length > 200 ? '${content.substring(0, 200)}...' : content;
      buffer.writeln('   $preview');
      buffer.writeln();
    }
    
    return buffer.toString();
  }
  
  @override
  bool validate() => _queryTemplate.isNotEmpty && 
                     _maxResults > 0 && 
                     _threshold >= 0.0 && 
                     _threshold <= 1.0 &&
                     _store.caps.contains(StoreCaps.vectorStorage);
}
```

## Example Usage

```dart
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_workflows/dartantic_workflows.dart';
import 'package:dartantic_sqlite/dartantic_sqlite.dart';
import 'package:dartantic_objectbox/dartantic_objectbox.dart';

Future<void> buildResearchWorkflow() async {
  // Initialize stores
  final sqliteStore = SQLiteStore('./research_data.db');
  await sqliteStore.initialize();
  
  final vectorStore = ObjectBoxStore(embeddingAgent: embeddingAgent);
  await vectorStore.initialize();
  
  // Build workflow using stores (not providers!)
  final workflow = GraphWorkflow.builder()
    .addNode('research_query', AgentNode(
      researchAgent,
      prompt: 'Analyze the research question and identify key search terms',
    ))
    .addNode('literature_search', VectorSearchNode(
      vectorStore,
      queryTemplate: '{research_query}',
      maxResults: 10,
      dependencies: ['research_query'],
    ))
    .addNode('data_analysis', DatabaseNode(
      sqliteStore,
      queryTemplate: 'SELECT * FROM studies WHERE topic LIKE "%{research_query}%"',
      dependencies: ['research_query'],
    ))
    .addNode('synthesis', AgentNode(
      analysisAgent,
      prompt: 'Synthesize findings from literature and database results',
      dependencies: ['literature_search', 'data_analysis'],
    ))
    .addEdge('research_query', 'literature_search')
    .addEdge('research_query', 'data_analysis')
    .addEdge('literature_search', 'synthesis')
    .addEdge('data_analysis', 'synthesis')
    .build();
    
  // Execute workflow
  final agent = Agent('anthropic');
  final result = await agent.runWorkflow(workflow);
  
  print(result.output);
}
```

## Implementation Timeline

### **Week 1: Interface Foundation**
- Extend `dartantic_interface` with store interfaces and data types
- Add `StoreCaps` enum separate from `ProviderCaps`
- Update interface exports and documentation

### **Week 2: SQLite Implementation**  
- Create `dartantic_sqlite` package structure
- Implement `SQLiteStore` with full interface compliance
- Add SQL generation utilities and natural language conversion
- Comprehensive testing with various SQL operations

### **Week 3: ObjectBox Implementation**
- Create `dartantic_objectbox` package structure  
- Implement `ObjectBoxStore` with embedding support
- Add similarity calculation and search ranking
- Testing with document storage and retrieval

### **Week 4: Integration & Node Implementation**
- Add `DatabaseNode` and `VectorSearchNode` to workflows
- Update workflows exports and documentation
- End-to-end integration testing
- Example workflows and usage guides

## Success Criteria

- ✅ **Store interfaces** in `dartantic_interface` enable clean abstraction
- ✅ **Separate implementation packages** allow pluggable stores
- ✅ **DatabaseNode** executes SQL queries using interface only
- ✅ **VectorSearchNode** performs semantic search using interface only
- ✅ **Capability system integration** with separate `StoreCaps`
- ✅ **Third-party extensibility** - others can create new store implementations
- ✅ **No terminology conflicts** with existing Provider pattern
- ✅ **All tests pass** and examples run successfully

## Benefits of Store Architecture

1. **Perfect terminology alignment** - no conflicts with Provider pattern
2. **Pluggable ecosystem** - users can mix and match data stores
3. **Clean dependencies** - workflows don't pull in heavy database libraries
4. **Third-party extensible** - anyone can create new store implementations
5. **Capability-driven** - nodes validate store capabilities before execution
6. **Industry standard** - "vector store", "database store" are common terms