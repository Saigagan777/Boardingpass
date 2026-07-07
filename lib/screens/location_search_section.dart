import 'package:flutter/material.dart';
import '../models/venue.dart';
import '../models/enums.dart';
import '../services/venue_repository.dart';
import '../services/recommendation_engine.dart';
import 'venue_details_sheet.dart';

class LocationSearchSection extends StatefulWidget {
  final String currentCity;
  final MeetingPurpose purpose;
  final Venue? selectedVenue;
  final ValueChanged<Venue> onVenueSelected;

  const LocationSearchSection({
    super.key,
    required this.currentCity,
    required this.purpose,
    required this.selectedVenue,
    required this.onVenueSelected,
  });

  @override
  State<LocationSearchSection> createState() => _LocationSearchSectionState();
}

class _LocationSearchSectionState extends State<LocationSearchSection> {
  final TextEditingController _searchController = TextEditingController();
  final VenueRepository _venueRepository = VenueRepositoryImpl();
  final RecommendationEngine _recommendationEngine = RecommendationEngine();

  List<Venue> _suggestions = [];
  List<Venue> _recommendations = [];
  bool _loadingRecommendations = true;

  // Filters
  VenueCategory? _selectedCategory;
  double _minRating = 4.0;
  bool _wifiOnly = false;
  bool _parkingOnly = false;
  final bool _accessibleOnly = false;


  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  @override
  void didUpdateWidget(LocationSearchSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentCity != widget.currentCity || oldWidget.purpose != widget.purpose) {
      _loadRecommendations();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    setState(() => _loadingRecommendations = true);
    try {
      final results = await _recommendationEngine.getPurposeRecommendations(
        city: widget.currentCity,
        purpose: widget.purpose,
      );
      setState(() {
        _recommendations = results;
        _loadingRecommendations = false;
      });
    } catch (_) {
      setState(() => _loadingRecommendations = false);
    }
  }

  void _onSearchChanged(String query) async {
    if (query.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }

    final filters = {
      if (_selectedCategory != null) 'category': _selectedCategory!.name,
      'minRating': _minRating,
      'wifi': _wifiOnly,
      'parking': _parkingOnly,
      'accessible': _accessibleOnly,
    };

    final results = await _venueRepository.searchVenues(
      query,
      city: widget.currentCity,
      filters: filters,
    );

    setState(() {
      _suggestions = results;
    });
  }

  void _onCategorySelected(VenueCategory? cat) {
    setState(() {
      _selectedCategory = _selectedCategory == cat ? null : cat;
    });
    _onSearchChanged(_searchController.text);
    _loadRecommendationsFiltered();
  }

