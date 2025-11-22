# Dartantic Evolution Package Specification

## Overview

`dartantic_evolution` provides genetic algorithm and configuration optimization patterns for evolving AI workflow configurations. It enables systematic improvement of system parameters through mutation, crossover, and selection operations.

## Core Interfaces

### EvolvableConfiguration
```dart
abstract interface class EvolvableConfiguration {
  /// Unique identifier for this configuration
  String get id;
  
  /// Generation number in evolution
  int get generation;
  
  /// Configuration parameters that can be mutated
  Map<String, dynamic> get parameters;
  
  /// History of mutations applied
  List<String> get mutationHistory;
  
  /// Create a mutated version of this configuration
  EvolvableConfiguration mutate(List<MutationStrategy> strategies);
  
  /// Combine with another configuration to create hybrid
  EvolvableConfiguration crossover(EvolvableConfiguration other);
  
  /// Calculate fitness score from evaluation result
  double calculateFitness(EvaluationResult evaluation);
  
  /// Create a copy with modified parameters
  EvolvableConfiguration copyWith({
    Map<String, dynamic>? parameters,
    List<String>? mutationHistory,
  });
}
```

### MutationStrategy
```dart
abstract interface class MutationStrategy {
  /// Name of this mutation strategy
  String get name;
  
  /// Apply mutation to parameters
  Map<String, dynamic> mutate(Map<String, dynamic> parameters);
  
  /// Check if this strategy can be applied to given parameters
  bool canApply(Map<String, dynamic> parameters);
  
  /// Probability of applying this mutation (0.0 to 1.0)
  double get mutationProbability;
}
```

### ConfigurationGeneration
```dart
class ConfigurationGeneration {
  final int generation;
  final DateTime timestamp;
  final List<EvolvableConfiguration> configurations;
  final EvolvableConfiguration? parentConfig;
  final String evolutionStrategy;
  final Map<String, double> performanceMetrics;
  
  ConfigurationGeneration({
    required this.generation,
    required this.configurations,
    required this.evolutionStrategy,
    DateTime? timestamp,
    this.parentConfig,
    this.performanceMetrics = const {},
  }) : timestamp = timestamp ?? DateTime.now();
  
  EvolvableConfiguration get bestPerforming => configurations
      .reduce((a, b) => a.calculateFitness(_lastEvaluations[a.id]!) > 
                        b.calculateFitness(_lastEvaluations[b.id]!) ? a : b);
}
```

## Core Implementation

### ConfigurationGenePool
```dart
class ConfigurationGenePool {
  final List<ConfigurationGeneration> _generations = [];
  final Map<String, EvaluationResult> _evaluationHistory = {};
  int _currentGeneration = 0;
  
  /// Add a new configuration with its evaluation result
  void addConfiguration(
    EvolvableConfiguration config, 
    EvaluationResult evaluation,
  ) {
    _evaluationHistory[config.id] = evaluation;
    
    // Add to current generation or create new one
    if (_generations.isEmpty || 
        _generations.last.generation < config.generation) {
      _generations.add(ConfigurationGeneration(
        generation: config.generation,
        configurations: [config],
        evolutionStrategy: 'initial',
      ));
    } else {
      _generations.last.configurations.add(config);
    }
  }
  
  /// Get the best performing configuration
  EvolvableConfiguration getBestPerforming() {
    if (_evaluationHistory.isEmpty) {
      throw StateError('No configurations available');
    }
    
    return _evaluationHistory.entries
        .map((e) => _getConfigById(e.key)!)
        .reduce((a, b) => 
            a.calculateFitness(_evaluationHistory[a.id]!) >
            b.calculateFitness(_evaluationHistory[b.id]!) ? a : b);
  }
  
  /// Get Pareto optimal configurations
  List<EvolvableConfiguration> getParetoOptimal() {
    final evaluations = _evaluationHistory.values.toList();
    final paretoResults = MultiDimensionalEvaluator({}).findParetoFront(evaluations);
    
    return paretoResults
        .map((result) => _getConfigById(result.configurationId)!)
        .toList();
  }
  
  /// Select parent configurations for breeding
  List<EvolvableConfiguration> selectParents(
    int count, 
    SelectionStrategy strategy,
  ) {
    return strategy.select(_getAllConfigurations(), count, _evaluationHistory);
  }
  
  /// Generate offspring from parent configurations
  List<EvolvableConfiguration> generateOffspring(
    List<EvolvableConfiguration> parents,
    List<MutationStrategy> mutationStrategies,
    {int offspringCount = 2}
  ) {
    final offspring = <EvolvableConfiguration>[];
    final random = Random();
    
    for (int i = 0; i < offspringCount; i++) {
      if (parents.length >= 2 && random.nextBool()) {
        // Crossover
        final parent1 = parents[random.nextInt(parents.length)];
        final parent2 = parents[random.nextInt(parents.length)];
        offspring.add(parent1.crossover(parent2));
      } else {
        // Mutation
        final parent = parents[random.nextInt(parents.length)];
        offspring.add(parent.mutate(mutationStrategies));
      }
    }
    
    return offspring;
  }
  
  List<EvolvableConfiguration> _getAllConfigurations() {
    return _generations.expand((gen) => gen.configurations).toList();
  }
  
  EvolvableConfiguration? _getConfigById(String id) {
    for (final gen in _generations) {
      for (final config in gen.configurations) {
        if (config.id == id) return config;
      }
    }
    return null;
  }
}
```

