# Dartantic Orchestrator Phase 2A: Database & Vector Storage (Revised Architecture)

## Overview

Phase 2A extends the dartantic ecosystem with database and vector storage capabilities following the **correct dartantic pattern**. This implementation adds provider interfaces to `dartantic_interface` and creates separate implementation packages, enabling pluggable data access within graph workflows.

**Corrected Architecture:**
- **Provider interfaces** in `dartantic_interface` (following provider pattern)
- **Implementation packages** `dartantic_sqlite` and `dartantic_objectbox`  
- **Orchestrator nodes** in `dartantic_orchestrator` (using interfaces only)

## Package Architecture

### 1. **`dartantic_interface` Extensions**

Add new provider interfaces to the existing interface package:

```dart
// Add to dartantic_interface/lib/src/data/
abstract interface class DatabaseProvider {
  String get connectionId;
  Future<void> initialize();
  Future<QueryResult> executeQuery(String sql, [List<dynamic>? parameters]);
  Future<String> generateSql(String naturalLanguageQuery, {String? context});
  Future<DatabaseSchema> getSchema();
  Future<void> dispose();
}

abstract interface class VectorProvider {
  String get providerId;
  Future<void> initialize();
  Future<void> storeDocuments(List<Document> documents);
  Future<List<SearchResult>> similaritySearch(String query, {int limit = 5, double threshold = 0.7});
  Future<List<double>> generateEmbedding(String text);
  Future<void> deleteDocuments({List<String>? ids, Map<String, dynamic>? filters});
  Future<void> dispose();
}

// Shared data types
class Document {
  final String id;
  final String content;
  final Map<String, dynamic> metadata;
  final List<double>? embedding;
  
  const Document({required this.id, required this.content, required this.metadata, this.embedding});
}

class QueryResult {
  final List<Map<String, dynamic>> rows;
  final List<String> columnNames;
  final int affectedRows;
  final String? error;
  final bool isSuccess;
  
  const QueryResult({required this.rows, required this.columnNames, required this.affectedRows, this.error, required this.isSuccess});
}

class SearchResult {
  final Document document;
  final double similarity;
  final Map<String, dynamic> metadata;
  
  const SearchResult({required this.document, required this.similarity, required this.metadata});
}
```

**Update `dartantic_interface/lib/dartantic_interface.dart`:**
```dart
export 'src/chat/chat.dart';
export 'src/embeddings/embeddings.dart';
export 'src/model/model.dart';
export 'src/provider/provider.dart';
export 'src/data/data.dart';        // NEW - data provider interfaces
export 'src/tool.dart';
```

### 2. **`dartantic_sqlite` Package (New)**

Create standalone SQLite provider implementation:

**Package Structure:**
```
packages/dartantic_sqlite/
├── lib/
│   ├── dartantic_sqlite.dart
│   └── src/
│       ├── sqlite_provider.dart
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
description: SQLite implementation for dartantic database providers
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

**`lib/src/sqlite_provider.dart`:**
```dart
import 'dart:io';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as path;
import 'sql_generator.dart';

class SQLiteProvider implements DatabaseProvider {
  late Database _database;
  final String _dbPath;
  final Agent? _sqlAgent;
  
  SQLiteProvider(this._dbPath, {Agent? sqlAgent}) : _sqlAgent = sqlAgent;
  
