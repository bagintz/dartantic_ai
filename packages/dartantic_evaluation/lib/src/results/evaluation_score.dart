/// Represents a score for a single dimension of evaluation.
class EvaluationScore {
  /// The name of the dimension being evaluated (e.g., "coherence", "accuracy").
  final String dimension;

  /// The numerical score, typically between 0.0 and 1.0.
  final double score;

  /// Explanation or reasoning for the assigned score.
  final String? reasoning;

  /// Additional metadata associated with the evaluation.
  final Map<String, dynamic> metadata;

  const EvaluationScore({
    required this.dimension,
    required this.score,
    this.reasoning,
    this.metadata = const {},
  });

  /// Returns true if the score is considered "passing" based on a threshold.
  bool isPassing(double threshold) => score >= threshold;

  @override
  String toString() {
    return 'EvaluationScore(dimension: $dimension, score: $score, reasoning: $reasoning)';
  }

  Map<String, dynamic> toJson() {
    return {
      'dimension': dimension,
      'score': score,
      'reasoning': reasoning,
      'metadata': metadata,
    };
  }
}
