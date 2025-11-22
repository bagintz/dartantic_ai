import 'package:json_schema/json_schema.dart';

/// Represents the difficulty of implementing a recommendation.
enum ImplementationDifficulty {
  low,
  medium,
  high,
}

/// Represents the expected impact of a recommendation.
enum ExpectedImpact {
  low,
  medium,
  high,
}

/// A specific recommendation for improving system performance.
class ImprovementRecommendation {
  /// The name of the parameter or component to change.
  final String target;

  /// The suggested action or value.
  final String suggestion;

  /// The reasoning behind this recommendation.
  final String reasoning;

  /// Estimated difficulty to implement.
  final ImplementationDifficulty difficulty;

  /// Estimated impact on performance.
  final ExpectedImpact expectedImpact;

  /// Confidence score for this specific recommendation (0.0 to 1.0).
  final double confidence;

  ImprovementRecommendation({
    required this.target,
    required this.suggestion,
    required this.reasoning,
    this.difficulty = ImplementationDifficulty.medium,
    this.expectedImpact = ExpectedImpact.medium,
    this.confidence = 0.5,
  });

  Map<String, dynamic> toJson() {
    return {
      'target': target,
      'suggestion': suggestion,
      'reasoning': reasoning,
      'difficulty': difficulty.name,
      'expectedImpact': expectedImpact.name,
      'confidence': confidence,
    };
  }

  factory ImprovementRecommendation.fromJson(Map<String, dynamic> json) {
    return ImprovementRecommendation(
      target: json['target'] as String,
      suggestion: json['suggestion'] as String,
      reasoning: json['reasoning'] as String,
      difficulty: ImplementationDifficulty.values.firstWhere(
        (e) => e.name == json['difficulty'],
        orElse: () => ImplementationDifficulty.medium,
      ),
      expectedImpact: ExpectedImpact.values.firstWhere(
        (e) => e.name == json['expectedImpact'],
        orElse: () => ExpectedImpact.medium,
      ),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
    );
  }
  
  @override
  String toString() {
    return 'Recommendation(target: $target, suggestion: $suggestion, impact: ${expectedImpact.name})';
  }
}

/// The result of a performance diagnosis.
class PerformanceDiagnosis {
  /// A summary of the identified weaknesses.
  final String weaknessAnalysis;

  /// Identified root causes for the weaknesses.
  final List<String> rootCauses;

  /// Actionable recommendations for improvement.
  final List<ImprovementRecommendation> recommendations;

  /// Overall confidence in this diagnosis (0.0 to 1.0).
  final double overallConfidence;
  
  /// Timestamp of the diagnosis.
  final DateTime timestamp;
  
  /// Metadata about the diagnosis (e.g. which analyzer was used).
  final Map<String, dynamic> metadata;

  PerformanceDiagnosis({
    required this.weaknessAnalysis,
    required this.rootCauses,
    required this.recommendations,
    this.overallConfidence = 0.0,
    DateTime? timestamp,
    this.metadata = const {},
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'weaknessAnalysis': weaknessAnalysis,
      'rootCauses': rootCauses,
      'recommendations': recommendations.map((r) => r.toJson()).toList(),
      'overallConfidence': overallConfidence,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory PerformanceDiagnosis.fromJson(Map<String, dynamic> json) {
    return PerformanceDiagnosis(
      weaknessAnalysis: json['weaknessAnalysis'] as String,
      rootCauses: (json['rootCauses'] as List<dynamic>?)?.cast<String>() ?? [],
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((e) => ImprovementRecommendation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      overallConfidence: (json['overallConfidence'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }
  
  /// Returns a JSON schema for validating the structure of this diagnosis
  /// (Useful for LLM structured output).
  static JsonSchema get schema {
    return JsonSchema.create({
      'type': 'object',
      'properties': {
        'weaknessAnalysis': {'type': 'string', 'description': 'Detailed analysis of performance weaknesses'},
        'rootCauses': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'List of identified root causes'
        },
        'recommendations': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'target': {'type': 'string', 'description': 'Parameter or component to change'},
              'suggestion': {'type': 'string', 'description': 'Suggested value or action'},
              'reasoning': {'type': 'string', 'description': 'Why this change is recommended'},
              'difficulty': {'type': 'string', 'enum': ['low', 'medium', 'high']},
              'expectedImpact': {'type': 'string', 'enum': ['low', 'medium', 'high']},
              'confidence': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0}
            },
            'required': ['target', 'suggestion', 'reasoning', 'difficulty', 'expectedImpact', 'confidence']
          }
        },
        'overallConfidence': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0}
      },
      'required': ['weaknessAnalysis', 'rootCauses', 'recommendations', 'overallConfidence']
    });
  }
}
