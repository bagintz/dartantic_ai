// import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_diagnosis/dartantic_diagnosis.dart';
import 'package:dartantic_evaluation/dartantic_evaluation.dart';
import 'package:logging/logging.dart';

void main() async {
  // Setup logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  print('Generating mock performance history...');
  final history = _generateMockHistory();

  // 1. Statistical Diagnosis
  print('\n--- Statistical Diagnosis ---');
  final statDiagnostician = StatisticalDiagnostician();
  final statResult = await statDiagnostician.diagnose(history);
  _printDiagnosis(statResult);

  // 2. LLM Diagnosis (requires an API key/provider)
  // In a real app, you would configure your agent here.
  // final agent = Agent('openai:gpt-4o', apiKey: 'YOUR_KEY');
  
  // For this example, we'll skip the actual LLM call if no key is present,
  // but here is how you would do it:
  /*
  print('\n--- LLM Diagnosis ---');
  final llmDiagnostician = LLMDiagnostician(agent);
  final llmResult = await llmDiagnostician.diagnose(
    history,
    context: {'system_version': 'v1.2.0', 'model': 'gpt-3.5-turbo'},
  );
  _printDiagnosis(llmResult);
  */

  // 3. Hybrid Diagnosis
  /*
  print('\n--- Hybrid Diagnosis ---');
  final hybridDiagnostician = HybridDiagnostician(agent);
  final hybridResult = await hybridDiagnostician.diagnose(history);
  _printDiagnosis(hybridResult);
  */
}

void _printDiagnosis(PerformanceDiagnosis diagnosis) {
  print('Weakness Analysis: ${diagnosis.weaknessAnalysis}');
  print('Root Causes:');
  for (final cause in diagnosis.rootCauses) {
    print(' - $cause');
  }
  print('Recommendations:');
  for (final rec in diagnosis.recommendations) {
    print(' - [${rec.difficulty.name.toUpperCase()}] ${rec.target}: ${rec.suggestion} (Confidence: ${rec.confidence})');
  }
  print('Overall Confidence: ${diagnosis.overallConfidence}');
}

List<EvaluationResult> _generateMockHistory() {
  final history = <EvaluationResult>[];
  
  // Simulate a declining trend
  for (int i = 0; i < 10; i++) {
    final score = 0.9 - (i * 0.05); // 0.9, 0.85, 0.80 ...
    history.add(EvaluationResult(
      input: 'Test input $i',
      output: 'Test output $i',
      scores: [
        EvaluationScore(
          dimension: 'accuracy',
          score: score,
          reasoning: 'Simulated score',
        )
      ],
    ));
  }
  
  return history;
}
