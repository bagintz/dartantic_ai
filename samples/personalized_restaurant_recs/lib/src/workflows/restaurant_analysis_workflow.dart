import 'package:dartantic_ai/dartantic_ai.dart';
import '../config/restaurant_analysis_sop.dart';
import '../models/restaurant.dart';
import '../models/review.dart';
import '../models/user_persona.dart';

/// Result of restaurant analysis workflow
class AnalysisResult {
  AnalysisResult({
    required this.restaurant,
    required this.persona,
    required this.analysis,
    required this.reviewsAnalyzed,
  });

  final Restaurant restaurant;
  final UserPersona persona;
  final String analysis;
  final int reviewsAnalyzed;

  @override
  String toString() {
    return 'AnalysisResult(${restaurant.name}, ${persona.name}, '
        '$reviewsAnalyzed reviews)';
  }
}

/// Multi-agent workflow for analyzing restaurants
class RestaurantAnalysisWorkflow {
  RestaurantAnalysisWorkflow({
    required this.agent,
  });

  final Agent agent;

  /// Run the workflow using the given SOP
  Future<AnalysisResult> analyze({
    required RestaurantAnalysisSOP sop,
    required Restaurant restaurant,
    required List<Review> allReviews,
    required UserPersona persona,
  }) async {
    // Step 1: Retrieve relevant reviews (controlled by SOP)
    final relevantReviews = _retrieveReviews(
      allReviews: allReviews,
      k: sop.reviewRetrieverK,
    );

    // Step 2: Plan the analysis (using SOP planner prompt)
    final plan = await _planAnalysis(
      sop: sop,
      restaurant: restaurant,
      reviews: relevantReviews,
      persona: persona,
    );

    // Step 3: Run specialist agents (controlled by SOP)
    final analyses = <String, String>{};

    if (sop.useDataAnalyst) {
      analyses['data'] = await _runDataAnalyst(
        restaurant: restaurant,
        reviews: relevantReviews,
        plan: plan,
      );
    }

    if (sop.useServiceAnalyst) {
      analyses['service'] = await _runServiceAnalyst(
        reviews: relevantReviews,
        plan: plan,
      );
    }

    // Always run sentiment analyst
    analyses['sentiment'] = await _runSentimentAnalyst(
      reviews: relevantReviews,
    );

    // Step 4: Synthesize results (using SOP synthesizer prompt)
    final synthesis = await _synthesizeResults(
      sop: sop,
      restaurant: restaurant,
      persona: persona,
      analyses: analyses,
      reviews: relevantReviews,
    );

    return AnalysisResult(
      restaurant: restaurant,
      persona: persona,
      analysis: synthesis,
      reviewsAnalyzed: relevantReviews.length,
    );
  }

  /// Retrieve top K reviews
  List<Review> _retrieveReviews({
    required List<Review> allReviews,
    required int k,
  }) {
    // Sort by usefulness and recency
    final sorted = allReviews.toList()
      ..sort((a, b) {
        final scoreA = a.useful + (a.date.millisecondsSinceEpoch / 1e12);
        final scoreB = b.useful + (b.date.millisecondsSinceEpoch / 1e12);
        return scoreB.compareTo(scoreA);
      });

    return sorted.take(k).toList();
  }

  /// Plan the analysis
  Future<String> _planAnalysis({
    required RestaurantAnalysisSOP sop,
    required Restaurant restaurant,
    required List<Review> reviews,
    required UserPersona persona,
  }) async {
    final prompt = '''${sop.plannerPrompt}

Restaurant: ${restaurant.name}
Categories: ${restaurant.categories.join(', ')}
Average Rating: ${restaurant.stars.toStringAsFixed(1)} stars

User Persona: ${persona.name}
Description: ${persona.description}
Priorities: ${persona.priorities.join(', ')}

Available Reviews: ${reviews.length}

Create a brief analysis plan (2-3 sentences).''';

    final result = await agent.send(prompt);
    return result.output;
  }

  /// Run data analyst agent
  Future<String> _runDataAnalyst({
    required Restaurant restaurant,
    required List<Review> reviews,
    required String plan,
  }) async {
    final reviewTexts = reviews.map((r) => '${r.stars}★: ${r.text}').join('\n\n');

    final prompt = '''You are a data analyst evaluating restaurant reviews.

Restaurant: ${restaurant.name}
Analysis Plan: $plan

Reviews:
$reviewTexts

Extract key statistics and patterns:
- Common themes in reviews
- Rating distribution insights
- Specific dishes mentioned
- Consistency of quality

Provide a concise data-driven analysis (3-4 sentences).''';

    final result = await agent.send(prompt);
    return result.output;
  }

  /// Run service analyst agent
  Future<String> _runServiceAnalyst({
    required List<Review> reviews,
    required String plan,
  }) async {
    final reviewTexts = reviews.map((r) => '${r.stars}★: ${r.text}').join('\n\n');

    final prompt = '''You are a service quality analyst.

Analysis Plan: $plan

Reviews:
$reviewTexts

Analyze service aspects:
- Staff friendliness and attentiveness
- Wait times and efficiency
- Overall customer experience
- Service consistency

Provide a concise service analysis (2-3 sentences).''';

    final result = await agent.send(prompt);
    return result.output;
  }

  /// Run sentiment analyst agent
  Future<String> _runSentimentAnalyst({
    required List<Review> reviews,
  }) async {
    final reviewTexts = reviews.map((r) => '${r.stars}★: ${r.text}').join('\n\n');

    final prompt = '''Analyze the overall sentiment of these restaurant reviews.

Reviews:
$reviewTexts

Provide a brief sentiment summary (2-3 sentences) covering:
- Overall positive/negative balance
- Emotional tone
- Customer satisfaction level''';

    final result = await agent.send(prompt);
    return result.output;
  }

  /// Synthesize all analyses into final recommendation
  Future<String> _synthesizeResults({
    required RestaurantAnalysisSOP sop,
    required Restaurant restaurant,
    required UserPersona persona,
    required Map<String, String> analyses,
    required List<Review> reviews,
  }) async {
    final analysisText = analyses.entries
        .map((e) => '${e.key.toUpperCase()} ANALYSIS:\n${e.value}')
        .join('\n\n');

    final personalizationPrompt = _buildPersonalizationPrompt(sop, persona);

    final prompt = '''${sop.synthesizerPrompt}

Restaurant: ${restaurant.name}
User Persona: ${persona.name} - ${persona.description}
Priorities: ${persona.priorities.join(', ')}

$analysisText

$personalizationPrompt

Create a personalized recommendation that helps the user decide whether to visit this restaurant.''';

    final result = await agent.send(prompt);
    return result.output;
  }

  /// Build personalization prompt based on SOP level
  String _buildPersonalizationPrompt(
    RestaurantAnalysisSOP sop,
    UserPersona persona,
  ) {
    switch (sop.personalizationLevel) {
      case 'high':
        return '''Strongly tailor the recommendation to ${persona.name}:
- Emphasize aspects matching their priorities: ${persona.priorities.join(', ')}
- Use language and tone appropriate for this persona
- Highlight specific details they care about most''';

      case 'medium':
        return '''Consider the user's priorities: ${persona.priorities.join(', ')}
Mention relevant aspects but maintain balanced coverage.''';

      case 'low':
      default:
        return 'Provide a general recommendation suitable for most diners.';
    }
  }
}
