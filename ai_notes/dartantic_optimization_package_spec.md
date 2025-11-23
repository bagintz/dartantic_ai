# Dartantic Optimization Package Specification

## Overview

`dartantic_optimization` provides the orchestration layer for self-improving AI systems. It coordinates evaluation, diagnosis, evolution, and testing to create autonomous optimization loops that can improve system performance over time.

## Core Interfaces

### SelfImprovementEngine
```dart
abstract interface class SelfImprovementEngine<T extends EvolvableConfiguration> {
  /// Run one complete evolution cycle
  Future<EvolutionCycleResult> runEvolutionCycle();
  
  /// Test a configuration and return performance metrics
  Future<Map<String, dynamic>> testConfiguration(T configuration);
  
  /// Check if evolution should continue
  bool shouldContinueEvolution();
  
  /// Get current optimization status
  OptimizationStatus get status;
  
  /// Stop the optimization process
  void stop();
}
```

### ConfigurationFactory
```dart
abstract interface class ConfigurationFactory<T extends EvolvableConfiguration> {
  /// Create initial baseline configuration
  T createBaseline();
  
  /// Generate mutations based on diagnosis
  List<T> generateMutations(
    T currentConfig,
    PerformanceDiagnosis diagnosis,
    {int count = 3}
  );
  
  /// Create configuration from parameters
  T fromParameters(Map<String, dynamic> parameters);
  
  /// Validate configuration is viable
  bool isValid(T configuration);
}
```

### EvolutionCycleResult
```dart
class EvolutionCycleResult {
  final int cycle;
  final DateTime timestamp;
  final EvolvableConfiguration previousBest;
  final EvolvableConfiguration newBest;
  final PerformanceDiagnosis diagnosis;
  final List<EvolvableConfiguration> testedConfigurations;
  final double improvementScore;
  final bool foundImprovement;
  
  EvolutionCycleResult({
    required this.cycle,
    required this.previousBest,
    required this.newBest,
    required this.diagnosis,
    required this.testedConfigurations,
    required this.improvementScore,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now(),
       foundImprovement = improvementScore > 0.01;
}
```

### OptimizationStatus
```dart
enum OptimizationStatus {
  initializing,
  running,
  paused,
  stopped,
  completed,
  error,
}

class OptimizationProgress {
  final int cyclesCompleted;
  final int totalCycles;
  final double bestScore;
  final double improvementRate;
  final OptimizationStatus status;
  final DateTime startTime;
  final Duration elapsed;
  
  OptimizationProgress({
    required this.cyclesCompleted,
    required this.totalCycles,
    required this.bestScore,
    required this.improvementRate,
    required this.status,
    required this.startTime,
  }) : elapsed = DateTime.now().difference(startTime);
  
  double get progress => totalCycles > 0 ? cyclesCompleted / totalCycles : 0.0;
}
```

## Core Implementation

