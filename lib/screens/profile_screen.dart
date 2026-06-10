import 'package:flutter/material.dart';
import '../state_manager.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AppStateManager _state = AppStateManager();
  
  // Local active intent states
  final List<Map<String, dynamic>> _intents = [
    {'icon': Icons.trending_up_rounded, 'label': 'Raising Seed', 'active': true},
    {'icon': Icons.people_outline_rounded, 'label': 'Hiring CTO', 'active': false},
    {'icon': Icons.coffee_outlined, 'label': 'Open to coffee', 'active': true},
    {'icon': Icons.storefront_outlined, 'label': 'B2B partnerships', 'active': true},
  ];

  final List<String> _expertise = [
    'SME Lending',
    'Risk Models',
    'PMF',
    'Fintech',
    'Go-to-market'
  ];

  bool _isDiscoverable = true;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F5),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Card with Gradient
            Container(
              width: double.infinity,
              height: 180,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF7A432D),
                    Color(0xFF3E1F11),
                  ],
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'MY PROFILE',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: Colors.white70,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                style: IconButton.styleFrom(
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  _state.currentScreen = AppScreen.hub;
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Rohan Mehta',
                            style: TextStyle(
                              fontFamily: 'PlayfairDisplay',
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Founder · Fintech · Bengaluru',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Floating Avatar Initials
                  Positioned(
                    bottom: -32,
                    left: 24,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE8E2DD),
                        border: Border.all(color: const Color(0xFFFAF7F5), width: 4),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          )
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'RM',
                        style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF7A432D),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // Profile info body
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location Status Row
                  Row(
                    children: const [
                      Icon(Icons.location_on, size: 14, color: Color(0xFF7A432D)),
                      SizedBox(width: 6),
                      Text(
                        'Bengaluru T2 · until 6:40 PM',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8C736B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Description
                  const Text(
                    'Building an SME credit platform for Tier-2 India. 8 yrs in lending, ex-Razorpay. Looking to meet investors and design partners.',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      color: Color(0xFF5C473E),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Intents section
                  Row(
                    children: const [
                      Icon(Icons.track_changes_rounded, size: 14, color: Color(0xFF8C736B)),
                      SizedBox(width: 6),
                      Text(
                        'ACTIVE INTENTS',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Color(0xFF8C736B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.8,
                    ),
                    itemCount: _intents.length,
                    itemBuilder: (context, index) {
                      final intent = _intents[index];
                      final isActive = intent['active'];

                      return InkWell(
                        onTap: () {
                          setState(() {
                            intent['active'] = !isActive;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF7A432D).withValues(alpha: 0.06)
                                : Colors.white.withValues(alpha: 0.4),
                            border: Border.all(
                              color: isActive
                                  ? const Color(0xFF7A432D).withValues(alpha: 0.4)
                                  : const Color(0xFFE8E2DD),
                              width: 1.2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                intent['icon'],
                                size: 16,
                                color: isActive
                                    ? const Color(0xFF7A432D)
                                    : const Color(0xFF8C736B),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  intent['label'],
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    fontWeight: isActive
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isActive
                                        ? const Color(0xFF3E1F11)
                                        : const Color(0xFF8C736B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Expertise section
                  const Text(
                    'EXPERTISE',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Color(0xFF8C736B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _expertise.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8E2DD).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            color: Color(0xFF3E1F11),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Visibility settings card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE8E2DD)),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Visibility',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF8C736B),
                              ),
                            ),
                            Text(
                              'Discoverable nearby',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3E1F11),
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isDiscoverable,
                          activeThumbColor: const Color(0xFF7A432D),
                          activeTrackColor: const Color(0xFFFAF7F5),
                          inactiveThumbColor: const Color(0xFF8C736B),
                          inactiveTrackColor: const Color(0xFFE8E2DD),
                          onChanged: (val) {
                            setState(() {
                              _isDiscoverable = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7A432D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 1,
                      ),
                      onPressed: () {
                        _state.currentScreen = AppScreen.discover;
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'Discover connections nearby',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 15,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
