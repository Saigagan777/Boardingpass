import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../state_manager.dart';
import '../services/user_service.dart';
import '../services/chat_service.dart';
import '../services/event_service.dart';
import '../models/user_profile.dart';
import '../utils/image_helper.dart';
import 'google_location_dropdown.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AppStateManager _state = AppStateManager();
  final bool _isLoading = false;
  int _activeProfileTab = 0;

  void _showEditProfileModal(BuildContext context, UserProfile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _EditProfileSheet(profile: profile);
      },
    );
  }

  double _calculateProfileCompleteness(UserProfile profile) {
    int total = 0;
    int completed = 0;

    total++;
    if (profile.name.trim().isNotEmpty) completed++;
    total++;
    if (profile.email.trim().isNotEmpty) completed++;
    total++;
    if ((profile.profileImageUrl ?? '').trim().isNotEmpty) completed++;
    total++;
    if ((profile.role ?? '').trim().isNotEmpty) completed++;
    total++;
    if ((profile.company ?? '').trim().isNotEmpty) completed++;
    total++;
    if ((profile.headline ?? '').trim().isNotEmpty) completed++;
    total++;
    if (profile.expertise.isNotEmpty || profile.skills.isNotEmpty) completed++;
    total++;
    if ((profile.industry ?? '').trim().isNotEmpty && profile.industry != 'Select Industry') completed++;
    total++;
    if ((profile.experience ?? '').trim().isNotEmpty) completed++;
    total++;
    if ((profile.bio ?? '').trim().isNotEmpty) completed++;
    total++;
    if (profile.intents.isNotEmpty) completed++;
    total++;
    if ((profile.travelFrequency ?? '').trim().isNotEmpty && profile.travelFrequency != 'Select Frequency') completed++;
    total++;
    if ((profile.currentLocationName ?? '').trim().isNotEmpty) completed++;
    total++;
    if (profile.careerTimeline.isNotEmpty) completed++;
    total++;
    if (profile.educationTimeline.isNotEmpty) completed++;

    return total == 0 ? 0.0 : (completed / total) * 100.0;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: UserService().streamCurrentUserProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFFAF7F5),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7A432D)),
              ),
            ),
          );
        }

        final profile = snapshot.data;
        if (profile == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFFAF7F5),
            body: Center(child: Text('Profile not found.')),
          );
        }

        final currentUser = FirebaseAuth.instance.currentUser;
        final String name = (profile.name.isNotEmpty && profile.name != 'User')
            ? profile.name
            : ((_state.profileData?['name']?.isNotEmpty == true && _state.profileData!['name'] != 'User')
                ? _state.profileData!['name']!
                : (currentUser?.displayName?.isNotEmpty == true
                    ? currentUser!.displayName!
                    : (currentUser?.email?.isNotEmpty == true ? currentUser!.email!.split('@')[0] : 'User')));
        final String headline = (profile.headline != null && profile.headline!.isNotEmpty)
            ? profile.headline!
            : '';
        final String workingLocation = (profile.currentLocationName != null && profile.currentLocationName!.isNotEmpty)
            ? profile.currentLocationName!
            : '';
        final String email = profile.email;
        final String bio = (profile.bio != null && profile.bio!.isNotEmpty)
            ? profile.bio!
            : 'No bio added yet. Tap Edit to introduce yourself!';
        final String currentLocation = (profile.currentLocationName != null && profile.currentLocationName!.isNotEmpty)
            ? profile.currentLocationName!
            : 'Not set';
        final String travelFrequency = (profile.travelFrequency != null && profile.travelFrequency!.isNotEmpty)
            ? profile.travelFrequency!
            : 'Not set';
        final List<String> interests = profile.interests;
        final List<String> skills = profile.skills;
        final completeness = _calculateProfileCompleteness(profile);

        return Scaffold(
          backgroundColor: const Color(0xFFFAF7F5),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF7A432D)),
                )
              : SafeArea(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(profile, completeness, context),
                        const SizedBox(height: 16),
                        _buildInfoSection(name, headline, email, workingLocation, profile, context),
                        const SizedBox(height: 16),
                        _buildStatsRow(profile, context),
                        const SizedBox(height: 20),
                        _buildProfileTabSwitcher(),
                        const SizedBox(height: 20),
                        IndexedStack(
                          index: _activeProfileTab,
                          children: [
                            // Tab 0: Professional
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (bio.isNotEmpty && bio != 'No bio added yet. Tap Edit to introduce yourself!') ...[
                                  _buildSectionLabel('About Me', Icons.person_outline_rounded),
                                  const SizedBox(height: 10),
                                  _buildAboutCard(bio),
                                  const SizedBox(height: 20),
                                ],
                                _buildSectionLabel('Work Experience', Icons.business_center_outlined),
                                const SizedBox(height: 10),
                                _buildTimelineSection(
                                  items: profile.careerTimeline,
                                  type: 'career',
                                  emptyText: 'No work experience added yet.',
                                ),
                                const SizedBox(height: 20),
                                _buildSectionLabel('Education', Icons.school_outlined),
                                const SizedBox(height: 10),
                                _buildTimelineSection(
                                  items: profile.educationTimeline,
                                  type: 'education',
                                  emptyText: 'No education details added yet.',
                                ),
                                const SizedBox(height: 20),
                                _buildSectionLabel('Expertise', Icons.verified_outlined),
                                const SizedBox(height: 10),
                                _buildSkillsCard(skills, profile),
                                const SizedBox(height: 30),
                              ],
                            ),
                            // Tab 1: Interests
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionLabel('Travel Profile', Icons.flight_takeoff_rounded),
                                const SizedBox(height: 10),
                                _buildTravelCard(currentLocation, travelFrequency),
                                const SizedBox(height: 20),
                                _buildSectionLabel('Interests & Looking For', Icons.explore_outlined),
                                const SizedBox(height: 10),
                                _buildInterestsCard(interests, profile),
                                const SizedBox(height: 30),
                              ],
                            ),
                            // Tab 2: Settings
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionLabel('Account & Settings', Icons.settings_outlined),
                                const SizedBox(height: 10),
                                _buildSettingsMenu(context, profile),
                                const SizedBox(height: 30),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildHeader(UserProfile profile, double completeness, BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final pictureUrl = (profile.profileImageUrl != null && profile.profileImageUrl!.isNotEmpty)
        ? profile.profileImageUrl!
        : ((_state.profileData?['picture']?.isNotEmpty == true)
            ? _state.profileData!['picture']!
            : (currentUser?.photoURL ?? ''));
    final coverUrl = (profile.coverImageUrl != null && profile.coverImageUrl!.isNotEmpty)
        ? profile.coverImageUrl!
        : '';
    final displayName = (profile.name.isNotEmpty && profile.name != 'User')
        ? profile.name
        : (currentUser?.displayName ?? (_state.profileData?['name'] ?? ''));
    final initials = displayName.isNotEmpty && displayName != 'User'
        ? displayName.trim().split(' ').where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join().toUpperCase()
        : 'U';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
          child: SizedBox(
            height: 200,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                buildProfileImage(
                  coverUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  fallback: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF7A432D), Color(0xFF3E1F11)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.35),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildIconCircle(
                Icons.arrow_back_ios_new_rounded,
                () => _state.currentScreen = AppScreen.hub,
              ),
              Row(
                children: [
                  _buildIconCircle(
                    Icons.ios_share_rounded,
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile link copied to clipboard')),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildEditButton(context, profile),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          left: 24,
          bottom: -40,
          child: _buildAvatarStack(pictureUrl, initials, completeness),
        ),
      ],
    );
  }

  Widget _buildIconCircle(IconData icon, VoidCallback onTap) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.92),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 16, color: const Color(0xFF7A432D)),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildEditButton(BuildContext context, UserProfile profile) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        color: Colors.white.withValues(alpha: 0.92),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: () => _showEditProfileModal(context, profile),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 14, color: const Color(0xFF7A432D)),
                const SizedBox(width: 6),
                Text(
                  'Edit',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF7A432D),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarStack(String pictureUrl, String initials, double completeness) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 96,
                height: 96,
                child: CircularProgressIndicator(
                  value: completeness / 100.0,
                  strokeWidth: 3.5,
                  backgroundColor: const Color(0xFFD6F0DB),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
                ),
              ),
              Container(
                width: 86,
                height: 86,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
              Container(
                width: 78,
                height: 78,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE8E2DD),
                ),
                child: ClipOval(
                  child: buildProfileImage(
                    pictureUrl,
                    width: 78,
                    height: 78,
                    fit: BoxFit.cover,
                    fallback: Container(
                      color: const Color(0xFFE8E2DD),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF7A432D),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Transform.translate(
          offset: const Offset(0, 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 12, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  '${completeness.toInt()}% Complete',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(
    String name,
    String headline,
    String email,
    String workingLocation,
    UserProfile profile,
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E1F11),
            ),
          ),
          if (profile.badges.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: profile.badges.map((badge) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars, size: 12, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 4),
                      Text(
                        badge,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          if (headline.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              headline,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                color: Color(0xFF5C473E),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
          ] else ...[
            const SizedBox(height: 6),
          ],
          if (email.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.email_outlined, size: 14, color: const Color(0xFF7A432D)),
                  const SizedBox(width: 8),
                  Text(
                    email,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      color: Color(0xFF8C736B),
                    ),
                  ),
                ],
              ),
            ),
          if (workingLocation.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.place_outlined, size: 14, color: const Color(0xFF7A432D)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    workingLocation,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      color: Color(0xFF8C736B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          _buildLinkedInButton(
            (profile.linkedinProfileUrl != null && profile.linkedinProfileUrl!.isNotEmpty) ||
                profile.linkedinSynced || (profile.linkedinId != null && profile.linkedinId!.isNotEmpty),
            profile,
            context,
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedInButton(bool isConnected, UserProfile profileData, BuildContext context) {
    return Material(
      color: const Color(0xFF0A66C2),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          final url = profileData.linkedinProfileUrl;
          if (url != null && url.isNotEmpty) {
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          } else if (profileData.linkedinSynced || (profileData.linkedinId != null && profileData.linkedinId!.isNotEmpty)) {
            launchUrl(Uri.parse('https://www.linkedin.com/me'), mode: LaunchMode.externalApplication);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No LinkedIn profile linked. Add your LinkedIn URL in Edit Profile.'),
                backgroundColor: Color(0xFF0A66C2),
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                isConnected ? 'View LinkedIn' : 'Connect LinkedIn',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(UserProfile profile, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEADDD6), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: ChatService().streamUserChats(),
                builder: (context, chatSnapshot) {
                  final count = chatSnapshot.hasData
                      ? chatSnapshot.data!.docs.length
                      : profile.connectionsCount;
                  return _buildStatItem(
                    Icons.people_outline_rounded,
                    '$count',
                    'Connections',
                  );
                },
              ),
            ),
            Container(height: 32, width: 1, color: const Color(0xFFE8E2DD)),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('events')
                    .where('attendees', arrayContains: profile.uid)
                    .snapshots(),
                builder: (context, joinedSnapshot) {
                  final count = joinedSnapshot.hasData
                      ? joinedSnapshot.data!.docs.length
                      : profile.eventsJoinedCount;
                  return _buildStatItem(
                    Icons.calendar_today_outlined,
                    '$count',
                    'Joined',
                  );
                },
              ),
            ),
            Container(height: 32, width: 1, color: const Color(0xFFE8E2DD)),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: EventService().streamEventsByUser(profile.uid),
                builder: (context, hostedSnapshot) {
                  final count = hostedSnapshot.hasData
                      ? hostedSnapshot.data!.docs.length
                      : profile.eventsHostedCount;
                  return _buildStatItem(
                    Icons.star_border_rounded,
                    '$count',
                    'Hosted',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF7A432D)),
            const SizedBox(width: 5),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E1F11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8C736B),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTabSwitcher() {
    final tabs = [
      ('Professional', Icons.work_outline),
      ('Interests', Icons.explore_outlined),
      ('Settings', Icons.settings_outlined),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 50,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF6F3),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFF0EAE5), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabWidth = constraints.maxWidth / 3;

            return Stack(
              children: [
                // Fixed Dividers between unselected tabs
                Positioned.fill(
                  child: Row(
                    children: [
                      const Expanded(child: SizedBox.shrink()),
                      if (_activeProfileTab != 0 && _activeProfileTab != 1)
                        Container(width: 1, height: 16, color: const Color(0xFFE5DDD7)),
                      const Expanded(child: SizedBox.shrink()),
                      if (_activeProfileTab != 1 && _activeProfileTab != 2)
                        Container(width: 1, height: 16, color: const Color(0xFFE5DDD7)),
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                ),
                // Animated Selected Pill Indicator
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  left: _activeProfileTab * tabWidth,
                  top: 0,
                  bottom: 0,
                  width: tabWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF753B23),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF753B23).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
                // Tab Text & Icons Row
                Row(
                  children: List.generate(tabs.length, (index) {
                    final isSelected = _activeProfileTab == index;
                    final item = tabs[index];

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_activeProfileTab != index) {
                            setState(() {
                              _activeProfileTab = index;
                            });
                          }
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                item.$2,
                                size: 17,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF4A342B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item.$1,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF3E1F11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCardContainer({required Widget child, EdgeInsetsGeometry? padding, double? width}) {
    return Container(
      width: width ?? double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionLabel(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF7A432D).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF7A432D)),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E1F11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection({
    required List<Map<String, dynamic>> items,
    required String type,
    required String emptyText,
  }) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _buildCardContainer(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF8C736B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.info_outline, size: 16, color: Color(0xFF8C736B)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  emptyText,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    color: Color(0xFF8C736B),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _buildCardContainer(
        child: Column(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isLast = index == items.length - 1;
            final titleText = type == 'career' ? (item['role'] ?? '') : (item['degree'] ?? '');
            final subtitleText = type == 'career' ? (item['company'] ?? '') : (item['school'] ?? '');
            final String durationLine;
            if (type == 'career' &&
                ((item['startDate'] ?? '').toString().isNotEmpty ||
                    (item['endDate'] ?? '').toString().isNotEmpty)) {
              durationLine = [
                '${item['startDate'] ?? ''} ${item['endDate'] ?? ''}',
                if ((item['employmentType'] ?? '').toString().isNotEmpty) item['employmentType'],
                if ((item['location'] ?? '').toString().isNotEmpty) item['location'],
              ].where((s) => s != null && s.toString().isNotEmpty).join('  ');
            } else {
              durationLine = item['duration'] ?? '';
            }
            final description = item['description'] ?? '';

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8E2DD)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 3,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7A432D),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titleText,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3E1F11),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitleText,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF7A432D),
                            ),
                          ),
                          if (durationLine.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                durationLine,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  color: Color(0xFF8C736B),
                                ),
                              ),
                            ),
                          if (description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                description,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  color: Color(0xFF5C473E),
                                  height: 1.4,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Column(
      children: [
        Container(height: 1, color: const Color(0xFFE8E2DD)),
        const SizedBox(height: 16),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8C736B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7A432D).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: const Color(0xFF7A432D)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3E1F11),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAboutCard(String bio) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _buildCardContainer(
        child: Text(
          bio,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            color: Color(0xFF5C473E),
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSkillsCard(List<String> skills, UserProfile profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _buildCardContainer(
        child: skills.isEmpty
            ? Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8C736B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.info_outline, size: 16, color: Color(0xFF8C736B)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No expertise added yet. Tap Edit to add your expertise.',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        color: Color(0xFF8C736B),
                      ),
                    ),
                  ),
                ],
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: skills.map((s) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7A432D).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF7A432D).withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF7A432D),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          s,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7A432D),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }

  Widget _buildInterestsCard(List<String> interests, UserProfile profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _buildCardContainer(
        child: interests.isEmpty
            ? Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8C736B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.info_outline, size: 16, color: Color(0xFF8C736B)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No interests added yet. Tap Edit to add your interests.',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        color: Color(0xFF8C736B),
                      ),
                    ),
                  ),
                ],
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: interests.map((tag) {
                  final icon = _getInterestIcon(tag);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7A432D).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF7A432D).withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 13, color: const Color(0xFF7A432D)),
                        const SizedBox(width: 6),
                        Text(
                          tag,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF3E1F11),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }

  Widget _buildTravelCard(String currentLocation, String travelFrequency) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _buildCardContainer(child: _buildTravelBody(currentLocation, travelFrequency)),
    );
  }

  Widget _buildTravelBody(String currentLocation, String travelFrequency) {
    return Column(
      children: [
        _buildInfoRow(Icons.my_location_rounded, 'Current', currentLocation),
        _buildInfoRow(Icons.flight_takeoff_outlined, 'Frequency', travelFrequency),
      ],
    );
  }

  Widget _buildSettingsMenu(BuildContext context, UserProfile profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _buildCardContainer(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _buildMenuItem(Icons.settings_outlined, 'Settings', 'Account preferences', () {}),
            _buildMenuItem(Icons.security_outlined, 'Privacy', 'Data & security controls', () {}),
            _buildMenuItem(Icons.help_outline_rounded, 'Help & Support', 'FAQs & contact', () {}),
            Builder(builder: (_) {
              final fbEmail = FirebaseAuth.instance.currentUser?.email ?? '';
              final isLinkedInSynthetic = fbEmail.startsWith('linkedin_') && fbEmail.contains('@boardingpass.com');
              final hasPassword = !isLinkedInSynthetic || profile.directPasswordSet;
              return _buildMenuItem(
                hasPassword ? Icons.lock_reset_rounded : Icons.lock_open_rounded,
                hasPassword ? 'Change Password' : 'Set Password',
                hasPassword ? 'Update your login credentials' : 'Add a password for direct sign-in',
                () => _showPasswordDialogFromProfile(context, profile, !hasPassword),
              );
            }),
            _buildMenuItem(Icons.logout_rounded, 'Logout', 'Sign out of your account', () => _state.logOut(), isLogout: true),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle, VoidCallback onTap, {bool isLogout = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: isLogout
            ? null
            : BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: const Color(0xFFF0EBE8)),
                ),
              ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isLogout
                    ? const Color(0xFF8B2500).withValues(alpha: 0.08)
                    : const Color(0xFF7A432D).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isLogout ? const Color(0xFF8B2500) : const Color(0xFF7A432D),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isLogout ? const Color(0xFF8B2500) : const Color(0xFF3E1F11),
                    ),
                  ),
                  if (!isLogout)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        color: Color(0xFF8C736B),
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isLogout ? const Color(0xFF8B2500) : const Color(0xFF8C736B),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPasswordDialogFromProfile(BuildContext context, UserProfile profile, bool isSettingNew) async {
    final messenger = ScaffoldMessenger.of(context);
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    final currentPasswordCtrl = TextEditingController();
    bool obscureNew = true;
    bool obscureCurrent = true;
    bool obscureConfirm = true;
    String confirmPassError = '';
    List<({String label, bool met})> newPassReqs = [];

    bool isPasswordValid(String p) {
      return p.length >= 8 &&
          p.contains(RegExp(r'[A-Z]')) &&
          p.contains(RegExp(r'[a-z]')) &&
          p.contains(RegExp(r'[0-9]')) &&
          p.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    }

    List<({String label, bool met})> checkPasswordReqs(String p) {
      return [
        (label: 'At least 8 characters', met: p.length >= 8),
        (label: '1 uppercase letter', met: p.contains(RegExp(r'[A-Z]'))),
        (label: '1 lowercase letter', met: p.contains(RegExp(r'[a-z]'))),
        (label: '1 number', met: p.contains(RegExp(r'[0-9]'))),
        (label: '1 special character', met: p.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))),
      ];
    }

    Widget buildPasswordReqsCtx(List<({String label, bool met})> reqs) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: reqs.map((r) {
          final ok = r.met;
          return Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ok ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 14,
                  color: ok ? const Color(0xFF2E7D32) : const Color(0xFF8C736B),
                ),
                const SizedBox(width: 6),
                Text(
                  r.label,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    color: ok ? const Color(0xFF2E7D32) : const Color(0xFF8C736B),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFFAF7F5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7A432D).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isSettingNew ? Icons.lock_open_rounded : Icons.lock_reset_rounded,
                    color: const Color(0xFF7A432D),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  isSettingNew ? 'Set Password' : 'Change Password',
                  style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E1F11),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isSettingNew)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: Color(0xFF2E7D32)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'After setting a password, you can sign in with ${profile.email} directly.',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (!isSettingNew) ...[
                      _buildDialogField('Current Password', currentPasswordCtrl, obscureCurrent, (v) => setDialogState(() => obscureCurrent = v)),
                      const SizedBox(height: 12),
                    ],
                    _buildDialogField('New Password', newPasswordCtrl, obscureNew, (v) => setDialogState(() => obscureNew = v),
                      onChanged: (_) {
                        final p = newPasswordCtrl.text;
                        newPassReqs = p.isEmpty ? [] : checkPasswordReqs(p);
                        setDialogState(() {});
                      },
                    ),
                    if (newPassReqs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: buildPasswordReqsCtx(newPassReqs),
                      ),
                    const SizedBox(height: 12),
                    _buildDialogField('Confirm New Password', confirmPasswordCtrl, obscureConfirm, (v) => setDialogState(() => obscureConfirm = v),
                      onChanged: (_) {
                        final p = confirmPasswordCtrl.text;
                        if (p.isEmpty) {
                          confirmPassError = '';
                        } else if (newPasswordCtrl.text.isNotEmpty && p != newPasswordCtrl.text) {
                          confirmPassError = 'Passwords do not match';
                        } else {
                          confirmPassError = '';
                        }
                        setDialogState(() {});
                      },
                    ),
                    if (confirmPassError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, left: 4),
                        child: Text(
                          confirmPassError,
                          style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: Color(0xFFC62828)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontFamily: 'PlusJakartaSans', color: Color(0xFF8C736B), fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A432D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () async {
                  final newPass = newPasswordCtrl.text.trim();
                  final confirmPass = confirmPasswordCtrl.text.trim();
                  if (!isPasswordValid(newPass)) {
                    confirmPassError = 'Must be 8+ chars with upper, lower, number & special';
                    setDialogState(() {});
                    return;
                  }
                  if (newPass != confirmPass) {
                    confirmPassError = 'Passwords do not match';
                    setDialogState(() {});
                    return;
                  }
                  Navigator.of(dialogCtx).pop();
                  try {
                    final firebaseUser = FirebaseAuth.instance.currentUser;
                    if (firebaseUser == null) throw Exception('Not logged in.');
                    if (isSettingNew) {
                      final sub = profile.linkedinId ?? '';
                      final syntheticEmail = 'linkedin_$sub@boardingpass.com';
                      final syntheticPassword = 'linkedin_user_$sub';
                      final synthCred = EmailAuthProvider.credential(email: syntheticEmail, password: syntheticPassword);
                      await firebaseUser.reauthenticateWithCredential(synthCred);
                      await firebaseUser.verifyBeforeUpdateEmail(profile.email);
                      await firebaseUser.updatePassword(newPass);
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(firebaseUser.uid)
                          .update({'directPasswordSet': true});
                      messenger.showSnackBar(const SnackBar(
                        content: Text('Password set! Verify the email sent to your inbox, then sign in directly.'),
                        backgroundColor: Color(0xFF2E7D32),
                        duration: Duration(seconds: 5),
                      ));
                    } else {
                      final currentPass = currentPasswordCtrl.text.trim();
                      if (currentPass.isEmpty) {
                        messenger.showSnackBar(const SnackBar(content: Text('Please enter your current password.')));
                        return;
                      }
                      final credential = EmailAuthProvider.credential(
                        email: firebaseUser.email ?? profile.email,
                        password: currentPass,
                      );
                      await firebaseUser.reauthenticateWithCredential(credential);
                      await firebaseUser.updatePassword(newPass);
                      messenger.showSnackBar(const SnackBar(
                        content: Text('Password changed successfully.'),
                        backgroundColor: Color(0xFF2E7D32),
                      ));
                    }
                  } on FirebaseAuthException catch (e) {
                    String msg = 'Failed to update password.';
                    if (e.code == 'wrong-password' || e.code == 'invalid-credential') msg = 'Current password is incorrect.';
                    if (e.code == 'requires-recent-login') msg = 'Session expired. Please log out and back in first.';
                    if (e.code == 'email-already-in-use') msg = 'That email is already in use by another account.';
                    if (e.code == 'invalid-email') msg = 'The email address is not valid.';
                    messenger.showSnackBar(SnackBar(content: Text(msg)));
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: Text(
                  isSettingNew ? 'Set Password' : 'Update',
                  style: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );

    currentPasswordCtrl.dispose();
    newPasswordCtrl.dispose();
    confirmPasswordCtrl.dispose();
  }

  Widget _buildDialogField(String label, TextEditingController controller, bool obscure, Function(bool) setObscure, {ValueChanged<String>? onChanged}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: Color(0xFF8C736B)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF7A432D), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18,
            color: const Color(0xFF8C736B),
          ),
          onPressed: () => setObscure(!obscure),
        ),
      ),
    );
  }

  IconData _getInterestIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('java')) return Icons.coffee_outlined;
    if (lower.contains('spring') || lower.contains('boot')) return Icons.spa_outlined;
    if (lower.contains('ai') || lower.contains('machine') || lower.contains('ml')) return Icons.auto_awesome_outlined;
    if (lower.contains('startup') || lower.contains('entrepreneur')) return Icons.rocket_launch_outlined;
    if (lower.contains('network') || lower.contains('connect')) return Icons.people_outline_rounded;
    if (lower.contains('travel') || lower.contains('explore') || lower.contains('flight')) return Icons.flight_takeoff_outlined;
    if (lower.contains('code') || lower.contains('develop') || lower.contains('program')) return Icons.code_outlined;
    if (lower.contains('coffee')) return Icons.coffee_outlined;
    if (lower.contains('partnership') || lower.contains('b2b')) return Icons.handshake_outlined;
    return Icons.label_outline_rounded;
  }
}

class ConstellationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = size.width * 0.45;

    final paintLine = Paint()
      ..color = const Color(0xFFE8E2DD)
      ..strokeWidth = 1.0;

    final paintNode = Paint()
      ..color = const Color(0xFF7A432D).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final paintHalo = Paint()
      ..color = const Color(0xFF7A432D).withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final List<Offset> points = [];
    points.add(center);

    final int outerCount = 6;
    for (int i = 0; i < outerCount; i++) {
      final double angle = (i * 2 * pi) / outerCount;
      points.add(
        Offset(
          center.dx + radius * 0.7 * cos(angle),
          center.dy + radius * 0.7 * sin(angle),
        ),
      );
    }

    final int innerCount = 4;
    for (int i = 0; i < innerCount; i++) {
      final double angle = (i * 2 * pi) / innerCount + 0.7;
      points.add(
        Offset(
          center.dx + radius * 0.35 * cos(angle),
          center.dy + radius * 0.35 * sin(angle),
        ),
      );
    }

    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        final dist = (points[i] - points[j]).distance;
        if (dist < radius * 0.95) {
          canvas.drawLine(points[i], points[j], paintLine);
        }
      }
    }

    for (final pt in points) {
      canvas.drawCircle(pt, 6, paintHalo);
      canvas.drawCircle(pt, 2.5, paintNode);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EditProfileSheet extends StatefulWidget {
  final UserProfile profile;
  const _EditProfileSheet({required this.profile});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _headlineController;
  late final TextEditingController _bioController;
  late final TextEditingController _companyController;
  late final TextEditingController _roleController;
  late final TextEditingController _industryController;
  late final TextEditingController _experienceController;
  late final TextEditingController _homeBaseController;
  late final TextEditingController _profileImageUrlController;
  late final TextEditingController _coverImageUrlController;
  late final TextEditingController _linkedinUrlController;

  final TextEditingController _newRoleController = TextEditingController();
  final TextEditingController _newCompanyController = TextEditingController();
  final TextEditingController _newLocationController = TextEditingController();
  final TextEditingController _newStartDateController = TextEditingController();
  final TextEditingController _newEndDateController = TextEditingController();
  final TextEditingController _newDescController = TextEditingController();
  String _newEmploymentType = 'Full-time';

  final TextEditingController _newSchoolController = TextEditingController();
  final TextEditingController _newDegreeController = TextEditingController();
  final TextEditingController _newEduStartDateController = TextEditingController();
  final TextEditingController _newEduEndDateController = TextEditingController();

  bool _isLoading = false;
  bool _isProfileLoading = false;
  bool _isCoverLoading = false;
  late List<Map<String, dynamic>> _localCareerTimeline;
  late List<Map<String, dynamic>> _localEducationTimeline;
  late List<String> _localSkills;
  late List<String> _localInterests;
  String _selectedOccupation = 'Software Engineer';
  final TextEditingController _customOccupationController = TextEditingController();
  final List<String> _occupations = [
    'Software Engineer',
    'CTO',
    'Product Manager',
    'Founder',
    'Doctor',
    'Lawyer',
    'Financial Analyst',
    'Other',
  ];
  final Map<String, String> _localExpertiseLevels = {};
  final Map<String, String> _localInterestsPriorities = {};

  final List<String> _industries = [
    'Technology',
    'Finance',
    'Healthcare',
    'Education',
    'Consulting',
    'Real Estate',
    'Automotive',
    'Entertainment',
    'Other',
  ];

  final List<String> _travelFrequencies = [
    'Rarely',
    'Occasional',
    'Frequent',
    'Never',
  ];

  String? _selectedIndustry;
  String? _selectedTravelFrequency;

  final List<String> _expertiseOptions = [
    'React',
    'Flutter',
    'Spring Boot',
    'AI/ML',
    'Data Science',
    'Stock Market',
    'Investing',
    'Leadership',
    'Product Strategy',
    'UI/UX',
    'Marketing',
    'Sales',
    'Public Speaking',
    'Other',
  ];

  final List<String> _interestOptions = [
    'Stock Market',
    'Artificial Intelligence',
    'Startups',
    'Investing',
    'Public Speaking',
    'Fitness',
    'Personal Finance',
    'Entrepreneurship',
    'Design',
    'Content Creation',
    'Other',
  ];


  late String _currentLocationCountry;
  late String _currentLocationState;
  late String _currentLocationCity;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _headlineController = TextEditingController(text: widget.profile.headline);
    _bioController = TextEditingController(text: widget.profile.bio);
    _companyController = TextEditingController(text: widget.profile.company);
    _roleController = TextEditingController(text: widget.profile.role);
    final roleVal = widget.profile.role ?? '';
    if (_occupations.contains(roleVal)) {
      _selectedOccupation = roleVal;
    } else if (roleVal.isNotEmpty) {
      _selectedOccupation = 'Other';
      _customOccupationController.text = roleVal;
    }

    final initialIndustry = widget.profile.industry ?? 'Technology';
    _selectedIndustry = _industries.contains(initialIndustry) ? initialIndustry : 'Other';
    _industryController = TextEditingController(text: widget.profile.industry ?? '');

    final initialTravel = widget.profile.travelFrequency ?? 'Occasional';
    _selectedTravelFrequency = _travelFrequencies.contains(initialTravel) ? initialTravel : 'Occasional';

    _localInterests = List<String>.from(widget.profile.interests.isNotEmpty ? widget.profile.interests : widget.profile.intents);

    _localExpertiseLevels.clear();
    for (final exp in widget.profile.expertiseWithLevel) {
      final name = exp['name']?.toString() ?? '';
      final lvl = exp['level']?.toString() ?? 'Intermediate';
      if (name.isNotEmpty) _localExpertiseLevels[name] = lvl;
    }
    _localInterestsPriorities.clear();
    for (final intr in widget.profile.interestsWithPriority) {
      final name = intr['name']?.toString() ?? '';
      final pri = intr['priority']?.toString() ?? 'Medium';
      if (name.isNotEmpty) _localInterestsPriorities[name] = pri;
    }

    _parseCurrentLocation(widget.profile.currentLocationName);

    _experienceController = TextEditingController(text: widget.profile.experience ?? '');
    _homeBaseController = TextEditingController(text: widget.profile.homeBase ?? '');
    _profileImageUrlController = TextEditingController(text: widget.profile.profileImageUrl ?? '');
    _coverImageUrlController = TextEditingController(text: widget.profile.coverImageUrl ?? '');
    _linkedinUrlController = TextEditingController(text: widget.profile.linkedinProfileUrl ?? '');

    _localCareerTimeline = List<Map<String, dynamic>>.from(widget.profile.careerTimeline);
    _localEducationTimeline = List<Map<String, dynamic>>.from(widget.profile.educationTimeline);
    _localSkills = List<String>.from(widget.profile.skills);

    _nameController.addListener(_onFieldChanged);
    _headlineController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
    _companyController.addListener(_onFieldChanged);
    _roleController.addListener(_onFieldChanged);
    _industryController.addListener(_onFieldChanged);
    _experienceController.addListener(_onFieldChanged);
    _homeBaseController.addListener(_onFieldChanged);
    _profileImageUrlController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  double _calculateLocalCompleteness() {
    int total = 0;
    int completed = 0;

    total++;
    if (_nameController.text.trim().isNotEmpty) completed++;
    total++;
    if (widget.profile.email.trim().isNotEmpty) completed++;
    total++;
    if (_profileImageUrlController.text.trim().isNotEmpty) completed++;
    total++;
    if (_roleController.text.trim().isNotEmpty) completed++;
    total++;
    if (_companyController.text.trim().isNotEmpty) completed++;
    total++;
    if (_headlineController.text.trim().isNotEmpty) completed++;
    total++;
    if (_localSkills.isNotEmpty) completed++;
    total++;
    if (_selectedIndustry != null && _selectedIndustry!.isNotEmpty && _selectedIndustry != 'Select Industry') {
      if (_selectedIndustry == 'Other') {
        if (_industryController.text.trim().isNotEmpty) completed++;
      } else {
        completed++;
      }
    }
    total++;
    if (_experienceController.text.trim().isNotEmpty) completed++;
    total++;
    if (_bioController.text.trim().isNotEmpty) completed++;
    total++;
    if (_localInterests.isNotEmpty) completed++;

    total++;
    if (_selectedTravelFrequency != null && _selectedTravelFrequency!.isNotEmpty && _selectedTravelFrequency != 'Select Frequency') {
      completed++;
    }
    total++;
    total++;
    if (_currentLocationCountry.isNotEmpty || _currentLocationCity.isNotEmpty) completed++;
    total++;
    if (_localCareerTimeline.isNotEmpty) completed++;
    total++;
    if (_localEducationTimeline.isNotEmpty) completed++;

    return total == 0 ? 0.0 : (completed / total) * 100.0;
  }

  void _parseCurrentLocation(String? currentLocStr) {
    if (currentLocStr == null || currentLocStr.isEmpty) {
      _currentLocationCountry = '';
      _currentLocationState = '';
      _currentLocationCity = '';
      return;
    }
    final parts = currentLocStr.split(',').map((e) => e.trim()).toList();
    if (parts.length >= 3) {
      _currentLocationCity = parts[0];
      _currentLocationState = parts[1];
      _currentLocationCountry = parts[2];
    } else if (parts.length == 2) {
      _currentLocationCity = '';
      _currentLocationState = parts[0];
      _currentLocationCountry = parts[1];
    } else if (parts.length == 1) {
      _currentLocationCity = '';
      _currentLocationState = '';
      _currentLocationCountry = parts[0];
    } else {
      _currentLocationCountry = '';
      _currentLocationState = '';
      _currentLocationCity = '';
    }
  }



  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _headlineController.removeListener(_onFieldChanged);
    _bioController.removeListener(_onFieldChanged);
    _companyController.removeListener(_onFieldChanged);
    _roleController.removeListener(_onFieldChanged);
    _industryController.removeListener(_onFieldChanged);
    _experienceController.removeListener(_onFieldChanged);
    _homeBaseController.removeListener(_onFieldChanged);
    _profileImageUrlController.removeListener(_onFieldChanged);

    _nameController.dispose();
    _headlineController.dispose();
    _bioController.dispose();
    _companyController.dispose();
    _roleController.dispose();
    _industryController.dispose();
    _experienceController.dispose();
    _homeBaseController.dispose();
    _profileImageUrlController.dispose();
    _coverImageUrlController.dispose();
    _linkedinUrlController.dispose();

    _newRoleController.dispose();
    _newCompanyController.dispose();
    _newLocationController.dispose();
    _newStartDateController.dispose();
    _newEndDateController.dispose();
    _newDescController.dispose();

    _newSchoolController.dispose();
    _newDegreeController.dispose();
    _newEduStartDateController.dispose();
    _newEduEndDateController.dispose();

    _customOccupationController.dispose();

    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    if (_newCompanyController.text.trim().isNotEmpty && _newRoleController.text.trim().isNotEmpty) {
      _localCareerTimeline.add({
        'company': _newCompanyController.text.trim(),
        'role': _newRoleController.text.trim(),
        'employmentType': _newEmploymentType,
        'location': _newLocationController.text.trim(),
        'startDate': _newStartDateController.text.trim(),
        'endDate': _newEndDateController.text.trim(),
        'duration': '${_newStartDateController.text.trim()} to ${_newEndDateController.text.trim()}',
        'description': _newDescController.text.trim(),
      });
    }

    if (_newSchoolController.text.trim().isNotEmpty && _newDegreeController.text.trim().isNotEmpty) {
      _localEducationTimeline.add({
        'degree': _newDegreeController.text.trim(),
        'school': _newSchoolController.text.trim(),
        'startDate': _newEduStartDateController.text.trim(),
        'endDate': _newEduEndDateController.text.trim(),
        'duration': '${_newEduStartDateController.text.trim()} to ${_newEduEndDateController.text.trim()}',
      });
    }

    final finalIndustry = _selectedIndustry == 'Other' ? _industryController.text.trim() : _selectedIndustry;

    final currentLocSegments = [
      if (_currentLocationCity.isNotEmpty) _currentLocationCity,
      if (_currentLocationState.isNotEmpty) _currentLocationState,
      if (_currentLocationCountry.isNotEmpty) _currentLocationCountry,
    ];
    final finalCurrentLocation = currentLocSegments.join(', ');

    try {
      await UserService().updateUserProfile(
        userId: widget.profile.uid,
        name: _nameController.text.trim(),
        headline: _headlineController.text.trim(),
        bio: _bioController.text.trim(),
        company: _companyController.text.trim(),
        role: _selectedOccupation == 'Other' ? _customOccupationController.text.trim() : _selectedOccupation,
        industry: finalIndustry,
        experience: _experienceController.text.trim(),
        homeBase: _homeBaseController.text.trim().isNotEmpty
            ? _homeBaseController.text.trim()
            : null,
        currentLocationName: finalCurrentLocation,
        travelFrequency: _selectedTravelFrequency,
        profileImageUrl: _profileImageUrlController.text.trim(),
        coverImageUrl: _coverImageUrlController.text.trim(),
        linkedinProfileUrl: _linkedinUrlController.text.trim(),
        skills: _localSkills,
        expertise: _localSkills,
        careerTimeline: _localCareerTimeline,
        educationTimeline: _localEducationTimeline,
        interests: _localInterests,
        intents: _localInterests,
        expertiseWithLevel: _localSkills.map((e) => {
          'name': e,
          'level': _localExpertiseLevels[e] ?? 'Intermediate',
          'endorsements': widget.profile.expertiseWithLevel.firstWhere(
            (o) => o['name'].toString().toLowerCase().trim() == e.toLowerCase().trim(),
            orElse: () => <String, dynamic>{},
          )['endorsements'] ?? 0,
        }).toList(),
        interestsWithPriority: _localInterests.map((i) => {
          'name': i,
          'priority': _localInterestsPriorities[i] ?? 'Medium',
        }).toList(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F5),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: 20 + keyboardHeight,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD0C8C0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7A432D).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF7A432D)),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E1F11),
                      ),
                    ),
                  ],
                ),
                _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7A432D)),
                        ),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7A432D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          elevation: 0,
                        ),
                        onPressed: _saveProfile,
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildSectionHeader('Photos'),
                    const SizedBox(height: 12),
                    _buildPhotoSection(),
                    const SizedBox(height: 20),
                    _buildSectionHeader('Basic Info'),
                    const SizedBox(height: 12),
                    _buildTextField('Name', _nameController, hintText: 'Enter your full name'),
                    _buildTextField('Headline', _headlineController, hintText: 'e.g. VP Engineering at Stripe'),
                    _buildTextField('Bio / Description', _bioController, maxLines: 3, hintText: 'Tell us about yourself'),
                    const SizedBox(height: 12),
                    _buildTextField('Company', _companyController, hintText: 'e.g. Google, Stripe'),
                    const SizedBox(height: 12),
                    _buildDropdownField(
                      label: 'Occupation',
                      currentValue: _selectedOccupation,
                      items: _occupations,
                      onChanged: (val) => setState(() => _selectedOccupation = val ?? 'Software Engineer'),
                      secondaryField: _selectedOccupation == 'Other'
                          ? _buildTextField('Custom Occupation', _customOccupationController, hintText: 'e.g. BioTech Consultant')
                          : null,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdownField(
                            label: 'Industry / Sector',
                            currentValue: _selectedIndustry!,
                            items: _industries,
                            onChanged: (val) => setState(() => _selectedIndustry = val),
                            secondaryField: _selectedIndustry == 'Other'
                                ? _buildTextField('Custom Industry', _industryController, hintText: 'e.g. BioTech')
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField('Experience', _experienceController, hintText: 'e.g. 5 years'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField('LinkedIn Profile URL', _linkedinUrlController, hintText: 'https://linkedin.com/in/yourprofile'),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Home Base Location', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8C736B))),
                    ),
                    const SizedBox(height: 6),
                    GoogleLocationDropdown(
                      controller: _homeBaseController,
                      onSelected: (_) => _onFieldChanged(),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Current Location', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8C736B))),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE8E2DD), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.gps_fixed_rounded, size: 16, color: Color(0xFF7A432D)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (widget.profile.currentLocationName != null && widget.profile.currentLocationName!.isNotEmpty)
                                  ? widget.profile.currentLocationName!
                                  : 'Detecting Location...',
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                color: Color(0xFF3E1F11),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDropdownField(
                      label: 'Travel Frequency',
                      currentValue: _selectedTravelFrequency!,
                      items: _travelFrequencies,
                      onChanged: (val) => setState(() => _selectedTravelFrequency = val),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionHeader('Work Experience'),
                    const SizedBox(height: 12),
                    ...List.generate(_localCareerTimeline.length, (idx) {
                      final item = _localCareerTimeline[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE8E2DD)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item['role']} at ${item['company']}',
                                    style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF3E1F11)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFFC62828), size: 20),
                                  onPressed: () => setState(() => _localCareerTimeline.removeAt(idx)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            if ((item['description'] ?? '').toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  item['description'],
                                  style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: Color(0xFF8C736B)),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    _buildAddCareerCard(),
                    const SizedBox(height: 20),
                    _buildSectionHeader('Education'),
                    const SizedBox(height: 12),
                    ...List.generate(_localEducationTimeline.length, (idx) {
                      final item = _localEducationTimeline[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE8E2DD)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item['degree']} at ${item['school']}',
                                    style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF3E1F11)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFFC62828), size: 20),
                                  onPressed: () => setState(() => _localEducationTimeline.removeAt(idx)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            if ((item['duration'] ?? '').toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  item['duration'],
                                  style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: Color(0xFF8C736B)),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    _buildAddEducationCard(),
                    const SizedBox(height: 20),
                    _buildSectionHeader('Expertise'),
                    const SizedBox(height: 12),
                    _buildMultiSelectDropdown(
                      options: _expertiseOptions,
                      selectedList: _localSkills,
                      onListChanged: _onFieldChanged,
                      isExpertise: true,
                      levelsMap: _localExpertiseLevels,
                      placeholder: 'Select expertise area',
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Interests'),
                    const SizedBox(height: 12),
                    _buildMultiSelectDropdown(
                      options: _interestOptions,
                      selectedList: _localInterests,
                      onListChanged: _onFieldChanged,
                      isExpertise: false,
                      prioritiesMap: _localInterestsPriorities,
                      placeholder: 'Select interest area',
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectDropdown({
    required List<String> options,
    required List<String> selectedList,
    required VoidCallback onListChanged,
    bool isExpertise = false,
    Map<String, String>? levelsMap,
    Map<String, String>? prioritiesMap,
    required String placeholder,
  }) {
    return _MultiSelectDropdownWidget(
      options: options,
      selectedList: selectedList,
      onListChanged: onListChanged,
      isExpertise: isExpertise,
      levelsMap: levelsMap,
      prioritiesMap: prioritiesMap,
      placeholder: placeholder,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF7A432D).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.folder_outlined, size: 16, color: Color(0xFF7A432D)),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E1F11),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E2DD)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            value: _calculateLocalCompleteness() / 100.0,
                            strokeWidth: 3,
                            backgroundColor: const Color(0xFFE8E2DD),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7A432D)),
                          ),
                        ),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE8E2DD)),
                          child: ClipOval(
                            child: _isProfileLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7A432D))),
                                  )
                                : buildProfileImage(
                                    _profileImageUrlController.text,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    fallback: const Icon(Icons.person, size: 28, color: Color(0xFF7A432D)),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Profile Photo', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3E1F11))),
                        const SizedBox(height: 4),
                        Text('${_calculateLocalCompleteness().toInt()}% complete', style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, color: Color(0xFF8C736B))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: _buildUploadButton('Upload Photo', _isProfileLoading, () => _pickImage(isProfile: true)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 100, color: const Color(0xFFE8E2DD)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cover Photo', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3E1F11))),
                const SizedBox(height: 4),
                Container(
                  width: 60,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E2DD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _isCoverLoading
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7A432D))),
                            ),
                          )
                        : buildProfileImage(
                            _coverImageUrlController.text,
                            width: 60,
                            height: 40,
                            fit: BoxFit.cover,
                            fallback: Container(color: Colors.black),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: _buildUploadButton('Upload Cover', _isCoverLoading, () => _pickImage(isProfile: false)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton(String label, bool isLoading, VoidCallback onPressed) {
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7A432D),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          elevation: 0,
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _pickImage({required bool isProfile}) async {
    XFile? pickedFile;
    Uint8List? bytes;
    try {
      final ImagePicker picker = ImagePicker();
      pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
        maxWidth: isProfile ? 300 : 800,
        maxHeight: isProfile ? 300 : 400,
      );
      if (pickedFile == null) return;
      if (isProfile) {
        setState(() => _isProfileLoading = true);
      } else {
        setState(() => _isCoverLoading = true);
      }
      bytes = await pickedFile.readAsBytes();
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      setState(() {
        if (isProfile) {
          _profileImageUrlController.text = downloadUrl;
          _isProfileLoading = false;
        } else {
          _coverImageUrlController.text = downloadUrl;
          _isCoverLoading = false;
        }
      });
    } catch (e) {
      debugPrint('Firebase Storage upload failed: $e');
      try {
        final fallbackBytes = bytes ?? await pickedFile!.readAsBytes();
        final base64Str = base64Encode(fallbackBytes);
        final dataUrl = 'data:image/jpeg;base64,$base64Str';
        setState(() {
          if (isProfile) {
            _profileImageUrlController.text = dataUrl;
            _isProfileLoading = false;
          } else {
            _coverImageUrlController.text = dataUrl;
            _isCoverLoading = false;
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage upload failed. Image saved locally as base64 fallback.')),
          );
        }
      } catch (fallbackError) {
        setState(() {
          if (isProfile) {
            _isProfileLoading = false;
          } else {
            _isCoverLoading = false;
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload image: $e')),
          );
        }
      }
    }
  }

  Widget _buildAddCareerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E2DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Experience', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF3E1F11))),
          const SizedBox(height: 10),
          _buildTextField('Company', _newCompanyController, hintText: 'e.g. Google, Stripe', dense: true),
          _buildTextField('Role / Job Title', _newRoleController, hintText: 'e.g. Software Engineer', dense: true),
          _buildCompactDropdown(
            label: 'Employment Type',
            value: _newEmploymentType,
            items: const ['Full-time', 'Part-time', 'Self-employed', 'Freelance', 'Contract', 'Internship'],
            onChanged: (val) => setState(() => _newEmploymentType = val),
          ),
          _buildTextField('Description', _newDescController, maxLines: 2, hintText: 'Describe your accomplishments', dense: true),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A432D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () {
                if (_newRoleController.text.trim().isEmpty || _newCompanyController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill Role and Company')));
                  return;
                }
                setState(() {
                  _localCareerTimeline.add({
                    'company': _newCompanyController.text.trim(),
                    'role': _newRoleController.text.trim(),
                    'employmentType': _newEmploymentType,
                    'location': _newLocationController.text.trim(),
                    'startDate': '',
                    'endDate': '',
                    'duration': '',
                    'description': _newDescController.text.trim(),
                  });
                  _newCompanyController.clear();
                  _newRoleController.clear();
                  _newEmploymentType = 'Full-time';
                  _newLocationController.clear();
                  _newStartDateController.clear();
                  _newEndDateController.clear();
                  _newDescController.clear();
                });
              },
              child: const Text('Add Experience', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddEducationCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E2DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Education', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF3E1F11))),
          const SizedBox(height: 10),
          _buildTextField('Degree / Course', _newDegreeController, hintText: 'e.g. B.S. in Computer Science', dense: true),
          _buildTextField('School / University', _newSchoolController, hintText: 'e.g. Stanford University', dense: true),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A432D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () {
                setState(() {
                  _localEducationTimeline.add({
                    'degree': _newDegreeController.text.trim(),
                    'school': _newSchoolController.text.trim(),
                    'startDate': '',
                    'endDate': '',
                    'duration': '',
                  });
                  _newDegreeController.clear();
                  _newSchoolController.clear();
                  _newEduStartDateController.clear();
                  _newEduEndDateController.clear();
                });
              },
              child: const Text('Add Education', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String? hintText,
    bool dense = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: dense ? 10 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8C736B),
            ),
          ),
          SizedBox(height: dense ? 4 : 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, color: Color(0xFF3E1F11)),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                color: const Color(0xFF3E1F11).withValues(alpha: 0.35),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
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
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String currentValue,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    Widget? secondaryField,
  }) {
    final List<String> safeItems = List<String>.from(items);
    if (currentValue.isNotEmpty && !safeItems.contains(currentValue)) {
      safeItems.add(currentValue);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(fontFamily: 'PlusJakartaSans', color: Color(0xFF8C736B), fontSize: 13),
              floatingLabelStyle: const TextStyle(fontFamily: 'PlusJakartaSans', color: Color(0xFF7A432D)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: safeItems.contains(currentValue) ? currentValue : (safeItems.isNotEmpty ? safeItems.first : null),
                isExpanded: true,
                isDense: true,
                dropdownColor: Colors.white,
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF7A432D)),
                style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, color: Color(0xFF3E1F11)),
                items: safeItems.map((String val) {
                  return DropdownMenuItem<String>(value: val, child: Text(val));
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
          if (secondaryField != null) ...[
            const SizedBox(height: 8),
            secondaryField,
          ],
        ],
      ),
    );
  }

  Widget _buildCompactDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: Color(0xFF8C736B)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF7A432D), width: 1.5),
          ),
        ),
        style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: Color(0xFF3E1F11)),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (val) {
          if (val != null) onChanged(val);
        },
      ),
    );
  }
}

