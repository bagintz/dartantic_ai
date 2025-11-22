import 'package:dartantic_evaluation/dartantic_evaluation.dart';
import 'package:dartantic_diagnosis/dartantic_diagnosis.dart';
import 'package:dartantic_evolution/dartantic_evolution.dart';

/// Represents the outcome of a single evolution cycle.
class EvolutionCycleResult<T extends EvolvableConfiguration<T>> {
  /// The cycle number (1-based).
  final int cycleNumber;

  /// The configuration used at the start of this cycle.
  final T initialConfiguration;

  /// The evaluation result of the initial configuration.
  final EvaluationResult evaluation;

  /// The diagnosis derived from the evaluation.
  final PerformanceDiagnosis? diagnosis;

  /// The new configuration produced by evolution (if any).
  final T? evolvedConfiguration;

  /// The improvement achieved in this cycle (positive means better).
  final double improvement;

  /// Whether this cycle resulted in a better configuration.
  final bool successful;

  /// Duration of this cycle.
  final Duration duration;

  /// Timestamp when the cycle completed.
  final DateTime timestamp;

  /// Additional metadata or logs.
  final Map<String, dynamic> metadata;

  EvolutionCycleResult({
    required this.cycleNumber,
    required this.initialConfiguration,
    required this.evaluation,
    this.diagnosis,
    this.evolvedConfiguration,
    required this.improvement,
    required this.successful,
    required this.duration,
    DateTime? timestamp,
    this.metadata = const {},
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'Cycle $cycleNumber: ${successful ? "Success" : "No Improvement"} (Improvement: ${improvement.toStringAsFixed(4)})';
  }
}
