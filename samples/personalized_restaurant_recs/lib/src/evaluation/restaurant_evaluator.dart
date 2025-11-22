import 'package:dartantic_ai/dartantic_ai.dart';
import '../models/user_persona.dart';
import '../models/review.dart';
import 'evaluation_result.dart';

/// Evaluates restaurant analysis outputs across multiple dimensions
class RestaurantEvaluator {
  RestaurantEvaluator({
    required this.agent,
  });

  final Agent agent;

  /// Evaluate a restaurant analysis output
  Future<EvaluationResult> evaluate({
    required String sopId,
    required String analysis,
    required List<Review> sourceReviews,
    required UserPersona persona,
  }) async {
    // Run LLM-judged evaluations in parallel
    final llmFutures = await Future.wait([
      _evaluateAccuracy(analysis, sourceReviews),
      _evaluateCompleteness(analysis),
      _evaluateHelpfulness(analysis, persona),
    ]);

    final accuracy = llmFutures[0];
    final completeness = llmFutures[1];
    final helpfulness = llmFutures[2];

    // Run programmatic evaluations
    final conciseness = _evaluateConciseness(analysis);
    final dataGrounded = _evaluateDataGrounded(analysis);
    final personalization = _evaluatePersonalization(analysis, persona);

    return EvaluationResult(
      sopId: sopId,
      accuracy: accuracy,
      completeness: completeness,
      helpfulness: helpfulness,
      conciseness: conciseness,
      dataGrounded: dataGrounded,
      personalization: personalization,
    );
  }

  /// Accuracy: Are claims supported by the reviews?
  Future<double> _evaluateAccuracy(
    String analysis,
    List<Review> reviews,
  ) async {
    final reviewTexts = reviews.map((r) => r.text).join('\n\n');

    final prompt = '''You are evaluating the accuracy of a restaurant analysis.

Source Reviews:
$reviewTexts

Analysis to Evaluate:
$analysis

Rate the accuracy from 0.0 to 1.0 based on:
- Are claims in the analysis supported by the reviews?
- Are there any unsupported or exaggerated claims?
- Is the analysis faithful to the source material?

Respond with ONLY a number between 0.0 and 1.0''';

    final response = await agent.chat(prompt);
    return _parseScore(response);
  }

  /// Completeness: Does it cover all important aspects?
  Future<double> _evaluateCompleteness(String analysis) async {
    final prompt = '''You are evaluating the completeness of a restaurant analysis.

Analysis to Evaluate:
$analysis

Rate the completeness from 0.0 to 1.0 based on:
- Does it cover food quality?
- Does it mention service?
- Does it discuss atmosphere/ambiance?
- Does it address value/pricing?
- Are any important aspects missing?

Respond with ONLY a number between 0.0 and 1.0''';

    final response = await agent.chat(prompt);
    return _parseScore(response);
  }

  /// Helpfulness: Does it aid decision-making?
  Future<double> _evaluateHelpfulness(
    String analysis,
    UserPersona persona,
  ) async {
    final prompt = '''You are evaluating how helpful a restaurant analysis is for decision-making.

User Persona: ${persona.name}
Description: ${persona.description}
Priorities: ${persona.priorities.join(', ')}

Analysis to Evaluate:
$analysis

Rate the helpfulness from 0.0 to 1.0 based on:
- Does it provide actionable insights?
- Would this help the user decide whether to visit?
- Does it address the user's specific priorities?
- Is the information presented clearly?

Respond with ONLY a number between 0.0 and 1.0''';

    final response = await agent.chat(prompt);
    return _parseScore(response);
  }

  /// Conciseness: Information density (programmatic)
  double _evaluateConciseness(String analysis) {
    final words = analysis.split(RegExp(r'\s+'));
    final sentences = analysis.split(RegExp(r'[.!?]+'));

    // Optimal: 100-200 words, 5-10 sentences
    final wordScore = _scoreInRange(
      words.length.toDouble(),
      optimal: 150,
      acceptable: 50,
    );

    final sentenceScore = _scoreInRange(
      sentences.length.toDouble(),
      optimal: 7,
      acceptable: 3,
    );

    return (wordScore + sentenceScore) / 2;
  }

  /// Data-Grounded: Contains specific examples and statistics
  double _evaluateDataGrounded(String analysis) {
    var score = 0.0;

    // Check for numbers (ratings, percentages, counts)
    final numberMatches =
        RegExp(r'\b\d+(\.\d+)?(%|stars?|reviews?)\b', caseSensitive: false)
            .allMatches(analysis);
    score += (numberMatches.length / 5).clamp(0.0, 0.4);

    // Check for specific dish mentions
    final dishMatches = RegExp(
      r'\b(pasta|pizza|burger|sushi|taco|steak|salad|ramen)',
      caseSensitive: false,
    ).allMatches(analysis);
    score += (dishMatches.length / 3).clamp(0.0, 0.3);

    // Check for quoted text from reviews
    final quoteMatches = RegExp(r'"[^"]+"').allMatches(analysis);
    score += (quoteMatches.length / 2).clamp(0.0, 0.3);

    return score.clamp(0.0, 1.0);
  }

  /// Personalization: Matches user persona preferences
  double _evaluatePersonalization(String analysis, UserPersona persona) {
    var score = 0.0;

    // Check if analysis mentions persona priorities
    for (final priority in persona.priorities) {
      if (analysis.toLowerCase().contains(priority.toLowerCase())) {
        score += 0.25;
      }
    }

    // Check for persona-specific keywords
    final focusAreas =
        (persona.preferences['focus_areas'] as List<dynamic>?) ?? [];
    for (final area in focusAreas) {
      if (analysis.toLowerCase().contains(area.toString().toLowerCase())) {
        score += 0.15;
      }
    }

    return score.clamp(0.0, 1.0);
  }

  /// Score a value based on how close it is to optimal
  double _scoreInRange(
    double value, {
    required double optimal,
    required double acceptable,
  }) {
    final distance = (value - optimal).abs();
    if (distance <= acceptable) {
      return 1.0 - (distance / acceptable) * 0.3; // 0.7 to 1.0
    }
    return (acceptable / distance).clamp(0.0, 0.7);
  }

  /// Parse LLM score response
  double _parseScore(String response) {
    final cleaned = response.trim();
    final match = RegExp(r'(\d+\.?\d*)').firstMatch(cleaned);
    if (match != null) {
      final value = double.tryParse(match.group(1)!) ?? 0.5;
      return value.clamp(0.0, 1.0);
    }
    return 0.5; // Default if parsing fails
  }
}
