import 'dart:math';
import '../config/restaurant_analysis_sop.dart';
import '../evaluation/evaluation_result.dart';

/// Strategy for selecting SOPs for the next generation
abstract class SelectionStrategy {
  List<RestaurantAnalysisSOP> select({
    required Map<String, RestaurantAnalysisSOP> population,
    required Map<String, EvaluationResult> evaluations,
    required int count,
  });
}

/// Selects the best performers based on overall score
class ElitistSelection implements SelectionStrategy {
  @override
  List<RestaurantAnalysisSOP> select({
    required Map<String, RestaurantAnalysisSOP> population,
    required Map<String, EvaluationResult> evaluations,
    required int count,
  }) {
    // Sort by overall score
    final sorted = population.values.toList()
      ..sort((a, b) {
        final scoreA = evaluations[a.id]?.overallScore ?? 0.0;
        final scoreB = evaluations[b.id]?.overallScore ?? 0.0;
        return scoreB.compareTo(scoreA); // Descending
      });

    return sorted.take(count).toList();
  }
}

/// Selects SOPs from the Pareto frontier (non-dominated solutions)
class ParetoSelection implements SelectionStrategy {
  @override
  List<RestaurantAnalysisSOP> select({
    required Map<String, RestaurantAnalysisSOP> population,
    required Map<String, EvaluationResult> evaluations,
    required int count,
  }) {
    final frontier = _computeParetoFrontier(evaluations);

    // If frontier has enough members, return them
    if (frontier.length >= count) {
      return frontier.take(count).map((id) => population[id]!).toList();
    }

    // Otherwise, supplement with best performers
    final remainingCount = count - frontier.length;
    final frontierIds = frontier.toSet();

    final remaining = population.entries
        .where((entry) => !frontierIds.contains(entry.key))
        .map((entry) => entry.value)
        .toList()
      ..sort((a, b) {
        final scoreA = evaluations[a.id]?.overallScore ?? 0.0;
        final scoreB = evaluations[b.id]?.overallScore ?? 0.0;
        return scoreB.compareTo(scoreA);
      });

    return [
      ...frontier.map((id) => population[id]!),
      ...remaining.take(remainingCount),
    ];
  }

  /// Compute Pareto frontier - solutions not dominated by any other
  List<String> _computeParetoFrontier(
    Map<String, EvaluationResult> evaluations,
  ) {
    final frontier = <String>[];

    for (final candidate in evaluations.entries) {
      var dominated = false;

      for (final other in evaluations.entries) {
        if (candidate.key == other.key) continue;

        if (other.value.dominates(candidate.value)) {
          dominated = true;
          break;
        }
      }

      if (!dominated) {
        frontier.add(candidate.key);
      }
    }

    return frontier;
  }
}

/// Tournament selection - randomly pick K candidates and select the best
class TournamentSelection implements SelectionStrategy {
  TournamentSelection({
    this.tournamentSize = 3,
    int? seed,
  }) : _random = Random(seed);

  final int tournamentSize;
  final Random _random;

  @override
  List<RestaurantAnalysisSOP> select({
    required Map<String, RestaurantAnalysisSOP> population,
    required Map<String, EvaluationResult> evaluations,
    required int count,
  }) {
    final selected = <RestaurantAnalysisSOP>[];
    final populationList = population.values.toList();

    for (var i = 0; i < count; i++) {
      // Run a tournament
      final tournament = <RestaurantAnalysisSOP>[];
      for (var j = 0; j < tournamentSize; j++) {
        tournament.add(populationList[_random.nextInt(populationList.length)]);
      }

      // Select winner
      tournament.sort((a, b) {
        final scoreA = evaluations[a.id]?.overallScore ?? 0.0;
        final scoreB = evaluations[b.id]?.overallScore ?? 0.0;
        return scoreB.compareTo(scoreA);
      });

      selected.add(tournament.first);
    }

    return selected;
  }
}

/// Diversity-preserving selection - ensures variety in the population
class DiversitySelection implements SelectionStrategy {
  DiversitySelection();

  @override
  List<RestaurantAnalysisSOP> select({
    required Map<String, RestaurantAnalysisSOP> population,
    required Map<String, EvaluationResult> evaluations,
    required int count,
  }) {
    final selected = <RestaurantAnalysisSOP>[];

    // First, take the absolute best
    final best = population.values.toList()
      ..sort((a, b) {
        final scoreA = evaluations[a.id]?.overallScore ?? 0.0;
        final scoreB = evaluations[b.id]?.overallScore ?? 0.0;
        return scoreB.compareTo(scoreA);
      });

    selected.add(best.first);

    // Then select diverse configurations
    final remaining = population.values.where((sop) => sop.id != best.first.id).toList();

    while (selected.length < count && remaining.isNotEmpty) {
      // Find most different from current selection
      RestaurantAnalysisSOP? mostDifferent;
      var maxDifference = 0;

      for (final candidate in remaining) {
        var difference = 0;

        for (final existing in selected) {
          if (candidate.reviewRetrieverK != existing.reviewRetrieverK) {
            difference++;
          }
          if (candidate.useDataAnalyst != existing.useDataAnalyst) difference++;
          if (candidate.useServiceAnalyst != existing.useServiceAnalyst) {
            difference++;
          }
          if (candidate.personalizationLevel != existing.personalizationLevel) {
            difference++;
          }
        }

        if (difference > maxDifference) {
          maxDifference = difference;
          mostDifferent = candidate;
        }
      }

      if (mostDifferent != null) {
        selected.add(mostDifferent);
        remaining.remove(mostDifferent);
      } else {
        break;
      }
    }

    return selected;
  }
}
