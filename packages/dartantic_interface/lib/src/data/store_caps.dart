/// Capabilities that a data store can support.
enum StoreCaps {
  /// Supports SQL database operations.
  sqlDatabase,

  /// Supports vector storage and similarity search.
  vectorStorage,

  /// Supports document processing and storage.
  documentProcessing,

  /// Supports full-text search capabilities.
  fullTextSearch,

  /// Supports graph-based queries.
  graphQueries,

  /// Supports converting natural language to SQL.
  naturalLanguageToSql,

  /// Supports generating embeddings for text.
  embeddingGeneration,

  /// Supports batch operations for better performance.
  batchOperations,
}
