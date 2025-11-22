import 'dart:io';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:logging/logging.dart';

/// A SQLite implementation of [DatabaseStore].
class SQLiteStore implements DatabaseStore {
  final String _path;
  final String _id;
  Database? _db;
  final Logger _logger = Logger('SQLiteStore');

  SQLiteStore(this._path, {String? id}) : _id = id ?? 'sqlite_${DateTime.now().millisecondsSinceEpoch}';

  @override
  String get storeId => _id;

  @override
  Set<StoreCaps> get caps => {
        StoreCaps.sqlDatabase,
        StoreCaps.batchOperations,
        // Add naturalLanguageToSql if an agent is provided (future implementation)
      };

  @override
  Future<void> initialize() async {
    _logger.info('Initializing SQLite store at $_path');
    try {
      // Ensure directory exists
      final file = File(_path);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      _db = sqlite3.open(_path);
      _logger.info('SQLite store initialized successfully');
    } catch (e) {
      _logger.severe('Failed to initialize SQLite store', e);
      rethrow;
    }
  }

  @override
  Future<QueryResult> executeQuery(String sql, [List<dynamic>? parameters]) async {
    if (_db == null) {
      throw StateError('Store not initialized. Call initialize() first.');
    }

    try {
      final stmt = _db!.prepare(sql);
      try {
        final result = stmt.select(parameters ?? []);
        
        // Convert ResultSet to List<Map<String, dynamic>>
        final rows = result.map((row) {
          final map = <String, dynamic>{};
          for (var i = 0; i < result.columnNames.length; i++) {
            map[result.columnNames[i]] = row[i];
          }
          return map;
        }).toList();

        return QueryResult(
          rows: rows,
          columns: result.columnNames,
          // sqlite3 package doesn't easily give affected rows for select, 
          // but for execute/update it might be different. 
          // For now we assume select-like behavior for this method signature 
          // or we'd need to check if it's a select or execute.
          // The interface implies a generic execute.
        );
      } finally {
        stmt.dispose();
      }
    } catch (e) {
      // If it's not a select, try execute
      try {
        _db!.execute(sql, parameters ?? []);
        return QueryResult(
          rows: [],
          affectedRows: _db!.updatedRows,
        );
      } catch (e2) {
        _logger.warning('Query execution failed: $sql', e2);
        rethrow;
      }
    }
  }

  @override
  Future<String> generateSql(String naturalLanguageQuery, {String? context}) async {
    // TODO: Implement using an Agent if provided
    throw UnimplementedError('Natural language to SQL generation not yet implemented');
  }

  @override
  Future<DatabaseSchema> getSchema() async {
    if (_db == null) {
      throw StateError('Store not initialized. Call initialize() first.');
    }

    final tablesResult = _db!.select("SELECT name, sql FROM sqlite_master WHERE type='table'");
    final rawSchemaBuffer = StringBuffer();
    final tables = <String, List<String>>{};

    for (final row in tablesResult) {
      final tableName = row['name'] as String;
      final sql = row['sql'] as String?;
      
      if (sql != null) {
        rawSchemaBuffer.writeln(sql);
        rawSchemaBuffer.writeln(';');
      }

      // Get columns for table
      final columnsResult = _db!.select("PRAGMA table_info($tableName)");
      final columns = columnsResult.map((c) => c['name'] as String).toList();
      tables[tableName] = columns;
    }

    return DatabaseSchema(
      rawSchema: rawSchemaBuffer.toString(),
      tables: tables,
    );
  }

  @override
  Future<void> dispose() async {
    _db?.dispose();
    _db = null;
    _logger.info('SQLite store disposed');
  }
}
