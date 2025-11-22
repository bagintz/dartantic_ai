import 'dart:async';
import 'package:test/test.dart';
import 'package:dartantic_optimization/dartantic_optimization.dart';
import 'package:dartantic_optimization/src/engines/configuration_evaluator.dart';
import 'package:dartantic_evaluation/dartantic_evaluation.dart';
import 'package:dartantic_diagnosis/dartantic_diagnosis.dart';
import 'package:dartantic_evolution/dartantic_evolution.dart';

// --- Mocks ---

class TestConfig implements EvolvableConfiguration<TestConfig> {
  final int value;
  final String id;

  TestConfig(this.value, [this.id = 'test']);

  TestConfig copyWith({int? value, String? id}) => TestConfig(value ?? this.value, id ?? this.id);

  @override
  Map<String, dynamic> get metadata => {'value': value, 'id': id};
  
  @override
  TestConfig clone() => TestConfig(value, id);
}

class MockEvaluator implements ConfigurationEvaluator<TestConfig> {
  @override
  Future<EvaluationResult> evaluate(TestConfig config) async {
    // Higher value is better
    return EvaluationResult(
      input: config.id,
      output: 'test_output',
      scores: [
        EvaluationScore(dimension: 'fitness', score: config.value.toDouble()),
      ],
    );
  }
}

class MockDiagnostician implements PerformanceDiagnostician {
  @override
  Future<PerformanceDiagnosis> diagnose(List<EvaluationResult> history, {Map<String, dynamic> context = const {}}) async {
    return PerformanceDiagnosis(
      weaknessAnalysis: 'None',
      rootCauses: [],
      recommendations: [],
    );
  }
}

class MockMutationStrategy implements MutationStrategy<TestConfig> {
  @override
  String get name => 'MockMutationStrategy';

  @override
  Future<TestConfig> mutate(TestConfig config, {double mutationRate = 0.1}) async {
    // Always increment value by 1
    return TestConfig(config.value + 1, '${config.id}_mut');
  }
}

void main() {
  group('DefaultSelfImprovementEngine', () {
    late DefaultSelfImprovementEngine<TestConfig> engine;

    setUp(() {
      engine = DefaultSelfImprovementEngine<TestConfig>(
        evaluator: MockEvaluator(),
        diagnostician: MockDiagnostician(),
        mutationStrategy: MockMutationStrategy(),
        parameters: EvolutionParameters(improvementThreshold: 0.0),
      );
    });

    test('initialization sets current configuration', () {
      final config = TestConfig(10);
      engine.initialize(config);
      expect(engine.currentConfiguration.value, equals(10));
    });

    test('runCycle improves configuration', () async {
      engine.initialize(TestConfig(10));
      
      final result = await engine.runCycle();
      
      expect(result.successful, isTrue);
      expect(result.evolvedConfiguration?.value, equals(11));
      expect(result.improvement, equals(1.0));
      expect(engine.currentConfiguration.value, equals(11));
    });

    test('streams results', () async {
      engine.initialize(TestConfig(10));
      
      final results = <EvolutionCycleResult<TestConfig>>[];
      final sub = engine.cycleResults.listen(results.add);
      
      await engine.runCycle();
      await engine.runCycle();
      
      await Future.delayed(Duration(milliseconds: 10)); // Wait for stream
      
      expect(results.length, equals(2));
      expect(results[0].cycleNumber, equals(1));
      expect(results[1].cycleNumber, equals(2));
      
      await sub.cancel();
    });
  });

  group('AutonomousOptimizationLoop', () {
    late DefaultSelfImprovementEngine<TestConfig> engine;
    late AutonomousOptimizationLoop<TestConfig> loop;

    setUp(() {
      engine = DefaultSelfImprovementEngine<TestConfig>(
        evaluator: MockEvaluator(),
        diagnostician: MockDiagnostician(),
        mutationStrategy: MockMutationStrategy(),
      );
      engine.initialize(TestConfig(0));
      
      loop = AutonomousOptimizationLoop<TestConfig>(
        engine: engine,
        parameters: EvolutionParameters(
          maxCycles: 5,
          convergenceThreshold: 0.001,
        ),
      );
    });

    test('runs for max cycles', () async {
      await loop.start();
      
      expect(loop.history.length, equals(5));
      expect(loop.status, equals(OptimizationStatus.completed));
    });

    test('stops on convergence', () async {
      // Use a mutation strategy that stops improving
      final stagnantEngine = DefaultSelfImprovementEngine<TestConfig>(
        evaluator: MockEvaluator(),
        diagnostician: MockDiagnostician(),
        mutationStrategy: _StagnantMutationStrategy(), // Returns same config
      );
      stagnantEngine.initialize(TestConfig(10));
      
      final stagnantLoop = AutonomousOptimizationLoop<TestConfig>(
        engine: stagnantEngine,
        parameters: EvolutionParameters(
          maxCycles: 10,
          convergenceWindow: 2,
          convergenceThreshold: 0.1,
        ),
      );
      
      await stagnantLoop.start();
      
      // Should stop early due to convergence (no improvement)
      expect(stagnantLoop.history.length, lessThan(10));
      expect(stagnantLoop.status, equals(OptimizationStatus.converged));
    });
  });
}

class _StagnantMutationStrategy implements MutationStrategy<TestConfig> {
  @override
  String get name => 'StagnantMutationStrategy';

  @override
  Future<TestConfig> mutate(TestConfig config, {double mutationRate = 0.1}) async => config; // No change
}
