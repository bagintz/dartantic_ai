import '../models/restaurant.dart';
import '../models/review.dart';
import '../models/user_persona.dart';
import 'synthetic_data.dart';
import 'yelp_data_loader.dart';

/// Data source type
enum DataSource {
  yelp,
  synthetic,
}

/// Unified data provider that uses Yelp data when available, synthetic otherwise
class DataProvider {
  DataProvider({
    int? seed,
  })  : _yelpLoader = YelpDataLoader(),
        _syntheticGenerator = SyntheticDataGenerator(seed: seed ?? 42);

  final YelpDataLoader _yelpLoader;
  final SyntheticDataGenerator _syntheticGenerator;

  DataSource? _dataSource;

  /// Initialize and determine which data source to use
  Future<DataSource> initialize() async {
    if (await _yelpLoader.isYelpDataAvailable()) {
      _dataSource = DataSource.yelp;
      return DataSource.yelp;
    } else {
      _dataSource = DataSource.synthetic;
      return DataSource.synthetic;
    }
  }

  /// Get data source being used
  DataSource get dataSource {
    if (_dataSource == null) {
      throw StateError('DataProvider not initialized. Call initialize() first.');
    }
    return _dataSource!;
  }

  /// Load restaurants by zip code
  Future<List<Restaurant>> loadRestaurantsByZipCode(String zipCode) async {
    if (_dataSource == null) {
      await initialize();
    }

    if (_dataSource == DataSource.yelp) {
      try {
        final restaurants = await _yelpLoader.loadRestaurantsByZipCode(zipCode);
        if (restaurants.isNotEmpty) {
          return restaurants;
        }
        // Fall back to synthetic if no restaurants found in zip code
      } catch (e) {
        // Fall back to synthetic on error
      }
    }

    // Use synthetic data for the requested zip code
    final dataset = _syntheticGenerator.generateDataset(
      restaurantCount: 10,
      reviewsPerRestaurant: 20,
      zipCode: zipCode,
    );
    return dataset['restaurants'] as List<Restaurant>;
  }

  /// Load reviews for restaurants
  Future<Map<String, List<Review>>> loadReviews(
    List<Restaurant> restaurants,
  ) async {
    if (_dataSource == null) {
      await initialize();
    }

    if (_dataSource == DataSource.yelp) {
      try {
        final businessIds = restaurants.map((r) => r.businessId).toList();
        return await _yelpLoader.loadReviewsForBusinesses(businessIds);
      } catch (e) {
        // Fall back to synthetic on error
      }
    }

    // Use synthetic data - generate reviews for each restaurant
    final reviewsByRestaurant = <String, List<Review>>{};
    for (final restaurant in restaurants) {
      reviewsByRestaurant[restaurant.businessId] =
          _syntheticGenerator.generateReviews(restaurant, count: 20);
    }
    return reviewsByRestaurant;
  }

  /// Get sample user personas
  List<UserPersona> getSamplePersonas() {
    return UserPersona.allPersonas;
  }
}
