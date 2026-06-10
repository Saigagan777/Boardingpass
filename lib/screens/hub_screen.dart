import 'dart:async';
import 'package:flutter/material.dart';
import '../state_manager.dart';

class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width * 0.5, 0);
    path.lineTo(size.width, size.height * 0.25);
    path.lineTo(size.width, size.height * 0.75);
    path.lineTo(size.width * 0.5, size.height);
    path.lineTo(0, size.height * 0.75);
    path.lineTo(0, size.height * 0.25);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  final AppStateManager _state = AppStateManager();
  int? _hoveredIndex;
  int _tickerIndex = 0;
  Timer? _tickerTimer;

  // 6 Honeycomb activities
  final List<Map<String, dynamic>> _activities = [
    {
      'screen': AppScreen.profile,
      'label': 'Profile',
      'icon': Icons.business_center_outlined,
      'hint': 'Who you are',
      'color': const Color(0xFFFAF5F0),
      'textColor': const Color(0xFF7A432D),
    },
    {
      'screen': AppScreen.checkin,
      'label': 'Check in',
      'icon': Icons.location_on_outlined,
      'hint': 'Where you are',
      'color': const Color(0xFFFDF0DD),
      'textColor': const Color(0xFF7A432D),
    },
    {
      'screen': AppScreen.events,
      'label': 'Events',
      'icon': Icons.confirmation_number_outlined,
      'hint': 'What\'s on',
      'color': const Color(0xFFEFF0EA),
      'textColor': const Color(0xFF4A5D4E),
    },
    {
      'screen': AppScreen.discover,
      'label': 'Discover',
      'icon': Icons.explore_outlined,
      'hint': 'Who\'s near',
      'color': const Color(0xFFF1EBF5),
      'textColor': const Color(0xFF4A3B52),
    },
    {
      'screen': AppScreen.chat,
      'label': 'Chat',
      'icon': Icons.chat_bubble_outline_rounded,
      'hint': 'Talk it out',
      'color': const Color(0xFFEDF3F9),
      'textColor': const Color(0xFF1E3A5F),
    },
    {
      'screen': AppScreen.meeting,
      'label': 'Meet',
      'icon': Icons.calendar_today_outlined,
      'hint': 'Lock it in',
      'color': const Color(0xFFFDF1E6),
      'textColor': const Color(0xFF7A432D),
    },
  ];

  // Ad/Notification Slots
  final List<Map<String, dynamic>> _slots = [
    {
      'kind': 'ad',
      'brand': 'Plaza Premium',
      'title': '20% off lounge upgrade — today only',
      'cta': 'Claim',
      'color': const Color(0xFFFAF7F5),
      'icon': Icons.auto_awesome_outlined,
    },
    {
      'kind': 'notif',
      'title': 'Ananya wants to meet',
      'body': 'Replied to your coffee intent · 2m ago',
      'color': const Color(0xFFFAF7F5),
      'icon': Icons.chat_bubble_outline_rounded,
    },
    {
      'kind': 'ad',
      'brand': 'Amex Platinum',
      'title': 'Free lounge access at 1,400+ airports',
      'cta': 'Learn',
      'color': const Color(0xFFFAF7F5),
      'icon': Icons.star_outline_rounded,
    },
    {
      'kind': 'notif',
      'title': 'Fintech Mixer · 6 PM',
      'body': '3 of your connections registered',
      'color': const Color(0xFFFAF7F5),
      'icon': Icons.notifications_none_outlined,
    },
    {
      'kind': 'ad',
      'brand': 'Starbucks Reserve',
      'title': 'Buy 1 get 1 — flash 30 min near Gate 14',
      'cta': 'Show',
      'color': const Color(0xFFFAF7F5),
      'icon': Icons.coffee,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 3500), (timer) {
      if (mounted) {
        setState(() {
          _tickerIndex = (_tickerIndex + 1) % _slots.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    final Map<String, dynamic>? focusedActivity =
        _hoveredIndex != null ? _activities[_hoveredIndex!] : null;

    final String userName = _state.profileData?['given_name'] ?? 'Rohan';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFAF7F5),
            Color(0xFFFAF7F5),
            Color(0xFFE8E2DD),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Welcome Row
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.07,
                vertical: screenHeight < 650 ? screenHeight * 0.015 : screenHeight * 0.025,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ACTIVITY HUB',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.5,
                            color: Color(0xFF8C736B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Good morning, $userName',
                          style: TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            fontSize: screenHeight < 650 ? 20 : 24,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF3E1F11),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Pick any cell — no order, no funnel.',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            color: Color(0xFF8C736B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Profile Avatar
                  GestureDetector(
                    onTap: () {
                      _state.currentScreen = AppScreen.profile;
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE8E2DD),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          )
                        ],
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _state.profileData?['picture'] != null
                          ? Image.network(
                              _state.profileData!['picture']!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Text(
                                  userName.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    fontFamily: 'PlayfairDisplay',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Color(0xFF7A432D),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                userName.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: 'PlayfairDisplay',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Color(0xFF7A432D),
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // Hexagon Stage
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Compute scaling factor based on the available space inside Expanded
                  final double scale = (constraints.maxHeight < 340 || constraints.maxWidth < 320)
                      ? (constraints.maxHeight / 340 < constraints.maxWidth / 320
                          ? constraints.maxHeight / 340
                          : constraints.maxWidth / 320).clamp(0.6, 1.0)
                      : 1.0;

                  final double stageWidth = 320 * scale;
                  final double stageHeight = 340 * scale;
                  final double R = 96.0 * scale;

                  // Angle positions around the center
                  final List<Offset> positions = [
                    Offset(0, -R), // top (Profile)
                    Offset(R * 0.866, -R * 0.5), // top-right (Check in)
                    Offset(R * 0.866, R * 0.5), // bottom-right (Events)
                    Offset(0, R), // bottom (Discover)
                    Offset(-R * 0.866, R * 0.5), // bottom-left (Chat)
                    Offset(-R * 0.866, -R * 0.5), // top-left (Meet)
                  ];

                  return Center(
                    child: SizedBox(
                      width: stageWidth,
                      height: stageHeight,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Concentric decorative rings
                          Container(
                            width: 260 * scale,
                            height: 260 * scale,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE8E2DD),
                                width: 1.2 * scale,
                              ),
                            ),
                          ),
                          Container(
                            width: 180 * scale,
                            height: 180 * scale,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE8E2DD),
                                width: 1.2 * scale,
                              ),
                            ),
                          ),

                          // Center dynamic text/icon container
                          SizedBox(
                            width: 110 * scale,
                            height: 110 * scale,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: focusedActivity != null
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      key: ValueKey('focused_$_hoveredIndex'),
                                      children: [
                                        Text(
                                          'ACTIVITY',
                                          style: TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 9 * scale,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 2 * scale,
                                            color: const Color(0xFF8C736B),
                                          ),
                                        ),
                                        SizedBox(height: 2 * scale),
                                        Text(
                                          focusedActivity['label'],
                                          style: TextStyle(
                                            fontFamily: 'PlayfairDisplay',
                                            fontSize: 16 * scale,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF3E1F11),
                                          ),
                                        ),
                                        Text(
                                          focusedActivity['hint'],
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 10 * scale,
                                            color: const Color(0xFF8C736B),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      key: const ValueKey('idle_hub'),
                                      children: [
                                        Container(
                                          width: 60 * scale,
                                          height: 60 * scale,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Color(0xFF9E5738),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black12,
                                                blurRadius: 6,
                                                offset: Offset(0, 3),
                                              )
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.airplanemode_active,
                                            color: Colors.white,
                                            size: 26 * scale,
                                          ),
                                        ),
                                        SizedBox(height: 6 * scale),
                                        Text(
                                          'HUB',
                                          style: TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 10 * scale,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 2.5 * scale,
                                            color: const Color(0xFF9E5738),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          // Build the 6 hex cells
                          ...List.generate(6, (index) {
                            final act = _activities[index];
                            final pos = positions[index];
                            final isFocused = _hoveredIndex == index;
                            final isAnyFocused = _hoveredIndex != null;

                            return Positioned(
                              left: (stageWidth / 2) + pos.dx - (36 * scale),
                              top: (stageHeight / 2) + pos.dy - (40 * scale),
                              child: GestureDetector(
                                onPanDown: (_) => setState(() => _hoveredIndex = index),
                                onPanCancel: () => setState(() => _hoveredIndex = null),
                                onPanEnd: (_) => setState(() => _hoveredIndex = null),
                                onTapDown: (_) => setState(() => _hoveredIndex = index),
                                onTapUp: (_) => setState(() => _hoveredIndex = null),
                                onTap: () {
                                  _state.currentScreen = act['screen'];
                                },
                                child: MouseRegion(
                                  onEnter: (_) => setState(() => _hoveredIndex = index),
                                  onExit: (_) => setState(() => _hoveredIndex = null),
                                  child: AnimatedScale(
                                    duration: const Duration(milliseconds: 200),
                                    scale: isFocused
                                        ? 1.15
                                        : (isAnyFocused ? 0.88 : 1.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ClipPath(
                                          clipper: HexagonClipper(),
                                          child: Container(
                                            width: 72 * scale,
                                            height: 80 * scale,
                                            color: act['color'],
                                            alignment: Alignment.center,
                                            child: Icon(
                                              act['icon'],
                                              color: act['textColor'],
                                              size: 26 * scale,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 4 * scale),
                                        AnimatedOpacity(
                                          duration: const Duration(milliseconds: 200),
                                          opacity: isFocused ? 1.0 : 0.6,
                                          child: Text(
                                            act['label'],
                                            style: TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              fontSize: 10 * scale,
                                              fontWeight: FontWeight.bold,
                                              color: isFocused
                                                  ? const Color(0xFF3E1F11)
                                                  : const Color(0xFF8C736B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Ad / Notifications Carousel
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
              child: _buildAdNotifCarousel(),
            ),

            SizedBox(height: screenHeight < 650 ? 4 : 12),

            // Location Strip
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.06,
                vertical: screenHeight < 650 ? screenHeight * 0.008 : screenHeight * 0.02,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFAF0E6), width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFDF1E6),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.location_on,
                            color: Color(0xFF7A432D),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'LIVE CONTEXT',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8C736B),
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              'BLR T2 · Plaza Premium · 42 nearby',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3E1F11),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Icon(
                      Icons.access_time_rounded,
                      color: Color(0xFF8C736B),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdNotifCarousel() {
    final slot = _slots[_tickerIndex];
    final isAd = slot['kind'] == 'ad';
    final IconData icon = slot['icon'] ?? Icons.notifications;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey('carousel_slot_$_tickerIndex'),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFAF0E6), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            )
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Icon Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isAd ? const Color(0xFFFAF5F0) : const Color(0xFFFDF1E6),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        icon == Icons.coffee ? Icons.coffee_outlined : icon,
                        color: isAd ? const Color(0xFF7A432D) : const Color(0xFFB06F4D),
                        size: 20,
                      ),
                      if (!isAd)
                        Positioned(
                          top: -1,
                          right: -1,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFFB06F4D),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tag header
                      Text(
                        isAd
                            ? 'SPONSORED · ${slot['brand']}'.toUpperCase()
                            : 'NOTIFICATION',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isAd
                              ? const Color(0xFF8C736B)
                              : const Color(0xFFB06F4D),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        slot['title'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                      if (!isAd && slot['body'] != null)
                        Text(
                          slot['body'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            color: Color(0xFF8C736B),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Action
                if (isAd)
                  Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3E1F11),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        slot['cta'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Color(0xFF8C736B),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Progress Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slots.length, (i) {
                final isActive = i == _tickerIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 3,
                  width: isActive ? 16 : 4,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF7A432D)
                        : const Color(0xFFE8E2DD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
