/// Configuration parameters for the optimization process.
class EvolutionParameters {
  /// Maximum number of evolution cycles to run.
  final int maxCycles;

  /// Minimum improvement threshold to consider a cycle successful.
  final double improvementThreshold;

  /// Threshold for convergence detection. If improvement is below this for
  /// [convergenceWindow] cycles, optimization is considered converged.
  final double convergenceThreshold;

  /// Number of cycles to look back for convergence detection.
  final int convergenceWindow;

  /// Maximum time allowed for the entire optimization process.
  final Duration? timeLimit;

  /// Whether to enable detailed logging.
  final bool verbose;

  /// Custom parameters for specific strategies.
  final Map<String, dynamic> customParameters;

  const EvolutionParameters({
    this.maxCycles = 10,
    this.improvementThreshold = 0.01,
    this.convergenceThreshold = 0.001,
    this.convergenceWindow = 3,
    this.timeLimit,
    this.verbose = false,
    this.customParameters = const {},
  });

  EvolutionParameters copyWith({
    int? maxCycles,
    double? improvementThreshold,
    double? convergenceThreshold,
    int? convergenceWindow,
    Duration? timeLimit,
    bool? verbose,
    Map<String, dynamic>? customParameters,
  }) {
    return EvolutionParameters(
      maxCycles: maxCycles ?? this.maxCycles,
      improvementThreshold: improvementThreshold ?? this.improvementThreshold,
      convergenceThreshold: convergenceThreshold ?? this.convergenceThreshold,
      convergenceWindow: convergenceWindow ?? this.convergenceWindow,
      timeLimit: timeLimit ?? this.timeLimit,
      verbose: verbose ?? this.verbose,
      customParameters: customParameters ?? this.customParameters,
    );
  }
}
