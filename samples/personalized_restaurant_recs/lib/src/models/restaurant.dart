/// Restaurant business data model matching Yelp dataset structure
class Restaurant {
  Restaurant({
    required this.businessId,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.latitude,
    required this.longitude,
    required this.stars,
    required this.reviewCount,
    required this.categories,
    this.attributes = const {},
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      businessId: json['business_id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      city: json['city'] as String,
      state: json['state'] as String,
      postalCode: json['postal_code'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      stars: (json['stars'] as num).toDouble(),
      reviewCount: json['review_count'] as int,
      categories: (json['categories'] as String?)?.split(', ') ?? [],
      attributes: json['attributes'] as Map<String, dynamic>? ?? {},
    );
  }

  final String businessId;
  final String name;
  final String address;
  final String city;
  final String state;
  final String postalCode;
  final double latitude;
  final double longitude;
  final double stars;
  final int reviewCount;
  final List<String> categories;
  final Map<String, dynamic> attributes;

  Map<String, dynamic> toJson() {
    return {
      'business_id': businessId,
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'postal_code': postalCode,
      'latitude': latitude,
      'longitude': longitude,
      'stars': stars,
      'review_count': reviewCount,
      'categories': categories.join(', '),
      'attributes': attributes,
    };
  }
}
