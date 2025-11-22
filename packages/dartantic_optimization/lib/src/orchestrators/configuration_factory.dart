import 'package:dartantic_evolution/dartantic_evolution.dart';

/// Interface for creating and validating configurations.
abstract class ConfigurationFactory<T extends EvolvableConfiguration<T>> {
  /// Creates a default configuration.
  T createDefault();

  /// Creates a configuration from a map of parameters.
  T createFromMap(Map<String, dynamic> map);

  /// Validates a configuration.
  /// Returns true if valid, false otherwise.
  bool validate(T config);
}
