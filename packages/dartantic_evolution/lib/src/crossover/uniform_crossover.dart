import 'dart:math';
import '../interfaces/crossover_strategy.dart';
import '../interfaces/evolvable_configuration.dart';
import '../interfaces/tunable.dart';

class UniformCrossover<T extends EvolvableConfiguration<T>> implements CrossoverStrategy<T> {
  final Random _random = Random();

  @override
  String get name => 'UniformCrossover';

  @override
  Future<List<T>> crossover(T parentA, T parentB) async {
    if (parentA is! Tunable || parentB is! Tunable) {
      // Cannot crossover non-tunable, just return clones
      return [parentA.clone(), parentB.clone()];
    }

    var childA = parentA.clone();
    var childB = parentB.clone();
    
    var tunableA = childA as Tunable;
    var tunableB = childB as Tunable;
    
    var paramsA = (parentA as Tunable).numericParameters;
    var paramsB = (parentB as Tunable).numericParameters;
    
    // Crossover numeric parameters
    for (var key in paramsA.keys) {
      if (paramsB.containsKey(key)) {
        if (_random.nextBool()) {
          tunableA.setNumericParameter(key, paramsB[key]!);
          tunableB.setNumericParameter(key, paramsA[key]!);
        }
      }
    }
    
    // Crossover discrete parameters
    var dParamsA = (parentA as Tunable).discreteParameters;
    var dParamsB = (parentB as Tunable).discreteParameters;
    
    for (var key in dParamsA.keys) {
      if (dParamsB.containsKey(key)) {
        if (_random.nextBool()) {
          tunableA.setDiscreteParameter(key, dParamsB[key]);
          tunableB.setDiscreteParameter(key, dParamsA[key]);
        }
      }
    }

    return [childA, childB];
  }
}
