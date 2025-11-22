import 'data_types.dart';
import 'store_caps.dart';

/// Interface for a vector database store.
abstract interface class VectorStore {
  /// Unique identifier for this store instance.
  String get storeId;

  /// Initializes the store connection.
  Future<void> initialize();

  /// Stores a list of documents in the vector store.
  ///
  /// If the store supports embedding generation, it may generate embeddings
  /// for documents that don't have them.
  Future<void> storeDocuments(List<Document> documents);

  /// Performs a similarity search using a query string.
  ///
  /// [query] is the text to search for.
  /// [limit] is the maximum number of results to return.
  /// [threshold] is the minimum similarity score required.
  Future<List<SearchResult>> similaritySearch(String query, {int limit = 5, double threshold = 0.7});

  /// Generates an embedding vector for the given text.
  Future<List<double>> generateEmbedding(String text);

  /// Deletes documents from the store.
  ///
  /// [ids] is a list of document IDs to delete.
  /// [filters] is a map of metadata filters to match documents for deletion.
  Future<void> deleteDocuments({List<String>? ids, Map<String, dynamic>? filters});

  /// Closes the store connection and releases resources.
  Future<void> dispose();

  /// The set of capabilities supported by this store.
  Set<StoreCaps> get caps;
}
