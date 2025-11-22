import 'dart:math';
import 'package:dartantic_evolution/dartantic_evolution.dart';
import 'package:uuid/uuid.dart';

// Example configuration class
class SimpleConfig extends EvolvableConfiguration<SimpleConfig> implements Tunable {
  final String _id;
  final Map<String, num> _numericParams;
  final Map<String, dynamic> _discreteParams;
  
  SimpleConfig({
    String? id,
    Map<String, num>? numericParams,
    Map<String, dynamic>? discreteParams,
  }) : _id = id ?? Uuid().v4(),
       _numericParams = Map.from(numericParams ?? {'learningRate': 0.01, 'batchSize': 32}),
       _discreteParams = Map.from(discreteParams ?? {'optimizer': 'adam'});

  @override
  SimpleConfig clone() {
    return SimpleConfig(
      numericParams: _numericParams,
      discreteParams: _discreteParams,
    );
  }

  @override
  String get id => _id;

  @override
  Map<String, dynamic> get metadata => {};

  @override
  Map<String, num> get numericParameters => _numericParams;

  @override
  void setNumericParameter(String key, num value) {
    _numericParams[key] = value;
  }

  @override
  Map<String, (num, num)> get parameterRanges => {
    'learningRate': (0.0001, 0.1),
    'batchSize': (16, 128),
  };

  @override
  Map<String, dynamic> get discreteParameters => _discreteParams;

  @override
  void setDiscreteParameter(String key, dynamic value) {
    _discreteParams[key] = value;
  }

  @override
  Map<String, List<dynamic>> get discreteOptions => {
    'optimizer': ['adam', 'sgd', 'rmsprop'],
  };
  
  @override
  String toString() => 'Config(lr: ${_numericParams['learningRate']?.toStringAsFixed(4)}, batch: ${_numericParams['batchSize']}, opt: ${_discreteParams['optimizer']})';
}

void main() async {
  // 1. Initialize population
  var initialPopulation = List.generate(10, (_) => SimpleConfig());
  
  // 2. Setup gene pool
  var pool = ConfigurationGenePool<SimpleConfig>(
    initialPopulation: initialPopulation,
    mutationStrategies: [
      ParameterTweakMutation(strength: 0.2),
      ParameterSwapMutation(),
    ],
    selectionStrategy: TournamentSelection(tournamentSize: 3),
    crossoverStrategy: UniformCrossover(),
    populationSize: 10,
    mutationRate: 0.3,
    crossoverRate: 0.5,
  );

  print('Initial population created.');

  // 3. Evolution loop
  for (var i = 0; i < 5; i++) {
    var generation = pool.currentGeneration;
    print('\nGeneration ${generation.number}:');
    
    // Evaluate fitness (simulated)
    var fitnessScores = <String, double>{};
    for (var config in generation.population) {
      // Simulate fitness: target lr=0.05, batch=64, opt='adam'
      var lr = config.numericParameters['learningRate']!;
      var batch = config.numericParameters['batchSize']!;
      var opt = config.discreteParameters['optimizer'];
      
      var score = 0.0;
      score -= (lr - 0.05).abs() * 100; // Penalty for lr deviation
      score -= (batch - 64).abs();      // Penalty for batch deviation
      if (opt == 'adam') score += 10.0; // Bonus for correct optimizer
      
      fitnessScores[config.id] = score;
    }
    
    // Record evaluation
    pool.recordEvaluation(fitnessScores);
    
    // Print best
    var best = generation.bestPerformer;
    if (best != null) {
      print('Best: $best (Score: ${fitnessScores[best.id]?.toStringAsFixed(2)})');
    }
    
    // Evolve
    await pool.evolve();
  }
}
