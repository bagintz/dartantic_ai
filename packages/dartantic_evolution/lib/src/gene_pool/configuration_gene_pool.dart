import 'dart:async';
import 'dart:math';
import 'package:logging/logging.dart';
import '../interfaces/evolvable_configuration.dart';
import '../interfaces/mutation_strategy.dart';
import '../interfaces/selection_strategy.dart';
import '../interfaces/crossover_strategy.dart';
import 'generation.dart';

class ConfigurationGenePool<T extends EvolvableConfiguration<T>> {
  final Logger _logger = Logger('ConfigurationGenePool');
  final Random _random = Random();
  
  final List<Generation<T>> _history = [];
  final List<MutationStrategy<T>> _mutationStrategies;
  final SelectionStrategy<T> _selectionStrategy;
  final CrossoverStrategy<T>? _crossoverStrategy;
  
  final int populationSize;
  final double mutationRate;
  final double crossoverRate;
  
  ConfigurationGenePool({
    required List<T> initialPopulation,
    required List<MutationStrategy<T>> mutationStrategies,
    required SelectionStrategy<T> selectionStrategy,
    CrossoverStrategy<T>? crossoverStrategy,
    this.populationSize = 50,
    this.mutationRate = 0.1,
    this.crossoverRate = 0.5,
  }) : _mutationStrategies = mutationStrategies,
       _selectionStrategy = selectionStrategy,
       _crossoverStrategy = crossoverStrategy {
    if (initialPopulation.isEmpty) {
      throw ArgumentError('Initial population cannot be empty');
    }
    // Create generation 0
    // Note: Fitness scores are empty initially. They must be evaluated before evolving.
    _history.add(Generation(
      number: 0,
      population: initialPopulation,
      fitnessScores: {},
    ));
  }

  List<Generation<T>> get history => List.unmodifiable(_history);
  Generation<T> get currentGeneration => _history.last;

  /// Records fitness scores for the current generation
  void recordEvaluation(Map<String, double> fitnessScores, {Map<String, Map<String, double>>? multiObjectiveScores}) {
    var current = _history.last;
    // Replace the last generation with one that has scores
    _history.removeLast();
    _history.add(Generation(
      number: current.number,
      population: current.population,
      fitnessScores: fitnessScores,
      multiObjectiveScores: multiObjectiveScores ?? const {},
      timestamp: current.timestamp,
      metadata: current.metadata,
    ));
  }

  /// Evolves the population to the next generation
  Future<Generation<T>> evolve() async {
    var current = _history.last;
    if (current.fitnessScores.isEmpty && current.multiObjectiveScores.isEmpty) {
      _logger.warning('Evolving without fitness scores. Selection might be random.');
    }

    _logger.info('Evolving generation ${current.number} -> ${current.number + 1}');

    // 1. Selection
    var best = current.bestPerformer;
    var parents = _selectionStrategy.select(current, populationSize);
    
    var nextPopulation = <T>[];
    
    // Elitism
    if (best != null) {
      nextPopulation.add(best.clone());
    }

    while (nextPopulation.length < populationSize) {
      // Decide whether to crossover or just clone/mutate
      if (_crossoverStrategy != null && _random.nextDouble() < crossoverRate && parents.length >= 2) {
        // Crossover
        var parentA = parents[_random.nextInt(parents.length)];
        var parentB = parents[_random.nextInt(parents.length)];
        
        var offspring = await _crossoverStrategy!.crossover(parentA, parentB);
        
        for (var child in offspring) {
          if (nextPopulation.length < populationSize) {
             // Mutate offspring
             for (var strategy in _mutationStrategies) {
               child = await strategy.mutate(child, mutationRate: mutationRate);
             }
             nextPopulation.add(child);
          }
        }
      } else {
        // Just mutate
        var parent = parents[_random.nextInt(parents.length)];
        var child = parent.clone();
        for (var strategy in _mutationStrategies) {
          child = await strategy.mutate(child, mutationRate: mutationRate);
        }
        nextPopulation.add(child);
      }
    }

    var nextGen = Generation(
      number: current.number + 1,
      population: nextPopulation,
      fitnessScores: {}, // To be evaluated
    );
    
    _history.add(nextGen);
    return nextGen;
  }
}
