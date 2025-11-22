import 'package:dartantic_evaluation/dartantic_evaluation.dart';
import '../models/diagnosis_models.dart';

/// Abstract interface for performance analysis.
abstract class PerformanceDiagnostician {
  /// Diagnoses performance based on a history of evaluation results.
  ///
  /// [history] is a list of evaluation results to analyze.
  /// [context] provides additional context for the diagnosis (e.g. system configuration).
  Future<PerformanceDiagnosis> diagnose(
    List<EvaluationResult> history, {
    Map<String, dynamic> context = const {},
  });
}
