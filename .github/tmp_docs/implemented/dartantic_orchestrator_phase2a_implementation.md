# Dartantic Orchestrator Phase 2A: Database & Vector Storage Implementation

## Overview

Phase 2A extends the existing `dartantic_orchestrator` package with database integration and vector storage capabilities. This implementation adds **DatabaseNode** and **VectorStorageNode** to enable SQL querying and document retrieval within graph workflows.

**Technology Choices:**
- **SQLite** - Local SQL database (via `sqlite3` package)
- **ObjectBox** - Local vector storage with embedding support
- **Extensions to existing orchestrator** - No breaking changes

## Core Implementation Strategy

### 1. Database Integration (DatabaseNode)

**Purpose**: Enable SQL querying and structured data analysis within workflows

**Key Features:**
- Natural language to SQL conversion
- Query execution with result formatting
- Database schema introspection
- Error handling and validation

### 2. Vector Storage Integration (VectorStorageNode) 

**Purpose**: Document storage, retrieval, and semantic search

**Key Features:**
- Document embedding and storage
- Similarity search with ObjectBox vectors
- Document chunking and preprocessing
- Retrieval result ranking

## Package Structure Extensions

```
packages/dartantic_orchestrator/
├── lib/src/
│   ├── nodes/
│   │   ├── database_node.dart          # NEW - SQL execution node
│   │   ├── vector_storage_node.dart    # NEW - Document retrieval node
│   │   └── data_processing_node.dart   # NEW - Document chunking/preprocessing
│   ├── providers/
│   │   ├── database_provider.dart      # NEW - Database abstraction
│   │   ├── sqlite_provider.dart        # NEW - SQLite implementation
│   │   ├── vector_provider.dart        # NEW - Vector storage abstraction
│   │   └── objectbox_provider.dart     # NEW - ObjectBox implementation
│   └── utils/
│       ├── sql_generator.dart          # NEW - NL to SQL conversion
│       ├── document_chunker.dart       # NEW - Text chunking utilities
│       └── embedding_utils.dart        # NEW - Embedding generation helpers
├── pubspec.yaml                        # ADD dependencies
└── test/
    ├── unit/
    │   ├── database_node_test.dart      # NEW
    │   └── vector_storage_node_test.dart # NEW
    └── integration/
        └── data_workflow_test.dart      # NEW
```

## Dependencies to Add

```yaml
dependencies:
  # Existing dependencies...
  
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
  # Existing dev dependencies...
  
  # Code generation for ObjectBox
  build_runner: ^2.4.7
  objectbox_generator: ^4.0.0
```

## Core Interfaces

### DatabaseProvider Interface

```dart
// lib/src/providers/database_provider.dart
abstract interface class DatabaseProvider {
  /// Database connection identifier
  String get connectionId;
  
  /// Initialize database connection
  Future<void> initialize();
  
  /// Execute SQL query and return results
  Future<QueryResult> executeQuery(String sql, [List<dynamic>? parameters]);
  
  /// Generate SQL from natural language description
  Future<String> generateSql(String naturalLanguageQuery, {String? context});
  
  /// Get database schema information
  Future<DatabaseSchema> getSchema();
  
  /// Dispose database connection
  Future<void> dispose();
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
```

### VectorProvider Interface

```dart
// lib/src/providers/vector_provider.dart
abstract interface class VectorProvider {
  /// Provider identifier
  String get providerId;
  
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
  
  /// Generate embedding for text
  Future<List<double>> generateEmbedding(String text);
  
  /// Delete documents by ID or filter
  Future<void> deleteDocuments({
    List<String>? ids,
    Map<String, dynamic>? filters,
  });
  
  /// Dispose vector storage
  Future<void> dispose();
}

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
```

## SQLite Provider Implementation

