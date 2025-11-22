/// Represents a document to be stored in a vector store.
class Document {
  /// Unique identifier for the document.
  final String id;

  /// The text content of the document.
  final String content;

  /// Metadata associated with the document.
  final Map<String, dynamic> metadata;

  /// The vector embedding of the document content.
  final List<double>? embedding;

  const Document({
    required this.id,
    required this.content,
    this.metadata = const {},
    this.embedding,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'metadata': metadata,
      if (embedding != null) 'embedding': embedding,
    };
  }

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'] as String,
      content: json['content'] as String,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      embedding: (json['embedding'] as List?)?.cast<double>(),
    );
  }
}

/// Represents a result from a vector similarity search.
class SearchResult {
  /// The document that matched the query.
  final Document document;

  /// The similarity score (usually between 0 and 1).
  final double score;

  const SearchResult({
    required this.document,
    required this.score,
  });
}

/// Represents the result of a database query.
class QueryResult {
  /// The rows returned by the query.
  final List<Map<String, dynamic>> rows;

  /// The number of rows affected by the query (for INSERT/UPDATE/DELETE).
  final int? affectedRows;

  /// The columns in the result set.
  final List<String>? columns;

  const QueryResult({
    this.rows = const [],
    this.affectedRows,
    this.columns,
  });
}

/// Represents the schema of a database.
class DatabaseSchema {
  /// The raw schema definition (e.g., CREATE TABLE statements).
  final String rawSchema;

  /// Structured information about tables (optional).
  final Map<String, List<String>>? tables;

  const DatabaseSchema({
    required this.rawSchema,
    this.tables,
  });

  @override
  String toString() => rawSchema;
}
