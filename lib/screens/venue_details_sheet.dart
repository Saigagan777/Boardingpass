import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/venue.dart';
import '../models/enums.dart';
import 'map_webview.dart';

class VenueDetailsSheet extends StatelessWidget {
  final Venue venue;
  final bool showConfirmButton;
  final ValueChanged<Venue>? onConfirm;

  const VenueDetailsSheet({
    super.key,
    required this.venue,
    this.showConfirmButton = true,
    this.onConfirm,
  });

  static void show(
    BuildContext context, {
    required Venue venue,
    bool showConfirmButton = true,
    ValueChanged<Venue>? onConfirm,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VenueDetailsSheet(
        venue: venue,
        showConfirmButton: showConfirmButton,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F5),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE8E2DD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover Image
                  if (venue.coverImage.isNotEmpty)
                    Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(venue.coverImage),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and Category Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                venue.name,
                                style: const TextStyle(
                                  fontFamily: 'PlayfairDisplay',
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3E1F11),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7A432D).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                venue.category.displayName,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7A432D),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Rating Summary
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              venue.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3E1F11),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${venue.ratingCount} reviews)',
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                color: Color(0xFF8C736B),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '\$' * venue.priceLevel,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7A432D),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Description
                        Text(
                          venue.description,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            height: 1.5,
                            color: Color(0xFF5C473E),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Amenities row
                        const Text(
                          'AMENITIES',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Color(0xFF8C736B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildAmenityChip(Icons.local_parking, 'Parking', venue.parkingAvailable),
                            const SizedBox(width: 8),
                            _buildAmenityChip(Icons.wifi, 'WiFi', venue.wifiAvailable),
                            const SizedBox(width: 8),
                            _buildAmenityChip(Icons.wheelchair_pickup, 'Wheelchair', venue.wheelchairAccessible),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Location Details
                        const Text(
                          'LOCATION & MAP',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Color(0xFF8C736B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on, size: 18, color: Color(0xFF7A432D)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                venue.formattedAddress,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13.5,
                                  color: Color(0xFF3E1F11),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Embed Map
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            height: 160,
                            width: double.infinity,
                            child: MapWebView(
                              latitude: venue.latitude,
                              longitude: venue.longitude,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Contact info & buttons
                        const Text(
                          'INFO & CONTACT',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Color(0xFF8C736B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (venue.openingHours.isNotEmpty)
                          _buildContactRow(Icons.access_time, venue.openingHours),
                        if (venue.phone.isNotEmpty)
                          InkWell(
                            onTap: () => launchUrl(Uri.parse('tel:${venue.phone}')),
                            child: _buildContactRow(Icons.phone, venue.phone, isLink: true),
                          ),
                        if (venue.website.isNotEmpty)
                          InkWell(
                            onTap: () => launchUrl(Uri.parse(venue.website)),
                            child: _buildContactRow(Icons.public, 'Visit website', isLink: true),
                          ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Confirm button banner
          if (showConfirmButton)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              color: const Color(0xFFFAF7F5),
              width: double.infinity,
              height: 76,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A432D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  onConfirm?.call(venue);
                },
                child: const Text(
                  'Confirm Venue',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAmenityChip(IconData icon, String label, bool available) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: available ? Colors.white : const Color(0xFFE8E2DD).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: available ? const Color(0xFFE5A475) : const Color(0xFFE8E2DD),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: available ? const Color(0xFF7A432D) : const Color(0xFF8C736B),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: available ? const Color(0xFF3E1F11) : const Color(0xFF8C736B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String value, {bool isLink = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF8C736B)),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              color: isLink ? const Color(0xFF7A432D) : const Color(0xFF3E1F11),
              fontWeight: isLink ? FontWeight.bold : FontWeight.normal,
              decoration: isLink ? TextDecoration.underline : null,
            ),
          ),
        ],
      ),
    );
  }
}
