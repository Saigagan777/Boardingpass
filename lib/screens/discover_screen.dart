import 'dart:async';
import 'package:flutter/material.dart';
import '../state_manager.dart';
import '../models/candidate.dart';
import '../utils/card_renderer.dart';
import '../utils/image_helper.dart';
import '../utils/app_logo.dart';

class DiscoverScreen extends StatefulWidget {
  final Function(String)? onMatch;
  const DiscoverScreen({super.key, this.onMatch});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> with SingleTickerProviderStateMixin {
  final AppStateManager _state = AppStateManager();

  // Filter states
  final TextEditingController _searchQuery = TextEditingController();
  String _selectedRole = 'All';
  String _selectedIntent = 'All';
  double _minMatchScore = 0.0;

  // Swiping state variables
  double _dragDx = 0.0;
  double _dragDy = 0.0;
  bool _isAnimating = false;

  // Match overlay state
  String? _matchedName;
  bool _showMatchOverlay = false;
  double _connectScale = 1.0;
  Timer? _connectTimer;

  // Local card index to manage swipe animations independently of global index
  int _cardIndex = 0;

  @override
  void initState() {
    super.initState();
    _cardIndex = _state.activeCandidateIndex;
    _searchQuery.addListener(() {
      if (mounted) {
        setState(() {
          _cardIndex = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _connectTimer?.cancel();
    _searchQuery.dispose();
    super.dispose();
  }

  List<Candidate> get filteredCandidates {
    final query = _searchQuery.text.trim().toLowerCase();
    return _state.candidates.where((c) {
      // 1. Search Query filter
      if (query.isNotEmpty) {
        final matchesName = c.name.toLowerCase().contains(query);
        final matchesCompany = c.org.toLowerCase().contains(query);
        final matchesRole = c.role.toLowerCase().contains(query);
        final matchesSkills = c.tags.any((tag) => tag.toLowerCase().contains(query));
        final matchesIntent = c.intent.toLowerCase().contains(query);
        if (!matchesName && !matchesCompany && !matchesRole && !matchesSkills && !matchesIntent) {
          return false;
        }
      }

      // 2. Role filter
      if (_selectedRole != 'All') {
        if (_selectedRole == 'Founders / CEOs') {
          final roleLower = c.role.toLowerCase();
          if (!roleLower.contains('founder') && !roleLower.contains('ceo') && !roleLower.contains('co-founder')) {
            return false;
          }
        } else if (_selectedRole == 'Investors / VCs') {
          final roleLower = c.role.toLowerCase();
          if (!roleLower.contains('investor') && !roleLower.contains('vc') && !roleLower.contains('partner') && !roleLower.contains('capital')) {
            return false;
          }
        } else if (_selectedRole == 'Tech / Engineering') {
          final roleLower = c.role.toLowerCase();
          if (!roleLower.contains('engineer') && !roleLower.contains('developer') && !roleLower.contains('cto') && !roleLower.contains('tech') && !roleLower.contains('product')) {
            return false;
          }
        } else if (_selectedRole == 'Sales / Marketing') {
          final roleLower = c.role.toLowerCase();
          if (!roleLower.contains('sales') && !roleLower.contains('marketing') && !roleLower.contains('growth') && !roleLower.contains('bd')) {
            return false;
          }
        } else {
          if (!c.role.toLowerCase().contains(_selectedRole.toLowerCase())) {
            return false;
          }
        }
      }

      // 3. Intent filter
      if (_selectedIntent != 'All') {
        if (!c.intent.toLowerCase().contains(_selectedIntent.toLowerCase())) {
          return false;
        }
      }

      // 4. Minimum Match Score filter
      if (c.match < _minMatchScore) {
        return false;
      }

      return true;
    }).toList();
  }

  void _showCustomCardsDeck(BuildContext context, Candidate c) {
    if (c.customCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${c.name} has not customized their cards yet.'),
          backgroundColor: const Color(0xFF7A432D),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        int currentPage = 0;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: 360,
              decoration: const BoxDecoration(
                color: Color(0xFF3E1F11),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                children: [
                  // Pull Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${c.name}'s Showcase Deck",
                            style: const TextStyle(
                              fontFamily: 'PlayfairDisplay',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE5A475),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Swipe left/right to view cards",
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // PageView Carousel
                  Expanded(
                    child: PageView.builder(
                      itemCount: c.customCards.length,
                      onPageChanged: (int page) {
                        setModalState(() {
                          currentPage = page;
                        });
                      },
                      itemBuilder: (context, idx) {
                        final card = c.customCards[idx];
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: PremiumCustomCard(
                              card: card,
                              width: 320,
                              height: 200,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(c.customCards.length, (idx) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: currentPage == idx ? 12 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: currentPage == idx ? const Color(0xFFE5A475) : Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _triggerMatch(String name) {
    setState(() {
      _matchedName = name;
      _showMatchOverlay = true;
      _connectScale = 1.0;
    });

    // Pulse handshake animation
    _connectTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (mounted) {
        setState(() {
          _connectScale = _connectScale == 1.0 ? 1.25 : 1.0;
        });
      }
    });

    // Dismiss overlay and navigate to Chat after 1.5s
    Future.delayed(const Duration(milliseconds: 1600), () {
      _connectTimer?.cancel();
      if (mounted) {
        setState(() {
          _showMatchOverlay = false;
          _matchedName = null;
        });
        if (widget.onMatch != null) {
          widget.onMatch!(name);
        } else {
          _state.currentScreen = AppScreen.chat;
        }
      }
    });
  }

  void _swipeLeft(List<Candidate> filteredList) {
    if (_isAnimating || filteredList.isEmpty) return;
    setState(() {
      _isAnimating = true;
      _dragDx = -400.0;
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _cardIndex = (_cardIndex + 1) % filteredList.length;
          _dragDx = 0.0;
          _dragDy = 0.0;
          _isAnimating = false;
        });
      }
    });
  }

  void _swipeRight(List<Candidate> filteredList) {
    if (_isAnimating || filteredList.isEmpty) return;
    final currentCandidate = filteredList[_cardIndex % filteredList.length];
    
    setState(() {
      _isAnimating = true;
      _dragDx = 400.0;
    });
    
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _triggerMatch(currentCandidate.name);
        setState(() {
          _cardIndex = (_cardIndex + 1) % filteredList.length;
          _dragDx = 0.0;
          _dragDy = 0.0;
          _isAnimating = false;
        });
      }
    });
  }

  Widget _buildFilterChip({required String label, required VoidCallback onClear}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E2DD),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E1F11),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClear,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: Color(0xFF3E1F11),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFAF7F5),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 30,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pull Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E2DD),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Professionals',
                        style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedRole = 'All';
                            _selectedIntent = 'All';
                            _minMatchScore = 0.0;
                          });
                          setState(() {});
                        },
                        child: const Text(
                          'Reset All',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB06F4D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFE8E2DD)),
                  const SizedBox(height: 16),

