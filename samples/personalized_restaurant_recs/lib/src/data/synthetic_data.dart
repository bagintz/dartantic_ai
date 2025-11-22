import 'dart:math';
import '../models/restaurant.dart';
import '../models/review.dart';

/// Generates synthetic restaurant and review data for testing
class SyntheticDataGenerator {
  SyntheticDataGenerator({int? seed}) : _random = Random(seed);

  final Random _random;

  static const _restaurantNames = [
    "Luigi's Italian Bistro",
    'The Golden Dragon',
    'Mama Rosa Trattoria',
    'Sakura Sushi House',
    'El Mariachi',
    'Le Petit Café',
    'The Burger Joint',
    'Spice of India',
    'Tokyo Ramen Bar',
    'Mediterranean Grill',
  ];

  static const _categories = [
    'Italian',
    'Chinese',
    'Japanese',
    'Mexican',
    'French',
    'American',
    'Indian',
    'Mediterranean',
    'Sushi',
    'Fast Food',
  ];

  static const _positiveReviewTemplates = [
    'Amazing {aspect}! The {dish} was perfectly prepared and full of flavor. Will definitely come back!',
    'Fantastic experience! The {aspect} exceeded expectations. {dish} was outstanding.',
    'Love this place! Great {aspect} and the {dish} is to die for. Highly recommend!',
    'Wonderful {aspect}! Had the {dish} and it was absolutely delicious.',
    'Best {dish} in town! The {aspect} makes this place special.',
  ];

  static const _negativeReviewTemplates = [
    'Disappointing {aspect}. The {dish} was bland and overpriced.',
    'Not impressed. The {aspect} needs improvement and {dish} was mediocre at best.',
    'Expected better. The {aspect} was lacking and the {dish} was disappointing.',
    'Underwhelming experience. {aspect} could be much better, and the {dish} was nothing special.',
    'Would not recommend. Poor {aspect} and the {dish} was not worth it.',
  ];

  static const _mixedReviewTemplates = [
    'Good {aspect} but the {dish} was just okay. Mixed feelings about this place.',
    'The {aspect} was great, but {dish} needs work. Hit or miss.',
    'Decent {aspect}, though the {dish} could use improvement. Not bad overall.',
    'The {aspect} is a highlight, but {dish} was mediocre. Worth trying once.',
  ];

  static const _aspects = [
    'food quality',
    'service',
    'atmosphere',
    'value',
    'presentation',
  ];

  static const _dishes = [
    'pasta carbonara',
    'sushi rolls',
    'tacos',
    'ramen',
    'steak',
    'chicken tikka masala',
    'pad thai',
    'pizza',
    'burger',
    'salad',
  ];

  /// Generate a restaurant with realistic data
  Restaurant generateRestaurant(int index) {
    final nameIndex = index % _restaurantNames.length;
    final category = _categories[index % _categories.length];

    return Restaurant(
      businessId: 'rest_${index.toString().padLeft(5, "0")}',
      name: _restaurantNames[nameIndex],
      address: '${100 + _random.nextInt(900)} Main St',
      city: 'San Francisco',
      state: 'CA',
      postalCode: '94${_random.nextInt(100).toString().padLeft(3, "0")}',
      latitude: 37.7749 + (_random.nextDouble() - 0.5) * 0.1,
      longitude: -122.4194 + (_random.nextDouble() - 0.5) * 0.1,
      stars: 2.5 + _random.nextDouble() * 2.5, // 2.5 to 5.0
      reviewCount: 10 + _random.nextInt(200),
      categories: [category],
      attributes: {
        'good_for_kids': _random.nextBool(),
        'has_outdoor_seating': _random.nextBool(),
        'takes_reservations': _random.nextBool(),
      },
    );
  }

  /// Generate reviews for a restaurant
  List<Review> generateReviews(
    Restaurant restaurant, {
    int count = 20,
  }) {
    final reviews = <Review>[];
    final avgStars = restaurant.stars;

    for (var i = 0; i < count; i++) {
      final variance = _random.nextDouble() * 2 - 1; // -1 to 1
      var stars = (avgStars + variance).round().clamp(1, 5);

      String text;
      if (stars >= 4) {
        text = _generateReviewText(_positiveReviewTemplates);
      } else if (stars <= 2) {
        text = _generateReviewText(_negativeReviewTemplates);
      } else {
        text = _generateReviewText(_mixedReviewTemplates);
      }

      final daysAgo = _random.nextInt(365);
      final date = DateTime.now().subtract(Duration(days: daysAgo));

      reviews.add(
        Review(
          reviewId: 'rev_${restaurant.businessId}_$i',
          userId: 'user_${_random.nextInt(1000).toString().padLeft(4, "0")}',
          businessId: restaurant.businessId,
          stars: stars,
          date: date,
          text: text,
          useful: _random.nextInt(20),
          funny: _random.nextInt(10),
          cool: _random.nextInt(15),
        ),
      );
    }

    return reviews;
  }

  String _generateReviewText(List<String> templates) {
    final template = templates[_random.nextInt(templates.length)];
    final aspect = _aspects[_random.nextInt(_aspects.length)];
    final dish = _dishes[_random.nextInt(_dishes.length)];

    return template
        .replaceAll('{aspect}', aspect)
        .replaceAll('{dish}', dish);
  }

  /// Generate a complete dataset
  Map<String, dynamic> generateDataset({
    int restaurantCount = 10,
    int reviewsPerRestaurant = 20,
  }) {
    final restaurants = <Restaurant>[];
    final allReviews = <Review>[];

    for (var i = 0; i < restaurantCount; i++) {
      final restaurant = generateRestaurant(i);
      restaurants.add(restaurant);

      final reviews = generateReviews(
        restaurant,
        count: reviewsPerRestaurant,
      );
      allReviews.addAll(reviews);
    }

    return {
      'restaurants': restaurants,
      'reviews': allReviews,
    };
  }
}
