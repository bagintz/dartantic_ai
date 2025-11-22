import 'package:dartantic_interface/dartantic_interface.dart';

/// Context passed to a node during execution
class NodeContext {
  final String nodeId;
  final List<ChatMessage> conversationHistory;
  final Map<String, dynamic> sharedData;
  
  const NodeContext({
    required this.nodeId,
    required this.conversationHistory,
    required this.sharedData,
  });
}