## Built-in Mutation Strategies

### ParameterTweakMutation
```dart
class ParameterTweakMutation implements MutationStrategy {
  final double adjustmentRange;
  final List<String> targetParameters;
  
  ParameterTweakMutation({
    this.adjustmentRange = 0.1,
    required this.targetParameters,
  });
  
  @override
  String get name => 'parameter_tweak';
  
  @override
  double get mutationProbability => 0.7;
  
  @override
  bool canApply(Map<String, dynamic> parameters) {
    return targetParameters.any((param) => parameters.containsKey(param));
  }
  
  @override
  Map<String, dynamic> mutate(Map<String, dynamic> parameters) {
    final mutated = Map<String, dynamic>.from(parameters);
    final random = Random();
    
    for (final param in targetParameters) {
      if (parameters.containsKey(param) && random.nextDouble() < mutationProbability) {
        final value = parameters[param];
        if (value is num) {
          final adjustment = (random.nextDouble() - 0.5) * 2 * adjustmentRange;
          mutated[param] = (value + adjustment).clamp(0.0, 1.0);
        }
      }
    }
    
    return mutated;
  }
}
```

### ParameterSwapMutation
```dart
class ParameterSwapMutation implements MutationStrategy {
  final Map<String, List<dynamic>> possibleValues;
  
  ParameterSwapMutation({required this.possibleValues});
  
  @override
  String get name => 'parameter_swap';
  
  @override
  double get mutationProbability => 0.3;
  
  @override
  bool canApply(Map<String, dynamic> parameters) {
    return possibleValues.keys.any((param) => parameters.containsKey(param));
  }
  
  @override
  Map<String, dynamic> mutate(Map<String, dynamic> parameters) {
    final mutated = Map<String, dynamic>.from(parameters);
    final random = Random();
    
    for (final entry in possibleValues.entries) {
      if (parameters.containsKey(entry.key) && 
          random.nextDouble() < mutationProbability) {
        mutated[entry.key] = entry.value[random.nextInt(entry.value.length)];
      }
    }
    
    return mutated;
  }
}
```

### StructuralMutation
```dart
class StructuralMutation implements MutationStrategy {
  final Map<String, StructuralChange> structuralChanges;
  
  StructuralMutation({required this.structuralChanges});
  
  @override
  String get name => 'structural';
  
  @override
  double get mutationProbability => 0.1;
  
  @override
  bool canApply(Map<String, dynamic> parameters) => true;
  
  @override
  Map<String, dynamic> mutate(Map<String, dynamic> parameters) {
    // Implementation for structural changes (add/remove components, etc.)
    final mutated = Map<String, dynamic>.from(parameters);
    final random = Random();
    
    for (final entry in structuralChanges.entries) {
      if (random.nextDouble() < mutationProbability) {
        entry.value.apply(mutated);
      }
    }
    
    return mutated;
  }
}

abstract class StructuralChange {
  void apply(Map<String, dynamic> parameters);
}
```

## Selection Strategies

### SelectionStrategy Interface
```dart
abstract interface class SelectionStrategy {
  List<EvolvableConfiguration> select(
    List<EvolvableConfiguration> population,
    int count,
    Map<String, EvaluationResult> evaluationHistory,
  );
}
```

### TournamentSelection
```dart
class TournamentSelection implements SelectionStrategy {
  final int tournamentSize;
  
  TournamentSelection({this.tournamentSize = 3});
  
  @override
  List<EvolvableConfiguration> select(
    List<EvolvableConfiguration> population,
    int count,
    Map<String, EvaluationResult> evaluationHistory,
  ) {
    final selected = <EvolvableConfiguration>[];
    final random = Random();
    
    for (int i = 0; i < count; i++) {
      // Tournament selection
      final tournament = <EvolvableConfiguration>[];
      for (int j = 0; j < tournamentSize; j++) {
        tournament.add(population[random.nextInt(population.length)]);
      }
      
      // Select best from tournament
      final winner = tournament.reduce((a, b) =>
          a.calculateFitness(evaluationHistory[a.id]!) >
          b.calculateFitness(evaluationHistory[b.id]!) ? a : b);
      
      selected.add(winner);
    }
    
    return selected;
  }
}
```

## Usage Example

```dart
// Setup gene pool with mutation strategies
final genePool = ConfigurationGenePool();
final mutations = [
  ParameterTweakMutation(targetParameters: ['temperature', 'top_p']),
  ParameterSwapMutation(possibleValues: {
    'model': ['gpt-4', 'claude-3', 'llama2'],
    'strategy': ['breadth_first', 'depth_first', 'best_first'],
  }),
];

// Evolution cycle
final parents = genePool.selectParents(4, TournamentSelection());
final offspring = genePool.generateOffspring(parents, mutations);

// Evaluate and add to pool
for (final child in offspring) {
  final result = await testConfiguration(child);
  final evaluation = await evaluator.evaluate(child.id, result);
  genePool.addConfiguration(child, evaluation);
}

// Get best configurations
final best = genePool.getBestPerforming();
final paretoOptimal = genePool.getParetoOptimal();
```

## Package Dependencies

```yaml
name: dartantic_evolution
dependencies:
  dartantic_evaluation: ^VERSION
  logging: ^VERSION
  uuid: ^VERSION
```

This package provides robust genetic algorithm patterns that can evolve any configuration type while maintaining diversity and avoiding local optima.