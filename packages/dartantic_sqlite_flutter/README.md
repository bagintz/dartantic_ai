# dartantic_sqlite_flutter

Flutter-specific implementation of the SQLite store for Dartantic AI.

This package provides `FlutterSQLiteStore`, which wraps the core `SQLiteStore` and automatically handles path resolution using `path_provider` and bundles the necessary native SQLite binaries via `sqlite3_flutter_libs`.

## Usage

```dart
import 'package:dartantic_sqlite_flutter/dartantic_sqlite_flutter.dart';

void main() async {
  // Create a store. The file will be created in the app's documents directory.
  final store = await FlutterSQLiteStore.create('my_app.db');
  
  // Use it as a standard DatabaseStore
  await store.executeQuery('CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT)');
}
```
