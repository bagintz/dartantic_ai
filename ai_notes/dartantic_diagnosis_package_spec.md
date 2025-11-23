# Dartantic Diagnosis Package Specification

## Overview

`dartantic_diagnosis` provides performance analysis and weakness identification patterns for AI systems. It enables automated root cause analysis and generates targeted improvement recommendations based on performance data patterns.

## Core Interfaces

### PerformanceDiagnosis
```dart
class PerformanceDiagnosis {
  final String primaryWeakness;
  final String rootCauseAnalysis;
  final List<ImprovementRecommendation> recommendations;
  final double confidenceScore;
  final DateTime timestamp;
  final Map<String, dynamic> supportingEvidence;
  
  PerformanceDiagnosis({
    required this.primaryWeakness,
    required this.rootCauseAnalysis,
    required this.recommendations,
    required this.confidenceScore,
    DateTime? timestamp,
    this.supportingEvidence = const {},
  }) : timestamp = timestamp ?? DateTime.now();
}
```

### ImprovementRecommendation
```dart
class ImprovementRecommendation {
  final String parameterToModify;
  final RecommendationAction action;
  final dynamic suggestedValue;
  final String reasoning;
  final double expectedImprovement;
  final double implementationDifficulty;
  
  ImprovementRecommendation({
    required this.parameterToModify,
    required this.action,
    this.suggestedValue,
    required this.reasoning,
    required this.expectedImprovement,
    required this.implementationDifficulty,
  });
}

enum RecommendationAction {
  increase,
  decrease,
  replace,
  remove,
  add,
  restructure,
}
```

### PerformanceDiagnostician Interface
```dart
abstract interface class PerformanceDiagnostician {
  /// Analyze performance trends and identify weaknesses
  Future<PerformanceDiagnosis> analyzeWeaknesses(
    List<EvaluationResult> performanceHistory,
    EvolvableConfiguration currentConfig,
  );
  
  /// Get insight into specific performance dimension
  Future<String> explainPerformancePattern(
    String dimension,
    List<double> scoreHistory,
  );
  
  /// Suggest targeted improvements for identified weaknesses
  Future<List<ImprovementRecommendation>> generateRecommendations(
    PerformanceDiagnosis diagnosis,
    EvolvableConfiguration config,
  );
}
```

## Core Implementation

### LLMDiagnostician
```dart
class LLMDiagnostician implements PerformanceDiagnostician {
  final Agent diagnosticAgent;
  final String systemPrompt;
  final DiagnosisPromptTemplate promptTemplate;
  
  LLMDiagnostician({
    required this.diagnosticAgent,
    String? systemPrompt,
    DiagnosisPromptTemplate? promptTemplate,
  }) : systemPrompt = systemPrompt ?? _defaultSystemPrompt,
       promptTemplate = promptTemplate ?? DiagnosisPromptTemplate.standard();
  
  static const String _defaultSystemPrompt = '''
You are a performance analysis expert that identifies weaknesses in AI system configurations 
and provides actionable improvement recommendations. Analyze performance data objectively 
and focus on root causes rather than symptoms.
''';
  
  @override
  Future<PerformanceDiagnosis> analyzeWeaknesses(
    List<EvaluationResult> performanceHistory,
    EvolvableConfiguration currentConfig,
  ) async {
    final prompt = promptTemplate.buildDiagnosisPrompt(
      performanceHistory,
      currentConfig,
    );
    
    final result = await diagnosticAgent.sendFor<Map<String, dynamic>>(
      prompt,
      outputSchema: JsonSchema.create({
        'type': 'object',
        'properties': {
          'primary_weakness': {'type': 'string'},
          'root_cause_analysis': {'type': 'string'},
          'confidence_score': {'type': 'number', 'minimum': 0, 'maximum': 1},
          'supporting_evidence': {'type': 'object'},
          'recommendations': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'parameter': {'type': 'string'},
                'action': {'type': 'string', 'enum': ['increase', 'decrease', 'replace', 'remove', 'add']},
                'suggested_value': {},
                'reasoning': {'type': 'string'},
                'expected_improvement': {'type': 'number', 'minimum': 0, 'maximum': 1},
                'implementation_difficulty': {'type': 'number', 'minimum': 0, 'maximum': 1},
              },
              'required': ['parameter', 'action', 'reasoning', 'expected_improvement', 'implementation_difficulty'],
            },
          },
        },
        'required': ['primary_weakness', 'root_cause_analysis', 'confidence_score', 'recommendations'],
      }),
      outputFromJson: (json) => json,
      history: [ChatMessage.system(systemPrompt)],
    );
    
    final recommendations = (result.output['recommendations'] as List)
        .map((r) => ImprovementRecommendation(
              parameterToModify: r['parameter'] as String,
              action: RecommendationAction.values.byName(r['action'] as String),
              suggestedValue: r['suggested_value'],
              reasoning: r['reasoning'] as String,
              expectedImprovement: (r['expected_improvement'] as num).toDouble(),
              implementationDifficulty: (r['implementation_difficulty'] as num).toDouble(),
            ))
        .toList();
    
    return PerformanceDiagnosis(
      primaryWeakness: result.output['primary_weakness'] as String,
      rootCauseAnalysis: result.output['root_cause_analysis'] as String,
      recommendations: recommendations,
      confidenceScore: (result.output['confidence_score'] as num).toDouble(),
      supportingEvidence: result.output['supporting_evidence'] as Map<String, dynamic>? ?? {},
    );
  }
  
  @override
  Future<String> explainPerformancePattern(
    String dimension,
    List<double> scoreHistory,
  ) async {
    final prompt = promptTemplate.buildPatternExplanationPrompt(dimension, scoreHistory);
    final result = await diagnosticAgent.send(prompt);
    return result.output;
  }
  
  @override
  Future<List<ImprovementRecommendation>> generateRecommendations(
    PerformanceDiagnosis diagnosis,
    EvolvableConfiguration config,
  ) async {
    // This could generate additional recommendations based on the diagnosis
    // For now, return the recommendations from the diagnosis
    return diagnosis.recommendations;
  }
}
```

