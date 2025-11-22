/// Represents the current state of the optimization process.
enum OptimizationStatus {
  /// The optimization process has not started yet.
  idle,

  /// The optimization process is currently running.
  running,

  /// The optimization process is paused.
  paused,

  /// The optimization process has completed successfully (e.g. convergence reached).
  converged,

  /// The optimization process has completed due to reaching maximum cycles.
  completed,

  /// The optimization process was stopped manually or by a timeout.
  stopped,

  /// The optimization process encountered an error.
  failed,
}
