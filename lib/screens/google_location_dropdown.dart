import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/google_search_helper.dart';

/// Google-powered address search with a compact dropdown of geocoding results.
class GoogleLocationDropdown extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onSelected;

  const GoogleLocationDropdown({
    super.key,
    required this.controller,
    this.hintText = 'Search a city, area, or address',
    this.onSelected,
  });

  @override
  State<GoogleLocationDropdown> createState() => _GoogleLocationDropdownState();
}

class _GoogleLocationDropdownState extends State<GoogleLocationDropdown> {
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  List<Map<String, dynamic>> _suggestions = [];
  bool _isSearching = false;
  int _searchRequest = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final request = ++_searchRequest;
      if (mounted) setState(() => _isSearching = true);
      try {
        final results = await searchGoogleGeocoding(query.trim());
        if (!mounted || request != _searchRequest) return;
        setState(() => _suggestions = results.take(5).toList());
      } catch (_) {
        if (mounted && request == _searchRequest) {
          setState(() => _suggestions = []);
        }
      } finally {
        if (mounted && request == _searchRequest) {
          setState(() => _isSearching = false);
        }
      }
    });
  }

  void _select(Map<String, dynamic> result) {
    final address = result['display_name']?.toString() ?? '';
    if (address.isEmpty) return;
    widget.controller.value = TextEditingValue(
      text: address,
      selection: TextSelection.collapsed(offset: address.length),
    );
    _focusNode.unfocus();
    setState(() => _suggestions = []);
    widget.onSelected?.call(address);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          onChanged: _onQueryChanged,
          textInputAction: TextInputAction.search,
          autofillHints: const [AutofillHints.fullStreetAddress],
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            color: Color(0xFF3E1F11),
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              color: Color(0xFF8C736B),
            ),
            prefixIcon: const Icon(
              Icons.location_on_outlined,
              color: Color(0xFF7A432D),
            ),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF7A432D),
                      ),
                    ),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7A432D), width: 1.5),
            ),
          ),
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8E2DD)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x143E1F11),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                color: Color(0xFFF0EBE7),
              ),
              itemBuilder: (context, index) {
                final result = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.place_outlined,
                    color: Color(0xFF7A432D),
                  ),
                  title: Text(
                    result['display_name']?.toString() ?? 'Location',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      color: Color(0xFF3E1F11),
                    ),
                  ),
                  onTap: () => _select(result),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
