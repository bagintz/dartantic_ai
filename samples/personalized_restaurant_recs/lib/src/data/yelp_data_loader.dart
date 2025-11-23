import 'dart:convert';
import 'dart:io';
import '../models/restaurant.dart';
import '../models/review.dart';

/// Loads Yelp dataset from /tmp/yelp_dataset or falls back to synthetic data
class YelpDataLoader {
  YelpDataLoader({
    this.datasetPath = '/tmp/yelp_dataset',
  });

  final String datasetPath;

  /// Check if Yelp dataset is available
  Future<bool> isYelpDataAvailable() async {
    final businessFile = File('$datasetPath/yelp_academic_dataset_business.json');
    final reviewFile = File('$datasetPath/yelp_academic_dataset_review.json');

    return await businessFile.exists() && await reviewFile.exists();
  }

  /// Load restaurants by zip code/postal code (matches by 3-digit prefix)
  Future<List<Restaurant>> loadRestaurantsByZipCode(String zipCode) async {
    final businessFile = File('$datasetPath/yelp_academic_dataset_business.json');

    if (!await businessFile.exists()) {
      throw Exception('Business dataset not found at $datasetPath');
    }

    // Use first 3 digits for broader area matching
    final zipPrefix = zipCode.length >= 3 ? zipCode.substring(0, 3) : zipCode;

    final restaurants = <Restaurant>[];
    final lines = businessFile.openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (line.trim().isEmpty) continue;

      try {
        final json = jsonDecode(line) as Map<String, dynamic>;

        // Check if this business matches the zip code prefix
        final postalCode = json['postal_code'] as String?;
        if (postalCode == null || postalCode.length < 3) continue;

        final restaurantPrefix = postalCode.substring(0, 3);
        if (restaurantPrefix != zipPrefix) continue;

        // Only include restaurants (has categories)
        final categories = json['categories'] as String?;
        if (categories == null || !_isRestaurant(categories)) continue;

        // Convert to our Restaurant model
        final restaurant = _parseRestaurant(json);
        if (restaurant != null) {
          restaurants.add(restaurant);
        }
      } catch (e) {
        // Skip malformed lines
        continue;
      }
    }

    return restaurants;
  }

  /// Load reviews for specific business IDs
  Future<Map<String, List<Review>>> loadReviewsForBusinesses(
    List<String> businessIds,
  ) async {
    final reviewFile = File('$datasetPath/yelp_academic_dataset_review.json');

    if (!await reviewFile.exists()) {
      throw Exception('Review dataset not found at $datasetPath');
    }

    final businessIdSet = businessIds.toSet();
    final reviewsByBusiness = <String, List<Review>>{};

    // Initialize empty lists
    for (final id in businessIds) {
      reviewsByBusiness[id] = [];
    }

    final lines = reviewFile.openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    var count = 0;
    await for (final line in lines) {
      if (line.trim().isEmpty) continue;

      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        final businessId = json['business_id'] as String?;

        if (businessId != null && businessIdSet.contains(businessId)) {
          final review = _parseReview(json);
          if (review != null) {
            reviewsByBusiness[businessId]!.add(review);
            count++;
          }
        }

        // Stop after collecting enough reviews (optimization)
        if (count > 1000) break;
      } catch (e) {
        // Skip malformed lines
        continue;
      }
    }

    return reviewsByBusiness;
  }

  /// Parse Yelp business JSON to Restaurant model
  Restaurant? _parseRestaurant(Map<String, dynamic> json) {
    try {
      return Restaurant(
        businessId: json['business_id'] as String,
        name: json['name'] as String,
        address: json['address'] as String? ?? '',
        city: json['city'] as String? ?? '',
        state: json['state'] as String? ?? '',
        postalCode: json['postal_code'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
        stars: (json['stars'] as num?)?.toDouble() ?? 0.0,
        reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
        categories: (json['categories'] as String?)?.split(', ') ?? [],
        attributes: json['attributes'] as Map<String, dynamic>? ?? {},
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse Yelp review JSON to Review model
  Review? _parseReview(Map<String, dynamic> json) {
    try {
      final reviewId = json['review_id'] as String;
      final userId = json['user_id'] as String;
      final businessId = json['business_id'] as String;
      final text = json['text'] as String;
      final stars = (json['stars'] as num?)?.toInt() ?? 0;
      final useful = (json['useful'] as num?)?.toInt() ?? 0;
      final funny = (json['funny'] as num?)?.toInt() ?? 0;
      final cool = (json['cool'] as num?)?.toInt() ?? 0;
      final dateStr = json['date'] as String;
      final date = DateTime.parse(dateStr);

      return Review(
        reviewId: reviewId,
        userId: userId,
        businessId: businessId,
        text: text,
        stars: stars,
        useful: useful,
        funny: funny,
        cool: cool,
        date: date,
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if categories indicate this is a restaurant
  bool _isRestaurant(String categories) {
    final lowerCategories = categories.toLowerCase();
    final restaurantKeywords = [
      'restaurant',
      'food',
      'cafe',
      'bar',
      'pizza',
      'burger',
      'sushi',
      'mexican',
      'italian',
      'chinese',
      'thai',
      'indian',
      'japanese',
      'american',
      'dining',
      'eatery',
    ];

    return restaurantKeywords.any((keyword) => lowerCategories.contains(keyword));
  }
}
