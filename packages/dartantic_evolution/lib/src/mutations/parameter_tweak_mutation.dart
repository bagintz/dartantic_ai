import 'dart:math';
import '../interfaces/evolvable_configuration.dart';
import '../interfaces/mutation_strategy.dart';
import '../interfaces/tunable.dart';

class ParameterTweakMutation<T extends EvolvableConfiguration<T>> implements MutationStrategy<T> {
  final Random _random = Random();
  final double strength;

  ParameterTweakMutation({this.strength = 0.1});

  @override
  String get name => 'ParameterTweak';

  @override
  Future<T> mutate(T configuration, {double mutationRate = 0.1}) async {
    if (configuration is! Tunable) {
      return configuration;
    }
    
    var clone = configuration.clone();
    var tunable = clone as Tunable;
    var params = tunable.numericParameters;
    var ranges = tunable.parameterRanges;

    for (var key in params.keys) {
      if (_random.nextDouble() < mutationRate) {
        var current = params[key]!;
        var range = ranges[key];
        
        if (range != null) {
          var span = range.$2 - range.$1;
          var delta = (span * strength) * (_random.nextDouble() * 2 - 1);
          var newValue = (current + delta).clamp(range.$1, range.$2);
          tunable.setNumericParameter(key, newValue);
        }
      }
    }
    
    return clone;
  }
}
