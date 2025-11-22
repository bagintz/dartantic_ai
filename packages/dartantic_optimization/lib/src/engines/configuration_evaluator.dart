import 'dart:async';
import 'package:dartantic_evaluation/dartantic_evaluation.dart';

/// Interface for evaluating a configuration.
abstract class ConfigurationEvaluator<T> {
  /// Evaluates the given [configuration].
  Future<EvaluationResult> evaluate(T configuration);
}
