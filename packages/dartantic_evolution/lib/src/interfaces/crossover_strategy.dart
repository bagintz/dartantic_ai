import 'evolvable_configuration.dart';

abstract class CrossoverStrategy<T extends EvolvableConfiguration<T>> {
  /// Performs crossover between two parents to produce offspring
  /// Returns a list of offspring (usually 1 or 2)
  Future<List<T>> crossover(T parentA, T parentB);
  
  String get name;
}
