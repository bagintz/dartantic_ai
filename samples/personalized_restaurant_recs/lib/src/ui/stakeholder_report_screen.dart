import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../models/user_persona.dart';

/// Restaurant recommendation with analysis
class RestaurantRecommendation {
  RestaurantRecommendation({
    required this.restaurant,
    required this.analysis,
    required this.score,
    required this.rank,
  });

  final Restaurant restaurant;
  final String analysis;
  final double score;
  final int rank;
}

/// Fourth screen: Final stakeholder report with top recommendations
class StakeholderReportScreen extends StatelessWidget {
  const StakeholderReportScreen({
    required this.recommendations,
    required this.persona,
    required this.zipCode,
    required this.generationsProcessed,
    required this.onRestart,
    super.key,
  });

  final List<RestaurantRecommendation> recommendations;
  final UserPersona persona;
  final String zipCode;
  final int generationsProcessed;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Your Personalized Recommendations',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Based on $generationsProcessed generations of self-improvement',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),

          // Summary card
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Diner Profile: ${persona.name}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(persona.description),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.location_on),
                      const SizedBox(width: 12),
                      Text('Location: Zip Code $zipCode'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.restaurant),
                      const SizedBox(width: 12),
                      Text('Found ${recommendations.length} top matches'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Recommendations
          Text(
            'Top Recommendations',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          ...recommendations.map((rec) => _buildRecommendationCard(context, rec)),

          const SizedBox(height: 24),

          // Restart button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.refresh),
              label: const Text('Start New Search'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(
    BuildContext context,
    RestaurantRecommendation rec,
  ) {
    final medalColors = [
      Colors.amber, // Gold
      Colors.grey[400], // Silver
      Colors.brown[300], // Bronze
    ];

    final medalIcons = [
      '🥇',
      '🥈',
      '🥉',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with rank and score
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: medalColors[rec.rank - 1],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      medalIcons[rec.rank - 1],
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rec.restaurant.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${rec.restaurant.stars.toStringAsFixed(1)} stars',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '${rec.restaurant.reviewCount} reviews',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Match: ${(rec.score * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Categories
            Wrap(
              spacing: 8,
              children: rec.restaurant.categories.take(3).map((category) {
                return Chip(
                  label: Text(category),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Location
            Row(
              children: [
                const Icon(Icons.location_on, size: 16),
                const SizedBox(width: 4),
                Text('${rec.restaurant.city}, ${rec.restaurant.state}'),
              ],
            ),
            const SizedBox(height: 16),

            // AI Analysis
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'AI-Powered Analysis',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(rec.analysis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
