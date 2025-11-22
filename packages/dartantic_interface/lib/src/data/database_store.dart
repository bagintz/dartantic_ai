import 'data_types.dart';
import 'store_caps.dart';

/// Interface for a SQL-based database store.
abstract interface class DatabaseStore {
  /// Unique identifier for this store instance.
  String get storeId;

  /// Initializes the store connection.
  Future<void> initialize();

  /// Executes a raw SQL query.
  ///
  /// [sql] is the SQL statement to execute.
  /// [parameters] are optional parameters to bind to the query.
  Future<QueryResult> executeQuery(String sql, [List<dynamic>? parameters]);

  /// Generates a SQL query from a natural language description.
  ///
  /// [naturalLanguageQuery] is the user's request in plain English.
  /// [context] provides additional context for the generation.
  Future<String> generateSql(String naturalLanguageQuery, {String? context});

  /// Retrieves the database schema.
  Future<DatabaseSchema> getSchema();

  /// Closes the store connection and releases resources.
  Future<void> dispose();

  /// The set of capabilities supported by this store.
  Set<StoreCaps> get caps;
}