                  // Role Selection
                  const Text(
                    'Role / Profession',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF3E1F11),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'All',
                      'Founders / CEOs',
                      'Investors / VCs',
                      'Tech / Engineering',
                      'Sales / Marketing'
                    ].map((role) {
                      final isSelected = _selectedRole == role;
                      return ChoiceChip(
                        label: Text(role),
                        selected: isSelected,
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedRole = role;
                          });
                          setState(() {});
                        },
                        selectedColor: const Color(0xFF7A432D),
                        disabledColor: Colors.transparent,
                        backgroundColor: Colors.transparent,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : const Color(0xFF5C473E),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? Colors.transparent : const Color(0xFFE8E2DD),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Intent Selection
                  const Text(
                    'Intent / Objective',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF3E1F11),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'All',
                      'Raising Seed',
                      'Hiring Team',
                      'Open to Coffee',
                      'B2B Partnerships'
                    ].map((intent) {
                      final isSelected = _selectedIntent == intent;
                      return ChoiceChip(
                        label: Text(intent),
                        selected: isSelected,
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedIntent = intent;
                          });
                          setState(() {});
                        },
                        selectedColor: const Color(0xFF7A432D),
                        disabledColor: Colors.transparent,
                        backgroundColor: Colors.transparent,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : const Color(0xFF5C473E),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? Colors.transparent : const Color(0xFFE8E2DD),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Match Score Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Minimum Match Score',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                      Text(
                        '${_minMatchScore.round()}%',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF7A432D),
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF7A432D),
                      inactiveTrackColor: const Color(0xFFE8E2DD),
                      thumbColor: const Color(0xFF7A432D),
                      overlayColor: const Color(0xFF7A432D).withValues(alpha: 0.12),
                      valueIndicatorColor: const Color(0xFF7A432D),
                    ),
                    child: Slider(
                      value: _minMatchScore,
                      min: 0,
                      max: 100,
                      divisions: 10,
                      onChanged: (val) {
                        setModalState(() {
                          _minMatchScore = val;
                        });
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7A432D),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFE8E2DD).withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 48,
                color: Color(0xFF8C736B),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Matching Professionals',
              style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E1F11),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try expanding your search query or loosening the filters to discover more people.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                color: Color(0xFF8C736B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _searchQuery.clear();
                  _selectedRole = 'All';
                  _selectedIntent = 'All';
                  _minMatchScore = 0.0;
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(
                'Reset All Filters',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A432D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_state.candidates.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No candidates available.')),
      );
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    final filtered = filteredCandidates;
    final filteredCount = filtered.length;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF3E1F11)),
          onPressed: () {
            _state.currentScreen = AppScreen.hub;
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppLogo(size: 20, showText: false),
            const SizedBox(height: 2),
            Text(
              '$filteredCount professionals nearby',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                color: Color(0xFF8C736B),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.tune_rounded, color: Color(0xFF3E1F11)),
                if (_selectedRole != 'All' || _selectedIntent != 'All' || _minMatchScore > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFB06F4D),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => _showFilterBottomSheet(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main Swiper area
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05,
              vertical: 10,
            ),
            child: Column(
              children: [
                // Search Input Field
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8E2DD), width: 1),
                    ),
                    child: TextField(
                      controller: _searchQuery,
                      decoration: InputDecoration(
                        hintText: 'Search by name, company, skills...',
                        hintStyle: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          color: Color(0xFF8C736B),
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8C736B), size: 18),
                        suffixIcon: _searchQuery.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  _searchQuery.clear();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        color: Color(0xFF3E1F11),
                      ),
                    ),
                  ),
                ),

                // Active Filter Chips
                if (_selectedRole != 'All' || _selectedIntent != 'All' || _minMatchScore > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      height: 32,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          if (_selectedRole != 'All')
                            _buildFilterChip(
                              label: 'Role: $_selectedRole',
                              onClear: () {
                                setState(() {
                                  _selectedRole = 'All';
                                });
                              },
                            ),
                          if (_selectedIntent != 'All')
                            _buildFilterChip(
                              label: 'Intent: $_selectedIntent',
                              onClear: () {
                                setState(() {
                                  _selectedIntent = 'All';
                                });
                              },
                            ),
                          if (_minMatchScore > 0)
                            _buildFilterChip(
                              label: 'Match: >=${_minMatchScore.round()}%',
                              onClear: () {
                                setState(() {
                                  _minMatchScore = 0.0;
                                });
                              },
                            ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedRole = 'All';
                                _selectedIntent = 'All';
                                _minMatchScore = 0.0;
                              });
                            },
                            child: const Text(
                              'Clear All',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB06F4D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                Expanded(
                  child: filteredCount == 0
                      ? _buildEmptyState()
                      : Center(
                          child: SizedBox(
                            width: double.infinity,
                            height: screenHeight * 0.62,
                            child: Builder(
                              builder: (context) {
                                final int index = _cardIndex % filteredCount;
                                final first = filtered[index];
                                final second = filteredCount > 1 ? filtered[(index + 1) % filteredCount] : null;
                                final third = filteredCount > 2 ? filtered[(index + 2) % filteredCount] : null;

                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Third Card (Bottom)
                                    if (third != null)
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        top: 20,
                                        bottom: 0,
                                        child: Transform.scale(
                                          scale: 0.92,
                                          child: _buildCard(third, isTop: false),
                                        ),
                                      ),

                                    // Second Card (Middle)
                                    if (second != null)
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        top: 10,
                                        bottom: 10,
                                        child: Transform.scale(
                                          scale: 0.96,
                                          child: _buildCard(second, isTop: false),
                                        ),
                                      ),

                                    // First Card (Top - Draggable)
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      top: 0,
                                      bottom: 20,
                                      child: GestureDetector(
                                        onPanUpdate: (details) {
                                          if (_isAnimating) return;
                                          setState(() {
                                            _dragDx += details.delta.dx;
                                            _dragDy += details.delta.dy;
                                          });
                                        },
                                        onPanEnd: (details) {
                                          if (_isAnimating) return;
                                          if (_dragDx > 120) {
                                            _swipeRight(filtered);
                                          } else if (_dragDx < -120) {
                                            _swipeLeft(filtered);
                                          } else {
                                            // Reset card position
                                            setState(() {
                                              _dragDx = 0;
                                              _dragDy = 0;
                                            });
                                          }
                                        },
                                        child: Transform.translate(
                                          offset: Offset(_dragDx, _dragDy),
                                          child: Transform.rotate(
                                            angle: _dragDx / 400 * 0.15,
                                            child: _buildCard(first, isTop: true),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                ),

                // Button controls (only visible if filtered list is not empty)
                if (filteredCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24, top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Dislike Button
                        _buildRoundButton(
                          icon: Icons.close,
                          iconColor: const Color(0xFF8C736B),
                          backgroundColor: Colors.white,
                          borderColor: const Color(0xFFE8E2DD),
                          size: 56,
                          onPressed: () => _swipeLeft(filtered),
                        ),
                        const SizedBox(width: 24),

                        // Handshake/Connect Button
                        Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF7A432D), Color(0xFFB06F4D)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              )
                            ],
                          ),
                          child: _buildRoundButton(
                            icon: Icons.handshake,
                            iconColor: Colors.white,
                            backgroundColor: Colors.transparent,
                            borderColor: Colors.transparent,
                            size: 68,
                            onPressed: () => _swipeRight(filtered),
                          ),
                        ),
                        const SizedBox(width: 24),

                        // Star Button
                        _buildRoundButton(
                          icon: Icons.star_rounded,
                          iconColor: const Color(0xFFB06F4D),
                          backgroundColor: Colors.white,
                          borderColor: const Color(0xFFE8E2DD),
                          size: 56,
                          onPressed: () => _swipeRight(filtered),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Connection Overlay
          if (_showMatchOverlay && _matchedName != null)
            AnimatedOpacity(
              opacity: _showMatchOverlay ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                color: const Color(0xFF3E1F11).withValues(alpha: 0.95),
                width: double.infinity,
                height: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'It\'s a Connection!',
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFE5A475),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You and $_matchedName both want to talk.',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 36),
                    AnimatedScale(
                      scale: _connectScale,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5A475).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.handshake,
                          color: Color(0xFFE5A475),
                          size: 44,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompanyEmblem(String org) {
    final initial = org.isNotEmpty ? org[0].toUpperCase() : 'C';
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF7A432D).withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF7A432D).withValues(alpha: 0.4), width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF7A432D),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              org,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7A432D),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Candidate c, {required bool isTop}) {
    return Card(
      color: Colors.white,
      elevation: isTop ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: Color(0xFFE8E2DD), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Large Image Block at the top
          SizedBox(
            height: 220,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  child: buildProfileImage(
                    c.profileImageUrl ?? '',
                    fit: BoxFit.cover,
                    fallback: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [c.primaryColor, const Color(0xFF3E1F11)],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          c.initials,
                          style: const TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
                // Overlay Match score badge
                Positioned(
                  left: 16,
                  top: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFE5A475), size: 12),
                        const SizedBox(width: 4),
                        Text(
                          "${c.match}% match",
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Overlay Location
                Positioned(
                  right: 16,
                  top: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          c.loc,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Showcase Deck Button overlay
                if (isTop && c.customCards.isNotEmpty)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: GestureDetector(
                      onTap: () => _showCustomCardsDeck(context, c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.style_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Deck',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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

          // 2. Content Details area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Headline (Name)
                  Text(
                    c.name,
                    style: const TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E1F11),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Subhead (Role & Company)
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          c.role,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3E1F11),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Text(
                        '  ·  ',
                        style: TextStyle(
                          color: Color(0xFF8C736B),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _buildCompanyEmblem(c.org),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Body (Bio)
                  Text(
                    c.bio,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      color: Color(0xFF5C473E),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // IntentTag
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFB06F4D).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.track_changes_rounded,
                          color: Color(0xFFB06F4D),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            c.intent,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3E1F11),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Highlights / Connections
                  if (isTop)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.stars_rounded,
                            color: Color(0xFFE5A475),
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '2 mutual connections · Co-invested with Sequoia',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 10,
                                color: Color(0xFF8C736B),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required Color borderColor,
    required double size,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: backgroundColor != Colors.transparent
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ]
            : [],
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor),
        iconSize: size * 0.45,
        onPressed: onPressed,
      ),
    );
  }
}
