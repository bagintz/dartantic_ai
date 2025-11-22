import 'dart:collection';
import '../interfaces/workflow_node.dart';
import '../interfaces/workflow_edge.dart';

/// Base class for all workflows
abstract class Workflow {
  /// Validate the workflow structure
  bool validate();
}

/// Defines a graph-based workflow with nodes and edges
class GraphWorkflow implements Workflow {
  final Map<String, WorkflowNode> _nodes = {};
  final Map<String, List<WorkflowEdge>> _edges = {};
  final String? _entryPoint;
  
  GraphWorkflow._(this._entryPoint);
  
  /// Get all nodes in the graph
  Map<String, WorkflowNode> get nodes => UnmodifiableMapView(_nodes);
  
  /// Get all edges from a node
  List<WorkflowEdge> getEdges(String nodeId) => 
      UnmodifiableListView(_edges[nodeId] ?? []);
  
  /// Get entry point node ID
  String? get entryPoint => _entryPoint;
  
  /// Get node by ID
  WorkflowNode? getNode(String id) => _nodes[id];
  
  @override
  bool validate() {
    // Check all nodes are valid
    for (final node in _nodes.values) {
      if (!node.validate()) return false;
    }
    
    // Check for cycles (if needed for DAG workflows)
    return _validateNoCycles();
  }
  
  /// Check for circular dependencies
  bool _validateNoCycles() {
    final visited = <String>{};
    final recursionStack = <String>{};
    
    for (final nodeId in _nodes.keys) {
      if (!visited.contains(nodeId)) {
        if (_hasCycleDFS(nodeId, visited, recursionStack)) {
          return false;
        }
      }
    }
    return true;
  }
  
  bool _hasCycleDFS(String nodeId, Set<String> visited, Set<String> recursionStack) {
    visited.add(nodeId);
    recursionStack.add(nodeId);
    
    for (final edge in getEdges(nodeId)) {
      final neighbor = edge.toNode;
      if (!visited.contains(neighbor)) {
        if (_hasCycleDFS(neighbor, visited, recursionStack)) {
          return true;
        }
      } else if (recursionStack.contains(neighbor)) {
        return true;
      }
    }
    
    recursionStack.remove(nodeId);
    return false;
  }
  
  /// Create a workflow graph builder
  static GraphWorkflowBuilder builder() => GraphWorkflowBuilder();
}

/// Builder for creating graph workflows
class GraphWorkflowBuilder {
  final Map<String, WorkflowNode> _nodes = {};
  final Map<String, List<WorkflowEdge>> _edges = {};
  String? _entryPoint;
  
  /// Add a node to the graph
  GraphWorkflowBuilder addNode(String id, WorkflowNode node) {
    if (_nodes.containsKey(id)) {
      throw ArgumentError('Node with id "$id" already exists');
    }
    _nodes[id] = node;
    _edges[id] = [];
    
    // First node becomes entry point by default
    _entryPoint ??= id;
    
    return this;
  }
  
  /// Add an edge between nodes
  GraphWorkflowBuilder addEdge(
    String fromId, 
    String toId, {
    EdgeCondition? condition,
    Map<String, dynamic>? metadata,
  }) {
    if (!_nodes.containsKey(fromId)) {
      throw ArgumentError('Source node "$fromId" does not exist');
    }
    if (!_nodes.containsKey(toId)) {
      throw ArgumentError('Target node "$toId" does not exist');
    }
    
    final edge = WorkflowEdge(
      fromNode: fromId,
      toNode: toId,
      condition: condition,
      metadata: metadata ?? {},
    );
    
    _edges[fromId]!.add(edge);
    return this;
  }
  
  /// Set explicit entry point
  GraphWorkflowBuilder setEntryPoint(String nodeId) {
    if (!_nodes.containsKey(nodeId)) {
      throw ArgumentError('Entry point node "$nodeId" does not exist');
    }
    _entryPoint = nodeId;
    return this;
  }
  
  /// Build the workflow graph
  GraphWorkflow build() {
    if (_nodes.isEmpty) {
      throw StateError('Cannot build empty graph');
    }
    
    final graph = GraphWorkflow._(_entryPoint);
    graph._nodes.addAll(_nodes);
    graph._edges.addAll(_edges);
    
    if (!graph.validate()) {
      throw StateError('Invalid graph structure');
    }
    
    return graph;
  }
}
