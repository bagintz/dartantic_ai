import 'package:uuid/uuid.dart';

/// Standard Operating Procedure for Restaurant Analysis - the "genome"
/// that controls workflow behavior and can be evolved over time
class RestaurantAnalysisSOP {
  RestaurantAnalysisSOP({
    String? id,
    required this.plannerPrompt,
    required this.reviewRetrieverK,
    required this.synthesizerPrompt,
    required this.synthesizerModel,
    required this.useDataAnalyst,
    required this.useServiceAnalyst,
    required this.personalizationLevel,
    this.generation = 0,
    this.parentId,
  }) : id = id ?? const Uuid().v4();

  final String id;
  final int generation;
  final String? parentId;

  // Evolvable parameters
  final String plannerPrompt;
  final int reviewRetrieverK; // How many reviews to retrieve
  final String synthesizerPrompt;
  final String synthesizerModel;
  final bool useDataAnalyst; // Whether to include data analyst agent
  final bool useServiceAnalyst; // Whether to include service analyst agent
  final String personalizationLevel; // 'low', 'medium', 'high'

  /// Create baseline SOP - the starting point for evolution
  factory RestaurantAnalysisSOP.baseline() {
    return RestaurantAnalysisSOP(
      plannerPrompt: '''You are a restaurant analysis planner. Your job is to coordinate analysis of restaurant reviews.
Break down the analysis into clear steps and identify what information needs to be extracted.''',
      reviewRetrieverK: 5,
      synthesizerPrompt: '''Synthesize the analysis results into a concise, helpful recommendation.
Focus on providing actionable insights for the user.''',
      synthesizerModel: 'gpt-4o-mini',
      useDataAnalyst: true,
      useServiceAnalyst: false,
      personalizationLevel: 'low',
      generation: 0,
    );
  }

  /// Create a mutated copy of this SOP
  RestaurantAnalysisSOP mutate({
    String? plannerPrompt,
    int? reviewRetrieverK,
    String? synthesizerPrompt,
    String? synthesizerModel,
    bool? useDataAnalyst,
    bool? useServiceAnalyst,
    String? personalizationLevel,
  }) {
    return RestaurantAnalysisSOP(
      plannerPrompt: plannerPrompt ?? this.plannerPrompt,
      reviewRetrieverK: reviewRetrieverK ?? this.reviewRetrieverK,
      synthesizerPrompt: synthesizerPrompt ?? this.synthesizerPrompt,
      synthesizerModel: synthesizerModel ?? this.synthesizerModel,
      useDataAnalyst: useDataAnalyst ?? this.useDataAnalyst,
      useServiceAnalyst: useServiceAnalyst ?? this.useServiceAnalyst,
      personalizationLevel: personalizationLevel ?? this.personalizationLevel,
      generation: generation + 1,
      parentId: id,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'generation': generation,
      'parent_id': parentId,
      'planner_prompt': plannerPrompt,
      'review_retriever_k': reviewRetrieverK,
      'synthesizer_prompt': synthesizerPrompt,
      'synthesizer_model': synthesizerModel,
      'use_data_analyst': useDataAnalyst,
      'use_service_analyst': useServiceAnalyst,
      'personalization_level': personalizationLevel,
    };
  }

  factory RestaurantAnalysisSOP.fromJson(Map<String, dynamic> json) {
    return RestaurantAnalysisSOP(
      id: json['id'] as String,
      generation: json['generation'] as int,
      parentId: json['parent_id'] as String?,
      plannerPrompt: json['planner_prompt'] as String,
      reviewRetrieverK: json['review_retriever_k'] as int,
      synthesizerPrompt: json['synthesizer_prompt'] as String,
      synthesizerModel: json['synthesizer_model'] as String,
      useDataAnalyst: json['use_data_analyst'] as bool,
      useServiceAnalyst: json['use_service_analyst'] as bool,
      personalizationLevel: json['personalization_level'] as String,
    );
  }

  @override
  String toString() {
    return 'RestaurantAnalysisSOP(id: $id, gen: $generation, k: $reviewRetrieverK, '
        'analysts: [${useDataAnalyst ? "data" : ""}${useServiceAnalyst ? " service" : ""}], '
        'personalization: $personalizationLevel)';
  }
}