### StatisticalDiagnostician
```dart
class StatisticalDiagnostician implements PerformanceDiagnostician {
  final Map<String, StatisticalAnalyzer> analyzers;
  
  StatisticalDiagnostician({Map<String, StatisticalAnalyzer>? analyzers})
      : analyzers = analyzers ?? _defaultAnalyzers();
  
  static Map<String, StatisticalAnalyzer> _defaultAnalyzers() => {
    'trend': TrendAnalyzer(),
    'correlation': CorrelationAnalyzer(),
    'outlier': OutlierAnalyzer(),
    'variance': VarianceAnalyzer(),
  };
  
  @override
  Future<PerformanceDiagnosis> analyzeWeaknesses(
    List<EvaluationResult> performanceHistory,
    EvolvableConfiguration currentConfig,
  ) async {
    if (performanceHistory.length < 3) {
      return PerformanceDiagnosis(
        primaryWeakness: 'insufficient_data',
        rootCauseAnalysis: 'Need more performance history for statistical analysis',
        recommendations: [],
        confidenceScore: 0.1,
      );
    }
    
    final analyses = <String, AnalysisResult>{};
    
    // Run each statistical analyzer
    for (final entry in analyzers.entries) {
      analyses[entry.key] = await entry.value.analyze(performanceHistory, currentConfig);
    }
    
    // Find the most significant issue
    final primaryIssue = analyses.values
        .where((a) => a.severity > 0.5)
        .reduce((a, b) => a.severity > b.severity ? a : b);
    
    final recommendations = _generateStatisticalRecommendations(analyses, currentConfig);
    
    return PerformanceDiagnosis(
      primaryWeakness: primaryIssue.dimension,
      rootCauseAnalysis: primaryIssue.explanation,
      recommendations: recommendations,
      confidenceScore: primaryIssue.confidence,
      supportingEvidence: {
        'analyses': analyses.map((k, v) => MapEntry(k, v.toMap())),
      },
    );
  }
  
  List<ImprovementRecommendation> _generateStatisticalRecommendations(
    Map<String, AnalysisResult> analyses,
    EvolvableConfiguration config,
  ) {
    final recommendations = <ImprovementRecommendation>[];
    
    for (final analysis in analyses.values) {
      if (analysis.severity > 0.3) {
        recommendations.addAll(analysis.recommendations);
      }
    }
    
    return recommendations;
  }
  
  @override
  Future<String> explainPerformancePattern(
    String dimension,
    List<double> scoreHistory,
  ) async {
    final analyzer = TrendAnalyzer();
    final trend = analyzer.calculateTrend(scoreHistory);
    
    if (trend > 0.1) return 'Improving trend detected';
    if (trend < -0.1) return 'Declining trend detected';
    return 'Stable performance pattern';
  }
  
  @override
  Future<List<ImprovementRecommendation>> generateRecommendations(
    PerformanceDiagnosis diagnosis,
    EvolvableConfiguration config,
  ) async {
    return diagnosis.recommendations;
  }
}
```

## Statistical Analyzers

### Statistical Analyzer Interface
```dart
abstract interface class StatisticalAnalyzer {
  Future<AnalysisResult> analyze(
    List<EvaluationResult> performanceHistory,
    EvolvableConfiguration currentConfig,
  );
}

class AnalysisResult {
  final String dimension;
  final double severity;
  final double confidence;
  final String explanation;
  final List<ImprovementRecommendation> recommendations;
  
  AnalysisResult({
    required this.dimension,
    required this.severity,
    required this.confidence,
    required this.explanation,
    required this.recommendations,
  });
  
  Map<String, dynamic> toMap() => {
    'dimension': dimension,
    'severity': severity,
    'confidence': confidence,
    'explanation': explanation,
    'recommendations': recommendations.length,
  };
}
```