```dart
// lib/src/providers/sqlite_provider.dart
import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as path;
import 'package:dartantic_ai/dartantic_ai.dart';
import 'database_provider.dart';
import '../utils/sql_generator.dart';

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
    
    // Enable foreign keys
    _database.execute('PRAGMA foreign_keys = ON');
  }
  
  @override
  Future<QueryResult> executeQuery(String sql, [List<dynamic>? parameters]) async {
    try {
      final statement = _database.prepare(sql);
      
      if (sql.trim().toLowerCase().startsWith('select')) {
        // Query operation
        final rows = statement.select(parameters ?? []);
        final columnNames = statement.columnNames;
        
        return QueryResult(
          rows: rows.map((row) => row.asMap()).toList(),
          columnNames: columnNames,
          affectedRows: 0,
          isSuccess: true,
        );
      } else {
        // Modification operation
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
        
        if (isPrimaryKey) {
          primaryKeys.add(columnName);
        }
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

## ObjectBox Provider Implementation

```dart
// lib/src/providers/objectbox_provider.dart
import 'dart:convert';
import 'dart:math';
import 'package:objectbox/objectbox.dart';
import 'package:dartantic_ai/dartantic_ai.dart';
import 'vector_provider.dart';

// ObjectBox entity for document storage
@Entity()
class DocumentEntity {
  @Id()
  int id = 0;
  
  String documentId;
  String content;
  String metadataJson;
  
  // Store embedding as string (JSON array) since ObjectBox doesn't support List<double>
  String embeddingJson;
  
  DocumentEntity({
    required this.documentId,
    required this.content,
    required this.metadataJson,
    required this.embeddingJson,
  });
  
  Document toDocument() {
    final embedding = (json.decode(embeddingJson) as List)
        .cast<double>();
    final metadata = json.decode(metadataJson) as Map<String, dynamic>;
    
    return Document(
      id: documentId,
      content: content,
      metadata: metadata,
      embedding: embedding,
    );
  }
  
  static DocumentEntity fromDocument(Document doc) {
    return DocumentEntity(
      documentId: doc.id,
      content: doc.content,
      metadataJson: json.encode(doc.metadata),
      embeddingJson: json.encode(doc.embedding ?? []),
    );
  }
}

class ObjectBoxProvider implements VectorProvider {
  late Store _store;
  late Box<DocumentEntity> _documentBox;
  final Agent? _embeddingAgent;
  
  ObjectBoxProvider({Agent? embeddingAgent}) : _embeddingAgent = embeddingAgent;
  
  @override
  String get providerId => 'objectbox';
  
  @override
  Future<void> initialize() async {
    // Initialize ObjectBox store
    _store = await openStore();
    _documentBox = _store.box<DocumentEntity>();
  }
  
