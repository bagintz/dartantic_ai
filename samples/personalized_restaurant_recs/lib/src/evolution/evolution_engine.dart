import 'dart:math';
import '../config/restaurant_analysis_sop.dart';
import '../evaluation/evaluation_result.dart';
import '../evaluation/restaurant_evaluator.dart';
import '../models/review.dart';
import '../models/user_persona.dart';
import 'mutation_strategy.dart';
import 'selection_strategy.dart';

/// Result of one evolution cycle
class EvolutionCycleResult {
  EvolutionCycleResult({
    required this.generation,
    required this.population,
    required this.evaluations,
    required this.paretoFrontier,
    required this.bestOverall,
  });

  final int generation;
  final Map<String, RestaurantAnalysisSOP> population;
  final Map<String, EvaluationResult> evaluations;
  final List<String> paretoFrontier;
  final String bestOverall;

  EvaluationResult get bestResult => evaluations[bestOverall]!;

  @override
  String toString() {
    return 'EvolutionCycle(gen: $generation, '
        'pop: ${population.length}, '
        'frontier: ${paretoFrontier.length}, '
        'best: ${bestResult.overallScore.toStringAsFixed(3)})';
  }
}

/// Orchestrates the evolution of restaurant analysis SOPs
class EvolutionEngine {
  EvolutionEngine({
    required this.evaluator,
    required this.mutationStrategy,
    required this.selectionStrategy,
    this.populationSize = 10,
    this.eliteCount = 2,
    int? seed,
  }) : _random = Random(seed);

  final RestaurantEvaluator evaluator;
  final MutationStrategy mutationStrategy;
  final SelectionStrategy selectionStrategy;
  final int populationSize;
  final int eliteCount;
  final Random _random;

  /// Run one evolution cycle
  Future<EvolutionCycleResult> evolve({
    required Map<String, RestaurantAnalysisSOP> currentPopulation,
    required String analysisText,
    required List<Review> sourceReviews,
    required UserPersona persona,
  }) async {
    // Evaluate current population
    final evaluations = <String, EvaluationResult>{};

    for (final sop in currentPopulation.values) {
      evaluations[sop.id] = await evaluator.evaluate(
        sopId: sop.id,
        analysis: analysisText,
        sourceReviews: sourceReviews,
        persona: persona,
      );
    }

    // Compute Pareto frontier
    final paretoFrontier = _computeParetoFrontier(evaluations);

    // Find best overall
    final bestOverall = _findBestOverall(evaluations);

    // Select parents for next generation
    final parents = selectionStrategy.select(
      population: currentPopulation,
      evaluations: evaluations,
      count: eliteCount,
    );

    // Create next generation
    final nextGeneration = <String, RestaurantAnalysisSOP>{};

    // Keep elite performers unchanged
    for (final parent in parents) {
      nextGeneration[parent.id] = parent;
    }

    // Generate offspring through mutation
    while (nextGeneration.length < populationSize) {
      final parent = parents[_random.nextInt(parents.length)];
      final offspring = mutationStrategy.mutate(parent);
      nextGeneration[offspring.id] = offspring;
    }

    return EvolutionCycleResult(
      generation: (currentPopulation.values.first.generation) + 1,
      population: nextGeneration,
      evaluations: evaluations,
      paretoFrontier: paretoFrontier,
      bestOverall: bestOverall,
    );
  }

  /// Initialize population with baseline and random variations
  Map<String, RestaurantAnalysisSOP> initializePopulation() {
    final population = <String, RestaurantAnalysisSOP>{};

    // Start with baseline
    final baseline = RestaurantAnalysisSOP.baseline();
    population[baseline.id] = baseline;

    // Create variations
    for (var i = 1; i < populationSize; i++) {
      final mutated = mutationStrategy.mutate(baseline);
      population[mutated.id] = mutated;
    }

    return population;
  }

  /// Compute Pareto frontier
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

  /// Find best overall performer
  String _findBestOverall(Map<String, EvaluationResult> evaluations) {
    var bestId = evaluations.keys.first;
    var bestScore = evaluations[bestId]!.overallScore;

    for (final entry in evaluations.entries) {
      if (entry.value.overallScore > bestScore) {
        bestScore = entry.value.overallScore;
        bestId = entry.key;
      }
    }

    return bestId;
  }
}
