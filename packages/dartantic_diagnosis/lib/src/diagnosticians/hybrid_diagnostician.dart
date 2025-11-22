import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_evaluation/dartantic_evaluation.dart';
import '../models/diagnosis_models.dart';
import '../templates/diagnosis_templates.dart';
import 'diagnostician_interface.dart';
import 'statistical_diagnostician.dart';
import 'llm_diagnostician.dart';

/// Combines both LLM and statistical approaches for comprehensive diagnosis.
class HybridDiagnostician implements PerformanceDiagnostician {
  final StatisticalDiagnostician _statisticalDiagnostician;
  final LLMDiagnostician _llmDiagnostician;

  HybridDiagnostician(Agent agent, {DiagnosisPromptTemplate? template})
      : _statisticalDiagnostician = StatisticalDiagnostician(),
        _llmDiagnostician = LLMDiagnostician(agent, template: template);

  @override
  Future<PerformanceDiagnosis> diagnose(
    List<EvaluationResult> history, {
    Map<String, dynamic> context = const {},
  }) async {
    // 1. Run Statistical Diagnosis
    final statDiagnosis = await _statisticalDiagnostician.diagnose(history, context: context);

    // 2. Enhance Context with Statistical Findings
    final enhancedContext = Map<String, dynamic>.from(context);
    enhancedContext['statistical_findings'] = statDiagnosis.toJson();

    // 3. Run LLM Diagnosis with enhanced context
    // The LLMDiagnostician will use the template which includes {{CONTEXT}}
    // So the statistical findings will be visible to the LLM.
    final llmDiagnosis = await _llmDiagnostician.diagnose(history, context: enhancedContext);

    // 4. Merge Results (Optional: currently just returning LLM result which theoretically incorporates stat findings)
    // We could merge recommendations explicitly if we wanted to ensure statistical ones are present.
    
    final mergedRecommendations = [
      ...statDiagnosis.recommendations,
      ...llmDiagnosis.recommendations
    ];
    
    // Deduplicate recommendations based on target and suggestion?
    // For now, just return the LLM diagnosis as it's the "synthesis".
    // But let's ensure we don't lose the hard statistical facts.
    
    return PerformanceDiagnosis(
      weaknessAnalysis: '${llmDiagnosis.weaknessAnalysis}\n\nStatistical Note: ${statDiagnosis.weaknessAnalysis}',
      rootCauses: {...llmDiagnosis.rootCauses, ...statDiagnosis.rootCauses}.toList(),
      recommendations: mergedRecommendations, // Union of recommendations
      overallConfidence: (llmDiagnosis.overallConfidence + statDiagnosis.overallConfidence) / 2,
      metadata: {
        'llm_metadata': llmDiagnosis.metadata,
        'statistical_metadata': statDiagnosis.metadata,
      },
    );
  }
}
