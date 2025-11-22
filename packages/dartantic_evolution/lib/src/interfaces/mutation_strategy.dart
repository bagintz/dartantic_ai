import 'evolvable_configuration.dart';

abstract class MutationStrategy<T extends EvolvableConfiguration<T>> {
  /// Applies mutation to a configuration
  /// Returns a new mutated configuration instance
  Future<T> mutate(T configuration, {double mutationRate = 0.1});
  
  /// The name of this mutation strategy
  String get name;
}
