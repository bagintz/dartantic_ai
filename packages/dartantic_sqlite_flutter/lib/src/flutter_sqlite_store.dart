import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_sqlite/dartantic_sqlite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A Flutter-specific SQLite store that automatically handles path resolution.
class FlutterSQLiteStore extends SQLiteStore {
  /// Private constructor. Use [create] to instantiate.
  FlutterSQLiteStore._(String path, {String? id, Agent? agent})
      : super(path, id: id, agent: agent);

  /// Creates and initializes a new [FlutterSQLiteStore].
  ///
  /// [name] is the name of the database file (e.g., 'app.db').
  /// The file will be stored in the application documents directory.
  static Future<FlutterSQLiteStore> create(
    String name, {
    String? id,
    Agent? agent,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, name);
    final store = FlutterSQLiteStore._(path, id: id, agent: agent);
    await store.initialize();
    return store;
  }
}
