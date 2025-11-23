/// User persona for personalized recommendations
class UserPersona {
  UserPersona({
    required this.id,
    required this.name,
    required this.description,
    required this.priorities,
    this.preferences = const {},
  });

  final String id;
  final String name;
  final String description;
  final List<String> priorities;
  final Map<String, dynamic> preferences;

  // Example personas for testing personalization
  static final UserPersona foodie = UserPersona(
    id: 'foodie',
    name: 'The Foodie',
    description:
        'Prioritizes food quality, creativity, and authenticity above all else',
    priorities: ['food_quality', 'authenticity', 'creativity'],
    preferences: {
      'detail_level': 'high',
      'focus_areas': ['ingredients', 'preparation', 'presentation'],
    },
  );

  static final UserPersona familyOriented = UserPersona(
    id: 'family',
    name: 'Family-Oriented',
    description: 'Values kid-friendly atmosphere, portion sizes, and value',
    priorities: ['family_friendly', 'value', 'portion_size'],
    preferences: {
      'detail_level': 'medium',
      'focus_areas': ['menu_variety', 'atmosphere', 'pricing'],
    },
  );

  static final UserPersona quickBite = UserPersona(
    id: 'quick',
    name: 'Quick Bite',
    description: 'Needs fast service, convenient location, and consistent quality',
    priorities: ['speed', 'convenience', 'consistency'],
    preferences: {
      'detail_level': 'low',
      'focus_areas': ['service_speed', 'location', 'reliability'],
    },
  );

  static final UserPersona dateNight = UserPersona(
    id: 'date_night',
    name: 'Date Night',
    description: 'Seeks romantic ambiance, excellent service, and memorable experience',
    priorities: ['ambiance', 'service', 'experience'],
    preferences: {
      'detail_level': 'high',
      'focus_areas': ['atmosphere', 'service_quality', 'wine_selection'],
    },
  );

  static List<UserPersona> get allPersonas => [
        foodie,
        familyOriented,
        quickBite,
        dateNight,
      ];
}
