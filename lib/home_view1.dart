import 'package:flutter/material.dart';
import 'package:hyellow_w/interests_related_posts.dart';
import 'user_list_screen.dart'; // Import your UserListScreen

class HomeView1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CustomDivider(),
          _buildCustomButton(context, 'Photography'),
          CustomDivider(),
          _buildCustomButton(context, 'Health | Fitness'),
          CustomDivider(),
          _buildCustomButton(context, 'Film | Cinema'),
          CustomDivider(),
          _buildCustomButton(context, 'Technology'),
          CustomDivider(),
          _buildCustomButton(context, 'Reality Gaming'),
          CustomDivider(),
          _buildCustomButton(context, 'Creative Art | Design'),
          CustomDivider(),
          _buildCustomButton(context, 'Fashion | Beauty'),
          CustomDivider(),
          _buildCustomButton(context, 'Mindfulness | Meditation'),
          CustomDivider(),
          _buildCustomButton(context, 'Entrepreneurship'),
          CustomDivider(),
          _buildCustomButton(context, 'Sports'),
          CustomDivider(),
          _buildCustomButton(context, 'Startup Building | Indie Hacking'),
          CustomDivider(),
          _buildCustomButton(context, 'Animals | Pets'),
          CustomDivider(),
          _buildCustomButton(context, 'AI Art | Tools'),
          CustomDivider(),
          _buildCustomButton(context, 'Nature | Outdoors'),
          CustomDivider(),
          _buildCustomButton(context, 'Gardening'),
          CustomDivider(),
          _buildCustomButton(context, 'Music | Sound Culture'),
          CustomDivider(),
          _buildCustomButton(context, 'Podcasts'),
          CustomDivider(),
          _buildCustomButton(context, 'Memes'),
          CustomDivider(),
          _buildCustomButton(context, 'Dance | Choreography'),
          CustomDivider(),
          _buildCustomButton(context, 'History'),
          CustomDivider(),
          _buildCustomButton(context, 'Science'),
          CustomDivider(),
          _buildCustomButton(context, 'Spirituality | Wellness'),
          CustomDivider(),
          _buildCustomButton(context, 'Finance | Investing'),
          CustomDivider(),
          _buildCustomButton(context, 'Education | Learning'),
          CustomDivider(),
          _buildCustomButton(context, 'Business'),
          CustomDivider(),
          _buildCustomButton(context, 'Automobiles'),
          CustomDivider(),
          _buildCustomButton(context, 'Social Media | Blogging'),
          CustomDivider(),
          _buildCustomButton(context, 'Home Improvement | DIY'),
          CustomDivider(),
          _buildCustomButton(context, 'Crypto'),
          CustomDivider(),
          _buildCustomButton(context, 'Real Estate'),
          CustomDivider(),
          _buildCustomButton(context, 'Cooking Techniques | Recipes'),
          CustomDivider(),
          _buildCustomButton(context, 'Community Service'),
          CustomDivider(),
          _buildCustomButton(context, 'Space | Astronomy'),
          CustomDivider(),
          _buildCustomButton(context, 'Languages | Linguistics'),
          CustomDivider(),
          _buildCustomButton(context, 'Day In The Life'),
          CustomDivider(),
          _buildCustomButton(context, 'Love'),
          CustomDivider(),
          _buildCustomButton(context, 'Entertainment'),
          CustomDivider(),
          _buildCustomButton(context, 'Environmental Sustainability'),
          CustomDivider(),
          _buildCustomButton(context, 'Parenting | Family'),
          CustomDivider(),
          _buildCustomButton(context, 'Travel | Places'),
          CustomDivider(),
          _buildCustomButton(context, 'Theater | Performing Arts'),
          CustomDivider(),
          _buildCustomButton(context, 'Professional Development'),
          CustomDivider(),
          _buildCustomButton(context, 'Writing | Publishing'),
          CustomDivider(),
        ],
      ),
    );
  }

  // Updated method to build a button with navigation to UserListScreen
  Widget _buildCustomButton(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: SizedBox(
        width: double.infinity,  // Make the button stretch horizontally
        height: 60,              // Adjust the height as needed to cover space
        child: GestureDetector(
          onTap: () {
            // Navigate to InterestsRelatedPosts and pass the selected interest as initialInterest
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => InterestsRelatedPosts(initialInterest: label), // Pass 'label' to initialInterest
              ),
            );
          },
          child: Container(
            alignment: Alignment.center, // Center the text
            child: Text(
              label,
              style: TextStyle(fontSize: 18),
            ),
            decoration: BoxDecoration(
              color: Colors.transparent, // Change to your desired color
            ),
          ),
        ),
      ),
    );
  }



}

class CustomDivider extends StatelessWidget {
  final Color color;
  final double thickness;
  final double indent;
  final double endIndent;

  const CustomDivider({
    this.color = Colors.grey,
    this.thickness = 1.0,
    this.indent = 40.0,
    this.endIndent = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: color,
      thickness: thickness,
      indent: indent,
      endIndent: endIndent,
    );
  }
}
