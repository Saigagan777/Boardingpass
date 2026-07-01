import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  double _calculateProfileCompleteness(UserProfile profile) {
    int total = 0;
    int completed = 0;

    // 1. Name
    total++;
    if (profile.name.trim().isNotEmpty) completed++;

    // 2. Email
    total++;
    if (profile.email.trim().isNotEmpty) completed++;

    // 3. Profile Image
    total++;
    if ((profile.profileImageUrl ?? '').trim().isNotEmpty) completed++;

    // 4. Role
    total++;
    if ((profile.role ?? '').trim().isNotEmpty) completed++;

    // 5. Company
    total++;
    if ((profile.company ?? '').trim().isNotEmpty) completed++;

    // 6. Headline
    total++;
    if ((profile.headline ?? '').trim().isNotEmpty) completed++;

    // 7. Expertise / Skills
    total++;
    if (profile.expertise.isNotEmpty || profile.skills.isNotEmpty) completed++;

    // 8. Industry
    total++;
    if ((profile.industry ?? '').trim().isNotEmpty && profile.industry != 'Select Industry') completed++;

    // 9. Experience Years
    total++;
    if ((profile.experience ?? '').trim().isNotEmpty) completed++;

    // 10. Bio
    total++;
    if ((profile.bio ?? '').trim().isNotEmpty) completed++;

    // 11. Intents
    total++;
    if (profile.intents.isNotEmpty) completed++;

    // 12. Travel Frequency
    total++;
    if ((profile.travelFrequency ?? '').trim().isNotEmpty && profile.travelFrequency != 'Select Frequency') completed++;

    // 13. Home Base
    total++;
    if ((profile.homeBase ?? '').trim().isNotEmpty) completed++;

    // 14. Current Location
    total++;
    if ((profile.currentLocationName ?? '').trim().isNotEmpty) completed++;

    // 15. Work Experience (Optional)
    total++;
    if (profile.careerTimeline.isNotEmpty) completed++;

    // 16. Education (Optional)
    total++;
    if (profile.educationTimeline.isNotEmpty) completed++;

    return total == 0 ? 0.0 : (completed / total) * 100.0;
  }

  Widget _buildProfileHeader(UserProfile profile, BuildContext context) {
    final coverUrl = profile.coverImageUrl ?? '';
    final pictureUrl = profile.profileImageUrl ?? '';
    final name = profile.name.isNotEmpty ? profile.name : 'User';
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'U';
    final completeness = _calculateProfileCompleteness(profile);

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
        // 3. Overlapping Circular Avatar & Completeness Percentage
        Positioned(
          top: 90,
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: SizedBox(
                        width: 90,
                        height: 90,
                        child: CircularProgressIndicator(
                          value: completeness / 100.0,
                          strokeWidth: 4.0,
                          backgroundColor: const Color(0xFFD6F0DB),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 83,
                        height: 83,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 75,
                        height: 75,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE8E2DD),
                        ),
                        child: ClipOval(
                          child: buildProfileImage(
                            pictureUrl,
                            width: 75,
                            height: 75,
                            fit: BoxFit.cover,
                            fallback: Container(
                              color: const Color(0xFFE8E2DD),
                              alignment: Alignment.center,
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  fontFamily: 'PlayfairDisplay',
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF7A432D),
                                ),
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
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
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
      final placeholderText = type == 'career'
          ? 'No work experience added yet.'
          : 'No education details added yet.';
      return _buildSectionCard(
        icon: icon,
        title: title,
        content: Text(
          placeholderText,
          style: const TextStyle(
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
                              if (profile.email.isNotEmpty) ...
                              [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.email_outlined,
                                      size: 13,
                                      color: Color(0xFF7A432D),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      profile.email,
                                      style: const TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 12,
                                        color: Color(0xFF8C736B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
                                  final bool isLinkedInSynced = profile.linkedinSynced ||
                                      (profile.linkedinId != null && profile.linkedinId!.isNotEmpty);

                                  if (url != null && url.isNotEmpty) {
                                    launchUrl(
                                      Uri.parse(url),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } else if (isLinkedInSynced) {
                                    launchUrl(
                                      Uri.parse('https://www.linkedin.com/me'),
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
                                        (profile.linkedinProfileUrl != null &&
                                                profile.linkedinProfileUrl!.isNotEmpty) ||
                                                profile.linkedinSynced ||
                                                (profile.linkedinId != null && profile.linkedinId!.isNotEmpty)
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
                                // Set / Change Password — shown for all users
                                Builder(builder: (_) {
                                  final fbEmail = FirebaseAuth.instance.currentUser?.email ?? '';
                                  final isLinkedInSynthetic = fbEmail.startsWith('linkedin_') && fbEmail.contains('@boardingpass.com');
                                  final hasPassword = !isLinkedInSynthetic || profile.directPasswordSet;
                                  return _buildMenuItem(
                                    icon: hasPassword ? Icons.lock_reset_rounded : Icons.lock_open_rounded,
                                    title: hasPassword ? 'Change Password' : 'Set Password',
                                    onTap: () => _showPasswordDialogFromProfile(context, profile, !hasPassword),
                                  );
                                }),
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

  /// Shows the Set Password / Change Password dialog from the profile screen settings.
  Future<void> _showPasswordDialogFromProfile(
    BuildContext context,
    UserProfile profile,
    bool isSettingNew,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    final currentPasswordCtrl = TextEditingController();
    bool obscureNew = true;
    bool obscureCurrent = true;
    bool obscureConfirm = true;
    String newPassError = '';
    String confirmPassError = '';

    await showDialog(

      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFFAF7F5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  isSettingNew ? Icons.lock_open_rounded : Icons.lock_reset_rounded,
                  color: const Color(0xFF7A432D),
                  size: 20,
                ),
                const SizedBox(width: 8),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSettingNew) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: Color(0xFF2E7D32)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'After setting a password, you can sign in with ${profile.email} directly — no LinkedIn needed.',
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
                  ] else ...[
                    TextField(
                      controller: currentPasswordCtrl,
                      obscureText: obscureCurrent,
                      style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        labelStyle: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: Color(0xFF8C736B)),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: const Color(0xFF8C736B)),
                          onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: newPasswordCtrl,
                    obscureText: obscureNew,
                    style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      labelStyle: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: Color(0xFF8C736B)),
                      helperText: 'Minimum 6 characters',
                      helperStyle: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, color: Color(0xFF8C736B)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: const Color(0xFF8C736B)),
                        onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                      ),
                    ),
                    onChanged: (_) {
                      final p = newPasswordCtrl.text;
                      if (p.isEmpty) {
                        newPassError = '';
                      } else if (p.length < 6) {
                        newPassError = 'Must be at least 6 characters';
                      } else {
                        newPassError = '';
                      }
                      setDialogState(() {});
                    },
                  ),
                  if (newPassError.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, left: 4),
                      child: Text(
                        newPassError,
                        style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: Color(0xFFC62828)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordCtrl,
                    obscureText: obscureConfirm,
                    style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      labelStyle: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: Color(0xFF8C736B)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: const Color(0xFF8C736B)),
                        onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
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
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel', style: TextStyle(fontFamily: 'PlusJakartaSans', color: Color(0xFF8C736B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A432D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: () async {
                  final newPass = newPasswordCtrl.text.trim();
                  final confirmPass = confirmPasswordCtrl.text.trim();
                  if (newPass.length < 6) {
                    newPassError = 'Must be at least 6 characters';
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
                      // LinkedIn user — re-authenticate with synthetic credentials, then
                      // update to real email + set new password so direct sign-in works.
                      final sub = profile.linkedinId ?? '';
                      final syntheticEmail = 'linkedin_$sub@boardingpass.com';
                      final syntheticPassword = 'linkedin_user_$sub';
                      final synthCred = EmailAuthProvider.credential(
                        email: syntheticEmail,
                        password: syntheticPassword,
                      );
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

    // Add listeners for real-time progress update in sheet
    _nameController.addListener(_onFieldChanged);
    _headlineController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
    _companyController.addListener(_onFieldChanged);
    _roleController.addListener(_onFieldChanged);
    _industryController.addListener(_onFieldChanged);
    _experienceController.addListener(_onFieldChanged);
    _profileImageUrlController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  double _calculateLocalCompleteness() {
    int total = 0;
    int completed = 0;

    // 1. Name
    total++;
    if (_nameController.text.trim().isNotEmpty) completed++;

    // 2. Email
    total++;
    if (widget.profile.email.trim().isNotEmpty) completed++;

    // 3. Profile Image
    total++;
    if (_profileImageUrlController.text.trim().isNotEmpty) completed++;

    // 4. Role
    total++;
    if (_roleController.text.trim().isNotEmpty) completed++;

    // 5. Company
    total++;
    if (_companyController.text.trim().isNotEmpty) completed++;

    // 6. Headline
    total++;
    if (_headlineController.text.trim().isNotEmpty) completed++;

    // 7. Expertise / Skills
    total++;
    if (_localSkills.isNotEmpty) completed++;

    // 8. Industry
    total++;
    if (_selectedIndustry != null &&
        _selectedIndustry!.isNotEmpty &&
        _selectedIndustry != 'Select Industry') {
      if (_selectedIndustry == 'Other') {
        if (_industryController.text.trim().isNotEmpty) {
          completed++;
        }
      } else {
        completed++;
      }
    }

    // 9. Experience Years
    total++;
    if (_experienceController.text.trim().isNotEmpty) completed++;

    // 10. Bio
    total++;
    if (_bioController.text.trim().isNotEmpty) completed++;

    // 11. Intents
    total++;
    if (widget.profile.intents.isNotEmpty) completed++;

    // 12. Travel Frequency
    total++;
    if (_selectedTravelFrequency != null &&
        _selectedTravelFrequency!.isNotEmpty &&
        _selectedTravelFrequency != 'Select Frequency') {
      completed++;
    }

    // 13. Home Base
    total++;
    if (_homeBaseCountry.isNotEmpty || _homeBaseCity.isNotEmpty) completed++;

    // 14. Current Location
    total++;
    if (_currentLocationCountry.isNotEmpty || _currentLocationCity.isNotEmpty) completed++;

    // 15. Work Experience (Optional)
    total++;
    if (_localCareerTimeline.isNotEmpty) completed++;

    // 16. Education (Optional)
    total++;
    if (_localEducationTimeline.isNotEmpty) completed++;

    return total == 0 ? 0.0 : (completed / total) * 100.0;
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
    _nameController.removeListener(_onFieldChanged);
    _headlineController.removeListener(_onFieldChanged);
    _bioController.removeListener(_onFieldChanged);
    _companyController.removeListener(_onFieldChanged);
    _roleController.removeListener(_onFieldChanged);
    _industryController.removeListener(_onFieldChanged);
    _experienceController.removeListener(_onFieldChanged);
    _profileImageUrlController.removeListener(_onFieldChanged);

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

    // Auto-add unsaved typed timeline inputs
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Profile Photo Section
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PROFILE PHOTO (${_calculateLocalCompleteness().toInt()}% COMPLETE)',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF8C736B),
                                ),
                              ),
                              const SizedBox(height: 8),
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
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFFE8E2DD),
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
                                    ],
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
                    _buildTextField('Name', _nameController, hintText: 'Enter your full name'),
                    _buildTextField('Headline', _headlineController, hintText: 'e.g. VP Engineering at Stripe'),
                    _buildTextField(
                      'Bio / Description',
                      _bioController,
                      maxLines: 3,
                      hintText: 'Tell us about yourself…',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField('Company', _companyController, hintText: 'e.g. Google, Stripe'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField('Role', _roleController, hintText: 'e.g. Software Engineer'),
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
                                    hintText: 'e.g. BioTech',
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            'Experience',
                            _experienceController,
                            hintText: 'e.g. 5 years',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    _buildTextField(
                      'LinkedIn Profile URL',
                      _linkedinUrlController,
                      hintText: 'https://linkedin.com/in/yourprofile',
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
                      currentCountry: getCountryForPicker(_homeBaseCountry),
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
                      currentCountry: getCountryForPicker(_currentLocationCountry),
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
                          _buildTextField('Company', _newCompanyController, hintText: 'e.g. Google, Stripe'),
                          _buildTextField(
                            'Role / Job Title',
                            _newRoleController,
                            hintText: 'e.g. Software Engineer',
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
                          _buildTextField('Location', _newLocationController, hintText: 'e.g. San Francisco, CA'),
                          _buildTextField(
                            'Description',
                            _newDescController,
                            maxLines: 2,
                            hintText: 'Describe your key accomplishments…',
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
                                    'startDate': '',
                                    'endDate': '',
                                    'duration': '',
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
                            hintText: 'e.g. B.S. in Computer Science',
                          ),
                          _buildTextField(
                            'School / University',
                            _newSchoolController,
                            hintText: 'e.g. Stanford University',
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7A432D),
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
                            hintText: 'Type a skill…',
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
    String? hintText,
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
              hintText: hintText,
              hintStyle: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                color: const Color(0xFF3E1F11).withValues(alpha: 0.35),
              ),
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
    String? hintText,
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
              hintText: hintText,
              hintStyle: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                color: const Color(0xFF3E1F11).withValues(alpha: 0.35),
              ),
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
                            }, hintText: 'Enter company name'),
                            _buildField(
                              'Job Title / Role',
                              item['role'] ?? '',
                              (val) {
                                item['role'] = val;
                              },
                              hintText: 'e.g. Software Engineer',
                            ),
                            _buildField(
                              'Employment Type',
                              item['employmentType'] ?? 'Full-time',
                              (val) {
                                item['employmentType'] = val;
                              },
                              hintText: 'e.g. Full-time, Contract',
                            ),
                            _buildField('Location', item['location'] ?? '', (
                              val,
                            ) {
                              item['location'] = val;
                            }, hintText: 'e.g. San Francisco, CA'),
                            _buildField(
                              'Description',
                              item['description'] ?? '',
                              (val) {
                                item['description'] = val;
                              },
                              maxLines: 2,
                              hintText: 'Describe your key accomplishments…',
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
                              hintText: 'e.g. B.S. in Computer Science',
                            ),
                            _buildField(
                              'School / Institution',
                              item['school'] ?? '',
                              (val) {
                                item['school'] = val;
                              },
                              hintText: 'e.g. Stanford University',
                            ),
                            _buildField('Duration', item['duration'] ?? '', (
                              val,
                            ) {
                              item['duration'] = val;
                            }, hintText: 'e.g. 2020 - 2024'),
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

String getCountryForPicker(String? countryName) {
  if (countryName == null || countryName.isEmpty) return '🇮🇳   India';
  if (countryName.contains('   ')) return countryName;
  
  final Map<String, String> countryToEmoji = {
    'Afghanistan': '🇦🇫   Afghanistan',
    'Albania': '🇦🇱   Albania',
    'Algeria': '🇩🇿   Algeria',
    'Andorra': '🇦🇩   Andorra',
    'Angola': '🇦🇴   Angola',
    'Argentina': '🇦🇷   Argentina',
    'Armenia': '🇦🇲   Armenia',
    'Australia': '🇦🇺   Australia',
    'Austria': '🇦🇹   Austria',
    'Azerbaijan': '🇦🇿   Azerbaijan',
    'Bahamas': '🇧🇸   Bahamas',
    'Bahrain': '🇧🇭   Bahrain',
    'Bangladesh': '🇧🇩   Bangladesh',
    'Barbados': '🇧🇧   Barbados',
    'Belarus': '🇧🇾   Belarus',
    'Belgium': '🇧🇪   Belgium',
    'Belize': '🇧🇿   Belize',
    'Benin': '🇧🇯   Benin',
    'Bhutan': '🇧🇹   Bhutan',
    'Bolivia': '🇧🇴   Bolivia',
    'Bosnia and Herzegovina': '🇧🇦   Bosnia and Herzegovina',
    'Botswana': '🇧🇼   Botswana',
    'Brazil': '🇧🇷   Brazil',
    'Brunei': '🇧🇳   Brunei',
    'Bulgaria': '🇧🇬   Bulgaria',
    'Burkina Faso': '🇧🇫   Burkina Faso',
    'Burundi': '🇧🇮   Burundi',
    'Cambodia': '🇰🇭   Cambodia',
    'Cameroon': '🇨🇲   Cameroon',
    'Canada': '🇨🇦   Canada',
    'Cape Verde': '🇨🇻   Cape Verde',
    'Central African Republic': '🇨🇫   Central African Republic',
    'Chad': '🇹🇩   Chad',
    'Chile': '🇨🇱   Chile',
    'China': '🇨🇳   China',
    'Colombia': '🇨🇴   Colombia',
    'Comoros': '🇰🇲   Comoros',
    'Congo': '🇨🇬   Congo',
    'Costa Rica': '🇨🇷   Costa Rica',
    'Croatia': '🇭🇷   Croatia',
    'Cuba': '🇨🇺   Cuba',
    'Cyprus': '🇨🇾   Cyprus',
    'Czech Republic': '🇨🇿   Czech Republic',
    'Denmark': '🇩🇰   Denmark',
    'Djibouti': '🇩🇯   Djibouti',
    'Dominica': '🇩🇲   Dominica',
    'Dominican Republic': '🇩🇴   Dominican Republic',
    'Ecuador': '🇪🇨   Ecuador',
    'Egypt': '🇪🇬   Egypt',
    'El Salvador': '🇸🇻   El Salvador',
    'Equatorial Guinea': '🇬🇶   Equatorial Guinea',
    'Eritrea': '🇪🇷   Eritrea',
    'Estonia': '🇪🇪   Estonia',
    'Ethiopia': '🇪🇹   Ethiopia',
    'Fiji': '🇫🇯   Fiji',
    'Finland': '🇫🇮   Finland',
    'France': '🇫🇷   France',
    'Gabon': '🇬🇦   Gabon',
    'Gambia': '🇬🇲   Gambia',
    'Georgia': '🇬🇪   Georgia',
    'Germany': '🇩🇪   Germany',
    'Ghana': '🇬🇭   Ghana',
    'Greece': '🇬🇷   Greece',
    'Grenada': '🇬🇩   Grenada',
    'Guatemala': '🇬🇹   Guatemala',
    'Guinea': '🇬🇳   Guinea',
    'Guinea-Bissau': '🇬🇼   Guinea-Bissau',
    'Guyana': '🇬🇾   Guyana',
    'Haiti': '🇭🇹   Haiti',
    'Honduras': '🇭🇳   Honduras',
    'Hungary': '🇭🇺   Hungary',
    'Iceland': '🇮🇸   Iceland',
    'India': '🇮🇳   India',
    'Indonesia': '🇮🇩   Indonesia',
    'Iran': '🇮🇷   Iran',
    'Iraq': '🇮🇶   Iraq',
    'Ireland': '🇮🇪   Ireland',
    'Israel': '🇮🇱   Israel',
    'Italy': '🇮🇹   Italy',
    'Jamaica': '🇯🇲   Jamaica',
    'Japan': '🇯🇵   Japan',
    'Jordan': '🇯🇴   Jordan',
    'Kazakhstan': '🇰🇿   Kazakhstan',
    'Kenya': '🇰🇪   Kenya',
    'Kiribati': '🇰🇮   Kiribati',
    'Kuwait': '🇰🇼   Kuwait',
    'Kyrgyzstan': '🇰🇬   Kyrgyzstan',
    'Laos': '🇱🇦   Laos',
    'Latvia': '🇱🇻   Latvia',
    'Lebanon': '🇱🇧   Lebanon',
    'Lesotho': '🇱🇸   Lesotho',
    'Liberia': '🇱🇷   Liberia',
    'Libya': '🇱🇾   Libya',
    'Liechtenstein': '🇱🇮   Liechtenstein',
    'Lithuania': '🇱🇹   Lithuania',
    'Luxembourg': '🇱🇺   Luxembourg',
    'Macedonia': '🇲🇰   Macedonia',
    'Madagascar': '🇲🇬   Madagascar',
    'Malawi': '🇲🇼   Malawi',
    'Malaysia': '🇲🇾   Malaysia',
    'Maldives': '🇲🇻   Maldives',
    'Mali': '🇲🇱   Mali',
    'Malta': '🇲🇹   Malta',
    'Marshall Islands': '🇲🇭   Marshall Islands',
    'Mauritania': '🇲🇷   Mauritania',
    'Mauritius': '🇲🇺   Mauritius',
    'Mexico': '🇲🇽   Mexico',
    'Micronesia': '🇫🇲   Micronesia',
    'Moldova': '🇲🇩   Moldova',
    'Monaco': '🇲🇨   Monaco',
    'Mongolia': '🇲🇳   Mongolia',
    'Montenegro': '🇲🇪   Montenegro',
    'Morocco': '🇲🇦   Morocco',
    'Mozambique': '🇲🇿   Mozambique',
    'Myanmar': '🇲🇲   Myanmar',
    'Namibia': '🇳🇦   Namibia',
    'Nauru': '🇳🇷   Nauru',
    'Nepal': '🇳🇵   Nepal',
    'Netherlands': '🇳🇱   Netherlands',
    'New Zealand': '🇳🇿   New Zealand',
    'Nicaragua': '🇳🇮   Nicaragua',
    'Niger': '🇳🇪   Niger',
    'Nigeria': '🇳🇬   Nigeria',
    'North Korea': '🇰🇵   North Korea',
    'Norway': '🇳🇴   Norway',
    'Oman': '🇴🇲   Oman',
    'Pakistan': '🇵🇰   Pakistan',
    'Palau': '🇵🇼   Palau',
    'Panama': '🇵🇦   Panama',
    'Papua New Guinea': '🇵🇬   Papua New Guinea',
    'Paraguay': '🇵🇾   Paraguay',
    'Peru': '🇵🇪   Peru',
    'Philippines': '🇵🇭   Philippines',
    'Poland': '🇵🇱   Poland',
    'Portugal': '🇵🇹   Portugal',
    'Qatar': '🇶🇦   Qatar',
    'Romania': '🇷🇴   Romania',
    'Russia': '🇷🇺   Russia',
    'Rwanda': '🇷🇼   Rwanda',
    'Samoa': '🇼🇸   Samoa',
    'San Marino': '🇸🇲   San Marino',
    'Saudi Arabia': '🇸🇦   Saudi Arabia',
    'Senegal': '🇸🇳   Senegal',
    'Serbia': '🇷🇸   Serbia',
    'Seychelles': '🇸🇨   Seychelles',
    'Sierra Leone': '🇸🇱   Sierra Leone',
    'Singapore': '🇸🇬   Singapore',
    'Slovakia': '🇸🇰   Slovakia',
    'Slovenia': '🇸🇮   Slovenia',
    'Solomon Islands': '🇸🇧   Solomon Islands',
    'Somalia': '🇸🇴   Somalia',
    'South Africa': '🇿🇦   South Africa',
    'South Korea': '🇰🇷   South Korea',
    'South Sudan': '🇸🇸   South Sudan',
    'Spain': '🇪🇸   Spain',
    'Sri Lanka': '🇱🇰   Sri Lanka',
    'Sudan': '🇸🇩   Sudan',
    'Suriname': '🇸🇷   Suriname',
    'Swaziland': '🇸🇿   Swaziland',
    'Sweden': '🇸🇪   Sweden',
    'Switzerland': '🇨🇭   Switzerland',
    'Syria': '🇸🇾   Syria',
    'Taiwan': '🇹🇼   Taiwan',
    'Tajikistan': '🇹🇯   Tajikistan',
    'Tanzania': '🇹🇿   Tanzania',
    'Thailand': '🇹🇭   Thailand',
    'Togo': '🇹🇬   Togo',
    'Tonga': '🇹🇴   Tonga',
    'Trinidad and Tobago': '🇹🇹   Trinidad and Tobago',
    'Tunisia': '🇹🇳   Tunisia',
    'Turkey': '🇹🇷   Turkey',
    'Turkmenistan': '🇹🇲   Turkmenistan',
    'Tuvalu': '🇹🇻   Tuvalu',
    'Uganda': '🇺🇬   Uganda',
    'Ukraine': '🇺🇦   Ukraine',
    'United Arab Emirates': '🇦🇪   United Arab Emirates',
    'United Kingdom': '🇬🇧   United Kingdom',
    'United States': '🇺🇸   United States',
    'Uruguay': '🇺🇾   Uruguay',
    'Uzbekistan': '🇺🇿   Uzbekistan',
    'Vanuatu': '🇻🇺   Vanuatu',
    'Vatican City': '🇻🇦   Vatican City',
    'Venezuela': '🇻🇪   Venezuela',
    'Vietnam': '🇻🇳   Vietnam',
    'Yemen': '🇾🇪   Yemen',
    'Zambia': '🇿🇲   Zambia',
    'Zimbabwe': '🇿🇼   Zimbabwe',
  };
  return countryToEmoji[countryName] ?? countryName;
}
