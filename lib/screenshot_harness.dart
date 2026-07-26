import 'package:flutter/material.dart';
import 'state_manager.dart';
import 'models/user_profile.dart';
import 'models/candidate.dart';
import 'models/event.dart';
import 'screens/onboarding_screen.dart';
import 'screens/hub_screen.dart';
import 'screens/discover_screen.dart';
import 'screens/events_screen.dart';
import 'screens/meet_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/candidate_profile_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScreenshotHarnessApp());
}

class ScreenshotHarnessApp extends StatefulWidget {
  const ScreenshotHarnessApp({super.key});

  @override
  State<ScreenshotHarnessApp> createState() => _ScreenshotHarnessAppState();
}

class _ScreenshotHarnessAppState extends State<ScreenshotHarnessApp> {
  int _activeScreenIndex = 0; // 0..7
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _populateMockData();
  }

  void _populateMockData() {
    final state = AppStateManager();

    // 1. Current User Profile
    final currentUser = UserProfile(
      uid: 'user_sarah_01',
      name: 'Sarah Jenkins',
      email: 'sarah.jenkins@anthropic.com',
      industry: 'Artificial Intelligence',
      experience: '8+ Years',
      homeBase: 'San Francisco, CA',
      currentLocationName: 'San Francisco, CA',
      headline: 'Lead AI Researcher @ Anthropic | Ex-Google DeepMind',
      company: 'Anthropic',
      role: 'Lead AI Researcher',
      bio: 'Building next-gen alignment & LLM architectures. Passionate about AI safety, scaling laws, and coffee.',
      skills: ['PyTorch', 'Transformers', 'Distributed Training', 'Python', 'LLMs'],
      interests: ['AI Safety', 'Generative Models', 'Startups', 'Hiking', 'Specialty Coffee'],
      expertise: ['AI / Machine Learning', 'Distributed Systems'],
      intents: ['Co-Founders & Technical Partners', 'Advisory & Mentorship'],
      isDiscoverable: true,
      isAdmin: false,
      createdAt: DateTime.now().subtract(const Duration(days: 120)),
      lastSeen: DateTime.now(),
      connectionsCount: 42,
      eventsJoinedCount: 12,
      eventsHostedCount: 3,
      cardImages: [],
      customCards: [],
      connectionCount: 42,
      followerCount: 1580,
      followedTopics: ['Artificial Intelligence', 'LLMs', 'Venture Capital'],
      professionalInterests: ['AI Architecture', 'Founding Teams', 'Deep Learning'],
      careerTimeline: [
        {
          'title': 'Lead AI Researcher',
          'company': 'Anthropic',
          'period': '2023 - Present',
          'description': 'Leading research on LLM alignment, RLHF, and inference optimization.',
        },
        {
          'title': 'Senior Staff Research Scientist',
          'company': 'Google DeepMind',
          'period': '2019 - 2023',
          'description': 'Contributed to Transformer architectures and distributed training infrastructure.',
        },
      ],
      educationTimeline: [
        {
          'institution': 'Stanford University',
          'degree': 'Ph.D. Computer Science (AI/ML)',
          'year': '2019',
        },
      ],
      notificationSettings: {},
    );

    state.setMockUserProfile(currentUser);

    // 2. Candidate Stack for Discover & Profile Detail Screens
    final mockCandidates = [
      Candidate(
        uid: 'cand_priya_02',
        name: 'Priya Sharma',
        headline: 'Principal Design Lead @ Figma | Design Systems & Accessibility',
        role: 'Principal Design Lead',
        org: 'Figma',
        loc: 'San Francisco, CA (0.6 km away)',
        match: 96,
        intent: 'Seeking Advisory Roles & Design Mentorship',
        tags: ['Design Systems', 'UI/UX', 'Mobile Apps', 'Accessibility'],
        bio: 'Crafting intuitive digital experiences. Specializing in high-level design systems, micro-animations, and collaborative design tooling.',
        initials: 'PS',
        primaryColor: const Color(0xFF6C5CE7),
        skills: ['Figma', 'Design Systems', 'Prototyping', 'Design Thinking', 'User Research'],
        interests: ['Product Design', 'Typography', 'Micro-Interactions', 'Art & Architecture'],
        homeBase: 'San Francisco, CA',
        currentLocationName: 'San Francisco, CA',
        industry: 'Design & Software',
        experience: '7+ Years',
        matchReasons: ['Shared interest in Product Strategy', 'High industry synergy (Design + AI)', 'Located nearby in SF'],
        conversationStarters: ['Ask about her favorite Figma plugin!', 'Discuss the latest design system trends.'],
        badges: ['Design Mentor', 'Verified Leader', 'Top 5% Matched'],
        completedMentoringSessions: 18,
        successfulCollaborations: 9,
        distanceKm: 0.6,
        expertiseWithLevel: [
          {'name': 'Design Systems', 'level': 'Expert'},
          {'name': 'UX Prototyping', 'level': 'Advanced'},
          {'name': 'Accessibility', 'level': 'Expert'},
        ],
        interestsWithPriority: [
          {'name': 'Design Tooling', 'priority': 'High'},
          {'name': 'AI in UX', 'priority': 'High'},
        ],
        careerTimeline: [
          {
            'title': 'Principal Design Lead',
            'company': 'Figma',
            'period': '2021 - Present',
          },
          {
            'title': 'Senior Product Designer',
            'company': 'Airbnb',
            'period': '2018 - 2021',
          },
        ],
      ),
      Candidate(
        uid: 'cand_aarav_03',
        name: 'Aarav Patel',
        headline: 'Founder & CEO @ Nexus Data | YC W24',
        role: 'Founder & CEO',
        org: 'Nexus Data',
        loc: 'San Francisco, CA (1.2 km away)',
        match: 92,
        intent: 'Raising Seed Round & Hiring Engineers',
        tags: ['Distributed Systems', 'Rust', 'Go', 'Venture Capital'],
        bio: 'Building real-time data pipelines for enterprise AI infrastructure. Previously scaled 2 developer tool startups.',
        initials: 'AP',
        primaryColor: const Color(0xFF00CEC9),
        skills: ['Rust', 'Go', 'Apache Kafka', 'Distributed Systems', 'Cloud Native'],
        interests: ['Data Infrastructure', 'Startups', 'Seed Fundraising', 'Open Source'],
        homeBase: 'San Francisco, CA',
        currentLocationName: 'San Francisco, CA',
        industry: 'Enterprise Data & Infrastructure',
        experience: '6+ Years',
        matchReasons: ['Both in early-stage tech innovation', 'Shared tech stack in backend systems'],
        conversationStarters: ['Ask about his YC experience!', 'Talk about high-throughput Rust architectures.'],
        badges: ['YC Alum', 'Active Founder', 'Top Matched'],
        completedMentoringSessions: 12,
        successfulCollaborations: 14,
        distanceKm: 1.2,
        expertiseWithLevel: [
          {'name': 'Distributed Systems', 'level': 'Expert'},
          {'name': 'Rust / Go', 'level': 'Expert'},
        ],
        interestsWithPriority: [
          {'name': 'AI Infrastructure', 'priority': 'High'},
        ],
      ),
    ];

    state.setMockCandidates(mockCandidates);

    // 3. Events List for Events Screen
    final mockEvents = [
      Event(
        id: 'event_01',
        illustrationPath: 'assets/images/boarding_pass_illustration.png',
        month: 'AUG',
        day: '15',
        title: 'AI & Web3 Innovators Summit 2026',
        location: 'Palace of Fine Arts, San Francisco',
        time: '06:00 PM - 09:30 PM PST',
        attendees: '142 Attending',
        category: 'Summit',
        price: 'Free Pass',
        mapUrl: 'https://maps.google.com',
        latitude: 37.8029,
        longitude: -122.4484,
        imageUrl: '',
        organiserId: 'admin',
        isJoined: true,
        isRegistered: true,
      ),
      Event(
        id: 'event_02',
        illustrationPath: 'assets/images/boarding_pass_illustration_2.png',
        month: 'AUG',
        day: '22',
        title: 'SF Tech Founders Coffee & Pitches',
        location: 'Blue Bottle Coffee, Market St',
        time: '09:00 AM - 11:00 AM PST',
        attendees: '48 Attending',
        category: 'Networking',
        price: 'Free',
        mapUrl: 'https://maps.google.com',
        latitude: 37.7897,
        longitude: -122.4036,
        imageUrl: '',
        organiserId: 'admin',
        isJoined: true,
        isRegistered: false,
      ),
      Event(
        id: 'event_03',
        illustrationPath: 'assets/images/boarding_pass_illustration_3.png',
        month: 'SEP',
        day: '05',
        title: 'Design Systems & UX Architecture Roundtable',
        location: 'Figma HQ, Downtown SF',
        time: '05:30 PM - 08:00 PM PST',
        attendees: '75 Attending',
        category: 'Workshop',
        price: 'Invite Only',
        mapUrl: 'https://maps.google.com',
        latitude: 37.7901,
        longitude: -122.4012,
        imageUrl: '',
        organiserId: 'admin',
        isJoined: false,
        isRegistered: false,
      ),
    ];

    state.setMockEvents(mockEvents);
  }

  Widget _buildScreenContent() {
    switch (_activeScreenIndex) {
      case 0:
        // Screen 1: Splash / Onboarding
        return const OnboardingScreen();
      case 1:
        // Screen 2: Sign-In Screen (LinkedIn OAuth UI view)
        return const OnboardingScreen();
      case 2:
        // Screen 3: Activity Hub Screen (Hexagon Cluster Navigation)
        return const HubScreen();
      case 3:
        // Screen 4: Discover / Nearby Professionals
        return const DiscoverScreen();
      case 4:
        // Screen 5: Events Screen
        return const EventsScreen();
      case 5:
        // Screen 6: Meet Screen (1-on-1 Coffee & Meeting Scheduler)
        return const MeetScreen();
      case 6:
        // Screen 7: Chat Screen (Rich Conversations & AI Icebreakers)
        return const ChatScreen(name: 'Priya Sharma');
      case 7:
        // Screen 8: Profile / Candidate Detail Sheet
        final mockCandidate = AppStateManager().candidates.first;
        return Scaffold(
          backgroundColor: const Color(0xFFFAF7F5),
          body: SafeArea(
            child: CandidateProfileSheet(candidate: mockCandidate),
          ),
        );
      default:
        return const HubScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NexMeet Screenshot Harness',
      debugShowCheckedModeBanner: false, // Ensure no DEBUG banner
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAF7F5),
        primaryColor: const Color(0xFF7A432D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7A432D),
          primary: const Color(0xFF7A432D),
          secondary: const Color(0xFF3E1F11),
          surface: const Color(0xFFFAF7F5),
          onSurface: const Color(0xFF3E1F11),
        ),
        fontFamily: 'PlusJakartaSans',
      ),
      home: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: _buildScreenContent(),
            ),

            // Top Floating Toolbar overlay to toggle between 8 screens for capture
            if (_showControls)
              Positioned(
                top: 40,
                left: 12,
                right: 12,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFF3E1F11).withValues(alpha: 0.92),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'NexMeet Screenshot Harness (9:16)',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 20),
                              onPressed: () {
                                setState(() {
                                  _showControls = false;
                                });
                              },
                              tooltip: 'Hide overlay for screenshot capture',
                            ),
                          ],
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(8, (i) {
                              final labels = [
                                '1. Onboarding',
                                '2. Sign-In',
                                '3. Activity Hub',
                                '4. Discover',
                                '5. Events',
                                '6. Meet',
                                '7. Chat',
                                '8. Profile',
                              ];
                              final isSelected = _activeScreenIndex == i;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(
                                    labels[i],
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.black87,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 11,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: const Color(0xFF7A432D),
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _activeScreenIndex = i;
                                      });
                                    }
                                  },
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Tap gesture hint to bring overlay back if hidden
            if (!_showControls)
              Positioned(
                top: 8,
                right: 8,
                child: SafeArea(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showControls = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.settings_overscan,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