  Future<void> _loadRecommendationsFiltered() async {
    setState(() => _loadingRecommendations = true);
    try {
      final results = await _venueRepository.getRecommendations(
        city: widget.currentCity,
        purpose: widget.purpose,
        category: _selectedCategory,
      );
      setState(() {
        _recommendations = results;
        _loadingRecommendations = false;
      });
    } catch (_) {
      setState(() => _loadingRecommendations = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected Venue Banner
        if (widget.selectedVenue != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F5),
              border: Border.all(color: const Color(0xFFE5A475), width: 1.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.selectedVenue!.name,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                      Text(
                        widget.selectedVenue!.formattedAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          color: Color(0xFF8C736B),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    VenueDetailsSheet.show(
                      context,
                      venue: widget.selectedVenue!,
                      showConfirmButton: false,
                    );
                  },
                  child: const Text(
                    'Details',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF7A432D),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Search Box
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search meetings venue (e.g. Novotel, Cafe)...',
            prefixIcon: const Icon(Icons.search, color: Color(0xFF8C736B)),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _suggestions = []);
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE8E2DD), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF7A432D), width: 1.5),
            ),
          ),
        ),

        // Autocomplete suggestions
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE8E2DD)),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.white,
              child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final v = _suggestions[index];
                return ListTile(
                  leading: const Icon(Icons.location_on, color: Color(0xFF7A432D)),
                  title: Text(v.name, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text(v.formattedAddress, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    _searchController.clear();
                    setState(() => _suggestions = []);
                    VenueDetailsSheet.show(
                      context,
                      venue: v,
                      onConfirm: widget.onVenueSelected,
                    );
                  },
                );
              },
            ),
          ),
        ),
        ],

        const SizedBox(height: 16),

        // Categories selector scroll
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: VenueCategory.values.where((cat) => cat != VenueCategory.custom).map((cat) {
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    cat.displayName,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF3E1F11),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF7A432D),
                  backgroundColor: Colors.white,
                  checkmarkColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF7A432D) : const Color(0xFFE8E2DD),
                  ),
                  onSelected: (_) => _onCategorySelected(cat),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 20),

        // Quick Filters chips
        Row(
          children: [
            _buildFilterChip(
              icon: Icons.star_border,
              label: '4.5+ Rating',
              value: _minRating == 4.5,
              onTap: () {
                setState(() => _minRating = _minRating == 4.5 ? 4.0 : 4.5);
                _onSearchChanged(_searchController.text);
                _loadRecommendationsFiltered();
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              icon: Icons.wifi,
              label: 'WiFi',
              value: _wifiOnly,
              onTap: () {
                setState(() => _wifiOnly = !_wifiOnly);
                _onSearchChanged(_searchController.text);
                _loadRecommendationsFiltered();
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              icon: Icons.local_parking,
              label: 'Parking',
              value: _parkingOnly,
              onTap: () {
                setState(() => _parkingOnly = !_parkingOnly);
                _onSearchChanged(_searchController.text);
                _loadRecommendationsFiltered();
              },
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Recommendations Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RECOMMENDED VENUES (${widget.currentCity})',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Color(0xFF8C736B),
              ),
            ),
            if (_loadingRecommendations)
              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7A432D))),
          ],
        ),

        const SizedBox(height: 12),

        // Recommendations horizontal list
        if (_loadingRecommendations)
          _buildSkeletons()
        else if (_recommendations.isEmpty)
          Container(
            height: 140,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE8E2DD)), borderRadius: BorderRadius.circular(16)),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off_outlined, color: Color(0xFF8C736B), size: 36),
                SizedBox(height: 8),
                Text('No recommended venues matching this category.', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: Color(0xFF8C736B))),
              ],
            ),
          )
        else
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _recommendations.length,
              itemBuilder: (context, index) {
                final v = _recommendations[index];
                return GestureDetector(
                  onTap: () {
                    VenueDetailsSheet.show(
                      context,
                      venue: v,
                      onConfirm: widget.onVenueSelected,
                    );
                  },
                  child: Container(
                    width: 260,
                    margin: const EdgeInsets.only(right: 12, bottom: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: widget.selectedVenue?.id == v.id ? const Color(0xFFE5A475) : const Color(0xFFE8E2DD),
                        width: widget.selectedVenue?.id == v.id ? 2.0 : 1.2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cover Thumbnail
                        ClipRRect(
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                          child: Container(
                            height: 90,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: NetworkImage(v.coverImage),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        // Details
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      v.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFF3E1F11),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 14),
                                      const SizedBox(width: 2),
                                      Text(
                                        v.rating.toStringAsFixed(1),
                                        style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                v.formattedAddress,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 10.5,
                                  color: Color(0xFF8C736B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required bool value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: value ? const Color(0xFF7A432D) : Colors.white,
          border: Border.all(
            color: value ? const Color(0xFF7A432D) : const Color(0xFFE8E2DD),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: value ? Colors.white : const Color(0xFF8C736B),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                fontWeight: value ? FontWeight.bold : FontWeight.w500,
                color: value ? Colors.white : const Color(0xFF3E1F11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletons() {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 2,
        itemBuilder: (context, index) {
          return Container(
            width: 260,
            margin: const EdgeInsets.only(right: 12, bottom: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE8E2DD), width: 1.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 90,
                  width: double.infinity,
                  color: Colors.grey[200],
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 12, width: 140, color: Colors.grey[200]),
                      const SizedBox(height: 6),
                      Container(height: 10, width: 200, color: Colors.grey[200]),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
