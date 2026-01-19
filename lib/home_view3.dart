import 'package:flutter/material.dart';
import 'package:hyellow_w/interests_related_posts.dart';

class HomeView3 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final List<Map<String, dynamic>> interests = [
      {'label': 'Photography', 'icon': Icons.camera_alt},
      {'label': 'Health | Fitness', 'icon': Icons.fitness_center},
      {'label': 'Film | Cinema', 'icon': Icons.movie},
      {'label': 'Technology', 'icon': Icons.developer_mode},
      {'label': 'Reality Gaming', 'icon': Icons.videogame_asset},
      {'label': 'Creative Art | Design', 'icon': Icons.brush},
      {'label': 'Fashion | Beauty', 'icon': Icons.checkroom},
      {'label': 'Mindfulness | Meditation', 'icon': Icons.spa},
      {'label': 'Entrepreneurship', 'icon': Icons.business_center},
      {'label': 'Sports', 'icon': Icons.sports_baseball},
      {'label': 'Startup Building | Indie Hacking', 'icon': Icons.rocket_launch},
      {'label': 'Animals | Pets', 'icon': Icons.pets},
      {'label': 'AI Art | Tools', 'icon': Icons.auto_awesome},
      {'label': 'Nature | Outdoors', 'icon': Icons.eco},
      {'label': 'Gardening', 'icon': Icons.local_florist},
      {'label': 'Music | Sound Culture', 'icon': Icons.music_note},
      {'label': 'Podcasts', 'icon': Icons.mic},
      {'label': 'Memes', 'icon': Icons.tag_faces},
      {'label': 'Dance | Choreography', 'icon': Icons.accessibility_new},
      {'label': 'History', 'icon': Icons.history_edu},
      {'label': 'Science', 'icon': Icons.science},
      {'label': 'Spirituality | Wellness', 'icon': Icons.self_improvement},
      {'label': 'Finance | Investing', 'icon': Icons.attach_money},
      {'label': 'Education | Learning', 'icon': Icons.school},
      {'label': 'Business', 'icon': Icons.work},
      {'label': 'Automobiles', 'icon': Icons.directions_car},
      {'label': 'Social Media | Blogging', 'icon': Icons.hub},
      {'label': 'Home Improvement | DIY', 'icon': Icons.home_repair_service},
      {'label': 'Crypto', 'icon': Icons.currency_bitcoin},
      {'label': 'Real Estate', 'icon': Icons.apartment},
      {'label': 'Cooking Techniques | Recipes', 'icon': Icons.restaurant_menu},
      {'label': 'Community Service', 'icon': Icons.volunteer_activism},
      {'label': 'Space | Astronomy', 'icon': Icons.rocket},
      {'label': 'Languages | Linguistics', 'icon': Icons.language},
      {'label': 'Day In The Life', 'icon': Icons.timer},
      {'label': 'Love', 'icon': Icons.favorite},
      {'label': 'Entertainment', 'icon': Icons.theaters},
      {'label': 'Environmental Sustainability', 'icon': Icons.energy_savings_leaf},
      {'label': 'Parenting | Family', 'icon': Icons.family_restroom},
      {'label': 'Travel | Places', 'icon': Icons.airplane_ticket},
      {'label': 'Theater | Performing Arts', 'icon': Icons.theater_comedy},
      {'label': 'Professional Development', 'icon': Icons.trending_up},
      {'label': 'Writing | Publishing', 'icon': Icons.edit},
    ];

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: interests.map((interest) {
            return _buildOutlinedInterestButton(
              context,
              theme,
              interest['label'],
              interest['icon'],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOutlinedInterestButton(
      BuildContext context,
      ThemeData theme,
      String label,
      IconData icon,
      ) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                InterestsRelatedPosts(initialInterest: label),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.dividerColor, // Adapts to theme
          ),
          borderRadius: BorderRadius.circular(0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: theme.iconTheme.color, // Dynamic icon color
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ), // Uses theme's text color
            ),
          ],
        ),
      ),
    );
  }
}
