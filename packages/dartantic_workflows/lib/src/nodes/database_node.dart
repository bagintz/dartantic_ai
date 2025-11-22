import 'dart:async';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:uuid/uuid.dart';
import '../interfaces/workflow_node.dart';
import '../state/node_context.dart';
import '../state/workflow_state.dart';

/// Node that executes a database query using a [DatabaseStore].
class DatabaseNode implements WorkflowNode {
  @override
  final String id;
  
  final DatabaseStore store;
  final String queryTemplate;
  final List<String> _dependencies;

  DatabaseNode(
    this.store, {
    required this.queryTemplate,
    String? id,
    List<String> dependencies = const [],
  }) : id = id ?? const Uuid().v4(),
       _dependencies = dependencies;

  @override
  String get type => 'database';

  @override
  String get description => 'Database Query: $queryTemplate';

  @override
  List<String> get dependencies => List.unmodifiable(_dependencies);

  @override
  bool validate() => store.caps.contains(StoreCaps.sqlDatabase);

  @override
  Stream<NodeResult> execute(NodeContext context, WorkflowState state) async* {
    try {
      final query = _resolveTemplate(queryTemplate, state);
      
      final result = await store.executeQuery(query);
      
      yield NodeResult.success(
        output: _formatResult(result),
        messages: [],
        data: {
          'rows': result.rows,
          'affectedRows': result.affectedRows,
          'columns': result.columns,
        },
        metadata: {
          'store_id': store.storeId,
          'query': query,
          'row_count': result.rows.length,
        },
      );
    } catch (e) {
      yield NodeResult.error(error: e.toString());
    }
  }

  String _resolveTemplate(String template, WorkflowState state) {
    var result = template;
    // Regex to find {variable}
    final regex = RegExp(r'\{([^}]+)\}');
    result = result.replaceAllMapped(regex, (match) {
      final key = match.group(1)!;
      // Check if key is a node ID
      final nodeResult = state.getNodeResult<String>(key);
      if (nodeResult != null) return nodeResult;
      
      // Check shared data
      final shared = state.getSharedData<String>(key);
      if (shared != null) return shared;
      
      return match.group(0)!; // Keep original if not found
    });
    
    return result;
  }

  String _formatResult(QueryResult result) {
    if (result.rows.isEmpty) {
      if (result.affectedRows != null) {
        return 'Query executed. Affected rows: ${result.affectedRows}';
      }
      return 'No results found.';
    }
    return result.rows.toString();
  }
}
