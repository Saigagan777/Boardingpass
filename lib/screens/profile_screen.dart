import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';
import '../state_manager.dart';
import '../services/user_service.dart';
import '../services/chat_service.dart';
import '../services/event_service.dart';
import '../models/user_profile.dart';
import '../utils/image_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AppStateManager _state = AppStateManager();
  final bool _isLoading = false;

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

  Widget _buildProfileHeader(UserProfile profile, BuildContext context) {
    final coverUrl = profile.coverImageUrl ?? '';
    final pictureUrl = profile.profileImageUrl ?? '';
    final name = profile.name.isNotEmpty ? profile.name : 'User';
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'U';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 140,
          width: double.infinity,
          color: const Color(0xFFE8E2DD),
          child: buildProfileImage(
            coverUrl,
            width: double.infinity,
            height: 140,
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
        ),
        // 2. Navigation Top Bar (back, share, edit)
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back Button
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 14,
                    color: Color(0xFF7A432D),
                  ),
                  onPressed: () {
                    _state.currentScreen = AppScreen.hub;
                  },
                ),
              ),
              // Right Actions: Share & Edit
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.ios_share_rounded,
                        size: 14,
                        color: Color(0xFF7A432D),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile link copied to clipboard'),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: () => _showEditProfileModal(context, profile),
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: Color(0xFF7A432D),
                      ),
                      label: const Text(
                        'Edit',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7A432D),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // 3. Overlapping Circular Avatar
        Positioned(
          top: 90,
          left: 20,
          child: Stack(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: buildProfileImage(
                    pictureUrl,
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
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineSection({
    required IconData icon,
    required String title,
    required List<Map<String, dynamic>> items,
    required String type, // 'career' or 'education'
  }) {
    if (items.isEmpty) {
      return _buildSectionCard(
        icon: icon,
        title: title,
        content: const Text(
          'No details added yet. Sync LinkedIn or parse your resume to enrich profile.',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 12,
            color: Color(0xFF8C736B),
          ),
        ),
      );
    }

    return _buildSectionCard(
      icon: icon,
      title: title,
      content: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final titleText = type == 'career'
              ? (item['role'] ?? '')
              : (item['degree'] ?? '');
          final subtitleText = type == 'career'
              ? (item['company'] ?? '')
              : (item['school'] ?? '');
          // Build formatted duration line
          final String durationLine;
          if (type == 'career' &&
              ((item['startDate'] ?? '').toString().isNotEmpty ||
                  (item['endDate'] ?? '').toString().isNotEmpty)) {
            durationLine = [
              '${item['startDate'] ?? ''} \u2192 ${item['endDate'] ?? ''}',
              if ((item['employmentType'] ?? '').toString().isNotEmpty)
                item['employmentType'],
              if ((item['location'] ?? '').toString().isNotEmpty)
                item['location'],
            ].where((s) => s != null && s.toString().isNotEmpty).join(' \u00B7 ');
          } else {
            durationLine = item['duration'] ?? '';
          }
          final description = item['description'] ?? '';

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline line & node
              Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF7A432D),
                    ),
                  ),
                  if (index != items.length - 1)
                    Container(
                      width: 2,
                      height: 60,
                      color: const Color(0xFFE8E2DD),
                    ),
                ],
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
                    Text(
                      subtitleText,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7A432D),
                      ),
                    ),
                    Text(
                      durationLine,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        color: Color(0xFF8C736B),
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: Color(0xFF5C473E),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
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

        final String name = profile.name.isNotEmpty
            ? profile.name
            : 'Sai Gagan';
        final String headline =
            (profile.headline != null && profile.headline!.isNotEmpty)
            ? profile.headline!
            : 'Java Full Stack Developer';
        final String workingLocation =
            (profile.currentLocationName != null &&
                profile.currentLocationName!.isNotEmpty)
            ? profile.currentLocationName!
            : 'Bangalore, Karnataka, India';
        final String bio = (profile.bio != null && profile.bio!.isNotEmpty)
            ? profile.bio!
            : 'No bio added yet. Tap Edit to introduce yourself!';
        final String company =
            (profile.company != null && profile.company!.isNotEmpty)
            ? profile.company!
            : 'Company';
        final String role = (profile.role != null && profile.role!.isNotEmpty)
            ? profile.role!
            : 'Role';
        final String industry =
            (profile.industry != null && profile.industry!.isNotEmpty)
            ? profile.industry!
            : 'Sector';
        final String experience =
            (profile.experience != null && profile.experience!.isNotEmpty)
            ? profile.experience!
            : 'Experience';

        final String homeBase =
            (profile.homeBase != null && profile.homeBase!.isNotEmpty)
            ? profile.homeBase!
            : 'Home Base';
        final String currentLocation =
            (profile.currentLocationName != null &&
                profile.currentLocationName!.isNotEmpty)
            ? profile.currentLocationName!
            : 'Current Location';
        final String travelFrequency =
            (profile.travelFrequency != null &&
                profile.travelFrequency!.isNotEmpty)
            ? profile.travelFrequency!
            : 'Travel Frequency';

        final List<String> interests = profile.interests;
        final List<String> skills = profile.skills;

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
                        // Stack Cover + Avatar Header
                        _buildProfileHeader(profile, context),

                        // Name, Headline, Location & Sync Buttons
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 50,
                            left: 20,
                            right: 20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontFamily: 'PlayfairDisplay',
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3E1F11),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                headline,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 14,
                                  color: Color(0xFF5C473E),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.place_outlined,
                                    size: 14,
                                    color: Color(0xFF7A432D),
                                  ),
                                  const SizedBox(width: 4),
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
                              const SizedBox(height: 12),
                              // LinkedIn Button
                              InkWell(
                                onTap: () {
                                  final url = profile.linkedinProfileUrl;
                                  if (url != null && url.isNotEmpty) {
                                    launchUrl(
                                      Uri.parse(url),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'No LinkedIn profile linked. Add your LinkedIn URL in Edit Profile.',
                                        ),
                                        backgroundColor: Color(0xFF0A66C2),
                                      ),
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0A66C2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.link,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        profile.linkedinProfileUrl != null &&
                                                profile
                                                    .linkedinProfileUrl!
                                                    .isNotEmpty
                                            ? 'View LinkedIn'
                                            : 'Connect LinkedIn',
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
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),

                        // Stats Dashboard
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                StreamBuilder<QuerySnapshot>(
                                  stream: ChatService().streamUserChats(),
                                  builder: (context, chatSnapshot) {
                                    final int count = chatSnapshot.hasData
                                        ? chatSnapshot.data!.docs.length
                                        : profile.connectionsCount;
                                    return _buildStatsCard(
                                      icon: Icons.people_outline_rounded,
                                      label: 'Connections',
                                      value: '$count',
                                      subtitle: 'People in your network',
                                    );
                                  },
                                ),
                                const SizedBox(width: 12),
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('events')
                                      .where(
                                        'attendees',
                                        arrayContains: profile.uid,
                                      )
                                      .snapshots(),
                                  builder: (context, joinedSnapshot) {
                                    final int count = joinedSnapshot.hasData
                                        ? joinedSnapshot.data!.docs.length
                                        : profile.eventsJoinedCount;
                                    return _buildStatsCard(
                                      icon: Icons.calendar_today_outlined,
                                      label: 'Joined',
                                      value: '$count',
                                      subtitle: 'Events you\'ve attended',
                                    );
                                  },
                                ),
                                const SizedBox(width: 12),
                                StreamBuilder<QuerySnapshot>(
                                  stream: EventService().streamEventsByUser(
                                    profile.uid,
                                  ),
                                  builder: (context, hostedSnapshot) {
                                    final int count = hostedSnapshot.hasData
                                        ? hostedSnapshot.data!.docs.length
                                        : profile.eventsHostedCount;
                                    return _buildStatsCard(
                                      icon: Icons.star_border_rounded,
                                      label: 'Hosted',
                                      value: '$count',
                                      subtitle: 'Events you\'ve organized',
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Timelines Sections
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildTimelineSection(
                            icon: Icons.business_center_outlined,
                            title: 'Work Experience',
                            items: profile.careerTimeline,
                            type: 'career',
                          ),
                        ),
                        const SizedBox(height: 20),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildTimelineSection(
                            icon: Icons.school_outlined,
                            title: 'Education',
                            items: profile.educationTimeline,
                            type: 'education',
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Skills Card
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildSectionCard(
                            icon: Icons.build_outlined,
                            title: 'Skills',
                            content: skills.isEmpty
                                ? const Text(
                                    'No skills added yet. Tap Edit to add your skills.',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 12,
                                      color: Color(0xFF8C736B),
                                    ),
                                  )
                                : Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: skills.map((s) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFAF7F5),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE8E2DD),
                                          ),
                                        ),
                                        child: Text(
                                          s,
                                          style: const TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 12,
                                            color: Color(0xFF3E1F11),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Professional Fields overview
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildSectionCard(
                            icon: Icons.badge_outlined,
                            title: 'Professional',
                            content: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildProfileFieldColumn('Company', company),
                                _buildVerticalDivider(),
                                _buildProfileFieldColumn('Role', role),
                                _buildVerticalDivider(),
                                _buildProfileFieldColumn('Sector', industry),
                                _buildVerticalDivider(),
                                _buildProfileFieldColumn(
                                  'Experience',
                                  experience,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // About Me Card
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildSectionCard(
                            icon: Icons.person_outline_rounded,
                            title: 'About Me',
                            content: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
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
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: CustomPaint(
                                    painter: ConstellationPainter(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Interests Card
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildSectionCard(
                            icon: Icons.star_border_rounded,
                            title: 'Interests',
                            content: interests.isEmpty
                                ? const Text(
                                    'No interests added yet. Tap Edit to add your interests.',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 12,
                                      color: Color(0xFF8C736B),
                                    ),
                                  )
                                : Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: interests.map((tag) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE8E2DD),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getInterestIcon(tag),
                                              size: 14,
                                              color: const Color(0xFF7A432D),
                                            ),
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
                        ),
                        const SizedBox(height: 20),

                        // Travel Profile Card
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildSectionCard(
                            icon: Icons.flight_takeoff_rounded,
                            title: 'Travel Profile',
                            content: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: _buildTravelItem(
                                    icon: Icons.place_outlined,
                                    label: 'Home Base',
                                    value: homeBase,
                                  ),
                                ),
                                Expanded(
                                  child: _buildTravelItem(
                                    icon: Icons.my_location_rounded,
                                    label: 'Current Location',
                                    value: currentLocation,
                                  ),
                                ),
                                Expanded(
                                  child: _buildTravelItem(
                                    icon: Icons.flight_takeoff_outlined,
                                    label: 'Travel Frequency',
                                    value: travelFrequency,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Settings / Menu List
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE8E2DD),
                              ),
                            ),
                            child: Column(
                              children: [
                                _buildMenuItem(
                                  icon: Icons.settings_outlined,
                                  title: 'Settings',
                                  onTap: () {},
                                ),
                                _buildMenuItem(
                                  icon: Icons.security_outlined,
                                  title: 'Privacy',
                                  onTap: () {},
                                ),
                                _buildMenuItem(
                                  icon: Icons.help_outline_rounded,
                                  title: 'Help & Support',
                                  onTap: () {},
                                ),
                                _buildMenuItem(
                                  icon: Icons.logout_rounded,
                                  title: 'Logout',
                                  isLogout: true,
                                  onTap: () {
                                    _state.logOut();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildStatsCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFAF7F5),
                  border: Border.all(
                    color: const Color(0xFFE8E2DD),
                    width: 0.5,
                  ),
                ),
                child: Icon(icon, size: 16, color: const Color(0xFF7A432D)),
              ),
              const SizedBox(width: 8),
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
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E1F11),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 10,
              color: Color(0xFF8C736B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    Widget? actionWidget,
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E2DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: const Color(0xFF7A432D)),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E1F11),
                    ),
                  ),
                ],
              ),
              ?actionWidget,
            ],
          ),
          const SizedBox(height: 14),
          content,
        ],
      ),
    );
  }

  Widget _buildProfileFieldColumn(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 10,
              color: Color(0xFF8C736B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7A432D),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1, height: 24, color: const Color(0xFFE8E2DD));
  }

  Widget _buildTravelItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFAF7F5),
            border: Border.all(color: const Color(0xFFE8E2DD), width: 0.5),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF7A432D)),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 10,
            color: Color(0xFF8C736B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF7A432D),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    final color = isLogout ? const Color(0xFF8B2500) : const Color(0xFF3E1F11);
    final iconColor = isLogout
        ? const Color(0xFF8B2500)
        : const Color(0xFF7A432D);

    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: iconColor),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: isLogout
                      ? const Color(0xFF8B2500)
                      : const Color(0xFF8C736B),
                ),
              ],
            ),
          ),
          if (!isLogout)
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Container(height: 0.5, color: const Color(0xFFE8E2DD)),
            ),
        ],
      ),
    );
  }

  IconData _getInterestIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('java')) return Icons.coffee_outlined;
    if (lower.contains('spring') || lower.contains('boot')) {
      return Icons.spa_outlined;
    }
    if (lower.contains('ai') ||
        lower.contains('machine') ||
        lower.contains('ml')) {
      return Icons.auto_awesome_outlined;
    }
    if (lower.contains('startup') || lower.contains('entrepreneur')) {
      return Icons.rocket_launch_outlined;
    }
    if (lower.contains('network') || lower.contains('connect')) {
      return Icons.people_outline_rounded;
    }
    if (lower.contains('travel') ||
        lower.contains('explore') ||
        lower.contains('flight')) {
      return Icons.flight_takeoff_outlined;
    }
    if (lower.contains('code') ||
        lower.contains('develop') ||
        lower.contains('program')) {
      return Icons.code_outlined;
    }
    if (lower.contains('coffee')) return Icons.coffee_outlined;
    if (lower.contains('partnership') || lower.contains('b2b')) {
      return Icons.handshake_outlined;
    }
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
  late final TextEditingController _profileImageUrlController;
  late final TextEditingController _coverImageUrlController;
  late final TextEditingController _linkedinUrlController;

  // New item text controllers for timeline and skills
  final TextEditingController _newRoleController = TextEditingController();
  final TextEditingController _newCompanyController = TextEditingController();
  final TextEditingController _newLocationController = TextEditingController();
  final TextEditingController _newStartDateController = TextEditingController();
  final TextEditingController _newEndDateController = TextEditingController();
  final TextEditingController _newDescController = TextEditingController();
  String _newEmploymentType = 'Full-time';

  final TextEditingController _newSchoolController = TextEditingController();
  final TextEditingController _newDegreeController = TextEditingController();
  final TextEditingController _newEduStartDateController =
      TextEditingController();
  final TextEditingController _newEduEndDateController =
      TextEditingController();

  final TextEditingController _newSkillController = TextEditingController();

  bool _isLoading = false;
  bool _isProfileLoading = false;
  bool _isCoverLoading = false;
  late List<Map<String, dynamic>> _localCareerTimeline;
  late List<Map<String, dynamic>> _localEducationTimeline;
  late List<String> _localSkills;

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

  late String _homeBaseCountry;
  late String _homeBaseState;
  late String _homeBaseCity;

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

    final initialIndustry = widget.profile.industry ?? 'Technology';
    _selectedIndustry = _industries.contains(initialIndustry)
        ? initialIndustry
        : 'Other';
    _industryController = TextEditingController(
      text: widget.profile.industry ?? '',
    );

    final initialTravel = widget.profile.travelFrequency ?? 'Occasional';
    _selectedTravelFrequency = _travelFrequencies.contains(initialTravel)
        ? initialTravel
        : 'Occasional';

    _parseHomeBase(widget.profile.homeBase);
    _parseCurrentLocation(widget.profile.currentLocationName);

    _experienceController = TextEditingController(
      text: widget.profile.experience ?? '',
    );
    _profileImageUrlController = TextEditingController(
      text: widget.profile.profileImageUrl ?? '',
    );
    _coverImageUrlController = TextEditingController(
      text: widget.profile.coverImageUrl ?? '',
    );
    _linkedinUrlController = TextEditingController(
      text: widget.profile.linkedinProfileUrl ?? '',
    );

    _localCareerTimeline = List<Map<String, dynamic>>.from(
      widget.profile.careerTimeline,
    );
    _localEducationTimeline = List<Map<String, dynamic>>.from(
      widget.profile.educationTimeline,
    );
    _localSkills = List<String>.from(widget.profile.skills);
  }

  void _parseHomeBase(String? homeBaseStr) {
    if (homeBaseStr == null || homeBaseStr.isEmpty) {
      _homeBaseCountry = 'India';
      _homeBaseState = 'Andhra Pradesh';
      _homeBaseCity = 'Vijayawada';
      return;
    }

    final parts = homeBaseStr.split(',').map((e) => e.trim()).toList();
    if (parts.length >= 3) {
      _homeBaseCity = parts[0];
      _homeBaseState = parts[1];
      _homeBaseCountry = parts[2];
    } else if (parts.length == 2) {
      _homeBaseCity = '';
      _homeBaseState = parts[0];
      _homeBaseCountry = parts[1];
    } else if (parts.length == 1) {
      _homeBaseCity = '';
      _homeBaseState = '';
      _homeBaseCountry = parts[0];
    } else {
      _homeBaseCountry = 'India';
      _homeBaseState = 'Andhra Pradesh';
      _homeBaseCity = 'Vijayawada';
    }
  }

  void _parseCurrentLocation(String? currentLocStr) {
    if (currentLocStr == null || currentLocStr.isEmpty) {
      _currentLocationCountry = 'India';
      _currentLocationState = 'Karnataka';
      _currentLocationCity = 'Bangalore';
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
      _currentLocationCountry = 'India';
      _currentLocationState = 'Karnataka';
      _currentLocationCity = 'Bangalore';
    }
  }

  void _onHomeBaseCountryChanged(String country) {
    setState(() {
      _homeBaseCountry = country.contains('   ')
          ? country.split('   ').last
          : country;
    });
  }

  void _onHomeBaseStateChanged(String? state) {
    setState(() {
      _homeBaseState = state ?? '';
    });
  }

  void _onHomeBaseCityChanged(String? city) {
    setState(() {
      _homeBaseCity = city ?? '';
    });
  }

  void _onCurrentLocationCountryChanged(String country) {
    setState(() {
      _currentLocationCountry = country.contains('   ')
          ? country.split('   ').last
          : country;
    });
  }

  void _onCurrentLocationStateChanged(String? state) {
    setState(() {
      _currentLocationState = state ?? '';
    });
  }

  void _onCurrentLocationCityChanged(String? city) {
    setState(() {
      _currentLocationCity = city ?? '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _headlineController.dispose();
    _bioController.dispose();
    _companyController.dispose();
    _roleController.dispose();
    _industryController.dispose();
    _experienceController.dispose();
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

    _newSkillController.dispose();

    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    final finalIndustry = _selectedIndustry == 'Other'
        ? _industryController.text.trim()
        : _selectedIndustry;

    final homeBaseSegments = [
      if (_homeBaseCity.isNotEmpty) _homeBaseCity,
      if (_homeBaseState.isNotEmpty) _homeBaseState,
      if (_homeBaseCountry.isNotEmpty) _homeBaseCountry,
    ];
    final finalHomeBase = homeBaseSegments.join(', ');

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
        role: _roleController.text.trim(),
        industry: finalIndustry,
        experience: _experienceController.text.trim(),
        homeBase: finalHomeBase,
        currentLocationName: finalCurrentLocation,
        travelFrequency: _selectedTravelFrequency,
        profileImageUrl: _profileImageUrlController.text.trim(),
        coverImageUrl: _coverImageUrlController.text.trim(),
        linkedinProfileUrl: _linkedinUrlController.text.trim(),
        skills: _localSkills,
        careerTimeline: _localCareerTimeline,
        educationTimeline: _localEducationTimeline,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

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
                color: const Color(0xFFE8E2DD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Profile',
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E1F11),
                  ),
                ),
                _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF7A432D),
                          ),
                        ),
                      )
                    : TextButton(
                        onPressed: _saveProfile,
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7A432D),
                          ),
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Profile Photo Section
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PROFILE PHOTO',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF8C736B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFE8E2DD),
                                      border: Border.all(
                                        color: const Color(0xFF7A432D),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: _isProfileLoading
                                          ? const Padding(
                                              padding: EdgeInsets.all(12.0),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7A432D)),
                                              ),
                                            )
                                          : buildProfileImage(
                                              _profileImageUrlController.text,
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                              fallback: const Icon(
                                                Icons.person,
                                                size: 28,
                                                color: Color(0xFF7A432D),
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        XFile? pickedFile;
                                        Uint8List? bytes;
                                        try {
                                          final ImagePicker picker =
                                              ImagePicker();
                                          pickedFile = await picker
                                              .pickImage(
                                                source: ImageSource.gallery,
                                                imageQuality: 70,
                                              );
                                          if (pickedFile == null) return;
                                          setState(() => _isProfileLoading = true);
                                          bytes = await pickedFile
                                              .readAsBytes();
                                          final storageRef = FirebaseStorage
                                              .instance
                                              .ref()
                                              .child('profile_images')
                                              .child(
                                                '${DateTime.now().millisecondsSinceEpoch}.jpg',
                                              );
                                          final uploadTask = storageRef.putData(
                                            bytes,
                                            SettableMetadata(
                                              contentType: 'image/jpeg',
                                            ),
                                          );
                                          final snapshot = await uploadTask;
                                          final downloadUrl = await snapshot.ref
                                              .getDownloadURL();
                                          setState(() {
                                            _profileImageUrlController.text =
                                                downloadUrl;
                                            _isProfileLoading = false;
                                          });
                                        } catch (e) {
                                          try {
                                            if (bytes != null || pickedFile != null) {
                                              final fallbackBytes = bytes ?? await pickedFile!.readAsBytes();
                                              final base64Str = base64Encode(fallbackBytes);
                                              final dataUrl = 'data:image/jpeg;base64,$base64Str';
                                              setState(() {
                                                _profileImageUrlController.text = dataUrl;
                                                _isProfileLoading = false;
                                              });
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Storage upload failed. Image saved locally as base64 fallback.'),
                                                  ),
                                                );
                                              }
                                            } else {
                                              rethrow;
                                            }
                                          } catch (fallbackError) {
                                            setState(() => _isProfileLoading = false);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Failed to upload image: $e',
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF7A432D,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                      ),
                                      child: const Text(
                                        'Upload',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Cover Photo Section
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'COVER PHOTO',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF8C736B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8E2DD),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFF7A432D),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: _isCoverLoading
                                          ? const Padding(
                                              padding: EdgeInsets.all(12.0),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7A432D)),
                                              ),
                                            )
                                          : buildProfileImage(
                                              _coverImageUrlController.text,
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                              fallback: const Icon(
                                                Icons.image,
                                                size: 28,
                                                color: Color(0xFF7A432D),
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        XFile? pickedFile;
                                        Uint8List? bytes;
                                        try {
                                          final ImagePicker picker =
                                              ImagePicker();
                                          pickedFile = await picker
                                              .pickImage(
                                                source: ImageSource.gallery,
                                                imageQuality: 70,
                                              );
                                          if (pickedFile == null) return;
                                          setState(() => _isCoverLoading = true);
                                          bytes = await pickedFile
                                              .readAsBytes();
                                          final storageRef = FirebaseStorage
                                              .instance
                                              .ref()
                                              .child('profile_images')
                                              .child(
                                                '${DateTime.now().millisecondsSinceEpoch}.jpg',
                                              );
                                          final uploadTask = storageRef.putData(
                                            bytes,
                                            SettableMetadata(
                                              contentType: 'image/jpeg',
                                            ),
                                          );
                                          final snapshot = await uploadTask;
                                          final downloadUrl = await snapshot.ref
                                              .getDownloadURL();
                                          setState(() {
                                            _coverImageUrlController.text =
                                                downloadUrl;
                                            _isCoverLoading = false;
                                          });
                                        } catch (e) {
                                          try {
                                            if (bytes != null || pickedFile != null) {
                                              final fallbackBytes = bytes ?? await pickedFile!.readAsBytes();
                                              final base64Str = base64Encode(fallbackBytes);
                                              final dataUrl = 'data:image/jpeg;base64,$base64Str';
                                              setState(() {
                                                _coverImageUrlController.text = dataUrl;
                                                _isCoverLoading = false;
                                              });
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Storage upload failed. Image saved locally as base64 fallback.'),
                                                  ),
                                                );
                                              }
                                            } else {
                                              rethrow;
                                            }
                                          } catch (fallbackError) {
                                            setState(() => _isCoverLoading = false);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Failed to upload image: $e',
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF7A432D,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                      ),
                                      child: const Text(
                                        'Upload',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField('Name', _nameController),
                    _buildTextField('Headline', _headlineController),
                    _buildTextField(
                      'Bio / Description',
                      _bioController,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField('Company', _companyController),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField('Role', _roleController),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdownField(
                            label: 'Industry / Sector',
                            currentValue: _selectedIndustry!,
                            items: _industries,
                            onChanged: (val) {
                              setState(() => _selectedIndustry = val);
                            },
                            secondaryField: _selectedIndustry == 'Other'
                                ? _buildTextField(
                                    'Custom Industry',
                                    _industryController,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            'Experience',
                            _experienceController,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    _buildTextField(
                      'LinkedIn Profile URL',
                      _linkedinUrlController,
                    ),
                    const SizedBox(height: 12),

                    // Home Base CSC Picker
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Home Base',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8C736B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    CSCPickerPlus(
                      layout: Layout.vertical,
                      showStates: true,
                      showCities: true,
                      flagState: CountryFlag.DISABLE,
                      currentCountry: _homeBaseCountry,
                      currentState: _homeBaseState,
                      currentCity: _homeBaseCity,
                      dropdownDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFFE8E2DD),
                          width: 1.5,
                        ),
                      ),
                      disabledDropdownDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFFFAF7F5),
                        border: Border.all(
                          color: const Color(0xFFE8E2DD),
                          width: 1.5,
                        ),
                      ),
                      selectedItemStyle: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        color: Color(0xFF3E1F11),
                        fontWeight: FontWeight.w600,
                      ),
                      dropdownHeadingStyle: const TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E1F11),
                      ),
                      dropdownItemStyle: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        color: Color(0xFF3E1F11),
                      ),
                      searchBarRadius: 10.0,
                      onCountryChanged: (value) {
                        _onHomeBaseCountryChanged(value);
                      },
                      onStateChanged: (value) {
                        _onHomeBaseStateChanged(value);
                      },
                      onCityChanged: (value) {
                        _onHomeBaseCityChanged(value);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Current Location CSC Picker
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Current / Working Location',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8C736B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    CSCPickerPlus(
                      layout: Layout.vertical,
                      showStates: true,
                      showCities: true,
                      flagState: CountryFlag.DISABLE,
                      currentCountry: _currentLocationCountry,
                      currentState: _currentLocationState,
                      currentCity: _currentLocationCity,
                      dropdownDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFFE8E2DD),
                          width: 1.5,
                        ),
                      ),
                      disabledDropdownDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFFFAF7F5),
                        border: Border.all(
                          color: const Color(0xFFE8E2DD),
                          width: 1.5,
                        ),
                      ),
                      selectedItemStyle: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        color: Color(0xFF3E1F11),
                        fontWeight: FontWeight.w600,
                      ),
                      dropdownHeadingStyle: const TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E1F11),
                      ),
                      dropdownItemStyle: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        color: Color(0xFF3E1F11),
                      ),
                      searchBarRadius: 10.0,
                      onCountryChanged: (value) {
                        _onCurrentLocationCountryChanged(value);
                      },
                      onStateChanged: (value) {
                        _onCurrentLocationStateChanged(value);
                      },
                      onCityChanged: (value) {
                        _onCurrentLocationCityChanged(value);
                      },
                    ),
                    const SizedBox(height: 12),

                    _buildDropdownField(
                      label: 'Travel Frequency',
                      currentValue: _selectedTravelFrequency!,
                      items: _travelFrequencies,
                      onChanged: (val) {
                        setState(() => _selectedTravelFrequency = val);
                      },
                    ),

                    // Career Timeline Editor
                    const Divider(color: Color(0xFFE8E2DD), thickness: 1),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Work Experience Timeline',
                        style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_localCareerTimeline.length, (idx) {
                      final item = _localCareerTimeline[idx];
                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFE8E2DD)),
                        ),
                        child: ListTile(
                          title: Text(
                            '${item['role']} at ${item['company']}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3E1F11),
                            ),
                          ),
                          subtitle: Text(
                            [
                                      if ((item['startDate'] ?? '')
                                              .toString()
                                              .isNotEmpty ||
                                          (item['endDate'] ?? '')
                                              .toString()
                                              .isNotEmpty)
                                        '${item['startDate'] ?? ''} to ${item['endDate'] ?? ''}',
                                      if ((item['employmentType'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        item['employmentType'],
                                      if ((item['location'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        item['location'],
                                    ]
                                    .where(
                                      (s) =>
                                          s != null && s.toString().isNotEmpty,
                                    )
                                    .join(' · ') +
                                ((item['description'] ?? '')
                                        .toString()
                                        .isNotEmpty
                                    ? '\n${item['description']}'
                                    : ''),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8C736B),
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _localCareerTimeline.removeAt(idx);
                              });
                            },
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE8E2DD)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add Work Experience',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF3E1F11),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildTextField('Company', _newCompanyController),
                          _buildTextField(
                            'Role / Job Title',
                            _newRoleController,
                          ),
                          // Employment Type Dropdown
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: DropdownButtonFormField<String>(
                              initialValue: _newEmploymentType,
                              decoration: InputDecoration(
                                labelText: 'Employment Type',
                                labelStyle: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  color: Color(0xFF8C736B),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFFAF7F5),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE8E2DD),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF7A432D),
                                  ),
                                ),
                              ),
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                color: Color(0xFF3E1F11),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Full-time',
                                  child: Text('Full-time'),
                                ),
                                DropdownMenuItem(
                                  value: 'Part-time',
                                  child: Text('Part-time'),
                                ),
                                DropdownMenuItem(
                                  value: 'Self-employed',
                                  child: Text('Self-employed'),
                                ),
                                DropdownMenuItem(
                                  value: 'Freelance',
                                  child: Text('Freelance'),
                                ),
                                DropdownMenuItem(
                                  value: 'Contract',
                                  child: Text('Contract'),
                                ),
                                DropdownMenuItem(
                                  value: 'Internship',
                                  child: Text('Internship'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _newEmploymentType = val);
                                }
                              },
                            ),
                          ),
                          _buildTextField('Location', _newLocationController),
                          _buildTextField(
                            'From',
                            _newStartDateController,
                            readOnly: true,
                            onTap: () =>
                                _selectDate(context, _newStartDateController),
                          ),
                          _buildTextField(
                            'To',
                            _newEndDateController,
                            readOnly: true,
                            onTap: () => _selectDate(
                              context,
                              _newEndDateController,
                              isEndDate: true,
                            ),
                          ),
                          _buildTextField(
                            'Description',
                            _newDescController,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7A432D),
                              ),
                              onPressed: () {
                                if (_newRoleController.text.trim().isEmpty ||
                                    _newCompanyController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please fill Role and Company',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setState(() {
                                  _localCareerTimeline.add({
                                    'company': _newCompanyController.text
                                        .trim(),
                                    'role': _newRoleController.text.trim(),
                                    'employmentType': _newEmploymentType,
                                    'location': _newLocationController.text
                                        .trim(),
                                    'startDate': _newStartDateController.text
                                        .trim(),
                                    'endDate': _newEndDateController.text
                                        .trim(),
                                    'duration':
                                        '${_newStartDateController.text.trim()} to ${_newEndDateController.text.trim()}',
                                    'description': _newDescController.text
                                        .trim(),
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
                              child: const Text(
                                'Add Experience',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Education Timeline Editor
                    const Divider(color: Color(0xFFE8E2DD), thickness: 1),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Education Timeline',
                        style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_localEducationTimeline.length, (idx) {
                      final item = _localEducationTimeline[idx];
                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFE8E2DD)),
                        ),
                        child: ListTile(
                          title: Text(
                            '${item['degree']} at ${item['school']}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3E1F11),
                            ),
                          ),
                          subtitle: Text(
                            ((item['startDate'] ?? '').toString().isNotEmpty ||
                                    (item['endDate'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                ? '${item['startDate'] ?? ''} to ${item['endDate'] ?? ''}'
                                : '${item['duration'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8C736B),
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _localEducationTimeline.removeAt(idx);
                              });
                            },
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE8E2DD)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add Education',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF3E1F11),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildTextField(
                            'Degree / Course',
                            _newDegreeController,
                          ),
                          _buildTextField(
                            'School / University',
                            _newSchoolController,
                          ),
                          _buildTextField(
                            'From',
                            _newEduStartDateController,
                            readOnly: true,
                            onTap: () => _selectDate(
                              context,
                              _newEduStartDateController,
                            ),
                          ),
                          _buildTextField(
                            'To',
                            _newEduEndDateController,
                            readOnly: true,
                            onTap: () => _selectDate(
                              context,
                              _newEduEndDateController,
                              isEndDate: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7A432D),
                              ),
                              onPressed: () {
                                if (_newDegreeController.text.trim().isEmpty ||
                                    _newSchoolController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please fill Degree and School',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                if (_newEduStartDateController.text
                                        .trim()
                                        .isEmpty ||
                                    _newEduEndDateController.text
                                        .trim()
                                        .isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please fill From and To dates',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setState(() {
                                  _localEducationTimeline.add({
                                    'degree': _newDegreeController.text.trim(),
                                    'school': _newSchoolController.text.trim(),
                                    'startDate': _newEduStartDateController.text
                                        .trim(),
                                    'endDate': _newEduEndDateController.text
                                        .trim(),
                                    'duration':
                                        '${_newEduStartDateController.text.trim()} to ${_newEduEndDateController.text.trim()}',
                                  });
                                  _newDegreeController.clear();
                                  _newSchoolController.clear();
                                  _newEduStartDateController.clear();
                                  _newEduEndDateController.clear();
                                });
                              },
                              child: const Text(
                                'Add Education',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Skills Editor
                    const Divider(color: Color(0xFFE8E2DD), thickness: 1),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Skills',
                        style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _localSkills
                          .map(
                            (s) => Chip(
                              backgroundColor: Colors.white,
                              label: Text(
                                s,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  color: Color(0xFF3E1F11),
                                ),
                              ),
                              onDeleted: () {
                                setState(() {
                                  _localSkills.remove(s);
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            'Add Skill',
                            _newSkillController,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7A432D),
                            ),
                            onPressed: () {
                              final text = _newSkillController.text.trim();
                              if (text.isNotEmpty &&
                                  !_localSkills.contains(text)) {
                                setState(() {
                                  _localSkills.add(text);
                                });
                                _newSkillController.clear();
                              }
                            },
                            child: const Text(
                              'Add',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    ValueChanged<String>? onChanged,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            onChanged: onChanged,
            readOnly: readOnly,
            onTap: onTap,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              color: Color(0xFF3E1F11),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              suffixIcon:
                  suffixIcon ??
                  (readOnly
                      ? const Icon(
                          Icons.calendar_today_outlined,
                          color: Color(0xFF7A432D),
                          size: 18,
                        )
                      : null),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF7A432D),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller, {
    bool isEndDate = false,
  }) async {
    if (isEndDate) {
      final String? result = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text(
              'Select End Date',
              style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'Choose if this is your current position or select a specific date.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'Present'),
                child: const Text(
                  'Present',
                  style: TextStyle(color: Color(0xFF7A432D)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'Select'),
                child: const Text(
                  'Select Date',
                  style: TextStyle(color: Color(0xFF7A432D)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          );
        },
      );
      if (result == 'Present') {
        controller.text = 'Present';
        return;
      } else if (result == null) {
        return;
      }
    }

    if (!mounted) return;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7A432D),
              onPrimary: Colors.white,
              onSurface: Color(0xFF3E1F11),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF7A432D),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      controller.text = '${months[picked.month - 1]} ${picked.year}';
    }
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
              labelStyle: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                color: Color(0xFF8C736B),
                fontSize: 13,
              ),
              floatingLabelStyle: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                color: Color(0xFF7A432D),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
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
                borderSide: const BorderSide(
                  color: Color(0xFF7A432D),
                  width: 1.5,
                ),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: safeItems.contains(currentValue)
                    ? currentValue
                    : (safeItems.isNotEmpty ? safeItems.first : null),
                isExpanded: true,
                isDense: true,
                dropdownColor: Colors.white,
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: Color(0xFF7A432D),
                ),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  color: Color(0xFF3E1F11),
                ),
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
  final TextEditingController _interestInputController =
      TextEditingController();
  final TextEditingController _profInterestInputController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _skills = List<String>.from(widget.parsedData['skills'] ?? []);
    _careerTimeline = (widget.parsedData['careerTimeline'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _educationTimeline = (widget.parsedData['educationTimeline'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _interests = List<String>.from(widget.parsedData['interests'] ?? []);
    _professionalInterests = List<String>.from(
      widget.parsedData['professionalInterests'] ?? [],
    );
  }

  @override
  void dispose() {
    _skillInputController.dispose();
    _interestInputController.dispose();
    _profInterestInputController.dispose();
    super.dispose();
  }

  Widget _buildField(
    String label,
    String value,
    Function(String) onChanged, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8C736B),
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            initialValue: value,
            maxLines: maxLines,
            onChanged: onChanged,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              color: Color(0xFF3E1F11),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF7A432D),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF7A432D)),
          const SizedBox(width: 8),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFFFAF7F5),
      child: Container(
        width: min(MediaQuery.of(context).size.width * 0.9, 600),
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.auto_awesome, color: Color(0xFF7A432D)),
                    SizedBox(width: 8),
                    Text(
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
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF8C736B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'We have extracted the following information from your resume. Review and edit it before saving.',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                color: Color(0xFF5C473E),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFE8E2DD)),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Skills ---
                    _buildSectionHeader('Skills', Icons.psychology),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _skills.map((skill) {
                        return Chip(
                          label: Text(
                            skill,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              color: Color(0xFF3E1F11),
                            ),
                          ),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFE8E2DD)),
                          onDeleted: () {
                            setState(() {
                              _skills.remove(skill);
                            });
                          },
                          deleteIconColor: const Color(0xFF7A432D),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _skillInputController,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Add a skill...',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE8E2DD),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF7A432D),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7A432D),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () {
                            final text = _skillInputController.text.trim();
                            if (text.isNotEmpty && !_skills.contains(text)) {
                              setState(() {
                                _skills.add(text);
                                _skillInputController.clear();
                              });
                            }
                          },
                          child: const Text(
                            'Add',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // --- Career History ---
                    _buildSectionHeader('Work Experience', Icons.work),
                    ...List.generate(_careerTimeline.length, (index) {
                      final item = _careerTimeline[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                                Text(
                                  'Position #${index + 1}',
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7A432D),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Color(0xFFC62828),
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _careerTimeline.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                            _buildField('Company', item['company'] ?? '', (
                              val,
                            ) {
                              item['company'] = val;
                            }),
                            _buildField(
                              'Job Title / Role',
                              item['role'] ?? '',
                              (val) {
                                item['role'] = val;
                              },
                            ),
                            _buildField(
                              'Employment Type',
                              item['employmentType'] ?? 'Full-time',
                              (val) {
                                item['employmentType'] = val;
                              },
                            ),
                            _buildField('Location', item['location'] ?? '', (
                              val,
                            ) {
                              item['location'] = val;
                            }),
                            _buildField('Start Date', item['startDate'] ?? '', (
                              val,
                            ) {
                              item['startDate'] = val;
                            }),
                            _buildField('End Date', item['endDate'] ?? '', (
                              val,
                            ) {
                              item['endDate'] = val;
                            }),
                            _buildField(
                              'Description',
                              item['description'] ?? '',
                              (val) {
                                item['description'] = val;
                              },
                              maxLines: 2,
                            ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      icon: const Icon(
                        Icons.add,
                        size: 16,
                        color: Color(0xFF7A432D),
                      ),
                      label: const Text(
                        'Add Work Experience',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          color: Color(0xFF7A432D),
                          fontSize: 12,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _careerTimeline.add({
                            'company': '',
                            'role': '',
                            'employmentType': 'Full-time',
                            'location': '',
                            'startDate': '',
                            'endDate': '',
                            'description': '',
                          });
                        });
                      },
                    ),

                    // --- Education ---
                    _buildSectionHeader('Education', Icons.school),
                    ...List.generate(_educationTimeline.length, (index) {
                      final item = _educationTimeline[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                                Text(
                                  'Education #${index + 1}',
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7A432D),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Color(0xFFC62828),
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _educationTimeline.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                            _buildField(
                              'Degree / Certificate',
                              item['degree'] ?? '',
                              (val) {
                                item['degree'] = val;
                              },
                            ),
                            _buildField(
                              'School / Institution',
                              item['school'] ?? '',
                              (val) {
                                item['school'] = val;
                              },
                            ),
                            _buildField('Duration', item['duration'] ?? '', (
                              val,
                            ) {
                              item['duration'] = val;
                            }),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      icon: const Icon(
                        Icons.add,
                        size: 16,
                        color: Color(0xFF7A432D),
                      ),
                      label: const Text(
                        'Add Education',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          color: Color(0xFF7A432D),
                          fontSize: 12,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _educationTimeline.add({
                            'degree': '',
                            'school': '',
                            'duration': '',
                          });
                        });
                      },
                    ),

                    // --- Interests ---
                    _buildSectionHeader('Interests', Icons.favorite),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _interests.map((interest) {
                        return Chip(
                          label: Text(
                            interest,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              color: Color(0xFF3E1F11),
                            ),
                          ),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFE8E2DD)),
                          onDeleted: () {
                            setState(() {
                              _interests.remove(interest);
                            });
                          },
                          deleteIconColor: const Color(0xFF7A432D),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _interestInputController,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Add an interest...',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE8E2DD),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF7A432D),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7A432D),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () {
                            final text = _interestInputController.text.trim();
                            if (text.isNotEmpty && !_interests.contains(text)) {
                              setState(() {
                                _interests.add(text);
                                _interestInputController.clear();
                              });
                            }
                          },
                          child: const Text(
                            'Add',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // --- Professional Interests ---
                    _buildSectionHeader(
                      'Professional Interests',
                      Icons.handshake,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _professionalInterests.map((interest) {
                        return Chip(
                          label: Text(
                            interest,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              color: Color(0xFF3E1F11),
                            ),
                          ),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFE8E2DD)),
                          onDeleted: () {
                            setState(() {
                              _professionalInterests.remove(interest);
                            });
                          },
                          deleteIconColor: const Color(0xFF7A432D),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _profInterestInputController,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Add a professional interest...',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE8E2DD),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF7A432D),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7A432D),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () {
                            final text = _profInterestInputController.text
                                .trim();
                            if (text.isNotEmpty &&
                                !_professionalInterests.contains(text)) {
                              setState(() {
                                _professionalInterests.add(text);
                                _profInterestInputController.clear();
                              });
                            }
                          },
                          child: const Text(
                            'Add',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Footer
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFE8E2DD)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      color: Color(0xFF8C736B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7A432D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {
                    final updatedData = {
                      'skills': _skills,
                      'careerTimeline': _careerTimeline,
                      'educationTimeline': _educationTimeline,
                      'interests': _interests,
                      'professionalInterests': _professionalInterests,
                    };
                    widget.onSave(updatedData);
                  },
                  child: const Text(
                    'Save & Enrich Profile',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
