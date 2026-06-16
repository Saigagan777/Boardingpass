import 'package:flutter/material.dart';
import '../models/user_profile.dart'; // To get CustomCard

class PremiumCustomCard extends StatelessWidget {
  final CustomCard card;
  final double width;
  final double height;

  const PremiumCustomCard({
    super.key,
    required this.card,
    this.width = 300,
    this.height = 190,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E2DD), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildLayout(),
    );
  }

  Widget _buildLayout() {
    switch (card.template) {
      case '50-50 Split':
        return Row(
          children: [
            // Left Image (42%)
            Container(
              width: width * 0.42,
              height: height,
              decoration: BoxDecoration(
                image: card.imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(card.imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: const Color(0xFFE8E2DD),
              ),
              child: card.imageUrl.isEmpty
                  ? const Icon(Icons.image_outlined, color: Color(0xFF8C736B))
                  : null,
            ),
            // Right Text (58%)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      card.title.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: Color(0xFF7A432D),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        card.description,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 10.5,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF3E1F11),
                        ),
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

      case 'Top Image / Bottom Text':
        return Column(
          children: [
            // Top Image (52%)
            Container(
              height: height * 0.52,
              width: double.infinity,
              decoration: BoxDecoration(
                image: card.imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(card.imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: const Color(0xFFE8E2DD),
              ),
              child: card.imageUrl.isEmpty
                  ? const Icon(Icons.image_outlined, color: Color(0xFF8C736B))
                  : null,
            ),
            // Bottom Text (48%)
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: const Color(0xFFFAF7F5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: const TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E1F11),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: Text(
                        card.description,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 10,
                          height: 1.3,
                          color: Color(0xFF8C736B),
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

      case 'Image Overlay':
      default:
        return Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: card.imageUrl.isNotEmpty
                  ? Image.network(
                      card.imageUrl,
                      fit: BoxFit.cover,
                    )
                  : Container(color: const Color(0xFFE8E2DD)),
            ),
            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
            ),
            // Foreground Content
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    style: const TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.description,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      height: 1.35,
                      color: Colors.white70,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }
}