class _ResumePreviewDialog extends StatefulWidget {
  final Map<String, dynamic> parsedData;
  final Function(Map<String, dynamic>) onSave;

  const _ResumePreviewDialog({required this.parsedData, required this.onSave});

  @override
  State<_ResumePreviewDialog> createState() => _ResumePreviewDialogState();
}

class _ResumePreviewDialogState extends State<_ResumePreviewDialog> {
  late List<String> _skills;
  late List<Map<String, dynamic>> _careerTimeline;
  late List<Map<String, dynamic>> _educationTimeline;
  late List<String> _interests;
  late List<String> _professionalInterests;

  final TextEditingController _skillInputController = TextEditingController();
  final TextEditingController _interestInputController = TextEditingController();
  final TextEditingController _profInterestInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _skills = List<String>.from(widget.parsedData['skills'] ?? []);
    _careerTimeline = (widget.parsedData['careerTimeline'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _educationTimeline = (widget.parsedData['educationTimeline'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _interests = List<String>.from(widget.parsedData['interests'] ?? []);
    _professionalInterests = List<String>.from(widget.parsedData['professionalInterests'] ?? []);
  }

  @override
  void dispose() {
    _skillInputController.dispose();
    _interestInputController.dispose();
    _profInterestInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFFFAF7F5),
      child: Container(
        width: min(MediaQuery.of(context).size.width * 0.9, 600),
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7A432D).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Color(0xFF7A432D), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Review Parsed Resume',
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E1F11),
                      ),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF8C736B), size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'We have extracted the following information from your resume. Review and edit it before saving.',
              style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: Color(0xFF5C473E)),
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFE8E2DD)),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Skills', Icons.psychology),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _skills.map((skill) {
                        return Chip(
                          label: Text(skill, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: Color(0xFF3E1F11))),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFE8E2DD)),
                          onDeleted: () => setState(() => _skills.remove(skill)),
                          deleteIconColor: const Color(0xFF7A432D),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    _buildAddRow(_skillInputController, 'Add a skill...', (text) {
                      if (text.isNotEmpty && !_skills.contains(text)) {
                        setState(() { _skills.add(text); _skillInputController.clear(); });
                      }
                    }),
                    const SizedBox(height: 20),
                    _buildSectionHeader('Work Experience', Icons.work),
                    const SizedBox(height: 8),
                    ...List.generate(_careerTimeline.length, (index) {
                      final item = _careerTimeline[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE8E2DD)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Position ${index + 1}', style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7A432D))),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Color(0xFFC62828), size: 18),
                                  onPressed: () => setState(() => _careerTimeline.removeAt(index)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            _buildField('Company', item['company'] ?? '', (v) => item['company'] = v, hint: 'Enter company name'),
                            _buildField('Role', item['role'] ?? '', (v) => item['role'] = v, hint: 'e.g. Software Engineer'),
                            _buildField('Description', item['description'] ?? '', (v) => item['description'] = v, maxLines: 2, hint: 'Describe your accomplishments'),
                          ],
                        ),
                      );
                    }),
                    _buildAddButton('Add Work Experience', () {
                      setState(() {
                        _careerTimeline.add({'company': '', 'role': '', 'employmentType': 'Full-time', 'location': '', 'startDate': '', 'endDate': '', 'description': ''});
                      });
                    }),
                    const SizedBox(height: 20),
                    _buildSectionHeader('Education', Icons.school),
                    const SizedBox(height: 8),
                    ...List.generate(_educationTimeline.length, (index) {
                      final item = _educationTimeline[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE8E2DD)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Education ${index + 1}', style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7A432D))),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Color(0xFFC62828), size: 18),
                                  onPressed: () => setState(() => _educationTimeline.removeAt(index)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            _buildField('Degree', item['degree'] ?? '', (v) => item['degree'] = v, hint: 'e.g. B.S. in CS'),
                            _buildField('School', item['school'] ?? '', (v) => item['school'] = v, hint: 'e.g. Stanford University'),
                            _buildField('Duration', item['duration'] ?? '', (v) => item['duration'] = v, hint: 'e.g. 2020 - 2024'),
                          ],
                        ),
                      );
                    }),
                    _buildAddButton('Add Education', () {
                      setState(() {
                        _educationTimeline.add({'degree': '', 'school': '', 'duration': ''});
                      });
                    }),
                    const SizedBox(height: 20),
                    _buildSectionHeader('Interests', Icons.favorite),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _interests.map((item) {
                        return Chip(
                          label: Text(item, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: Color(0xFF3E1F11))),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFE8E2DD)),
                          onDeleted: () => setState(() => _interests.remove(item)),
                          deleteIconColor: const Color(0xFF7A432D),
                        );
                      }).toList(),
                    ),
                    _buildAddRow(_interestInputController, 'Add an interest...', (text) {
                      if (text.isNotEmpty && !_interests.contains(text)) {
                        setState(() { _interests.add(text); _interestInputController.clear(); });
                      }
                    }),
                    const SizedBox(height: 20),
                    _buildSectionHeader('Professional Interests', Icons.handshake),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _professionalInterests.map((item) {
                        return Chip(
                          label: Text(item, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: Color(0xFF3E1F11))),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFE8E2DD)),
                          onDeleted: () => setState(() => _professionalInterests.remove(item)),
                          deleteIconColor: const Color(0xFF7A432D),
                        );
                      }).toList(),
                    ),
                    _buildAddRow(_profInterestInputController, 'Add a professional interest...', (text) {
                      if (text.isNotEmpty && !_professionalInterests.contains(text)) {
                        setState(() { _professionalInterests.add(text); _profInterestInputController.clear(); });
                      }
                    }),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFE8E2DD)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(fontFamily: 'PlusJakartaSans', color: Color(0xFF8C736B), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7A432D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    elevation: 0,
                  ),
                  onPressed: () {
                    widget.onSave({
                      'skills': _skills,
                      'careerTimeline': _careerTimeline,
                      'educationTimeline': _educationTimeline,
                      'interests': _interests,
                      'professionalInterests': _professionalInterests,
                    });
                  },
                  child: const Text('Save & Enrich Profile', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF7A432D).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF7A432D)),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3E1F11)),
        ),
      ],
    );
  }

  Widget _buildField(String label, String value, Function(String) onChanged, {int maxLines = 1, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8C736B))),
          const SizedBox(height: 4),
          TextFormField(
            initialValue: value,
            maxLines: maxLines,
            onChanged: onChanged,
            style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: Color(0xFF3E1F11)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: const Color(0xFF3E1F11).withValues(alpha: 0.35)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF7A432D), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddRow(TextEditingController controller, String hint, Function(String) onAdd) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13),
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF7A432D)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7A432D),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: 0,
            ),
            onPressed: () => onAdd(controller.text.trim()),
            child: const Text('Add', style: TextStyle(fontFamily: 'PlusJakartaSans', color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(String label, VoidCallback onPressed) {
    return TextButton.icon(
      icon: const Icon(Icons.add, size: 16, color: Color(0xFF7A432D)),
      label: Text(label, style: const TextStyle(fontFamily: 'PlusJakartaSans', color: Color(0xFF7A432D), fontSize: 12)),
      onPressed: onPressed,
    );
  }
}

String getCountryForPicker(String? countryName) {
  if (countryName == null || countryName.isEmpty) return '  India';
  if (countryName.contains('   ')) return countryName;

  final Map<String, String> countryToEmoji = {
    'Afghanistan': '  Afghanistan',
    'Albania': '  Albania',
    'Algeria': '  Algeria',
    'Andorra': '  Andorra',
    'Angola': '  Angola',
    'Argentina': '  Argentina',
    'Armenia': '  Armenia',
    'Australia': '  Australia',
    'Austria': '  Austria',
    'Azerbaijan': '  Azerbaijan',
    'Bahamas': '  Bahamas',
    'Bahrain': '  Bahrain',
    'Bangladesh': '  Bangladesh',
    'Barbados': '  Barbados',
    'Belarus': '  Belarus',
    'Belgium': '  Belgium',
    'Belize': '  Belize',
    'Benin': '  Benin',
    'Bhutan': '  Bhutan',
    'Bolivia': '  Bolivia',
    'Bosnia and Herzegovina': '  Bosnia and Herzegovina',
    'Botswana': '  Botswana',
    'Brazil': '  Brazil',
    'Brunei': '  Brunei',
    'Bulgaria': '  Bulgaria',
    'Burkina Faso': '  Burkina Faso',
    'Burundi': '  Burundi',
    'Cambodia': '  Cambodia',
    'Cameroon': '  Cameroon',
    'Canada': '  Canada',
    'Cape Verde': '  Cape Verde',
    'Central African Republic': '  Central African Republic',
    'Chad': '  Chad',
    'Chile': '  Chile',
    'China': '  China',
    'Colombia': '  Colombia',
    'Comoros': '  Comoros',
    'Congo': '  Congo',
    'Costa Rica': '  Costa Rica',
    'Croatia': '  Croatia',
    'Cuba': '  Cuba',
    'Cyprus': '  Cyprus',
    'Czech Republic': '  Czech Republic',
    'Denmark': '  Denmark',
    'Djibouti': '  Djibouti',
    'Dominica': '  Dominica',
    'Dominican Republic': '  Dominican Republic',
    'Ecuador': '  Ecuador',
    'Egypt': '  Egypt',
    'El Salvador': '  El Salvador',
    'Equatorial Guinea': '  Equatorial Guinea',
    'Eritrea': '  Eritrea',
    'Estonia': '  Estonia',
    'Ethiopia': '  Ethiopia',
    'Fiji': '  Fiji',
    'Finland': '  Finland',
    'France': '  France',
    'Gabon': '  Gabon',
    'Gambia': '  Gambia',
    'Georgia': '  Georgia',
    'Germany': '  Germany',
    'Ghana': '  Ghana',
    'Greece': '  Greece',
    'Grenada': '  Grenada',
    'Guatemala': '  Guatemala',
    'Guinea': '  Guinea',
    'Guinea-Bissau': '  Guinea-Bissau',
    'Guyana': '  Guyana',
    'Haiti': '  Haiti',
    'Honduras': '  Honduras',
    'Hungary': '  Hungary',
    'Iceland': '  Iceland',
    'India': '  India',
    'Indonesia': '  Indonesia',
    'Iran': '  Iran',
    'Iraq': '  Iraq',
    'Ireland': '  Ireland',
    'Israel': '  Israel',
    'Italy': '  Italy',
    'Jamaica': '  Jamaica',
    'Japan': '  Japan',
    'Jordan': '  Jordan',
    'Kazakhstan': '  Kazakhstan',
    'Kenya': '  Kenya',
    'Kiribati': '  Kiribati',
    'Kuwait': '  Kuwait',
    'Kyrgyzstan': '  Kyrgyzstan',
    'Laos': '  Laos',
    'Latvia': '  Latvia',
    'Lebanon': '  Lebanon',
    'Lesotho': '  Lesotho',
    'Liberia': '  Liberia',
    'Libya': '  Libya',
    'Liechtenstein': '  Liechtenstein',
    'Lithuania': '  Lithuania',
    'Luxembourg': '  Luxembourg',
    'Macedonia': '  Macedonia',
    'Madagascar': '  Madagascar',
    'Malawi': '  Malawi',
    'Malaysia': '  Malaysia',
    'Maldives': '  Maldives',
    'Mali': '  Mali',
    'Malta': '  Malta',
    'Marshall Islands': '  Marshall Islands',
    'Mauritania': '  Mauritania',
    'Mauritius': '  Mauritius',
    'Mexico': '  Mexico',
    'Micronesia': '  Micronesia',
    'Moldova': '  Moldova',
    'Monaco': '  Monaco',
    'Mongolia': '  Mongolia',
    'Montenegro': '  Montenegro',
    'Morocco': '  Morocco',
    'Mozambique': '  Mozambique',
    'Myanmar': '  Myanmar',
    'Namibia': '  Namibia',
    'Nauru': '  Nauru',
    'Nepal': '  Nepal',
    'Netherlands': '  Netherlands',
    'New Zealand': '  New Zealand',
    'Nicaragua': '  Nicaragua',
    'Niger': '  Niger',
    'Nigeria': '  Nigeria',
    'North Korea': '  North Korea',
    'Norway': '  Norway',
    'Oman': '  Oman',
    'Pakistan': '  Pakistan',
    'Palau': '  Palau',
    'Panama': '  Panama',
    'Papua New Guinea': '  Papua New Guinea',
    'Paraguay': '  Paraguay',
    'Peru': '  Peru',
    'Philippines': '  Philippines',
    'Poland': '  Poland',
    'Portugal': '  Portugal',
    'Qatar': '  Qatar',
    'Romania': '  Romania',
    'Russia': '  Russia',
    'Rwanda': '  Rwanda',
    'Samoa': '  Samoa',
    'San Marino': '  San Marino',
    'Saudi Arabia': '  Saudi Arabia',
    'Senegal': '  Senegal',
    'Serbia': '  Serbia',
    'Seychelles': '  Seychelles',
    'Sierra Leone': '  Sierra Leone',
    'Singapore': '  Singapore',
    'Slovakia': '  Slovakia',
    'Slovenia': '  Slovenia',
    'Solomon Islands': '  Solomon Islands',
    'Somalia': '  Somalia',
    'South Africa': '  South Africa',
    'South Korea': '  South Korea',
    'South Sudan': '  South Sudan',
    'Spain': '  Spain',
    'Sri Lanka': '  Sri Lanka',
    'Sudan': '  Sudan',
    'Suriname': '  Suriname',
    'Swaziland': '  Swaziland',
    'Sweden': '  Sweden',
    'Switzerland': '  Switzerland',
    'Syria': '  Syria',
    'Taiwan': '  Taiwan',
    'Tajikistan': '  Tajikistan',
    'Tanzania': '  Tanzania',
    'Thailand': '  Thailand',
    'Togo': '  Togo',
    'Tonga': '  Tonga',
    'Trinidad and Tobago': '  Trinidad and Tobago',
    'Tunisia': '  Tunisia',
    'Turkey': '  Turkey',
    'Turkmenistan': '  Turkmenistan',
    'Tuvalu': '  Tuvalu',
    'Uganda': '  Uganda',
    'Ukraine': '  Ukraine',
    'United Arab Emirates': '  United Arab Emirates',
    'United Kingdom': '  United Kingdom',
    'United States': '  United States',
    'Uruguay': '  Uruguay',
    'Uzbekistan': '  Uzbekistan',
    'Vanuatu': '  Vanuatu',
    'Vatican City': '  Vatican City',
    'Venezuela': '  Venezuela',
    'Vietnam': '  Vietnam',
    'Yemen': '  Yemen',
    'Zambia': '  Zambia',
    'Zimbabwe': '  Zimbabwe',
  };
  return countryToEmoji[countryName] ?? countryName;
}

class _MultiSelectDropdownWidget extends StatefulWidget {
  final List<String> options;
  final List<String> selectedList;
  final VoidCallback onListChanged;
  final bool isExpertise;
  final Map<String, String>? levelsMap;
  final Map<String, String>? prioritiesMap;
  final String placeholder;

  const _MultiSelectDropdownWidget({
    required this.options,
    required this.selectedList,
    required this.onListChanged,
    this.isExpertise = false,
    this.levelsMap,
    this.prioritiesMap,
    required this.placeholder,
  });

  @override
  State<_MultiSelectDropdownWidget> createState() => _MultiSelectDropdownWidgetState();
}

class _MultiSelectDropdownWidgetState extends State<_MultiSelectDropdownWidget> {
  bool _showCustomInput = false;
  final TextEditingController _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _addCustomItem(String text) {
    final trimmed = text.trim();
    if (trimmed.isNotEmpty && !widget.selectedList.contains(trimmed)) {
      setState(() {
        widget.selectedList.add(trimmed);
        if (widget.isExpertise && widget.levelsMap != null) {
          widget.levelsMap![trimmed] = 'Intermediate';
        } else if (!widget.isExpertise && widget.prioritiesMap != null) {
          widget.prioritiesMap![trimmed] = 'Medium';
        }
        _showCustomInput = false;
        _customController.clear();
      });
      widget.onListChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableOptions = widget.options
        .where((opt) => opt == 'Other' || opt == 'Others' || !widget.selectedList.contains(opt))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE8E2DD)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: null,
              hint: Text(
                widget.placeholder,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  color: Color(0xFF8C736B),
                ),
              ),
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF7A432D)),
              dropdownColor: Colors.white,
              items: availableOptions.map((String opt) {
                final isOther = (opt == 'Other' || opt == 'Others');
                return DropdownMenuItem<String>(
                  value: opt,
                  child: Text(
                    opt,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: isOther ? FontWeight.bold : FontWeight.normal,
                      color: isOther ? const Color(0xFF7A432D) : const Color(0xFF3E1F11),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? val) {
                if (val != null) {
                  if (val == 'Other' || val == 'Others') {
                    setState(() {
                      _showCustomInput = true;
                    });
                  } else {
                    setState(() {
                      widget.selectedList.add(val);
                      if (widget.isExpertise && widget.levelsMap != null) {
                        widget.levelsMap![val] = 'Intermediate';
                      } else if (!widget.isExpertise && widget.prioritiesMap != null) {
                        widget.prioritiesMap![val] = 'Medium';
                      }
                    });
                    widget.onListChanged();
                  }
                }
              },
            ),
          ),
        ),
        if (_showCustomInput) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customController,
                  autofocus: true,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    color: Color(0xFF3E1F11),
                  ),
                  decoration: InputDecoration(
                    hintText: widget.isExpertise ? 'Enter custom expertise...' : 'Enter custom interest...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF7A432D), width: 1.5),
                    ),
                  ),
                  onSubmitted: _addCustomItem,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A432D),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onPressed: () => _addCustomItem(_customController.text),
                child: const Text(
                  'Add',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF8C736B), size: 20),
                onPressed: () {
                  setState(() {
                    _showCustomInput = false;
                    _customController.clear();
                  });
                },
              ),
            ],
          ),
        ],
        if (widget.selectedList.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.selectedList.map((opt) {
              return Chip(
                backgroundColor: const Color(0xFF7A432D).withValues(alpha: 0.08),
                label: Text(
                  opt,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    color: Color(0xFF7A432D),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFF7A432D)),
                onDeleted: () {
                  setState(() {
                    widget.selectedList.remove(opt);
                    if (widget.isExpertise && widget.levelsMap != null) {
                      widget.levelsMap!.remove(opt);
                    } else if (!widget.isExpertise && widget.prioritiesMap != null) {
                      widget.prioritiesMap!.remove(opt);
                    }
                  });
                  widget.onListChanged();
                },
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

