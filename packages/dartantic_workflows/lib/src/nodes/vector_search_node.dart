import 'dart:async';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:uuid/uuid.dart';
import '../interfaces/workflow_node.dart';
import '../state/node_context.dart';
import '../state/workflow_state.dart';

/// Node that executes a vector similarity search using a [VectorStore].
class VectorSearchNode implements WorkflowNode {
  @override
  final String id;
  
  final VectorStore store;
  final String queryTemplate;
  final int maxResults;
  final double threshold;
  final List<String> _dependencies;

  VectorSearchNode(
    this.store, {
    required this.queryTemplate,
    this.maxResults = 5,
    this.threshold = 0.7,
    String? id,
    List<String> dependencies = const [],
  }) : id = id ?? const Uuid().v4(),
       _dependencies = dependencies;

  @override
  String get type => 'vector_search';

  @override
  String get description => 'Vector Search: $queryTemplate';

  @override
  List<String> get dependencies => List.unmodifiable(_dependencies);

  @override
  bool validate() => store.caps.contains(StoreCaps.vectorStorage);

  @override
  Stream<NodeResult> execute(NodeContext context, WorkflowState state) async* {
    try {
      final query = _resolveTemplate(queryTemplate, state);
      
      final results = await store.similaritySearch(
        query, 
        limit: maxResults, 
        threshold: threshold
      );
      
      yield NodeResult.success(
        output: _formatResult(results),
        messages: [],
        data: {
          'results': results.map((r) => {
            'content': r.document.content,
            'score': r.score,
            'metadata': r.document.metadata,
            'id': r.document.id,
          }).toList(),
        },
        metadata: {
          'store_id': store.storeId,
          'query': query,
          'result_count': results.length,
        },
      );
    } catch (e) {
      yield NodeResult.error(error: e.toString());
    }
  }

  String _resolveTemplate(String template, WorkflowState state) {
    var result = template;
    final regex = RegExp(r'\{([^}]+)\}');
    result = result.replaceAllMapped(regex, (match) {
      final key = match.group(1)!;
      final nodeResult = state.getNodeResult<String>(key);
      if (nodeResult != null) return nodeResult;
      final shared = state.getSharedData<String>(key);
      if (shared != null) return shared;
      return match.group(0)!;
    });
    return result;
  }

  String _formatResult(List<SearchResult> results) {
    if (results.isEmpty) return 'No matching documents found.';
    final buffer = StringBuffer();
    for (final result in results) {
      buffer.writeln('--- Document (Score: ${result.score.toStringAsFixed(3)}) ---');
      buffer.writeln(result.document.content);
      buffer.writeln();
    }
    return buffer.toString();
  }
}
