/// Review data model matching Yelp dataset structure
class Review {
  Review({
    required this.reviewId,
    required this.userId,
    required this.businessId,
    required this.stars,
    required this.date,
    required this.text,
    required this.useful,
    required this.funny,
    required this.cool,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      reviewId: json['review_id'] as String,
      userId: json['user_id'] as String,
      businessId: json['business_id'] as String,
      stars: json['stars'] as int,
      date: DateTime.parse(json['date'] as String),
      text: json['text'] as String,
      useful: json['useful'] as int,
      funny: json['funny'] as int,
      cool: json['cool'] as int,
    );
  }

  final String reviewId;
  final String userId;
  final String businessId;
  final int stars;
  final DateTime date;
  final String text;
  final int useful;
  final int funny;
  final int cool;

  Map<String, dynamic> toJson() {
    return {
      'review_id': reviewId,
      'user_id': userId,
      'business_id': businessId,
      'stars': stars,
      'date': date.toIso8601String(),
      'text': text,
      'useful': useful,
      'funny': funny,
      'cool': cool,
    };
  }
}
