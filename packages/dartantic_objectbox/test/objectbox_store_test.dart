import 'dart:io';
import 'package:test/test.dart';
import 'package:dartantic_objectbox/dartantic_objectbox.dart';
import 'package:dartantic_interface/dartantic_interface.dart';

void main() {
  // These tests require objectbox.g.dart to be generated
  // Run: dart run build_runner build
  
  group('ObjectBoxStore', () {
    late ObjectBoxStore store;
    final dbPath = 'test_objectbox';

    setUp(() async {
      final dir = Directory(dbPath);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      
      store = ObjectBoxStore(path: dbPath);
      await store.initialize();
    });

    tearDown(() async {
      await store.dispose();
      final dir = Directory(dbPath);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('initializes correctly', () {
      expect(store.storeId, isNotEmpty);
      expect(store.caps, contains(StoreCaps.vectorStorage));
    });
  });
}
