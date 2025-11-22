import 'package:dartantic_ai/dartantic_ai.dart';
import 'dart:collection';
import 'package:collection/collection.dart';

/// Record of node execution
class NodeExecution {
  final String nodeId;
  final DateTime startTime;
  final DateTime endTime;
  final bool success;
  final String? error;
  final Map<String, dynamic> metadata;
  
  const NodeExecution({
    required this.nodeId,
    required this.startTime,
    required this.endTime,
    required this.success,
    this.error,
    this.metadata = const {},
  });
  
  Duration get duration => endTime.difference(startTime);
}

/// Extended state for multi-agent graph workflows
class GraphState extends StreamingState {
  GraphState({
    required super.conversationHistory,
    required super.toolMap,
  });

  /// Shared data accessible by all nodes
  final Map<String, dynamic> _sharedData = {};
  
  /// Node execution history
  final List<NodeExecution> _executionHistory = [];
  
  /// Results from completed nodes
  final Map<String, dynamic> _nodeResults = {};
  
  /// Currently executing nodes
  final Set<String> _runningNodes = {};
  
  /// Failed node IDs
  final Set<String> _failedNodes = {};
  
  // Public accessors
  Map<String, dynamic> get sharedData => UnmodifiableMapView(_sharedData);
  List<NodeExecution> get executionHistory => UnmodifiableListView(_executionHistory);
  Set<String> get runningNodes => UnmodifiableSetView(_runningNodes);
  Set<String> get failedNodes => UnmodifiableSetView(_failedNodes);
  
  /// Add shared data accessible by all nodes
  void setSharedData(String key, dynamic value) {
    _sharedData[key] = value;
  }
  
  /// Get shared data
  T? getSharedData<T>(String key) => _sharedData[key] as T?;
  
  /// Add result from a completed node
  void addNodeResult(String nodeId, dynamic result) {
    _nodeResults[nodeId] = result;
    _runningNodes.remove(nodeId);
  }
  
  /// Get result from a specific node
  T? getNodeResult<T>(String nodeId) => _nodeResults[nodeId] as T?;
  
  /// Check if node has been executed successfully
  bool hasNodeExecuted(String nodeId) => _nodeResults.containsKey(nodeId);
  
  /// Check if node is currently running
  bool isNodeRunning(String nodeId) => _runningNodes.contains(nodeId);
  
  /// Check if node has failed
  bool hasNodeFailed(String nodeId) => _failedNodes.contains(nodeId);
  
  /// Mark node as started
  void markNodeStarted(String nodeId) {
    _runningNodes.add(nodeId);
  }
  
  /// Mark node as failed
  void markNodeFailed(String nodeId, String error) {
    _runningNodes.remove(nodeId);
    _failedNodes.add(nodeId);
    _executionHistory.add(NodeExecution(
      nodeId: nodeId,
      startTime: DateTime.now(),
      endTime: DateTime.now(),
      success: false,
      error: error,
    ));
  }
  
  /// Record successful node execution
  void recordNodeExecution(String nodeId, Duration duration, {Map<String, dynamic>? metadata}) {
    _executionHistory.add(NodeExecution(
      nodeId: nodeId,
      startTime: DateTime.now().subtract(duration),
      endTime: DateTime.now(),
      success: true,
      metadata: metadata ?? {},
    ));
  }
}
