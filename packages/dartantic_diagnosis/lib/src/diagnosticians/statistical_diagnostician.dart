import 'package:dartantic_evaluation/dartantic_evaluation.dart';
import '../models/diagnosis_models.dart';
import '../analyzers/statistical_analyzers.dart';
import 'diagnostician_interface.dart';

/// Uses statistical methods for trend and correlation analysis.
class StatisticalDiagnostician implements PerformanceDiagnostician {
  final TrendAnalyzer _trendAnalyzer = TrendAnalyzer();
  final VarianceAnalyzer _varianceAnalyzer = VarianceAnalyzer();
  final OutlierAnalyzer _outlierAnalyzer = OutlierAnalyzer();

  @override
  Future<PerformanceDiagnosis> diagnose(
    List<EvaluationResult> history, {
    Map<String, dynamic> context = const {},
  }) async {
    if (history.isEmpty) {
      return PerformanceDiagnosis(
        weaknessAnalysis: 'No history data available.',
        rootCauses: [],
        recommendations: [],
      );
    }

    final scores = history.map((e) => e.overallScore).toList();
    
    // Run analyzers
    final trend = _trendAnalyzer.analyze(scores);
    final variance = _varianceAnalyzer.analyze(scores);
    final outliers = _outlierAnalyzer.analyze(scores);

    final weaknesses = <String>[];
    final rootCauses = <String>[];
    final recommendations = <ImprovementRecommendation>[];

    // Analyze Trend
    if (trend.direction == 'decreasing') {
      weaknesses.add('Performance is declining over time (slope: ${trend.slope.toStringAsFixed(4)}).');
      rootCauses.add('Systematic degradation or negative adaptation.');
      recommendations.add(ImprovementRecommendation(
        target: 'System Configuration',
        suggestion: 'Revert recent changes or retrain.',
        reasoning: 'Performance trend is negative.',
        difficulty: ImplementationDifficulty.medium,
        expectedImpact: ExpectedImpact.high,
        confidence: trend.confidence,
      ));
    }

    // Analyze Variance
    if (variance.stability == 'volatile') {
      weaknesses.add('Performance is volatile (stdDev: ${variance.stdDev.toStringAsFixed(2)}).');
      rootCauses.add('Inconsistent model outputs or environment instability.');
      recommendations.add(ImprovementRecommendation(
        target: 'Temperature/Sampling',
        suggestion: 'Lower temperature or use consistent seeding.',
        reasoning: 'High variance indicates instability.',
        difficulty: ImplementationDifficulty.low,
        expectedImpact: ExpectedImpact.medium,
        confidence: 0.8,
      ));
    }

    // Analyze Outliers
    if (outliers.outlierIndices.isNotEmpty) {
      weaknesses.add('Detected ${outliers.outlierIndices.length} performance outliers.');
      rootCauses.add('Edge cases or specific failure modes.');
      recommendations.add(ImprovementRecommendation(
        target: 'Data Handling',
        suggestion: 'Investigate outlier inputs for edge cases.',
        reasoning: 'Outliers suggest specific scenarios are failing.',
        difficulty: ImplementationDifficulty.medium,
        expectedImpact: ExpectedImpact.medium,
        confidence: 0.7,
      ));
    }

    if (weaknesses.isEmpty) {
      weaknesses.add('Performance appears stable and consistent.');
    }

    return PerformanceDiagnosis(
      weaknessAnalysis: weaknesses.join(' '),
      rootCauses: rootCauses,
      recommendations: recommendations,
      overallConfidence: 0.9, // Statistical methods are confident in their math
      metadata: {
        'trend': trend.toString(),
        'variance': variance.toString(),
        'outliers': outliers.outlierIndices.length,
      },
    );
  }
}
