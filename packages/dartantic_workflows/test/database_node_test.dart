import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:dartantic_workflows/dartantic_workflows.dart';
import 'package:test/test.dart';

class MockDatabaseStore implements DatabaseStore {
  @override
  String get storeId => 'mock_db';

  @override
  Set<StoreCaps> get caps => {StoreCaps.sqlDatabase};

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<QueryResult> executeQuery(String sql, [List? parameters]) async {
    if (sql.contains('users')) {
      return QueryResult(rows: [
        {'id': 1, 'name': 'Bob'}
      ]);
    }
    return QueryResult(rows: []);
  }

  @override
  Future<String> generateSql(String naturalLanguageQuery, {String? context}) async {
    return 'SELECT * FROM users';
  }

  @override
  Future<DatabaseSchema> getSchema() async {
    return DatabaseSchema(rawSchema: '');
  }
}

void main() {
  group('DatabaseNode', () {
    late MockDatabaseStore store;
    late DatabaseNode node;

    setUp(() {
      store = MockDatabaseStore();
      node = DatabaseNode(store, queryTemplate: 'SELECT * FROM users WHERE id = {userId}');
    });

    test('validates correctly', () {
      expect(node.validate(), isTrue);
    });

    test('executes and resolves template', () async {
      final state = WorkflowState(
        conversationHistory: [],
        toolMap: {},
      );
      state.setSharedData('userId', '1');
      
      final context = NodeContext(
        nodeId: node.id,
        conversationHistory: [],
        sharedData: state.sharedData,
      );

      final results = await node.execute(context, state).toList();
      expect(results.length, 1);
      expect(results.first.isSuccess, isTrue);
      expect(results.first.data['rows'], isNotEmpty);
      expect(results.first.data['rows'][0]['name'], 'Bob');
      expect(results.first.metadata['query'], 'SELECT * FROM users WHERE id = 1');
    });
  });
}
