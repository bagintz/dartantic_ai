import 'dart:math';
import '../interfaces/evolvable_configuration.dart';
import '../interfaces/mutation_strategy.dart';
import '../interfaces/tunable.dart';

class ParameterSwapMutation<T extends EvolvableConfiguration<T>> implements MutationStrategy<T> {
  final Random _random = Random();

  @override
  String get name => 'ParameterSwap';

  @override
  Future<T> mutate(T configuration, {double mutationRate = 0.1}) async {
    if (configuration is! Tunable) {
      return configuration;
    }

    var clone = configuration.clone();
    var tunable = clone as Tunable;
    var params = tunable.discreteParameters;
    var options = tunable.discreteOptions;

    for (var key in params.keys) {
      if (_random.nextDouble() < mutationRate) {
        var choices = options[key];
        if (choices != null && choices.isNotEmpty) {
          var newValue = choices[_random.nextInt(choices.length)];
          tunable.setDiscreteParameter(key, newValue);
        }
      }
    }

    return clone;
  }
}
