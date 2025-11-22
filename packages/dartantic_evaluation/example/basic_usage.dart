import 'package:dartantic_evaluation/dartantic_evaluation.dart';

void main() async {
  print('--- Dartantic Evaluation Basic Usage ---\n');

  // 1. Define some metric-based evaluators
  // Evaluator 1: Conciseness (shorter is better)
  // We'll normalize length: 0 chars = score 1.0, 100 chars = score 0.0
  final concisenessEvaluator = MetricBasedEvaluator(
    'conciseness',
    (input, output) {
      final len = output.toString().length;
      // Simple inverse normalization for demo
      return (100 - len).toDouble(); 
    },
    minVal: 0.0,
    maxVal: 100.0,
  );

  // Evaluator 2: Accuracy (contains "42")
  final accuracyEvaluator = MetricBasedEvaluator(
    'accuracy',
    (input, output) => output.toString().contains('42') ? 1.0 : 0.0,
    minVal: 0.0,
    maxVal: 1.0,
  );

  // 2. Create the multi-dimensional evaluator
  final evaluator = MultiDimensionalEvaluator([
    concisenessEvaluator,
    accuracyEvaluator,
  ]);

  // 3. Evaluate some candidates
  final input = "What is the answer?";
  final candidates = [
    "The answer is 42.", // Accurate, medium length
    "42",                // Accurate, short (Best of both worlds?)
    "I don't know.",     // Inaccurate, medium length
    "The answer to the ultimate question of life, the universe, and everything is 42.", // Accurate, long
  ];

  print('Evaluating candidates for input: "$input"');
  final results = <EvaluationResult>[];

  for (final output in candidates) {
    final result = await evaluator.evaluate(input, output);
    results.add(result);
    print('\nOutput: "$output"');
    print('  Overall Score: ${result.overallScore.toStringAsFixed(2)}');
    for (final score in result.scores) {
      print('  - ${score.dimension}: ${score.score.toStringAsFixed(2)}');
    }
  }

  // 4. Find Pareto Frontier
  // "42" should be on the frontier (highest accuracy, highest conciseness)
  // "The answer is 42." might be dominated by "42" if "42" is strictly better in conciseness and equal in accuracy.
  print('\n--- Pareto Frontier ---');
  final frontier = evaluator.findParetoFrontier(results);
  
  for (final result in frontier) {
    print('Output: "${result.output}" is on the frontier.');
  }
  
  // Note: LLMJudgeEvaluator usage would look like this:
  /*
  final agent = Agent('openai:gpt-4o');
  final judge = LLMJudgeEvaluator(agent, 'coherence');
  final score = await judge.evaluate(input, output);
  */
}
