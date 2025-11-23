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
    print('[DataProvider] Checking for Yelp dataset at: ${_yelpLoader.datasetPath}');

    if (await _yelpLoader.isYelpDataAvailable()) {
      print('[DataProvider] ✓ Yelp dataset found! Using real Yelp data.');
      _dataSource = DataSource.yelp;
      return DataSource.yelp;
    } else {
      print('[DataProvider] ✗ Yelp dataset not found at ${_yelpLoader.datasetPath}');
      print('[DataProvider] → Falling back to synthetic demo data');
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

    print('[DataProvider] Loading restaurants for zip code: $zipCode');

    if (_dataSource == DataSource.yelp) {
      print('[DataProvider] Attempting to load from Yelp dataset...');
      try {
        final restaurants = await _yelpLoader.loadRestaurantsByZipCode(zipCode);
        if (restaurants.isNotEmpty) {
          print('[DataProvider] ✓ Loaded ${restaurants.length} restaurants from Yelp data');
          return restaurants;
        }
        print('[DataProvider] ✗ No restaurants found in Yelp data for zip $zipCode');
        print('[DataProvider] → Falling back to synthetic data');
        _dataSource = DataSource.synthetic; // Update data source on fallback
      } catch (e) {
        print('[DataProvider] ✗ Error loading Yelp data: $e');
        print('[DataProvider] → Falling back to synthetic data');
        _dataSource = DataSource.synthetic; // Update data source on fallback
      }
    }

    // Use synthetic data for the requested zip code
    print('[DataProvider] Generating 10 synthetic restaurants for zip $zipCode...');
    final dataset = _syntheticGenerator.generateDataset(
      restaurantCount: 10,
      reviewsPerRestaurant: 20,
      zipCode: zipCode,
    );
    final restaurants = dataset['restaurants'] as List<Restaurant>;
    print('[DataProvider] ✓ Generated ${restaurants.length} synthetic restaurants');
    return restaurants;
  }

  /// Load reviews for restaurants
  Future<Map<String, List<Review>>> loadReviews(
    List<Restaurant> restaurants,
  ) async {
    if (_dataSource == null) {
      await initialize();
    }

    print('[DataProvider] Loading reviews for ${restaurants.length} restaurants...');

    if (_dataSource == DataSource.yelp) {
      print('[DataProvider] Attempting to load reviews from Yelp dataset...');
      try {
        final businessIds = restaurants.map((r) => r.businessId).toList();
        final reviews = await _yelpLoader.loadReviewsForBusinesses(businessIds);
        final totalReviews = reviews.values.fold(0, (sum, list) => sum + list.length);
        print('[DataProvider] ✓ Loaded $totalReviews reviews from Yelp data');
        return reviews;
      } catch (e) {
        print('[DataProvider] ✗ Error loading Yelp reviews: $e');
        print('[DataProvider] → Falling back to synthetic reviews');
        _dataSource = DataSource.synthetic; // Update data source on fallback
      }
    }

    // Use synthetic data - generate reviews for each restaurant
    print('[DataProvider] Generating synthetic reviews (20 per restaurant)...');
    final reviewsByRestaurant = <String, List<Review>>{};
    for (final restaurant in restaurants) {
      reviewsByRestaurant[restaurant.businessId] =
          _syntheticGenerator.generateReviews(restaurant, count: 20);
    }
    final totalReviews = reviewsByRestaurant.values.fold(0, (sum, list) => sum + list.length);
    print('[DataProvider] ✓ Generated $totalReviews synthetic reviews');
    return reviewsByRestaurant;
  }

  /// Get sample user personas
  List<UserPersona> getSamplePersonas() {
    return UserPersona.allPersonas;
  }
}
