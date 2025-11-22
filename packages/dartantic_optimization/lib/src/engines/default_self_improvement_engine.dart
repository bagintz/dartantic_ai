import 'dart:async';
import 'package:logging/logging.dart';
import 'package:dartantic_evaluation/dartantic_evaluation.dart';
import 'package:dartantic_diagnosis/dartantic_diagnosis.dart';
import 'package:dartantic_evolution/dartantic_evolution.dart';

import '../parameters/evolution_parameters.dart';
import '../results/evolution_cycle_result.dart';
import 'self_improvement_engine.dart';
import 'configuration_evaluator.dart';

/// Default implementation of the [SelfImprovementEngine].
class DefaultSelfImprovementEngine<T extends EvolvableConfiguration<T>>
    implements SelfImprovementEngine<T> {
  final Logger _logger = Logger('DefaultSelfImprovementEngine');

  final ConfigurationEvaluator<T> _evaluator;
  final PerformanceDiagnostician _diagnostician;
  final MutationStrategy<T> _mutationStrategy;
  
  // Optional: Selection strategy if we generate multiple candidates
  final SelectionStrategy<T>? _selectionStrategy;

  T? _currentConfiguration;
  EvolutionParameters _parameters;
  
  final StreamController<EvolutionCycleResult<T>> _cycleResultsController =
      StreamController<EvolutionCycleResult<T>>.broadcast();

  int _currentCycle = 0;

  DefaultSelfImprovementEngine({
    required ConfigurationEvaluator<T> evaluator,
    required PerformanceDiagnostician diagnostician,
    required MutationStrategy<T> mutationStrategy,
    SelectionStrategy<T>? selectionStrategy,
    EvolutionParameters parameters = const EvolutionParameters(),
  })  : _evaluator = evaluator,
        _diagnostician = diagnostician,
        _mutationStrategy = mutationStrategy,
        _selectionStrategy = selectionStrategy,
        _parameters = parameters;

  @override
  T get currentConfiguration {
    if (_currentConfiguration == null) {
      throw StateError('Engine not initialized. Call initialize() first.');
    }
    return _currentConfiguration!;
  }

  @override
  Stream<EvolutionCycleResult<T>> get cycleResults =>
      _cycleResultsController.stream;

  @override
  void initialize(T initialConfiguration) {
    _currentConfiguration = initialConfiguration;
    _currentCycle = 0;
    _logger.info('Initialized with configuration: ${initialConfiguration.id}');
  }

  @override
  void updateParameters(EvolutionParameters parameters) {
    _parameters = parameters;
    _logger.info('Parameters updated');
  }

  @override
  Future<EvolutionCycleResult<T>> runCycle() async {
    if (_currentConfiguration == null) {
      throw StateError('Engine not initialized');
    }

    _currentCycle++;
    final stopwatch = Stopwatch()..start();
    final startConfig = _currentConfiguration!;

    _logger.info('Starting cycle $_currentCycle');

    try {
      // 1. Evaluate current configuration
      _logger.fine('Evaluating current configuration...');
      final evaluationResult = await _evaluator.evaluate(startConfig);
      
      // 2. Diagnose
      _logger.fine('Diagnosing performance...');
      // Pass history as a list containing the current result
      final diagnosis = await _diagnostician.diagnose([evaluationResult]);

      // 3. Mutate / Evolve
      _logger.fine('Generating candidates...');
      
      // Let's generate a few candidates and pick the best.
      final candidates = <T>[];
      final candidateCount = _parameters.customParameters['candidateCount'] as int? ?? 3;
      
      for (int i = 0; i < candidateCount; i++) {
        // Pass diagnosis if mutation strategy supports it?
        // For now, just mutate.
        candidates.add(await _mutationStrategy.mutate(startConfig));
      }

      // 4. Test Candidates
      _logger.fine('Testing ${candidates.length} candidates...');
      T? bestCandidate;
      EvaluationResult? bestCandidateEvaluation;
      double bestImprovement = double.negativeInfinity;

      // Baseline score
      final baselineScore = evaluationResult.overallScore;

      for (final candidate in candidates) {
        final candidateEval = await _evaluator.evaluate(candidate);
        final candidateScore = candidateEval.overallScore;
        final improvement = candidateScore - baselineScore;

        if (improvement > bestImprovement) {
          bestImprovement = improvement;
          bestCandidate = candidate;
          bestCandidateEvaluation = candidateEval;
        }
      }

      // 5. Select
      bool successful = false;
      T? evolvedConfig;
      
      if (bestCandidate != null && bestImprovement > _parameters.improvementThreshold) {
        _logger.info('Improvement found: $bestImprovement');
        _currentConfiguration = bestCandidate;
        evolvedConfig = bestCandidate;
        successful = true;
      } else {
        _logger.info('No significant improvement found (best: $bestImprovement)');
      }

      stopwatch.stop();

      final result = EvolutionCycleResult<T>(
        cycleNumber: _currentCycle,
        initialConfiguration: startConfig,
        evaluation: evaluationResult,
        diagnosis: diagnosis,
        evolvedConfiguration: evolvedConfig,
        improvement: successful ? bestImprovement : 0.0,
        successful: successful,
        duration: stopwatch.elapsed,
      );

      _cycleResultsController.add(result);
      return result;

    } catch (e, stackTrace) {
      _logger.severe('Error in evolution cycle $_currentCycle', e, stackTrace);
      rethrow;
    }
  }
  
  /// Closes the stream controller.
  Future<void> dispose() async {
    await _cycleResultsController.close();
  }
}
