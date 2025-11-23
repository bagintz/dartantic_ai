# Dartantic Evaluation Package Specification

## Overview

`dartantic_evaluation` provides a framework for multi-dimensional performance assessment of AI workflows. It enables applications to evaluate outputs across multiple competing objectives and identify optimal trade-offs using Pareto frontier analysis.

## Core Interfaces

### EvaluationScore
```dart
class EvaluationScore {
  final double value;        // 0.0 to 1.0
  final String reasoning;    // Explanation of score
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  
  EvaluationScore({
    required this.value,
    required this.reasoning,
    DateTime? timestamp,
    this.metadata = const {},
  }) : timestamp = timestamp ?? DateTime.now();
}
```

### Evaluator Interface
```dart
abstract interface class Evaluator {
  /// Unique name for this evaluation dimension
  String get dimensionName;
  
  /// Evaluate output and return score with reasoning
  Future<EvaluationScore> evaluate(Map<String, dynamic> output);
  
  /// Optional: Validate that this evaluator can assess the given output
  bool canEvaluate(Map<String, dynamic> output) => true;
}
```

### EvaluationResult
```dart
class EvaluationResult {
  final String configurationId;
  final Map<String, EvaluationScore> scores;
  final DateTime timestamp;
  final double overallScore; // Computed aggregate score
  
  EvaluationResult({
    required this.configurationId,
    required this.scores,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now(),
       overallScore = _calculateOverallScore(scores);
       
  static double _calculateOverallScore(Map<String, EvaluationScore> scores) {
    if (scores.isEmpty) return 0.0;
    return scores.values.map((s) => s.value).reduce((a, b) => a + b) / scores.length;
  }
}
```

## Core Implementation

### MultiDimensionalEvaluator
```dart
class MultiDimensionalEvaluator {
  final Map<String, Evaluator> _evaluators;
  
  MultiDimensionalEvaluator(this._evaluators);
  
  Future<EvaluationResult> evaluate(
    String configurationId,
    Map<String, dynamic> output,
  ) async {
    final scores = <String, EvaluationScore>{};
    
    for (final entry in _evaluators.entries) {
      if (entry.value.canEvaluate(output)) {
        scores[entry.key] = await entry.value.evaluate(output);
      }
    }
    
    return EvaluationResult(
      configurationId: configurationId,
      scores: scores,
    );
  }
  
  /// Find non-dominated solutions (Pareto optimal)
  List<EvaluationResult> findParetoFront(List<EvaluationResult> results) {
    final paretoOptimal = <EvaluationResult>[];
    
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
        paretoOptimal.add(candidate);
      }
    }
    
    return paretoOptimal;
  }
  
  bool _dominates(EvaluationResult a, EvaluationResult b) {
    bool atLeastOneStrictlyBetter = false;
    
    for (final dimension in a.scores.keys) {
      final aScore = a.scores[dimension]?.value ?? 0.0;
      final bScore = b.scores[dimension]?.value ?? 0.0;
      
      if (aScore < bScore) return false; // a is worse in this dimension
      if (aScore > bScore) atLeastOneStrictlyBetter = true;
    }
    
    return atLeastOneStrictlyBetter;
  }
}
```

## Built-in Evaluator Types

### LLMJudgeEvaluator
```dart
class LLMJudgeEvaluator implements Evaluator {
  final Agent agent;
  final String prompt;
  final String dimensionName;
  
  LLMJudgeEvaluator({
    required this.agent,
    required this.prompt,
    required this.dimensionName,
  });
  
  @override
  Future<EvaluationScore> evaluate(Map<String, dynamic> output) async {
    final evaluationPrompt = '''
$prompt

Output to evaluate:
${output.toString()}

Please provide a score from 0.0 to 1.0 and explain your reasoning.
Format your response as JSON: {"score": 0.85, "reasoning": "explanation here"}
''';
    
    final result = await agent.sendFor<Map<String, dynamic>>(
      evaluationPrompt,
      outputSchema: JsonSchema.create({
        'type': 'object',
        'properties': {
          'score': {'type': 'number', 'minimum': 0, 'maximum': 1},
          'reasoning': {'type': 'string'},
        },
        'required': ['score', 'reasoning'],
      }),
      outputFromJson: (json) => json,
    );
    
    return EvaluationScore(
      value: (result.output['score'] as num).toDouble(),
      reasoning: result.output['reasoning'] as String,
    );
  }
}
```

### MetricBasedEvaluator
```dart
class MetricBasedEvaluator implements Evaluator {
  final String dimensionName;
  final double Function(Map<String, dynamic>) metricExtractor;
  final double maxValue;
  final String description;
  
  MetricBasedEvaluator({
    required this.dimensionName,
    required this.metricExtractor,
    required this.maxValue,
    required this.description,
  });
  
  @override
  Future<EvaluationScore> evaluate(Map<String, dynamic> output) async {
    final rawValue = metricExtractor(output);
    final normalizedScore = (rawValue / maxValue).clamp(0.0, 1.0);
    
    return EvaluationScore(
      value: normalizedScore,
      reasoning: '$description: $rawValue (normalized to $normalizedScore)',
    );
  }
}
```

### HumanFeedbackEvaluator
```dart
class HumanFeedbackEvaluator implements Evaluator {
  final String dimensionName;
  final Future<EvaluationScore> Function(Map<String, dynamic>) feedbackCollector;
  
  HumanFeedbackEvaluator({
    required this.dimensionName,
    required this.feedbackCollector,
  });
  
  @override
  Future<EvaluationScore> evaluate(Map<String, dynamic> output) async {
    return await feedbackCollector(output);
  }
}
```

## Usage Example

```dart
// Setup evaluators
final evaluator = MultiDimensionalEvaluator({
  'accuracy': LLMJudgeEvaluator(
    agent: Agent('anthropic'),
    prompt: 'Rate the factual accuracy of this response...',
    dimensionName: 'accuracy',
  ),
  'helpfulness': LLMJudgeEvaluator(
    agent: Agent('openai'),
    prompt: 'Rate how helpful this response is...',
    dimensionName: 'helpfulness',
  ),
  'response_time': MetricBasedEvaluator(
    dimensionName: 'response_time',
    metricExtractor: (output) => 1.0 / (output['duration_ms'] as int),
    maxValue: 1.0,
    description: 'Response speed score',
  ),
});

// Evaluate multiple configurations
final results = <EvaluationResult>[];
for (final config in configurations) {
  final output = await runConfiguration(config);
  final evaluation = await evaluator.evaluate(config.id, output);
  results.add(evaluation);
}

// Find optimal trade-offs
final paretoOptimal = evaluator.findParetoFront(results);
```

## Package Dependencies

```yaml
name: dartantic_evaluation
dependencies:
  dartantic_ai: ^VERSION
  dartantic_interface: ^VERSION
  json_schema: ^VERSION
  logging: ^VERSION
```

This package provides the foundation for sophisticated performance assessment that can be customized for any domain while maintaining consistent interfaces and Pareto optimization capabilities.