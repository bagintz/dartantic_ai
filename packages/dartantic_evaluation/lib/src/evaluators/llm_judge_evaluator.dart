import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:json_schema/json_schema.dart';
import '../results/evaluation_score.dart';
import 'evaluator.dart';

/// An evaluator that uses an LLM (via dartantic_ai Agent) to judge the output.
class LLMJudgeEvaluator extends Evaluator<dynamic, dynamic> {
  final Agent agent;
  final String _dimension;
  final String? promptTemplate;

  /// Creates an LLM-based evaluator.
  ///
  /// [agent] is the dartantic_ai Agent to use for evaluation.
  /// [dimension] is the name of the metric being evaluated (e.g. "coherence").
  /// [promptTemplate] is an optional template string. If provided, it must
  /// contain `{{input}}` and `{{output}}` placeholders.
  LLMJudgeEvaluator(this.agent, this._dimension, {this.promptTemplate});

  @override
  String get dimension => _dimension;

  @override
  Future<EvaluationScore> evaluate(dynamic input, dynamic output) async {
    final schema = JsonSchema.create({
      'type': 'object',
      'properties': {
        'score': {
          'type': 'number',
          'minimum': 0.0,
          'maximum': 1.0,
          'description': 'The score between 0.0 and 1.0'
        },
        'reasoning': {
          'type': 'string',
          'description': 'Explanation for the score'
        }
      },
      'required': ['score', 'reasoning']
    });

    final prompt = promptTemplate != null
        ? promptTemplate!
            .replaceAll('{{input}}', input.toString())
            .replaceAll('{{output}}', output.toString())
        : '''
You are an impartial judge evaluating the quality of an AI output based on the dimension: $dimension.

Input:
$input

Output:
$output

Evaluate the output on a scale of 0.0 to 1.0 for the dimension "$dimension".
Provide your reasoning.
''';

    final result = await agent.sendFor<Map<String, dynamic>>(
      prompt,
      outputSchema: schema,
    );

    return EvaluationScore(
      dimension: dimension,
      score: (result.output['score'] as num).toDouble(),
      reasoning: result.output['reasoning'] as String?,
    );
  }
}