  @override
  String get connectionId => 'sqlite:${path.basename(_dbPath)}';
  
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
    if (_sqlAgent == null) {
      throw StateError('SQL agent not configured for natural language queries');
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

// Supporting classes
class DatabaseSchema {
  final Map<String, TableSchema> tables;
  const DatabaseSchema(this.tables);
}

class TableSchema {
  final String name;
  final Map<String, ColumnInfo> columns;
  final List<String> primaryKeys;
  
  const TableSchema({required this.name, required this.columns, required this.primaryKeys});
}

class ColumnInfo {
  final String name;
  final String type;
  final bool nullable;
  final bool isPrimaryKey;
  
  const ColumnInfo({required this.name, required this.type, required this.nullable, required this.isPrimaryKey});
}
```

### 3. **`dartantic_objectbox` Package (New)**

Create standalone ObjectBox provider implementation:

**Package Structure:**
```
packages/dartantic_objectbox/
├── lib/
│   ├── dartantic_objectbox.dart
│   └── src/
│       ├── objectbox_provider.dart
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
description: ObjectBox implementation for dartantic vector providers
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

**`lib/src/objectbox_provider.dart`:**
```dart
import 'dart:convert';
import 'dart:math';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:objectbox/objectbox.dart';
import 'document_entity.dart';

class ObjectBoxProvider implements VectorProvider {
  late Store _store;
  late Box<DocumentEntity> _documentBox;
  final Agent? _embeddingAgent;
  
  ObjectBoxProvider({Agent? embeddingAgent}) : _embeddingAgent = embeddingAgent;
  
  @override
  String get providerId => 'objectbox';
  
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
      
      if (embedding == null && _embeddingAgent != null) {
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
    if (_embeddingAgent == null) {
      throw StateError('Embedding agent not configured');
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

### 4. **`dartantic_orchestrator` Node Extensions**

Add nodes that use the provider interfaces:

**`lib/src/nodes/database_node.dart`:**
```dart
import 'dart:async';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:uuid/uuid.dart';
import '../interfaces/workflow_node.dart';
import '../state/node_context.dart';
import '../state/graph_state_impl.dart';

class DatabaseNode implements WorkflowNode {
  @override
  final String id;
  
  final DatabaseProvider _provider;
  final String _queryTemplate;
  final bool _useNaturalLanguage;
  final List<String> _dependencies;
  
  DatabaseNode(
    this._provider, {
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
  Stream<NodeResult> execute(NodeContext context, GraphState state) async* {
    try {
      final query = await _buildQuery(context, state);
      final result = await _provider.executeQuery(query);
      
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
            'database': _provider.connectionId,
            'row_count': result.rows.length,
            'execution_time': DateTime.now().toIso8601String(),
          },
        );
      } else {
        yield NodeResult.error(
          error: 'Database query failed: ${result.error}',
          metadata: {'query': query},
        );
      }
    } catch (e) {
      yield NodeResult.error(
        error: 'Database node execution failed: $e',
      );
    }
  }
  
  Future<String> _buildQuery(NodeContext context, GraphState state) async {
    var query = _queryTemplate;
    
    // Replace placeholders with context data
    for (final depId in dependencies) {
      final depResult = state.getNodeResult<String>(depId);
      if (depResult != null) {
        query = query.replaceAll('{$depId}', depResult);
      }
    }
    
    // Convert natural language to SQL if needed
    if (_useNaturalLanguage) {
      final schema = await _provider.getSchema();
      query = await _provider.generateSql(query, context: _buildSchemaContext(schema));
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
  bool validate() => _queryTemplate.isNotEmpty;
}
```

**`lib/src/nodes/vector_storage_node.dart`:**
```dart
import 'dart:async';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:uuid/uuid.dart';
import '../interfaces/workflow_node.dart';
import '../state/node_context.dart';
import '../state/graph_state_impl.dart';

class VectorStorageNode implements WorkflowNode {
  @override
  final String id;
  
  final VectorProvider _provider;
  final String _queryTemplate;
  final int _maxResults;
  final double _threshold;
  final List<String> _dependencies;
  
  VectorStorageNode(
    this._provider, {
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
  String get type => 'vector_storage';
  
  @override
  String get description => 'Vector Search: $_queryTemplate';
  
  @override
  List<String> get dependencies => List.unmodifiable(_dependencies);
  
  @override
  Stream<NodeResult> execute(NodeContext context, GraphState state) async* {
    try {
      final searchQuery = _buildSearchQuery(context, state);
      
      final results = await _provider.similaritySearch(
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
          'vector_provider': _provider.providerId,
          'search_query': searchQuery,
          'max_results': _maxResults,
          'threshold': _threshold,
          'execution_time': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      yield NodeResult.error(
        error: 'Vector storage search failed: $e',
      );
    }
  }
  
  String _buildSearchQuery(NodeContext context, GraphState state) {
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
  bool validate() => _queryTemplate.isNotEmpty && _maxResults > 0 && _threshold >= 0.0 && _threshold <= 1.0;
}
```

## Example Usage

```dart
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_orchestrator/dartantic_orchestrator.dart';
import 'package:dartantic_sqlite/dartantic_sqlite.dart';
import 'package:dartantic_objectbox/dartantic_objectbox.dart';

Future<void> buildResearchWorkflow() async {
  // Initialize providers
  final dbProvider = SQLiteProvider('./research_data.db');
  await dbProvider.initialize();
  
  final vectorProvider = ObjectBoxProvider(embeddingAgent: embeddingAgent);
  await vectorProvider.initialize();
  
  // Build workflow
  final workflow = WorkflowGraph.builder()
    .addNode('research_query', AgentNode(
      researchAgent,
      prompt: 'Analyze the research question and identify key search terms',
    ))
    .addNode('literature_search', VectorStorageNode(
      vectorProvider,
      queryTemplate: '{research_query}',
      maxResults: 10,
      dependencies: ['research_query'],
    ))
    .addNode('data_analysis', DatabaseNode(
      dbProvider,
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
  final orchestrator = DefaultGraphOrchestrator();
  final graphOrchestrator = GraphStreamingOrchestrator(orchestrator, workflow);
  
  final agent = Agent('anthropic', orchestrator: graphOrchestrator);
  final result = await agent.send('What are the latest findings on AI safety research?');
  
  print(result.output);
}
```

## Implementation Timeline

### **Week 1: Interface Extensions**
- Extend `dartantic_interface` with database and vector provider interfaces
- Add shared data types (Document, QueryResult, SearchResult, DatabaseSchema)
- Update interface exports and documentation

### **Week 2: SQLite Implementation**  
- Create `dartantic_sqlite` package structure
- Implement `SQLiteProvider` with full interface compliance
- Add SQL generation utilities and natural language conversion
- Comprehensive testing with various SQL operations

### **Week 3: ObjectBox Implementation**
- Create `dartantic_objectbox` package structure  
- Implement `ObjectBoxProvider` with embedding support
- Add similarity calculation and search ranking
- Testing with document storage and retrieval

### **Week 4: Integration & Node Implementation**
- Add `DatabaseNode` and `VectorStorageNode` to orchestrator
- Update orchestrator exports and documentation
- End-to-end integration testing
- Example workflows and usage guides

## Success Criteria

- ✅ **Provider interfaces** in `dartantic_interface` enable clean abstraction
- ✅ **Separate implementation packages** allow pluggable providers
- ✅ **DatabaseNode** executes SQL queries using interface only
- ✅ **VectorStorageNode** performs semantic search using interface only
- ✅ **Third-party extensibility** - others can create `dartantic_postgresql`, `dartantic_pinecone`, etc.
- ✅ **No breaking changes** to existing orchestrator functionality
- ✅ **All tests pass** and examples run successfully

## Benefits of Corrected Architecture

1. **Follows dartantic patterns** - interfaces in `dartantic_interface`, implementations separate
2. **Pluggable ecosystem** - users can mix and match database/vector providers
3. **Clean dependencies** - orchestrator doesn't pull in heavy database libraries
4. **Third-party extensible** - anyone can create new provider implementations
5. **Minimal orchestrator changes** - only adds nodes that use provider interfaces