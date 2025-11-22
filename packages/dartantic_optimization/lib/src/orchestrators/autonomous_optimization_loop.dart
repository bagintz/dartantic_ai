import 'dart:async';
import 'package:logging/logging.dart';
import 'package:dartantic_evolution/dartantic_evolution.dart';

import '../engines/self_improvement_engine.dart';
import '../parameters/evolution_parameters.dart';
import '../parameters/optimization_status.dart';
import '../results/evolution_cycle_result.dart';

/// Orchestrates the continuous self-improvement process.
class AutonomousOptimizationLoop<T extends EvolvableConfiguration<T>> {
  final Logger _logger = Logger('AutonomousOptimizationLoop');
  final SelfImprovementEngine<T> _engine;
  
  EvolutionParameters _parameters;
  OptimizationStatus _status = OptimizationStatus.idle;
  
  final StreamController<OptimizationStatus> _statusController = 
      StreamController<OptimizationStatus>.broadcast();
      
  final List<EvolutionCycleResult<T>> _history = [];
  
  Timer? _timeoutTimer;
  bool _stopRequested = false;

  AutonomousOptimizationLoop({
    required SelfImprovementEngine<T> engine,
    EvolutionParameters parameters = const EvolutionParameters(),
  })  : _engine = engine,
        _parameters = parameters;

  /// Current status of the optimization loop.
  OptimizationStatus get status => _status;
  
  /// Stream of status changes.
  Stream<OptimizationStatus> get statusStream => _statusController.stream;
  
  /// Stream of cycle results from the engine.
  Stream<EvolutionCycleResult<T>> get resultsStream => _engine.cycleResults;

  /// The history of all cycles run in this session.
  List<EvolutionCycleResult<T>> get history => List.unmodifiable(_history);

  /// Starts the optimization loop.
  Future<void> start() async {
    if (_status == OptimizationStatus.running) {
      _logger.warning('Optimization loop is already running.');
      return;
    }

    _logger.info('Starting autonomous optimization loop...');
    _updateStatus(OptimizationStatus.running);
    _stopRequested = false;
    _history.clear();
    
    // Set timeout if configured
    if (_parameters.timeLimit != null) {
      _timeoutTimer = Timer(_parameters.timeLimit!, () {
        _logger.info('Time limit reached. Stopping optimization.');
        stop();
      });
    }

    try {
      int cyclesWithoutImprovement = 0;

      while (!_stopRequested) {
        // Check max cycles
        if (_history.length >= _parameters.maxCycles) {
          _logger.info('Max cycles reached (${_parameters.maxCycles}).');
          _updateStatus(OptimizationStatus.completed);
          break;
        }

        // Run cycle
        final result = await _engine.runCycle();
        _history.add(result);

        // Check convergence
        if (result.improvement < _parameters.convergenceThreshold) {
          cyclesWithoutImprovement++;
        } else {
          cyclesWithoutImprovement = 0;
        }

        if (cyclesWithoutImprovement >= _parameters.convergenceWindow) {
          _logger.info('Convergence detected (no improvement for $cyclesWithoutImprovement cycles).');
          _updateStatus(OptimizationStatus.converged);
          break;
        }
        
        // Allow event loop to process other events
        await Future.delayed(Duration.zero);
      }
    } catch (e, stackTrace) {
      _logger.severe('Optimization loop failed', e, stackTrace);
      _updateStatus(OptimizationStatus.failed);
    } finally {
      _timeoutTimer?.cancel();
      if (_status == OptimizationStatus.running) {
        _updateStatus(OptimizationStatus.stopped);
      }
    }
  }

  /// Stops the optimization loop gracefully.
  void stop() {
    if (_status != OptimizationStatus.running) return;
    _logger.info('Stopping optimization loop...');
    _stopRequested = true;
  }

  void _updateStatus(OptimizationStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }
  
  /// Updates the parameters for the next cycle.
  void updateParameters(EvolutionParameters parameters) {
    _parameters = parameters;
    _engine.updateParameters(parameters);
  }
  
  Future<void> dispose() async {
    stop();
    await _statusController.close();
  }
}
