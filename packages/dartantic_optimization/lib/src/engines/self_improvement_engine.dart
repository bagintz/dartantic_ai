import 'dart:async';

import 'package:dartantic_evolution/dartantic_evolution.dart';
import '../parameters/evolution_parameters.dart';
import '../results/evolution_cycle_result.dart';

/// Interface for an engine that coordinates the self-improvement process.
abstract class SelfImprovementEngine<T extends EvolvableConfiguration<T>> {
  /// The current configuration being optimized.
  T get currentConfiguration;

  /// Runs a single evolution cycle: Evaluate -> Diagnose -> Mutate -> Test -> Select.
  Future<EvolutionCycleResult<T>> runCycle();

  /// Initializes the engine with a starting configuration.
  void initialize(T initialConfiguration);

  /// Updates the parameters for the engine.
  void updateParameters(EvolutionParameters parameters);
  
  /// Stream of results from each cycle.
  Stream<EvolutionCycleResult<T>> get cycleResults;
}
