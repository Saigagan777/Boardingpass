import 'package:flutter/material.dart';
import '../models/venue.dart';
import '../models/enums.dart';
import '../services/venue_repository.dart';
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

  List<Venue> _suggestions = [];

  // Filters
  VenueCategory? _selectedCategory;
  double _minRating = 4.0;
  bool _wifiOnly = false;
  bool _parkingOnly = false;
  final bool _accessibleOnly = false;


  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              },
            ),
          ],
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
}
