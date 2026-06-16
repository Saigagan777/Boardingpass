import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../state_manager.dart';
import '../models/event.dart';
import 'map_webview.dart';

class EventsScreen extends StatefulWidget {
  final VoidCallback? onNext;
  const EventsScreen({super.key, this.onNext});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final AppStateManager _state = AppStateManager();
  int _activeSubTab = 0; // 0 for Upcoming, 1 for My Events
  String _selectedCategory = 'All';
  final Set<String> _bookmarkedEvents = {};

  final List<String> _categories = [
    'All',
    'Networking',
    'Workshops',
    'Meetups',
    'Business'
  ];

  String _getCategoryImageUrl(String category) {
    switch (category.toLowerCase()) {
      case 'networking':
        return 'https://images.unsplash.com/photo-1515187029135-18ee286d815b?w=600&q=80';
      case 'concerts':
      case 'music':
        return 'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=600&q=80';
      case 'workshops':
        return 'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?w=600&q=80';
      case 'meetups':
        return 'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=600&q=80';
      case 'comedy':
      case 'comedy shows':
        return 'https://images.unsplash.com/photo-1516280440614-37939bbacd6a?w=600&q=80';
      case 'business':
        return 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=600&q=80';
      default:
        return 'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?w=600&q=80';
    }
  }

  Future<List<Map<String, dynamic>>> _searchVenues(String query) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5');
      final response = await http.get(url, headers: {'User-Agent': 'BoardingPassApp/1.0'});
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.map((item) {
          return {
            'display_name': item['display_name'] as String,
            'lat': double.parse(item['lat'] as String),
            'lon': double.parse(item['lon'] as String),
          };
        }).toList();
      }
    } catch (e) {
      debugPrint('Geocoding search error: $e');
    }
    return [];
  }

  Map<String, double>? _extractCoordinatesFromUrl(String url) {
    final regex = RegExp(r'(?:place/|query=|@)(-?\d+\.\d+)\s*,\s*(-?\d+\.\d+)');
    final match = regex.firstMatch(url);
    if (match != null) {
      final lat = double.tryParse(match.group(1) ?? '');
      final lon = double.tryParse(match.group(2) ?? '');
      if (lat != null && lon != null) {
        return {'lat': lat, 'lon': lon};
      }
    }
    return null;
  }

  void _handleCreateEvent() {
    showDialog(
      context: context,
      builder: (context) {
        final titleController = TextEditingController();
        final locController = TextEditingController();
        final dateController = TextEditingController();
        final timeController = TextEditingController();
        final mapsController = TextEditingController();
        final priceController = TextEditingController(text: 'Free');
        String selectedCat = 'Networking';

        bool isGeocoding = false;
        double? latitude;
        double? longitude;
        String geocodeStatus = '';
        List<Map<String, dynamic>> searchResults = [];
        Timer? debounceTimer;
        bool isSelectingVenue = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFAF7F5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE8E2DD), width: 1.5),
              ),
              title: const Text(
                'Host a New Event',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3E1F11),
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EVENT TITLE',
                        style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Airport Networking Meetup',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CATEGORY',
                                  style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedCat,
                                  dropdownColor: Colors.white,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: _categories.where((c) => c != 'All').map((c) {
                                    return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDialogState(() {
                                        selectedCat = val;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PRICE / TICKET',
                                  style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: priceController,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Free or \$10',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DATE',
                                  style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: dateController,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    hintText: 'Select Date',
                                    suffixIcon: const Icon(Icons.calendar_today, size: 16, color: Color(0xFF7A432D)),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onTap: () async {
                                    final DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                                    );
                                    if (picked != null) {
                                      final List<String> months = [
                                        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                                      ];
                                      dateController.text = '${picked.day} ${months[picked.month - 1]}';
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'TIME',
                                  style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: timeController,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    hintText: 'Select Time',
                                    suffixIcon: const Icon(Icons.access_time, size: 16, color: Color(0xFF7A432D)),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onTap: () async {
                                    final TimeOfDay? picked = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.now(),
                                    );
                                    if (picked != null && context.mounted) {
                                      final localizations = MaterialLocalizations.of(context);
                                      timeController.text = localizations.formatTimeOfDay(picked);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'VENUE / LOCATION NAME',
                        style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: locController,
                              decoration: InputDecoration(
                                hintText: 'e.g. Gate 14 Lounge',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onChanged: (val) {
                                if (isSelectingVenue) return;
                                if (debounceTimer?.isActive ?? false) debounceTimer!.cancel();
                                debounceTimer = Timer(const Duration(milliseconds: 600), () async {
                                  final venue = val.trim();
                                  if (venue.isEmpty) {
                                    if (context.mounted) {
                                      setDialogState(() {
                                        searchResults = [];
                                        geocodeStatus = '';
                                      });
                                    }
                                    return;
                                  }
                                  if (context.mounted) {
                                    setDialogState(() {
                                      isGeocoding = true;
                                      geocodeStatus = 'Searching...';
                                      searchResults = [];
                                    });
                                  }
                                  final results = await _searchVenues(venue);
                                  if (context.mounted) {
                                    setDialogState(() {
                                      isGeocoding = false;
                                      searchResults = results;
                                      if (results.isNotEmpty) {
                                        geocodeStatus = '✓ Select location below:';
                                      } else {
                                        geocodeStatus = '✗ Not found';
                                      }
                                    });
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7A432D),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onPressed: isGeocoding
                                ? null
                                : () async {
                                    final venue = locController.text.trim();
                                    if (venue.isEmpty) return;
                                    setDialogState(() {
                                      isGeocoding = true;
                                      geocodeStatus = 'Searching...';
                                      searchResults = [];
                                    });
                                    final results = await _searchVenues(venue);
                                    setDialogState(() {
                                      isGeocoding = false;
                                      searchResults = results;
                                      if (results.isNotEmpty) {
                                        geocodeStatus = '✓ Select location below:';
                                      } else {
                                        geocodeStatus = '✗ Not found';
                                      }
                                    });
                                  },
                            child: isGeocoding
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Search', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ],
                      ),
                      if (geocodeStatus.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          geocodeStatus.startsWith('✓')
                              ? '$geocodeStatus Coordinates: ${latitude?.toStringAsFixed(4)}, ${longitude?.toStringAsFixed(4)}'
                              : geocodeStatus,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: geocodeStatus.startsWith('✓') ? Colors.green[800] : Colors.red[800],
                          ),
                        ),
                      ],
                      if (searchResults.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 150),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE8E2DD)),
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: searchResults.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE8E2DD)),
                            itemBuilder: (context, index) {
                              final item = searchResults[index];
                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                title: Text(
                                  item['display_name'],
                                  style: const TextStyle(fontSize: 12, fontFamily: 'PlusJakartaSans', color: Color(0xFF3E1F11)),
                                ),
                                onTap: () {
                                  setDialogState(() {
                                    isSelectingVenue = true;
                                    locController.text = item['display_name'];
                                    latitude = item['lat'];
                                    longitude = item['lon'];
                                    mapsController.text = 'https://www.google.com/maps/search/?api=1&query=${item['lat']},${item['lon']}';
                                    geocodeStatus = '✓ Location selected!';
                                    searchResults = [];
                                  });
                                  isSelectingVenue = false;
                                },
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Text(
                        'GOOGLE MAPS LINK / LOCATION URL (OPTIONAL)',
                        style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: mapsController,
                        decoration: InputDecoration(
                          hintText: 'Paste location link here...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (val) {
                          final coords = _extractCoordinatesFromUrl(val);
                          if (coords != null) {
                            setDialogState(() {
                              latitude = coords['lat'];
                              longitude = coords['lon'];
                              geocodeStatus = '✓ Link parsed!';
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF8C736B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A432D)),
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) return;

                    final dateVal = dateController.text.trim();
                    final timeVal = timeController.text.trim();

                    // Defaults
                    final finalMonth = dateVal.toUpperCase().contains(' ')
                        ? dateVal.split(' ').last
                        : 'JUN';
                    final finalDay = dateVal.isNotEmpty ? dateVal.split(' ').first : '15';

                    final newEvent = Event(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      illustrationPath: _getCategoryImageUrl(selectedCat),
                      month: finalMonth,
                      day: finalDay,
                      title: titleController.text.trim(),
                      location: locController.text.isEmpty ? 'General Lounge' : locController.text.trim(),
                      time: "${timeVal.isEmpty ? '6:00 PM' : timeVal} • Today",
                      attendees: '1 attending',
                      category: selectedCat,
                      price: priceController.text.trim().isEmpty ? 'Free' : priceController.text.trim(),
                      mapUrl: mapsController.text.trim().isNotEmpty ? mapsController.text.trim() : null,
                      latitude: latitude,
                      longitude: longitude,
                      isJoined: true,
                    );

                    _state.createEvent(newEvent);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Event hosted successfully!'),
                        backgroundColor: Color(0xFF7A432D),
                      ),
                    );
                  },
                  child: const Text('Publish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEventDetailsBottomSheet(Event event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFAF7F5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Top drag handler
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // Banner Image Header
              Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: _getCategoryImageUrl(event.category),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7A432D),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            event.category.toUpperCase(),
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.0),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          event.title,
                          style: const TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price tag
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          event.price == 'Free' ? 'FREE ENTRY' : event.price,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.people_outline, size: 16, color: Color(0xFF8C736B)),
                            const SizedBox(width: 4),
                            Text(
                              event.attendees,
                              style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: Color(0xFF8C736B)),
                            ),
                          ],
                        )
                      ],
                    ),
                    const Divider(height: 24, color: Color(0xFFE8E2DD)),

                    // Schedule Info Row
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 20, color: Color(0xFF7A432D)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${event.day} ${event.month}',
                              style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF3E1F11)),
                            ),
                            Text(
                              event.time,
                              style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: Color(0xFF8C736B)),
                            ),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Location Info Row
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 20, color: Color(0xFF7A432D)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.location,
                                style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF3E1F11)),
                              ),
                              const Text(
                                'Tap map below to launch navigation',
                                style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: Color(0xFF8C736B)),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Map Section
                    if (event.latitude != null && event.longitude != null) ...[
                      const Text(
                        'LOCATION MAP',
                        style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Color(0xFF8C736B)),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE8E2DD)),
                          ),
                          child: Stack(
                            children: [
                              MapWebView(
                                latitude: event.latitude!,
                                longitude: event.longitude!,
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: InkWell(
                                  onTap: () async {
                                    final double lat = event.latitude!;
                                    final double lon = event.longitude!;
                                    final url = event.mapUrl ?? 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
                                    if (await canLaunchUrl(Uri.parse(url))) {
                                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.directions, color: Colors.white, size: 12),
                                        SizedBox(width: 4),
                                        Text('Directions', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else if (event.mapUrl != null) ...[
                      const Text(
                        'LOCATION MAP',
                        style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Color(0xFF8C736B)),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF7A432D)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        icon: const Icon(Icons.map, color: Color(0xFF7A432D), size: 16),
                        label: const Text('Open Location on Google Maps', style: TextStyle(fontFamily: 'PlusJakartaSans', color: Color(0xFF7A432D), fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          if (await canLaunchUrl(Uri.parse(event.mapUrl!))) {
                            await launchUrl(Uri.parse(event.mapUrl!), mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Book / Join CTA Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: event.isJoined ? const Color(0xFFE8E2DD) : const Color(0xFF7A432D),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          _state.toggleJoinEvent(event.id);
                          Navigator.pop(context);
                        },
                        child: Text(
                          event.isJoined ? '✓ Joined' : 'Book Ticket / Join',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: event.isJoined ? const Color(0xFF3E1F11) : Colors.white,
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
         ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final upcomingEvents = _state.events.where((e) {
      if (_selectedCategory == 'All') return true;
      return e.category.toLowerCase() == _selectedCategory.toLowerCase();
    }).toList();

    final myEvents = _state.events.where((e) {
      if (!e.isJoined) return false;
      if (_selectedCategory == 'All') return true;
      return e.category.toLowerCase() == _selectedCategory.toLowerCase();
    }).toList();

    final currentList = _activeSubTab == 0 ? upcomingEvents : myEvents;

    // Split list into Featured (first 3) and standard grid
    final featuredList = currentList.take(3).toList();
    final gridList = currentList.skip(3).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF3E1F11)),
          onPressed: widget.onNext ?? () {
            _state.currentScreen = AppScreen.hub;
          },
        ),
        title: const Text(
          'Events & Networking',
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E1F11),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF3E1F11)),
            onPressed: _handleCreateEvent,
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Sub-Tab Switcher
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: 8),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E2DD).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildSubTabButton(0, 'Explore Events'),
                    _buildSubTabButton(1, 'Joined By Me'),
                  ],
                ),
              ),
            ),
          ),

          // Category Chips Bar
          SliverToBoxAdapter(
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF3E1F11),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF7A432D),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF7A432D) : const Color(0xFFE8E2DD),
                        ),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ),

          // Featured Carousel Section (Only shown if featured exists)
          if (featuredList.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(left: screenWidth * 0.05, top: 12, bottom: 8),
                child: const Text(
                  'FEATURED EVENTS',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Color(0xFF8C736B),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                  itemCount: featuredList.length,
                  itemBuilder: (context, index) {
                    final event = featuredList[index];
                    return _buildFeaturedEventCard(event);
                  },
                ),
              ),
            ),
          ],

          // Grid Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(left: screenWidth * 0.05, top: 20, bottom: 8),
              child: Text(
                _selectedCategory == 'All' ? 'ALL EVENTS' : '$_selectedCategory EVENTS'.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Color(0xFF8C736B),
                ),
              ),
            ),
          ),

          // Events 2-Column Grid or Empty placeholder
          currentList.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.event_busy_outlined, color: Color(0xFF8C736B), size: 40),
                        SizedBox(height: 8),
                        Text(
                          'No matching events found.',
                          style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: Color(0xFF8C736B)),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.7,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        // In grid, show remaining list after featured, or all if featured is empty
                        final list = featuredList.isEmpty ? currentList : gridList;
                        if (index >= list.length) {
                          return _buildCreateGridCTA();
                        }
                        final event = list[index];
                        return _buildGridEventCard(event);
                      },
                      childCount: (featuredList.isEmpty ? currentList.length : gridList.length) + 1,
                    ),
                  ),
                ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 30),
          )
        ],
      ),
    );
  }

  Widget _buildSubTabButton(int index, String title) {
    final isActive = _activeSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeSubTab = index;
          });
        },
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    )
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? const Color(0xFF3E1F11) : const Color(0xFF8C736B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedEventCard(Event event) {
    final isBookmarked = _bookmarkedEvents.contains(event.id);
    return GestureDetector(
      onTap: () => _showEventDetailsBottomSheet(event),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.82,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: CachedNetworkImageProvider(_getCategoryImageUrl(event.category)),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Bar of Card
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${event.day} ${event.month.toUpperCase()}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.black38,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        size: 16,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          if (isBookmarked) {
                            _bookmarkedEvents.remove(event.id);
                          } else {
                            _bookmarkedEvents.add(event.id);
                          }
                        });
                      },
                    ),
                  )
                ],
              ),

              // Bottom Details of Card
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFE5A475), borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      event.category.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: Colors.white70),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                      Text(
                        event.price == 'Free' ? 'FREE' : event.price,
                        style: const TextStyle(color: Color(0xFF81C784), fontSize: 12, fontWeight: FontWeight.bold),
                      )
                    ],
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridEventCard(Event event) {
    return GestureDetector(
      onTap: () => _showEventDetailsBottomSheet(event),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E2DD)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: CachedNetworkImage(
                imageUrl: _getCategoryImageUrl(event.category),
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.category.toUpperCase(),
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF7A432D)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E1F11)),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 10, color: Color(0xFF8C736B)),
                            const SizedBox(width: 4),
                            Text(
                              '${event.day} ${event.month}',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF8C736B)),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 10, color: Color(0xFF8C736B)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                event.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, color: Color(0xFF8C736B)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              event.price == 'Free' ? 'FREE' : event.price,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: event.isJoined ? const Color(0xFFE8E2DD) : const Color(0xFF7A432D),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                event.isJoined ? 'Joined' : 'Join',
                                style: TextStyle(
                                  color: event.isJoined ? const Color(0xFF3E1F11) : Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          ],
                        )
                      ],
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCreateGridCTA() {
    return GestureDetector(
      onTap: _handleCreateEvent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF7A432D).withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.add_circle_outline, color: Color(0xFF7A432D), size: 32),
            SizedBox(height: 8),
            Text(
              'Host Your Own',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF7A432D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
