import 'dart:async';
import 'package:logging/logging.dart';
import 'package:dartantic_evolution/dartantic_evolution.dart';

import '../parameters/optimization_status.dart';
import 'autonomous_optimization_loop.dart';
import '../results/evolution_cycle_result.dart';

/// Result of a batch optimization run.
class BatchOptimizationResult<T extends EvolvableConfiguration<T>> {
  final String runId;
  final T finalConfiguration;
  final double totalImprovement;
  final int cyclesRun;
  final Duration duration;
  final bool converged;

  BatchOptimizationResult({
    required this.runId,
    required this.finalConfiguration,
    required this.totalImprovement,
    required this.cyclesRun,
    required this.duration,
    required this.converged,
  });
}

/// Runs multiple optimization loops, potentially in parallel or sequence.
class BatchOptimizationRunner<T extends EvolvableConfiguration<T>> {
  final Logger _logger = Logger('BatchOptimizationRunner');
  
  /// Runs a set of optimization loops and returns their results.
  /// 
  /// [loops] is a map of run IDs to the loops to run.
  Future<Map<String, BatchOptimizationResult<T>>> runBatch(
    Map<String, AutonomousOptimizationLoop<T>> loops, {
    bool parallel = false,
  }) async {
    _logger.info('Starting batch optimization with ${loops.length} loops (parallel: $parallel)');
    
    final results = <String, BatchOptimizationResult<T>>{};
    
    if (parallel) {
      await Future.wait(loops.entries.map((entry) => _runSingleLoop(entry.key, entry.value)
          .then((result) => results[entry.key] = result)));
    } else {
      for (final entry in loops.entries) {
        results[entry.key] = await _runSingleLoop(entry.key, entry.value);
      }
    }
    
    return results;
  }

  Future<BatchOptimizationResult<T>> _runSingleLoop(
    String id, 
    AutonomousOptimizationLoop<T> loop,
  ) async {
    _logger.info('Starting loop: $id');
    final stopwatch = Stopwatch()..start();
    
    await loop.start();
    
    stopwatch.stop();
    
    final history = loop.history;
    final lastResult = history.isNotEmpty ? history.last : null;
    
    // Calculate total improvement
    // Assuming improvement is relative to the start of the cycle, 
    // total improvement is the score of final config - score of initial config of first cycle.
    // But we only have cycle improvements.
    // Let's assume the last result has the best config if successful.
    
    // We need the final configuration.
    // If the last cycle was successful, it's evolvedConfiguration.
    // If not, we might need to look back or use the engine's current config.
    // But we don't have access to engine here easily unless we expose it.
    // Let's assume the loop history tracks the best.
    
    // Actually, AutonomousOptimizationLoop doesn't expose the final config directly, 
    // but we can get it from the last successful cycle.
    
    T? finalConfig;
    double totalImprovement = 0.0;
    
    if (history.isNotEmpty) {
      // Find last successful cycle
      final lastSuccess = history.lastWhere((r) => r.successful, orElse: () => history.first);
      finalConfig = lastSuccess.successful ? lastSuccess.evolvedConfiguration : lastSuccess.initialConfiguration;
      
      // Total improvement calculation depends on how we track scores.
      // For now, sum of improvements? Or difference between first and last score?
      // We don't have raw scores in EvolutionCycleResult easily accessible as a simple number 
      // (it's in EvaluationResult which is dynamic/generic).
      // But we have `improvement` double.
      totalImprovement = history.fold(0.0, (sum, r) => sum + r.improvement);
    } else {
      // No cycles run?
      // We can't get the config easily without access to the engine's state.
      // This is a limitation of the current interface.
      // Ideally loop.start() returns the result or loop exposes final state.
      throw StateError('Loop $id produced no history.');
    }

    return BatchOptimizationResult<T>(
      runId: id,
      finalConfiguration: finalConfig!,
      totalImprovement: totalImprovement,
      cyclesRun: history.length,
      duration: stopwatch.elapsed,
      converged: loop.status == OptimizationStatus.converged,
    );
  }
}
