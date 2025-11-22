import 'dart:async';
import '../results/workflow_result.dart';
import '../workflows/workflow.dart';
import '../state/workflow_state.dart';

/// Core interface for workflow execution engines
abstract interface class WorkflowEngine {
  /// Hint for engine identification and selection (e.g. 'graph', 'sequential')
  String get engineType;
  
  /// Initialize the workflow engine with shared state
  void initialize(WorkflowState state);
  
  /// Execute the workflow
  Stream<WorkflowResult> execute(
    Workflow workflow,
    WorkflowState state,
  );
  
  /// Finalize after workflow execution completes  
  void finalize(WorkflowState state);
}
