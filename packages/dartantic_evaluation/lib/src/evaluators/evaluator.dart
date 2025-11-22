import '../results/evaluation_score.dart';

/// Abstract interface for dimension-specific assessment.
abstract class Evaluator<TInput, TOutput> {
  /// The name of the dimension this evaluator assesses.
  String get dimension;

  /// Evaluates the given [output] based on the [input].
  ///
  /// Returns an [EvaluationScore] representing the assessment.
  Future<EvaluationScore> evaluate(TInput input, TOutput output);
}
