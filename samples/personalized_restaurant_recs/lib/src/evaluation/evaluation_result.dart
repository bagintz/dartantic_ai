/// Result of evaluating a restaurant analysis against multiple dimensions
class EvaluationResult {
  EvaluationResult({
    required this.sopId,
    required this.accuracy,
    required this.completeness,
    required this.helpfulness,
    required this.conciseness,
    required this.dataGrounded,
    required this.personalization,
  });

  final String sopId;

  // LLM-judged dimensions (0.0 to 1.0)
  final double accuracy; // Claims supported by reviews
  final double completeness; // Covers all aspects
  final double helpfulness; // Aids decision-making

  // Programmatic dimensions (0.0 to 1.0)
  final double conciseness; // Information density
  final double dataGrounded; // Specific examples/statistics
  final double personalization; // Matches user persona

  /// Overall score (average of all dimensions)
  double get overallScore {
    return (accuracy +
            completeness +
            helpfulness +
            conciseness +
            dataGrounded +
            personalization) /
        6.0;
  }

  /// Performance vector for Pareto optimization
  List<double> get performanceVector => [
        accuracy,
        completeness,
        helpfulness,
        conciseness,
        dataGrounded,
        personalization,
      ];

  /// Check if this result dominates another (better on all dimensions)
  bool dominates(EvaluationResult other) {
    var betterOnAny = false;
    for (var i = 0; i < performanceVector.length; i++) {
      if (performanceVector[i] < other.performanceVector[i]) {
        return false; // Worse on this dimension
      }
      if (performanceVector[i] > other.performanceVector[i]) {
        betterOnAny = true;
      }
    }
    return betterOnAny;
  }

  Map<String, dynamic> toJson() {
    return {
      'sop_id': sopId,
      'accuracy': accuracy,
      'completeness': completeness,
      'helpfulness': helpfulness,
      'conciseness': conciseness,
      'data_grounded': dataGrounded,
      'personalization': personalization,
      'overall_score': overallScore,
    };
  }

  @override
  String toString() {
    return 'EvaluationResult('
        'overall: ${overallScore.toStringAsFixed(3)}, '
        'acc: ${accuracy.toStringAsFixed(2)}, '
        'comp: ${completeness.toStringAsFixed(2)}, '
        'help: ${helpfulness.toStringAsFixed(2)}, '
        'conc: ${conciseness.toStringAsFixed(2)}, '
        'data: ${dataGrounded.toStringAsFixed(2)}, '
        'pers: ${personalization.toStringAsFixed(2)})';
  }
}