### DefaultSelfImprovementEngine
```dart
class DefaultSelfImprovementEngine<T extends EvolvableConfiguration> 
    implements SelfImprovementEngine<T> {
  final MultiDimensionalEvaluator evaluator;
  final PerformanceDiagnostician diagnostician;
  final ConfigurationGenePool genePool;
  final ConfigurationFactory<T> configFactory;
  final List<MutationStrategy> mutationStrategies;
  final EvolutionParameters parameters;
  final Logger _logger = Logger('dartantic.optimization');
  
  OptimizationStatus _status = OptimizationStatus.initializing;
  int _cycleCount = 0;
  late final DateTime _startTime;
  
  DefaultSelfImprovementEngine({
    required this.evaluator,
    required this.diagnostician,
    required this.genePool,
    required this.configFactory,
    required this.mutationStrategies,
    EvolutionParameters? parameters,
  }) : parameters = parameters ?? EvolutionParameters.defaults();
  
  @override
  OptimizationStatus get status => _status;
  
  @override
  Future<EvolutionCycleResult> runEvolutionCycle() async {
    if (_cycleCount == 0) {
      _startTime = DateTime.now();
      _status = OptimizationStatus.running;
      await _initializeBaseline();
    }
    
    _logger.info('Starting evolution cycle ${++_cycleCount}');
    
    try {
      // 1. Get current best configuration
      final currentBest = genePool.getBestPerforming();
      _logger.fine('Current best: ${currentBest.id} (fitness: ${_getCurrentFitness(currentBest)})');
      
      // 2. Get recent performance history for diagnosis
      final recentHistory = _getRecentHistory(parameters.historyWindowSize);
      
      // 3. Diagnose performance weaknesses
      _logger.fine('Diagnosing performance weaknesses...');
      final diagnosis = await diagnostician.analyzeWeaknesses(recentHistory, currentBest);
      _logger.info('Primary weakness identified: ${diagnosis.primaryWeakness}');
      
      // 4. Generate candidate improvements
      final candidates = configFactory.generateMutations(
        currentBest,
        diagnosis,
        count: parameters.candidatesPerCycle,
      );
      _logger.fine('Generated ${candidates.length} candidate mutations');
      
      // 5. Test each candidate configuration
      final testedConfigurations = <T>[];
      for (final candidate in candidates) {
        try {
          _logger.fine('Testing candidate: ${candidate.id}');
          final result = await testConfiguration(candidate);
          final evaluation = await evaluator.evaluate(candidate.id, result);
          genePool.addConfiguration(candidate, evaluation);
          testedConfigurations.add(candidate);
          
          _logger.fine('Candidate ${candidate.id} scored: ${evaluation.overallScore}');
        } catch (e) {
          _logger.warning('Failed to test candidate ${candidate.id}: $e');
        }
      }
      
      // 6. Determine if improvement was found
      final newBest = genePool.getBestPerforming();
      final improvement = _calculateImprovement(currentBest, newBest);
      
      final result = EvolutionCycleResult(
        cycle: _cycleCount,
        previousBest: currentBest,
        newBest: newBest,
        diagnosis: diagnosis,
        testedConfigurations: testedConfigurations,
        improvementScore: improvement,
      );
      
      _logger.info(
        'Cycle ${_cycleCount} complete. '
        'Improvement: ${improvement > 0 ? '+' : ''}${improvement.toStringAsFixed(3)}'
      );
      
      return result;
    } catch (e) {
      _logger.severe('Evolution cycle failed: $e');
      _status = OptimizationStatus.error;
      rethrow;
    }
  }
  
  @override
  bool shouldContinueEvolution() {
    if (_status != OptimizationStatus.running) return false;
    if (_cycleCount >= parameters.maxCycles) return false;
    
    // Check for convergence
    final recentImprovements = _getRecentImprovements(parameters.convergenceWindow);
    final averageImprovement = recentImprovements.isEmpty 
        ? 0.0 
        : recentImprovements.reduce((a, b) => a + b) / recentImprovements.length;
    
    return averageImprovement > parameters.convergenceThreshold;
  }
  
  @override
  void stop() {
    _logger.info('Stopping optimization engine');
    _status = OptimizationStatus.stopped;
  }
  
  Future<void> _initializeBaseline() async {
    if (genePool._getAllConfigurations().isEmpty) {
      _logger.info('Initializing with baseline configuration');
      final baseline = configFactory.createBaseline();
      final result = await testConfiguration(baseline);
      final evaluation = await evaluator.evaluate(baseline.id, result);
      genePool.addConfiguration(baseline, evaluation);
    }
  }
  
  double _getCurrentFitness(EvolvableConfiguration config) {
    final evaluation = genePool._evaluationHistory[config.id];
    return evaluation?.overallScore ?? 0.0;
  }
  
  double _calculateImprovement(EvolvableConfiguration old, EvolvableConfiguration new_) {
    final oldFitness = _getCurrentFitness(old);
    final newFitness = _getCurrentFitness(new_);
    return newFitness - oldFitness;
  }
  
  List<EvaluationResult> _getRecentHistory(int windowSize) {
    final allEvaluations = genePool._evaluationHistory.values.toList();
    allEvaluations.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allEvaluations.take(windowSize).toList();
  }
  
  List<double> _getRecentImprovements(int windowSize) {
    // Implementation to track recent improvement scores
    return []; // Simplified for spec
  }
}
```

### EvolutionParameters
```dart
class EvolutionParameters {
  final int maxCycles;
  final int candidatesPerCycle;
  final int historyWindowSize;
  final int convergenceWindow;
  final double convergenceThreshold;
  final Duration maxRuntime;
  
  const EvolutionParameters({
    required this.maxCycles,
    required this.candidatesPerCycle,
    required this.historyWindowSize,
    required this.convergenceWindow,
    required this.convergenceThreshold,
    required this.maxRuntime,
  });
  
  factory EvolutionParameters.defaults() => const EvolutionParameters(
    maxCycles: 50,
    candidatesPerCycle: 3,
    historyWindowSize: 10,
    convergenceWindow: 5,
    convergenceThreshold: 0.001,
    maxRuntime: Duration(hours: 2),
  );
}
```

## Optimization Orchestrators

