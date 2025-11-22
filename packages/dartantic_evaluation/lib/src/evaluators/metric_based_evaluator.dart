import '../results/evaluation_score.dart';
import 'evaluator.dart';

/// A function that extracts a raw numeric metric from input/output.
typedef MetricExtractor = double Function(dynamic input, dynamic output);

/// An evaluator that calculates a score based on a deterministic metric.
class MetricBasedEvaluator extends Evaluator<dynamic, dynamic> {
  final String _dimension;
  final MetricExtractor extractor;
  final double minVal;
  final double maxVal;

  /// Creates a metric-based evaluator.
  ///
  /// [dimension] is the name of the metric.
  /// [extractor] is a function that returns a raw double value.
  /// [minVal] and [maxVal] define the range for normalization to [0.0, 1.0].
  MetricBasedEvaluator(
    this._dimension,
    this.extractor, {
    this.minVal = 0.0,
    this.maxVal = 1.0,
  });

  @override
  String get dimension => _dimension;

  @override
  Future<EvaluationScore> evaluate(dynamic input, dynamic output) async {
    final rawValue = extractor(input, output);
    
    // Avoid division by zero
    double normalized;
    if (maxVal == minVal) {
      normalized = rawValue >= maxVal ? 1.0 : 0.0;
    } else {
      normalized = (rawValue - minVal) / (maxVal - minVal);
    }
    
    normalized = normalized.clamp(0.0, 1.0);

    return EvaluationScore(
      dimension: dimension,
      score: normalized,
      reasoning: 'Calculated metric value: $rawValue (normalized from range $minVal-$maxVal)',
      metadata: {'rawValue': rawValue},
    );
  }
}
