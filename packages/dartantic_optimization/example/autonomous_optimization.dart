import 'dart:async';
import 'dart:math';

import 'package:dartantic_evaluation/dartantic_evaluation.dart';
import 'package:dartantic_diagnosis/dartantic_diagnosis.dart';
import 'package:dartantic_evolution/dartantic_evolution.dart';
import 'package:dartantic_optimization/dartantic_optimization.dart';
import 'package:dartantic_optimization/src/engines/configuration_evaluator.dart';
import 'package:logging/logging.dart';

// --- Mock Implementations for the Example ---

/// A simple configuration representing a system with a few parameters.
class SimpleConfig implements EvolvableConfiguration<SimpleConfig> {
  final String id;
  final double learningRate;
  final int batchSize;
  final double momentum;

  SimpleConfig({
    required this.id,
    required this.learningRate,
    required this.batchSize,
    required this.momentum,
  });

  @override
  Map<String, dynamic> get metadata => {
        'id': id,
        'learningRate': learningRate,
        'batchSize': batchSize,
        'momentum': momentum,
      };

  @override
  SimpleConfig clone() {
    return SimpleConfig(
      id: id,
      learningRate: learningRate,
      batchSize: batchSize,
      momentum: momentum,
    );
  }

  @override
  SimpleConfig copyWith({
    String? id,
    double? learningRate,
    int? batchSize,
    double? momentum,
  }) {
    return SimpleConfig(
      id: id ?? this.id,
      learningRate: learningRate ?? this.learningRate,
      batchSize: batchSize ?? this.batchSize,
      momentum: momentum ?? this.momentum,
    );
  }
  
  @override
  String toString() => 'Config(lr: ${learningRate.toStringAsFixed(3)}, batch: $batchSize, mom: ${momentum.toStringAsFixed(3)})';
}

/// A mock evaluator that simulates a fitness function.
/// Target: learningRate = 0.01, batchSize = 32, momentum = 0.9
class MockEvaluator implements ConfigurationEvaluator<SimpleConfig> {
  @override
  Future<EvaluationResult> evaluate(SimpleConfig config) async {
    // Simulate processing time
    await Future.delayed(Duration(milliseconds: 10));

    // Calculate distance from optimal values
    double lrError = (config.learningRate - 0.01).abs();
    double batchError = (config.batchSize - 32).abs() / 32.0;
    double momError = (config.momentum - 0.9).abs();

    // Score is 1.0 / (1.0 + totalError) to ensure we always have a gradient
    double totalError = lrError * 10 + batchError + momError;
    double scoreVal = 1.0 / (1.0 + totalError);

    return EvaluationResult(
      input: config.id,
      output: 'simulation',
      scores: [
        EvaluationScore(dimension: 'fitness', score: scoreVal),
      ],
      metadata: {'error': totalError},
    );
  }
}

/// A mock diagnostician.
class MockDiagnostician implements PerformanceDiagnostician {
  @override
  Future<PerformanceDiagnosis> diagnose(List<EvaluationResult> history, {Map<String, dynamic> context = const {}}) async {
    // In a real system, this would analyze the result and suggest changes.
    // Here we just return a dummy diagnosis.
    return PerformanceDiagnosis(
      weaknessAnalysis: 'Simulation',
      rootCauses: [],
      recommendations: [],
      overallConfidence: 0.5,
    );
  }
}

/// A simple mutation strategy that tweaks parameters randomly.
class SimpleMutationStrategy implements MutationStrategy<SimpleConfig> {
  final Random _rng = Random();

  @override
  String get name => 'SimpleMutationStrategy';

  @override
  Future<SimpleConfig> mutate(SimpleConfig config, {double mutationRate = 0.1}) async {
    // Randomly pick a parameter to change
    int choice = _rng.nextInt(3);
    
    double newLr = config.learningRate;
    int newBatch = config.batchSize;
    double newMom = config.momentum;

    if (choice == 0) {
      // Tweak learning rate
      newLr += (_rng.nextDouble() - 0.5) * 0.01;
      newLr = newLr.clamp(0.0001, 0.1);
    } else if (choice == 1) {
      // Tweak batch size
      newBatch += (_rng.nextBool() ? 1 : -1) * 4;
      newBatch = newBatch.clamp(4, 128);
    } else {
      // Tweak momentum
      newMom += (_rng.nextDouble() - 0.5) * 0.1;
      newMom = newMom.clamp(0.0, 1.0);
    }

    return config.copyWith(
      id: '${config.id}_mut',
      learningRate: newLr,
      batchSize: newBatch,
      momentum: newMom,
    );
  }
}

// --- Main Example ---

void main() async {
  // Setup logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  print('--- Starting Autonomous Optimization Example ---');

  // 1. Initialize components
  final initialConfig = SimpleConfig(
    id: 'gen_0',
    learningRate: 0.05, // Far from 0.01
    batchSize: 64,      // Far from 32
    momentum: 0.5,      // Far from 0.9
  );

  final engine = DefaultSelfImprovementEngine<SimpleConfig>(
    evaluator: MockEvaluator(),
    diagnostician: MockDiagnostician(),
    mutationStrategy: SimpleMutationStrategy(),
    parameters: EvolutionParameters(
      maxCycles: 20,
      improvementThreshold: 0.001,
      verbose: true,
    ),
  );

  // 2. Initialize engine
  engine.initialize(initialConfig);

  // 3. Create the loop
  final loop = AutonomousOptimizationLoop<SimpleConfig>(
    engine: engine,
    parameters: EvolutionParameters(
      maxCycles: 50,
      convergenceThreshold: 0.0001,
      convergenceWindow: 5,
    ),
  );

  // 4. Listen to progress
  loop.resultsStream.listen((result) {
    print(
        'Cycle ${result.cycleNumber} completed. '
        'Score: ${result.evaluation.overallScore.toStringAsFixed(4)} '
        '(${result.successful ? "Improved" : "Stagnant"})');
        
    if (result.successful) {
      print('  New Config: ${result.evolvedConfiguration}');
    }
  });

  loop.statusStream.listen((status) {
    print('Status changed: $status');
  });

  // 5. Start optimization
  await loop.start();

  print('--- Optimization Finished ---');
  print('Final Status: ${loop.status}');
  
  if (loop.history.isNotEmpty) {
    final lastSuccess = loop.history.lastWhere((r) => r.successful, orElse: () => loop.history.first);
    final bestConfig = lastSuccess.successful ? lastSuccess.evolvedConfiguration : lastSuccess.initialConfiguration;
    print('Best Configuration Found: $bestConfig');
  }
  
  // Cleanup
  await loop.dispose();
  await engine.dispose();
}
