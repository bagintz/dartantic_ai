import '../results/evaluation_score.dart';
import 'evaluator.dart';

/// A callback that retrieves a score from a human (or external system) asynchronously.
typedef HumanFeedbackCallback = Future<double> Function(dynamic input, dynamic output);

/// An evaluator that delegates assessment to a human via a callback.
class HumanFeedbackEvaluator extends Evaluator<dynamic, dynamic> {
  final String _dimension;
  final HumanFeedbackCallback callback;
  final String? description;

  /// Creates a human feedback evaluator.
  ///
  /// [dimension] is the name of the metric.
  /// [callback] is the async function that will obtain the score.
  /// [description] is optional text describing what the human should evaluate.
  HumanFeedbackEvaluator(this._dimension, this.callback, {this.description});

  @override
  String get dimension => _dimension;

  @override
  Future<EvaluationScore> evaluate(dynamic input, dynamic output) async {
    final score = await callback(input, output);
    return EvaluationScore(
      dimension: dimension,
      score: score.clamp(0.0, 1.0),
      reasoning: 'Human provided score',
      metadata: {'description': description},
    );
  }
}
