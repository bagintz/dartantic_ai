# dartantic_objectbox_flutter

Flutter-specific implementation of the ObjectBox vector store for Dartantic AI.

This package provides `FlutterObjectBoxStore`, which wraps the core `ObjectBoxStore` and automatically handles path resolution using `path_provider` and bundles the necessary native ObjectBox binaries via `objectbox_flutter_libs`.

## Usage

```dart
import 'package:dartantic_objectbox_flutter/dartantic_objectbox_flutter.dart';

void main() async {
  // Create a store. The directory will be created in the app's documents directory.
  final store = await FlutterObjectBoxStore.create('my_vector_store');
  
  // Use it as a standard VectorStore
  await store.storeDocuments([
    Document(content: 'Hello world', metadata: {'source': 'example'}),
  ]);
}
```
