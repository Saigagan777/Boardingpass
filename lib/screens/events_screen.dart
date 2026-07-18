import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/google_search_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../state_manager.dart';
import '../models/event.dart';
import '../services/event_service.dart';
import 'event_attendee_avatar_stack.dart';
import 'map_webview.dart';

class EventsScreen extends StatefulWidget {
  final VoidCallback? onNext;
  const EventsScreen({super.key, this.onNext});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final AppStateManager _state = AppStateManager();


  Widget _buildEventImageWidget(String url, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (url.startsWith('data:image') && url.contains('base64,')) {
      try {
        final base64Str = url.split('base64,').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
        );
      } catch (e) {
        // Fallback
      }
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => Container(color: const Color(0xFFE8E2DD)),
      errorWidget: (context, url, error) => const Icon(Icons.error),
    );
  }

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
    return searchGoogleGeocoding(query);
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
        Uint8List? selectedImageBytes;
        bool isUploadingImage = false;

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
                        'EVENT FLYER / IMAGE',
                        style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                          if (image != null) {
                            final bytes = await image.readAsBytes();
                            setDialogState(() {
                              selectedImageBytes = bytes;
                            });
                          }
                        },
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8E2DD).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE8E2DD)),
                          ),
                          child: selectedImageBytes != null
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.memory(
                                        selectedImageBytes!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () {
                                          setDialogState(() {
                                            selectedImageBytes = null;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF7A432D), size: 36),
                                    SizedBox(height: 6),
                                    Text(
                                      'Upload Event Flyer',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF7A432D),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Optional (Default category image will be used)',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 10,
                                        color: Color(0xFF8C736B),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Material(
                            color: Colors.white,
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                  onPressed: isUploadingImage ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF8C736B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A432D)),
                  onPressed: isUploadingImage
                      ? null
                      : () async {
                          if (titleController.text.trim().isEmpty) return;

                          setDialogState(() {
                            isUploadingImage = true;
                          });

                          try {
                            final eventId = DateTime.now().millisecondsSinceEpoch.toString();
                            String? imageUrl;

                            if (selectedImageBytes != null) {
                              imageUrl = await EventService().uploadEventImage(eventId, selectedImageBytes!);
                            }

                            final dateVal = dateController.text.trim();
                            final timeVal = timeController.text.trim();

                            // Defaults
                            final finalMonth = dateVal.toUpperCase().contains(' ')
                                ? dateVal.split(' ').last
                                : 'JUN';
                            final finalDay = dateVal.isNotEmpty ? dateVal.split(' ').first : '15';

                            final newEvent = Event(
                              id: eventId,
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
                              imageUrl: imageUrl,
                              isJoined: true,
                            );

                            _state.createEvent(newEvent);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Event hosted successfully!'),
                                  backgroundColor: Color(0xFF7A432D),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to host event: $e'),
                                  backgroundColor: const Color(0xFFC62828),
                                ),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setDialogState(() {
                                isUploadingImage = false;
                              });
                            }
                          }
                        },
                  child: isUploadingImage
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Publish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  _buildEventImageWidget(
                    (event.imageUrl != null && event.imageUrl!.isNotEmpty)
                        ? event.imageUrl!
                        : _getCategoryImageUrl(event.category),
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
                                    final uri = Uri.parse(url);
                                    try {
                                      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      if (!launched) {
                                        await launchUrl(uri, mode: LaunchMode.platformDefault);
                                      }
                                    } catch (e) {
                                      debugPrint('Could not launch map URL: $url - Error: $e');
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
                          final uri = Uri.parse(event.mapUrl!);
                          try {
                            final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                            if (!launched) {
                              await launchUrl(uri, mode: LaunchMode.platformDefault);
                            }
                          } catch (e) {
                            debugPrint('Could not launch map URL: ${event.mapUrl!} - Error: $e');
                          }
                        },
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Interested + Book / Join CTAs
                    Row(
                      children: [
                        // Interested toggle button
                        Expanded(
                          flex: 1,
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: event.isJoined
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFF7A432D),
                                  width: 1.5,
                                ),
                                backgroundColor: event.isJoined
                                    ? const Color(0xFF2E7D32).withValues(alpha: 0.08)
                                    : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {
                                _state.toggleJoinEvent(event.id);
                                Navigator.pop(context);
                              },
                              icon: Icon(
                                event.isJoined
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 18,
                                color: event.isJoined
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFF7A432D),
                              ),
                              label: Text(
                                event.isJoined ? 'Interested' : 'Interested?',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: event.isJoined
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFF7A432D),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Book / Join CTA
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7A432D),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async {
                                final nav = Navigator.of(context);
                                final messenger = ScaffoldMessenger.of(context);
                                if (event.isJoined) {
                                  nav.pop();
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('You are already registered for this event.'),
                                      backgroundColor: Color(0xFF2E7D32),
                                    ),
                                  );
                                  return;
                                }

                                try {
                                  final isNowJoined = await EventService()
                                      .toggleJoinEvent(event.id);
                                  if (!context.mounted) return;
                                  if (isNowJoined) {
                                    setState(() => event.isJoined = true);
                                    nav.pop();
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('You are registered for this event!'),
                                        backgroundColor: Color(0xFF2E7D32),
                                      ),
                                    );
                                  }
                                } catch (_) {
                                  if (!context.mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Could not register for this event. Please try again.'),
                                      backgroundColor: Color(0xFFC62828),
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                event.isJoined ? 'Registered' : 'Book Ticket / Join',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
          // Sub-Tab Switcher — matches reference image
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: 10),
              child: Row(
                children: [
                  // Explore Events — dark filled pill
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeSubTab = 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 44,
                        decoration: BoxDecoration(
                          color: _activeSubTab == 0 ? const Color(0xFF3E1F11) : Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: _activeSubTab == 0 ? const Color(0xFF3E1F11) : const Color(0xFFD6C9C0),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.explore_rounded,
                              size: 16,
                              color: _activeSubTab == 0 ? Colors.white : const Color(0xFF8C736B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Explore Events',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _activeSubTab == 0 ? Colors.white : const Color(0xFF8C736B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Joined By Me — outlined pill
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeSubTab = 1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 44,
                        decoration: BoxDecoration(
                          color: _activeSubTab == 1 ? const Color(0xFF3E1F11) : Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: _activeSubTab == 1 ? const Color(0xFF3E1F11) : const Color(0xFFD6C9C0),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 16,
                              color: _activeSubTab == 1 ? Colors.white : const Color(0xFF8C736B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Joined By Me',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _activeSubTab == 1 ? Colors.white : const Color(0xFF8C736B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Category Chips Bar — fixed row, 3 main + More button, no scrolling
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: 4),
              child: Row(
                children: [
                  // 3 main categories
                  ..._categories.take(3).map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF7A432D) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF7A432D) : const Color(0xFFD6C9C0),
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF5C473E),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  // More ▾ button — shows remaining categories in a bottom sheet
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (_) => Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'More Categories',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3E1F11),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: _categories.skip(3).map((cat) {
                                  final isSel = _selectedCategory == cat;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() => _selectedCategory = cat);
                                      Navigator.pop(context);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSel ? const Color(0xFF7A432D) : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isSel ? const Color(0xFF7A432D) : const Color(0xFFD6C9C0),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Text(
                                        cat,
                                        style: TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isSel ? Colors.white : const Color(0xFF5C473E),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFD6C9C0), width: 1.2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'More',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF5C473E),
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF5C473E)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Featured Carousel Section (Only shown if featured exists)
          if (featuredList.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(left: screenWidth * 0.05, right: screenWidth * 0.05, top: 16, bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'FEATURED EVENTS',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Color(0xFF3E1F11),
                      ),
                    ),
                    GestureDetector(
                      child: Row(
                        children: const [
                          Text(
                            'View All',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF7A432D),
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF7A432D)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 520,
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

          // Grid Section Header with View All
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(left: screenWidth * 0.05, right: screenWidth * 0.05, top: 20, bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedCategory == 'All' ? 'ALL EVENTS' : '${_selectedCategory.toUpperCase()} EVENTS',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Color(0xFF3E1F11),
                    ),
                  ),
                  GestureDetector(
                    child: Row(
                      children: const [
                        Text(
                          'View All',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7A432D),
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF7A432D)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Events 2-Column Grid or Empty placeholder
          currentList.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE8E2DD), width: 1),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5EFE9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.calendar_today_outlined,
                              color: Color(0xFF8C736B),
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No events yet',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3E1F11),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Be the first to create an event!',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              color: Color(0xFF8C736B),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          GestureDetector(
                            onTap: _handleCreateEvent,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF7A432D), width: 1.5),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add, size: 16, color: Color(0xFF7A432D)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Create Event',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7A432D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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


  Widget _buildFeaturedEventCard(Event event) {
    final isBookmarked = _bookmarkedEvents.contains(event.id);
    final cardWidth = MediaQuery.of(context).size.width * 0.88;

    // Parse attendee count for display
    final attendeeText = event.attendees;
    final attendeeCount = RegExp(r'\d+').firstMatch(attendeeText)?.group(0) ?? '0';

    // Derive a city label from the location string
    final locationParts = event.location.split(',');
    final cityLabel = locationParts.isNotEmpty
        ? locationParts.last.trim().toUpperCase()
        : 'YOUR CITY';

    return GestureDetector(
      onTap: () => _showEventDetailsBottomSheet(event),
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 16, bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // ── Full-bleed background image ──
              Positioned.fill(
                child: _buildEventImageWidget(
                  (event.imageUrl != null && event.imageUrl!.isNotEmpty)
                      ? event.imageUrl!
                      : _getCategoryImageUrl(event.category),
                  fit: BoxFit.cover,
                ),
              ),

              // ── Top gradient for badges readability ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 120,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // ── Bottom gradient for text readability ──
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 340,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.92),
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.55, 1],
                    ),
                  ),
                ),
              ),

              // ── TOP: Free Entry badge + Bookmark ──
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Free Entry pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.confirmation_number_rounded, size: 13, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(
                            event.price == 'Free' ? 'FREE ENTRY' : event.price.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Bookmark button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isBookmarked) {
                            _bookmarkedEvents.remove(event.id);
                          } else {
                            _bookmarkedEvents.add(event.id);
                          }
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: Icon(
                          isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── MIDDLE-BOTTOM: City + Title + Interested row ──
              Positioned(
                bottom: 180,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // City label in copper
                    Text(
                      cityLabel,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE5A475),
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Large event title
                    Text(
                      event.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Avatars (only if there are real attendees) + Interested pill
                    Row(
                      children: [
                        // Show real profile photos: every attendee up to four,
                        // otherwise only the four most recently interested.
                        if (event.attendeeIds.isNotEmpty) ...[
                          EventAttendeeAvatarStack(
                            attendeeIds: event.attendeeIds,
                          ),
                          const SizedBox(width: 10),
                        ],
                                // +N overflow badge — only if count > 4
                        // Interested count pill — always shown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_outline_rounded, size: 14, color: Colors.white70),
                              const SizedBox(width: 5),
                              Text(
                                '$attendeeCount Interested',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Tagline
                    const Text(
                      'Connect. Collaborate. Grow.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        color: Colors.white70,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),

              // ── BOTTOM: Dark info card + Register button ──
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dark info card
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1412).withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          // Date row
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7A432D).withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.calendar_month_rounded, color: Color(0xFFE5A475), size: 20),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_getDayLabel(event.day)}, ${event.day} ${_getMonthFull(event.month)} 2026',
                                      style: const TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      event.time,
                                      style: const TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 11,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Divider
                          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                          // Location row
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7A432D).withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.location_on_rounded, color: Color(0xFFE5A475), size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.location.split(',').first.trim(),
                                        style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        event.location,
                                        style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 11,
                                          color: Colors.white54,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Register Now button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GestureDetector(
                        onTap: () => _showEventDetailsBottomSheet(event),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7A432D),
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'REGISTER NOW',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDayLabel(String day) {
    final d = int.tryParse(day);
    if (d == null) return 'Sat';
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(d - 1) % 7];
  }

  String _getMonthFull(String abbr) {
    const monthMap = {
      'JAN': 'January', 'FEB': 'February', 'MAR': 'March', 'APR': 'April',
      'MAY': 'May', 'JUN': 'June', 'JUL': 'July', 'AUG': 'August',
      'SEP': 'September', 'OCT': 'October', 'NOV': 'November', 'DEC': 'December',
    };
    return monthMap[abbr.toUpperCase()] ?? abbr;
  }

  Widget _buildGridEventCard(Event event) {
    return GestureDetector(
      onTap: () => _showEventDetailsBottomSheet(event),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEADDD6), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7A432D).withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  _buildEventImageWidget(
                    (event.imageUrl != null && event.imageUrl!.isNotEmpty)
                        ? event.imageUrl!
                        : _getCategoryImageUrl(event.category),
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  // Category pill overlay on image
                  Positioned(
                    top: 7,
                    left: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7A432D).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        event.category.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(9.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E1F11),
                        height: 1.3,
                      ),
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
                              style: const TextStyle(fontSize: 10, color: Color(0xFF8C736B), fontFamily: 'PlusJakartaSans'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 10, color: Color(0xFF8C736B)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                event.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, color: Color(0xFF8C736B), fontFamily: 'PlusJakartaSans'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.people_outline, size: 10, color: Color(0xFF8C736B)),
                            const SizedBox(width: 4),
                            Text(
                              event.attendees,
                              style: const TextStyle(fontSize: 10, color: Color(0xFF8C736B), fontFamily: 'PlusJakartaSans'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              event.price == 'Free' ? 'FREE' : event.price,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                                fontFamily: 'PlusJakartaSans',
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: event.isJoined ? const Color(0xFFE8E2DD) : const Color(0xFF7A432D),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                event.isJoined ? 'Joined' : 'Join',
                                style: TextStyle(
                                  color: event.isJoined ? const Color(0xFF3E1F11) : Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'PlusJakartaSans',
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
