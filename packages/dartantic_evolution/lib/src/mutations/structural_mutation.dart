import 'dart:math';
import '../interfaces/evolvable_configuration.dart';
import '../interfaces/mutation_strategy.dart';
import '../interfaces/structurally_mutable.dart';

class StructuralMutation<T extends EvolvableConfiguration<T>> implements MutationStrategy<T> {
  final Random _random = Random();

  @override
  String get name => 'Structural';

  @override
  Future<T> mutate(T configuration, {double mutationRate = 0.1}) async {
    if (configuration is! StructurallyMutable) {
      return configuration;
    }

    var clone = configuration.clone();
    var mutable = clone as StructurallyMutable;

    if (_random.nextDouble() < mutationRate) {
      if (_random.nextBool()) {
        if (mutable.canAddComponent) {
          mutable.addComponent();
        }
      } else {
        if (mutable.canRemoveComponent) {
          mutable.removeComponent();
        }
      }
    }

    return clone;
  }
}
