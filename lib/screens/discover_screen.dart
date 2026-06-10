import 'dart:async';
import 'package:flutter/material.dart';
import '../state_manager.dart';
import '../models/candidate.dart';

class DiscoverScreen extends StatefulWidget {
  final Function(String)? onMatch;
  const DiscoverScreen({super.key, this.onMatch});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> with SingleTickerProviderStateMixin {
  final AppStateManager _state = AppStateManager();

  // Swiping state variables
  double _dragDx = 0.0;
  double _dragDy = 0.0;
  bool _isAnimating = false;

  // Match overlay state
  String? _matchedName;
  bool _showMatchOverlay = false;
  double _heartScale = 1.0;
  Timer? _heartTimer;

  // Local card index to manage swipe animations independently of global index
  int _cardIndex = 0;

  @override
  void initState() {
    super.initState();
    _cardIndex = _state.activeCandidateIndex;
  }

  @override
  void dispose() {
    _heartTimer?.cancel();
    super.dispose();
  }

  void _triggerMatch(String name) {
    setState(() {
      _matchedName = name;
      _showMatchOverlay = true;
      _heartScale = 1.0;
    });

    // Pulse heart animation
    _heartTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (mounted) {
        setState(() {
          _heartScale = _heartScale == 1.0 ? 1.25 : 1.0;
        });
      }
    });

    // Dismiss overlay and navigate to Chat after 1.5s
    Future.delayed(const Duration(milliseconds: 1600), () {
      _heartTimer?.cancel();
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

  void _swipeLeft() {
    if (_isAnimating) return;
    setState(() {
      _isAnimating = true;
      _dragDx = -400.0;
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _state.nextCandidate();
        setState(() {
          _cardIndex = _state.activeCandidateIndex;
          _dragDx = 0.0;
          _dragDy = 0.0;
          _isAnimating = false;
        });
      }
    });
  }

  void _swipeRight() {
    if (_isAnimating) return;
    final currentCandidate = _state.candidates[_cardIndex];
    
    setState(() {
      _isAnimating = true;
      _dragDx = 400.0;
    });
    
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        // If they swiped right on Ananya Rao, trigger the match!
        if (currentCandidate.name == 'Ananya Rao') {
          _triggerMatch(currentCandidate.name);
        }
        _state.nextCandidate();
        setState(() {
          _cardIndex = _state.activeCandidateIndex;
          _dragDx = 0.0;
          _dragDy = 0.0;
          _isAnimating = false;
        });
      }
    });
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

    // Get current candidates (stack of 3)
    final candidateCount = _state.candidates.length;
    final first = _state.candidates[_cardIndex];
    final second = _state.candidates[(_cardIndex + 1) % candidateCount];
    final third = _state.candidates[(_cardIndex + 2) % candidateCount];

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
          children: const [
            Text(
              'Nearby now',
              style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E1F11),
              ),
            ),
            Text(
              '42 professionals · BLR T2',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                color: Color(0xFF8C736B),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8E2DD),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Filter · Investors',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E1F11),
              ),
            ),
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
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: double.infinity,
                      height: screenHeight * 0.62,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Third Card (Bottom)
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
                                  _swipeRight();
                                } else if (_dragDx < -120) {
                                  _swipeLeft();
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
                      ),
                    ),
                  ),
                ),

                // Button controls
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
                        onPressed: _swipeLeft,
                      ),
                      const SizedBox(width: 24),

                      // Heart/Connect Button
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
                          icon: Icons.favorite,
                          iconColor: Colors.white,
                          backgroundColor: Colors.transparent,
                          borderColor: Colors.transparent,
                          size: 68,
                          onPressed: _swipeRight,
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
                        onPressed: _swipeRight,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Match Overlay
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
                      'It\'s a match.',
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 44,
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
                      scale: _heartScale,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5A475).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
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
          // Header / Graphic block
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.primaryColor, const Color(0xFF3E1F11)],
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                // Top Tags
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.white, size: 12),
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
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white70, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          c.loc,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 10,
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Core details overlay
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    children: [
                      // Initials Block
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          c.initials,
                          style: const TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Name & Role
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: const TextStyle(
                                fontFamily: 'PlayfairDisplay',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              "${c.role} · ${c.org}",
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11,
                                color: Colors.white70,
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

          // Content body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Intent tag
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFB06F4D).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.track_changes, color: Color(0xFFB06F4D), size: 14),
                        const SizedBox(width: 8),
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
                  const SizedBox(height: 12),

                  // Bio
                  Text(
                    c.bio,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      color: Color(0xFF5C473E),
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Tags
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: c.tags.map((t) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8E2DD).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          t,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            color: Color(0xFF3E1F11),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const Spacer(),

                  // Highlights / Connections
                  if (isTop)
                    Row(
                      children: const [
                        Icon(Icons.star, color: Color(0xFFB06F4D), size: 12),
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