### AutonomousOptimizationLoop
```dart
class AutonomousOptimizationLoop<T extends EvolvableConfiguration> {
  final SelfImprovementEngine<T> engine;
  final OptimizationCallback<T>? onCycleComplete;
  final OptimizationCallback<T>? onImprovementFound;
  final ProgressCallback? onProgressUpdate;
  
  AutonomousOptimizationLoop({
    required this.engine,
    this.onCycleComplete,
    this.onImprovementFound,
    this.onProgressUpdate,
  });
  
  /// Run continuous optimization until convergence or manual stop
  Stream<OptimizationProgress> runContinuous() async* {
    final startTime = DateTime.now();
    int cycle = 0;
    
    while (engine.shouldContinueEvolution()) {
      final result = await engine.runEvolutionCycle();
      cycle++;
      
      // Notify callbacks
      await onCycleComplete?.call(result);
      if (result.foundImprovement) {
        await onImprovementFound?.call(result);
      }
      
      // Yield progress
      final progress = OptimizationProgress(
        cyclesCompleted: cycle,
        totalCycles: -1, // Unknown total for continuous
        bestScore: _getCurrentBestScore(),
        improvementRate: result.improvementScore,
        status: engine.status,
        startTime: startTime,
      );
      
      yield progress;
      await onProgressUpdate?.call(progress);
      
      // Respect stop conditions
      if (engine.status != OptimizationStatus.running) {
        break;
      }
    }
  }
  
  double _getCurrentBestScore() {
    // Implementation to get current best score
    return 0.0; // Simplified for spec
  }
}

typedef OptimizationCallback<T> = Future<void> Function(EvolutionCycleResult result);
typedef ProgressCallback = Future<void> Function(OptimizationProgress progress);
```

### BatchOptimizationRunner
```dart
class BatchOptimizationRunner<T extends EvolvableConfiguration> {
  final SelfImprovementEngine<T> engine;
  final int batchSize;
  
  BatchOptimizationRunner({
    required this.engine,
    this.batchSize = 10,
  });
  
  /// Run a fixed number of optimization cycles
  Future<List<EvolutionCycleResult>> runBatch(int cycles) async {
    final results = <EvolutionCycleResult>[];
    
    for (int i = 0; i < cycles && engine.shouldContinueEvolution(); i++) {
      final result = await engine.runEvolutionCycle();
      results.add(result);
    }
    
    return results;
  }
  
  /// Run optimization with A/B testing between configurations
  Future<ABTestResult<T>> runABTest(
    T configA,
    T configB,
    int iterations,
  ) async {
    final resultsA = <Map<String, dynamic>>[];
    final resultsB = <Map<String, dynamic>>[];
    
    for (int i = 0; i < iterations; i++) {
      final resultA = await engine.testConfiguration(configA);
      final resultB = await engine.testConfiguration(configB);
      resultsA.add(resultA);
      resultsB.add(resultB);
    }
    
    return ABTestResult(
      configA: configA,
      configB: configB,
      resultsA: resultsA,
      resultsB: resultsB,
    );
  }
}

class ABTestResult<T extends EvolvableConfiguration> {
  final T configA;
  final T configB;
  final List<Map<String, dynamic>> resultsA;
  final List<Map<String, dynamic>> resultsB;
  
  ABTestResult({
    required this.configA,
    required this.configB,
    required this.resultsA,
    required this.resultsB,
  });
  
  T get winner {
    // Implementation to determine statistical winner
    return configA; // Simplified for spec
  }
}
```

## Usage Example

```dart
// Setup optimization engine
final engine = DefaultSelfImprovementEngine<MedicalTrialConfig>(
  evaluator: MultiDimensionalEvaluator({
    'rigor': MedicalRigorEvaluator(),
    'compliance': RegulatoryEvaluator(),
    'ethics': EthicsEvaluator(),
    'feasibility': FeasibilityEvaluator(),
    'simplicity': SimplicityEvaluator(),
  }),
  diagnostician: LLMDiagnostician(Agent('anthropic')),
  genePool: ConfigurationGenePool(),
  configFactory: MedicalTrialConfigFactory(),
  mutationStrategies: [
    ParameterTweakMutation(targetParameters: ['temperature', 'retrieval_k']),
    ParameterSwapMutation(possibleValues: {
      'model': ['gpt-4', 'claude-3', 'llama2'],
      'strategy': ['depth_first', 'breadth_first'],
    }),
  ],
  parameters: EvolutionParameters(
    maxCycles: 25,
    candidatesPerCycle: 3,
    convergenceThreshold: 0.005,
    maxRuntime: Duration(hours: 1),
  ),
);

// Run continuous optimization with callbacks
final optimizer = AutonomousOptimizationLoop(
  engine: engine,
  onImprovementFound: (result) async {
    print('🎉 Found improvement! Score: ${result.improvementScore}');
  },
  onProgressUpdate: (progress) async {
    print('Progress: ${(progress.progress * 100).toStringAsFixed(1)}%');
  },
);

// Start optimization
await for (final progress in optimizer.runContinuous()) {
  if (progress.status == OptimizationStatus.completed) {
    print('Optimization completed! Best score: ${progress.bestScore}');
    break;
  }
}
```

## Package Dependencies

```yaml
name: dartantic_optimization
dependencies:
  dartantic_evaluation: ^VERSION
  dartantic_evolution: ^VERSION
  dartantic_diagnosis: ^VERSION
  logging: ^VERSION
```

This package provides the complete orchestration layer for autonomous system improvement, coordinating all the individual components into a cohesive self-optimizing system.