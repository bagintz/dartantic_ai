import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_evaluation/dartantic_evaluation.dart';
import '../models/diagnosis_models.dart';
import '../templates/diagnosis_templates.dart';
import '../analyzers/statistical_analyzers.dart';
import 'diagnostician_interface.dart';

/// Uses dartantic_ai Agent for AI-powered root cause analysis.
class LLMDiagnostician implements PerformanceDiagnostician {
  final Agent _agent;
  final DiagnosisPromptTemplate _template;
  final TrendAnalyzer _trendAnalyzer = TrendAnalyzer();

  LLMDiagnostician(this._agent, {DiagnosisPromptTemplate? template})
      : _template = template ?? DiagnosisPromptTemplate.defaultTemplate;

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

    // Prepare data for the prompt
    final scores = history.map((e) => e.overallScore).toList();
    final trend = _trendAnalyzer.analyze(scores);
    
    final historySummary = history.map((e) {
      return 'Score: ${e.overallScore.toStringAsFixed(2)}, Input: ${e.input.toString().substring(0, 50)}...';
    }).join('\n');

    final statisticalAnalysis = '''
Trend: ${trend.direction} (slope: ${trend.slope.toStringAsFixed(4)})
Confidence: ${trend.confidence.toStringAsFixed(2)}
Average Score: ${(scores.reduce((a, b) => a + b) / scores.length).toStringAsFixed(2)}
''';

    final prompt = _template.fill({
      'CONTEXT': context.toString(),
      'HISTORY_SUMMARY': historySummary,
      'STATISTICAL_ANALYSIS': statisticalAnalysis,
    });

    try {
      final result = await _agent.sendFor<PerformanceDiagnosis>(
        prompt,
        outputSchema: PerformanceDiagnosis.schema,
        outputFromJson: (json) => PerformanceDiagnosis.fromJson(json),
      );

      return result.output;
    } catch (e) {
      // Fallback or error handling
      return PerformanceDiagnosis(
        weaknessAnalysis: 'Failed to perform LLM diagnosis: $e',
        rootCauses: ['LLM Error'],
        recommendations: [],
        overallConfidence: 0.0,
      );
    }
  }
}
