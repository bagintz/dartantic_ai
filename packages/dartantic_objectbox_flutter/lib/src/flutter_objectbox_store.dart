import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_objectbox/dartantic_objectbox.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A Flutter-specific ObjectBox store that automatically handles path resolution.
class FlutterObjectBoxStore extends ObjectBoxStore {
  /// Private constructor. Use [create] to instantiate.
  FlutterObjectBoxStore._({
    required String path,
    String? id,
    Agent? embeddingAgent,
  }) : super(path: path, id: id, embeddingAgent: embeddingAgent);

  /// Creates and initializes a new [FlutterObjectBoxStore].
  ///
  /// [name] is the name of the directory (e.g., 'objectbox').
  /// The directory will be created in the application documents directory.
  static Future<FlutterObjectBoxStore> create(
    String name, {
    String? id,
    Agent? embeddingAgent,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, name);
    final store = FlutterObjectBoxStore._(
      path: path,
      id: id,
      embeddingAgent: embeddingAgent,
    );
    await store.initialize();
    return store;
  }
}
