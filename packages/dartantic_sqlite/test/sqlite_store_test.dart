import 'dart:io';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:dartantic_sqlite/dartantic_sqlite.dart';
import 'package:test/test.dart';

void main() {
  group('SQLiteStore', () {
    late SQLiteStore store;
    final dbPath = 'test_db.sqlite';

    setUp(() async {
      store = SQLiteStore(dbPath);
      await store.initialize();
    });

    tearDown(() async {
      await store.dispose();
      final file = File(dbPath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    test('initializes correctly', () {
      expect(store.storeId, isNotEmpty);
      expect(store.caps, contains(StoreCaps.sqlDatabase));
    });

    test('executes queries', () async {
      // Create table
      await store.executeQuery(
        'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)'
      );

      // Insert
      await store.executeQuery(
        'INSERT INTO users (name) VALUES (?)',
        ['Alice']
      );

      // Select
      final result = await store.executeQuery('SELECT * FROM users');
      expect(result.rows.length, 1);
      expect(result.rows.first['name'], 'Alice');
    });

    test('gets schema', () async {
      await store.executeQuery(
        'CREATE TABLE products (id INTEGER PRIMARY KEY, title TEXT)'
      );

      final schema = await store.getSchema();
      expect(schema.tables, contains('products'));
      expect(schema.tables!['products'], contains('title'));
    });
  });
}
