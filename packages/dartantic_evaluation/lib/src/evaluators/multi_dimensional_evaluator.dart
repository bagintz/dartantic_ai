import '../results/evaluation_result.dart';
import 'evaluator.dart';

/// Coordinates multiple evaluators and performs analysis like Pareto frontier identification.
class MultiDimensionalEvaluator {
  final List<Evaluator> evaluators;

  MultiDimensionalEvaluator(this.evaluators);

  /// Evaluates a single input/output pair across all configured dimensions.
  Future<EvaluationResult> evaluate(dynamic input, dynamic output) async {
    final futures = evaluators.map((e) => e.evaluate(input, output));
    final scores = await Future.wait(futures);
    return EvaluationResult(
      input: input,
      output: output,
      scores: scores,
    );
  }

  /// Identifies the Pareto frontier from a list of evaluation results.
  ///
  /// Returns the subset of results that are not dominated by any other result.
  /// A result A dominates result B if A is at least as good as B in all
  /// dimensions and strictly better in at least one.
  List<EvaluationResult> findParetoFrontier(List<EvaluationResult> results) {
    final frontier = <EvaluationResult>[];

    for (final candidate in results) {
      bool isDominated = false;
      for (final other in results) {
        if (candidate == other) continue;
        if (_dominates(other, candidate)) {
          isDominated = true;
          break;
        }
      }
      if (!isDominated) {
        frontier.add(candidate);
      }
    }
    return frontier;
  }

  /// Returns true if [a] dominates [b].
  bool _dominates(EvaluationResult a, EvaluationResult b) {
    bool strictlyBetterInOne = false;
    
    // We compare scores for the dimensions defined in this evaluator.
    // If a result is missing a score, we treat it as 0.0.
    for (final evaluator in evaluators) {
      final dim = evaluator.dimension;
      final scoreA = a.getScore(dim)?.score ?? 0.0;
      final scoreB = b.getScore(dim)?.score ?? 0.0;

      if (scoreA < scoreB) return false; // A is worse in this dimension, so it cannot dominate
      if (scoreA > scoreB) strictlyBetterInOne = true;
    }

    return strictlyBetterInOne;
  }
}