  @override
  Future<void> storeDocuments(List<Document> documents) async {
    final entities = <DocumentEntity>[];
    
    for (final doc in documents) {
      var embedding = doc.embedding;
      
      // Generate embedding if not provided
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
    // Generate query embedding
    final queryEmbedding = await generateEmbedding(query);
    
    // Get all documents (in production, you'd want indexing/filtering)
    final allEntities = _documentBox.getAll();
    final results = <SearchResult>[];
    
    for (final entity in allEntities) {
      final doc = entity.toDocument();
      if (doc.embedding == null) continue;
      
      // Calculate cosine similarity
      final similarity = _cosineSimilarity(queryEmbedding, doc.embedding!);
      
      if (similarity >= threshold) {
        results.add(SearchResult(
          document: doc,
          similarity: similarity,
          metadata: {'objectbox_id': entity.id},
        ));
      }
    }
    
    // Sort by similarity (descending) and limit results
    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    return results.take(limit).toList();
  }
  
  @override
  Future<List<double>> generateEmbedding(String text) async {
    if (_embeddingAgent == null) {
      throw StateError('Embedding agent not configured');
    }
    
    // Use the agent to generate embeddings
    final embedding = await _embeddingAgent!.embedQuery(text);
    return embedding;
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

## Node Implementations

### DatabaseNode

```dart
// lib/src/nodes/database_node.dart
import 'dart:async';
import 'package:uuid/uuid.dart';
import '../interfaces/workflow_node.dart';
import '../state/node_context.dart';
import '../state/graph_state_impl.dart';
import '../providers/database_provider.dart';

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
      // Build query from template and context
      final query = await _buildQuery(context, state);
      
      // Execute query
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
      final depResult = state.getNodeResult<Map<String, dynamic>>(depId);
      if (depResult != null) {
        // Simple placeholder replacement (enhance as needed)
        query = query.replaceAll('{$depId}', depResult.toString());
      }
    }
    
    // Add shared context
    final sharedContext = state.getSharedData<String>('database_context');
    if (sharedContext != null) {
      query = query.replaceAll('{context}', sharedContext);
    }
    
    // Convert natural language to SQL if needed
    if (_useNaturalLanguage) {
      final schema = await _provider.getSchema();
      query = await _provider.generateSql(query, context: _buildSchemaContext(schema));
    }
    
    return query;
  }
  
  String _formatResults(QueryResult result) {
    if (result.rows.isEmpty) {
      return 'No results found.';
    }
    
    final buffer = StringBuffer();
    buffer.writeln('Query Results (${result.rows.length} rows):');
    
    // Add header
    buffer.writeln(result.columnNames.join(' | '));
    buffer.writeln('-' * (result.columnNames.join(' | ').length));
    
    // Add rows
    for (final row in result.rows.take(10)) { // Limit to 10 rows for display
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
  bool validate() {
    return _queryTemplate.isNotEmpty;
  }
}
```

### VectorStorageNode

```dart
// lib/src/nodes/vector_storage_node.dart
import 'dart:async';
import 'package:uuid/uuid.dart';
import '../interfaces/workflow_node.dart';
import '../state/node_context.dart';
import '../state/graph_state_impl.dart';
import '../providers/vector_provider.dart';

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
      // Build search query from template and context
      final searchQuery = _buildSearchQuery(context, state);
      
      // Perform similarity search
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
    
    // Replace placeholders with context data
    for (final depId in dependencies) {
      final depResult = state.getNodeResult<String>(depId);
      if (depResult != null) {
        query = query.replaceAll('{$depId}', depResult);
      }
    }
    
    // Add shared context
    final sharedContext = state.getSharedData<String>('search_context');
    if (sharedContext != null) {
      query = query.replaceAll('{context}', sharedContext);
    }
    
    return query;
  }
  
  String _formatResults(List<SearchResult> results) {
    if (results.isEmpty) {
      return 'No relevant documents found.';
    }
    
    final buffer = StringBuffer();
    buffer.writeln('Vector Search Results (${results.length} documents):');
    buffer.writeln();
    
    for (var i = 0; i < results.length; i++) {
      final result = results[i];
      buffer.writeln('${i + 1}. ${result.document.id} (similarity: ${result.similarity.toStringAsFixed(3)})');
      
      // Truncate content for display
      final content = result.document.content;
      final preview = content.length > 200 ? '${content.substring(0, 200)}...' : content;
      buffer.writeln('   $preview');
      buffer.writeln();
    }
    
    return buffer.toString();
  }
  
  @override
  bool validate() {
    return _queryTemplate.isNotEmpty && _maxResults > 0 && _threshold >= 0.0 && _threshold <= 1.0;
  }
}
```

## Example Usage

```dart
// Example: Research workflow with database and vector search
import 'package:dartantic_orchestrator/dartantic_orchestrator.dart';

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

## Testing Strategy

### Unit Tests
- Database provider SQL generation and execution
- Vector provider similarity search accuracy
- Node validation and error handling

### Integration Tests
- End-to-end workflow with real database queries
- Vector search with actual document embeddings
- Multi-node coordination and data passing

## Implementation Timeline

**Week 1: Foundation**
- Database provider interface and SQLite implementation
- Basic SQL generation utilities
- DatabaseNode implementation

**Week 2: Vector Storage**
- Vector provider interface and ObjectBox implementation
- Document chunking and embedding utilities
- VectorStorageNode implementation

**Week 3: Integration & Testing**
- Comprehensive test suite
- Example workflows
- Documentation and usage guides

## Success Criteria

- ✅ DatabaseNode executes SQL queries and returns formatted results
- ✅ VectorStorageNode performs semantic search and returns relevant documents
- ✅ Both nodes integrate seamlessly with existing graph orchestration
- ✅ Natural language to SQL conversion works for basic queries
- ✅ Document embedding and similarity search delivers relevant results
- ✅ All tests pass and examples run successfully