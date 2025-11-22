import '../gene_pool/generation.dart';
import 'evolvable_configuration.dart';

abstract class SelectionStrategy<T extends EvolvableConfiguration<T>> {
  /// Selects parents from the population for breeding
  /// Returns a list of selected configurations
  List<T> select(Generation<T> generation, int count);
  
  /// The name of this selection strategy
  String get name;
}
