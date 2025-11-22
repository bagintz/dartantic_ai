import 'dart:math';
import '../config/restaurant_analysis_sop.dart';

/// Strategy for mutating SOPs to create variations
abstract class MutationStrategy {
  RestaurantAnalysisSOP mutate(RestaurantAnalysisSOP sop);
}

/// Tweaks numeric parameters slightly
class ParameterTweakMutation implements MutationStrategy {
  ParameterTweakMutation({int? seed}) : _random = Random(seed);

  final Random _random;

  @override
  RestaurantAnalysisSOP mutate(RestaurantAnalysisSOP sop) {
    final mutation = _random.nextInt(3);

    switch (mutation) {
      case 0:
        // Adjust review retriever K
        final delta = _random.nextInt(5) - 2; // -2 to +2
        return sop.mutate(
          reviewRetrieverK: (sop.reviewRetrieverK + delta).clamp(3, 15),
        );

      case 1:
        // Change personalization level
        final levels = ['low', 'medium', 'high'];
        final currentIndex = levels.indexOf(sop.personalizationLevel);
        final newIndex = (currentIndex + (_random.nextBool() ? 1 : -1))
            .clamp(0, levels.length - 1);
        return sop.mutate(personalizationLevel: levels[newIndex]);

      case 2:
      default:
        // Toggle analyst usage
        if (_random.nextBool()) {
          return sop.mutate(useDataAnalyst: !sop.useDataAnalyst);
        } else {
          return sop.mutate(useServiceAnalyst: !sop.useServiceAnalyst);
        }
    }
  }
}

/// Makes structural changes to the workflow
class StructuralMutation implements MutationStrategy {
  StructuralMutation({int? seed}) : _random = Random(seed);

  final Random _random;

  @override
  RestaurantAnalysisSOP mutate(RestaurantAnalysisSOP sop) {
    final mutation = _random.nextInt(2);

    switch (mutation) {
      case 0:
        // Enable both analysts for thoroughness
        return sop.mutate(
          useDataAnalyst: true,
          useServiceAnalyst: true,
          personalizationLevel: 'high',
        );

      case 1:
      default:
        // Minimize for speed
        return sop.mutate(
          useDataAnalyst: _random.nextBool(),
          useServiceAnalyst: false,
          reviewRetrieverK: 3,
          personalizationLevel: 'low',
        );
    }
  }
}

/// Modifies prompts to improve specific dimensions
class PromptEnhancementMutation implements MutationStrategy {
  PromptEnhancementMutation({int? seed}) : _random = Random(seed);

  final Random _random;

  static const _plannerEnhancements = [
    'Focus on extracting specific examples and quotes from reviews.',
    'Prioritize identifying patterns across multiple reviews.',
    'Pay special attention to recent reviews for current conditions.',
    'Look for consistency or contradictions in reviewer feedback.',
  ];

  static const _synthesizerEnhancements = [
    'Be concise but include specific examples from the reviews.',
    'Structure the response to match the user persona priorities.',
    'Include both strengths and weaknesses with supporting evidence.',
    'Provide actionable recommendations based on the analysis.',
  ];

  @override
  RestaurantAnalysisSOP mutate(RestaurantAnalysisSOP sop) {
    if (_random.nextBool()) {
      // Enhance planner prompt
      final enhancement =
          _plannerEnhancements[_random.nextInt(_plannerEnhancements.length)];
      return sop.mutate(
        plannerPrompt: '${sop.plannerPrompt}\n\n$enhancement',
      );
    } else {
      // Enhance synthesizer prompt
      final enhancement = _synthesizerEnhancements[
          _random.nextInt(_synthesizerEnhancements.length)];
      return sop.mutate(
        synthesizerPrompt: '${sop.synthesizerPrompt}\n\n$enhancement',
      );
    }
  }
}

/// Combines multiple mutation strategies
class CompositeMutation implements MutationStrategy {
  CompositeMutation({
    required this.strategies,
    int? seed,
  }) : _random = Random(seed);

  final List<MutationStrategy> strategies;
  final Random _random;

  @override
  RestaurantAnalysisSOP mutate(RestaurantAnalysisSOP sop) {
    final strategy = strategies[_random.nextInt(strategies.length)];
    return strategy.mutate(sop);
  }
}
