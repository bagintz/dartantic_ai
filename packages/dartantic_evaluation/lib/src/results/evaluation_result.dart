import 'package:collection/collection.dart';
import 'evaluation_score.dart';

/// Container for multi-dimensional evaluation scores.
class EvaluationResult {
  /// The input that was evaluated.
  final dynamic input;

  /// The output that was evaluated.
  final dynamic output;

  /// The list of scores for each dimension.
  final List<EvaluationScore> scores;

  /// Additional metadata for the overall result.
  final Map<String, dynamic> metadata;

  EvaluationResult({
    required this.input,
    required this.output,
    required this.scores,
    this.metadata = const {},
  });

  /// Computes the overall score as the average of all dimension scores.
  double get overallScore {
    if (scores.isEmpty) return 0.0;
    return scores.map((s) => s.score).average;
  }

  /// Retrieves a score by dimension name.
  EvaluationScore? getScore(String dimension) {
    return scores.firstWhereOrNull((s) => s.dimension == dimension);
  }

  @override
  String toString() {
    return 'EvaluationResult(overallScore: ${overallScore.toStringAsFixed(2)}, scores: $scores)';
  }

  Map<String, dynamic> toJson() {
    return {
      'input': input.toString(),
      'output': output.toString(),
      'overallScore': overallScore,
      'scores': scores.map((s) => s.toJson()).toList(),
      'metadata': metadata,
    };
  }
}