### TrendAnalyzer
```dart
class TrendAnalyzer implements StatisticalAnalyzer {
  @override
  Future<AnalysisResult> analyze(
    List<EvaluationResult> performanceHistory,
    EvolvableConfiguration currentConfig,
  ) async {
    final recommendations = <ImprovementRecommendation>[];
    
    // Analyze trends for each performance dimension
    final dimensionTrends = <String, double>{};
    if (performanceHistory.isNotEmpty) {
      final firstResult = performanceHistory.first;
      for (final dimension in firstResult.scores.keys) {
        final scores = performanceHistory
            .map((result) => result.scores[dimension]?.value ?? 0.0)
            .toList();
        dimensionTrends[dimension] = calculateTrend(scores);
      }
    }
    
    // Find the dimension with the worst declining trend
    final worstTrend = dimensionTrends.entries
        .reduce((a, b) => a.value < b.value ? a : b);
    
    if (worstTrend.value < -0.1) {
      recommendations.add(ImprovementRecommendation(
        parameterToModify: 'focus_${worstTrend.key}',
        action: RecommendationAction.increase,
        reasoning: 'Declining performance in ${worstTrend.key} (trend: ${worstTrend.value.toStringAsFixed(3)})',
        expectedImprovement: 0.3,
        implementationDifficulty: 0.2,
      ));
    }
    
    return AnalysisResult(
      dimension: worstTrend.key,
      severity: (-worstTrend.value).clamp(0.0, 1.0),
      confidence: 0.8,
      explanation: 'Performance trend analysis shows declining pattern in ${worstTrend.key}',
      recommendations: recommendations,
    );
  }
  
  double calculateTrend(List<double> scores) {
    if (scores.length < 2) return 0.0;
    
    // Simple linear regression slope
    final n = scores.length;
    final sumX = List.generate(n, (i) => i).reduce((a, b) => a + b);
    final sumY = scores.reduce((a, b) => a + b);
    final sumXY = List.generate(n, (i) => i * scores[i]).reduce((a, b) => a + b);
    final sumX2 = List.generate(n, (i) => i * i).reduce((a, b) => a + b);
    
    return (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
  }
}
```

## Prompt Templates

### DiagnosisPromptTemplate
```dart
class DiagnosisPromptTemplate {
  final String diagnosisTemplate;
  final String patternTemplate;
  
  DiagnosisPromptTemplate({
    required this.diagnosisTemplate,
    required this.patternTemplate,
  });
  
  factory DiagnosisPromptTemplate.standard() => DiagnosisPromptTemplate(
    diagnosisTemplate: _standardDiagnosisTemplate,
    patternTemplate: _standardPatternTemplate,
  );
  
  String buildDiagnosisPrompt(
    List<EvaluationResult> history,
    EvolvableConfiguration config,
  ) {
    final historyText = history.map((result) => 
        'Config ${result.configurationId}: ${result.scores}').join('\n');
    
    return diagnosisTemplate
        .replaceAll('{PERFORMANCE_HISTORY}', historyText)
        .replaceAll('{CURRENT_CONFIG}', config.parameters.toString());
  }
  
  String buildPatternExplanationPrompt(String dimension, List<double> scores) {
    return patternTemplate
        .replaceAll('{DIMENSION}', dimension)
        .replaceAll('{SCORE_HISTORY}', scores.toString());
  }
  
  static const String _standardDiagnosisTemplate = '''
Analyze the following performance data and identify the primary weakness:

Performance History:
{PERFORMANCE_HISTORY}

Current Configuration:
{CURRENT_CONFIG}

Identify:
1. The single most critical weakness affecting overall performance
2. Root cause analysis of why this weakness exists  
3. Specific recommendations to address the weakness
4. Your confidence in this diagnosis (0.0 to 1.0)

Focus on actionable insights that can guide configuration improvements.
''';

  static const String _standardPatternTemplate = '''
Explain the performance pattern for the {DIMENSION} dimension:

Score History: {SCORE_HISTORY}

Provide a concise explanation of the observed pattern and what it indicates 
about system performance in this dimension.
''';
}
```

## Usage Example

```dart
// Setup diagnosticians
final llmDiagnostician = LLMDiagnostician(
  diagnosticAgent: Agent('anthropic'),
  systemPrompt: 'You are an expert in medical AI system performance...',
);

final statDiagnostician = StatisticalDiagnostician();

// Combine both approaches
final combinedDiagnosis = await Future.wait([
  llmDiagnostician.analyzeWeaknesses(performanceHistory, currentConfig),
  statDiagnostician.analyzeWeaknesses(performanceHistory, currentConfig),
]);

// Select the diagnosis with highest confidence
final bestDiagnosis = combinedDiagnosis
    .reduce((a, b) => a.confidenceScore > b.confidenceScore ? a : b);

print('Primary weakness: ${bestDiagnosis.primaryWeakness}');
print('Root cause: ${bestDiagnosis.rootCauseAnalysis}');
print('Recommendations: ${bestDiagnosis.recommendations.length}');
```

## Package Dependencies

```yaml
name: dartantic_diagnosis
dependencies:
  dartantic_ai: ^VERSION
  dartantic_evaluation: ^VERSION
  dartantic_evolution: ^VERSION
  json_schema: ^VERSION
  logging: ^VERSION
```

This package provides sophisticated performance analysis capabilities that can identify bottlenecks and generate targeted improvement strategies for any AI system configuration.