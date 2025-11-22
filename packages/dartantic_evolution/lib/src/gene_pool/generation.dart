import '../interfaces/evolvable_configuration.dart';

class Generation<T extends EvolvableConfiguration<T>> {
  final int number;
  final List<T> population;
  final Map<String, double> fitnessScores;
  final Map<String, Map<String, double>> multiObjectiveScores;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  Generation({
    required this.number,
    required this.population,
    required this.fitnessScores,
    this.multiObjectiveScores = const {},
    DateTime? timestamp,
    this.metadata = const {},
  }) : timestamp = timestamp ?? DateTime.now();
  
  T? get bestPerformer {
    if (population.isEmpty) return null;
    return population.reduce((a, b) {
      var scoreA = fitnessScores[a.id] ?? double.negativeInfinity;
      var scoreB = fitnessScores[b.id] ?? double.negativeInfinity;
      return scoreA > scoreB ? a : b;
    });
  }
}
