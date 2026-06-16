import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../state_manager.dart';
import '../services/user_service.dart';
import '../services/chat_service.dart';
import '../services/event_service.dart';
import '../models/user_profile.dart';
import '../utils/card_renderer.dart';
import '../utils/image_helper.dart';
import '../services/linkedin_oauth_config.dart';
import 'linkedin_webview.dart';
import '../services/resume_parser_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AppStateManager _state = AppStateManager();
  bool _isLoading = false;

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

  void _showResumePromptDialog(BuildContext context, String uid) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFAF7F5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.auto_awesome, color: Color(0xFF7A432D)),
              SizedBox(width: 8),
              Text(
                'Sync Complete!',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3E1F11),
                ),
              ),
            ],
          ),
          content: const Text(
            'Your basic LinkedIn details have been synced.\n\n'
            'Want to add more details? Upload your resume to enrich your profile with career history, skills, and education.',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              color: Color(0xFF5C473E),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Maybe Later',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  color: Color(0xFF8C736B),
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A432D),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context); // close prompt dialog
                _handleResumeUpload(uid); // trigger real resume upload
              },
              child: const Text(
                'Upload Resume',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleResumeUpload(String uid) async {
    try {
      final parser = ResumeParserService();
      final pickedFile = await parser.pickResumeFile();
      if (pickedFile == null || pickedFile.bytes == null) {
        return;
      }

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFFFAF7F5),
          content: Row(
            children: const [
              CircularProgressIndicator(color: Color(0xFF7A432D)),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'AI is parsing your resume...',
                  style: TextStyle(fontFamily: 'PlusJakartaSans'),
                ),
              ),
            ],
          ),
        ),
      );

      final text = parser.extractText(pickedFile.bytes!, pickedFile.name);
      final parsedData = parser.parseResumeText(text);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return _ResumePreviewDialog(
            parsedData: parsedData,
            onSave: (updatedData) async {
              Navigator.pop(context); // close preview dialog
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFFFAF7F5),
                  content: Row(
                    children: const [
                      CircularProgressIndicator(color: Color(0xFF7A432D)),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Saving your parsed profile data...',
                          style: TextStyle(fontFamily: 'PlusJakartaSans'),
                        ),
                      ),
                    ],
                  ),
                ),
              );

              try {
                await parser.saveResumeDataToProfile(uid, updatedData);
                if (mounted) Navigator.pop(context); // close saving dialog
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Resume parsed & profile enriched!'),
                      backgroundColor: Color(0xFF2E7D32),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) Navigator.pop(context); // close saving dialog
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to save parsed profile: $e'),
                      backgroundColor: const Color(0xFFC62828),
                    ),
                  );
                }
              }
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking/parsing resume: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    }
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
        // 1. Cover Photo Banner
        Container(
          height: 140,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFE8E2DD),
            image: coverUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(coverUrl),
                    fit: BoxFit.cover,
                  )
                : null,
            gradient: coverUrl.isEmpty
                ? const LinearGradient(
                    colors: [Color(0xFF7A432D), Color(0xFF3E1F11)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
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
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Color(0xFF7A432D)),
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
                      icon: const Icon(Icons.ios_share_rounded, size: 14, color: Color(0xFF7A432D)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profile link copied to clipboard')),
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
                      icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF7A432D)),
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
          style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: Color(0xFF8C736B)),
        ),
      );
    }

    return _buildSectionCard(
      icon: icon,
      title: title,
      content: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final titleText = type == 'career' ? (item['role'] ?? '') : (item['degree'] ?? '');
          final subtitleText = type == 'career' ? (item['company'] ?? '') : (item['school'] ?? '');
          final duration = item['duration'] ?? '';
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
                      duration,
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
            body: Center(
              child: Text('Profile not found.'),
            ),
          );
        }

        final String name = profile.name.isNotEmpty ? profile.name : 'Sai Gagan';
        final String headline = (profile.headline != null && profile.headline!.isNotEmpty)
            ? profile.headline!
            : 'Java Full Stack Developer';
        final String workingLocation = (profile.currentLocationName != null && profile.currentLocationName!.isNotEmpty)
            ? profile.currentLocationName!
            : 'Bangalore, Karnataka, India';
        final String bio = (profile.bio != null && profile.bio!.isNotEmpty)
            ? profile.bio!
            : 'No bio added yet. Tap Edit to introduce yourself!';
        final String company = (profile.company != null && profile.company!.isNotEmpty) ? profile.company! : 'Company';
        final String role = (profile.role != null && profile.role!.isNotEmpty) ? profile.role! : 'Role';
        final String industry = (profile.industry != null && profile.industry!.isNotEmpty) ? profile.industry! : 'Sector';
        final String experience = (profile.experience != null && profile.experience!.isNotEmpty) ? profile.experience! : 'Experience';

        final String homeBase = (profile.homeBase != null && profile.homeBase!.isNotEmpty) ? profile.homeBase! : 'Home Base';
        final String currentLocation = (profile.currentLocationName != null && profile.currentLocationName!.isNotEmpty) ? profile.currentLocationName! : 'Current Location';
        final String travelFrequency = (profile.travelFrequency != null && profile.travelFrequency!.isNotEmpty) ? profile.travelFrequency! : 'Travel Frequency';

        final List<String> interests = (profile.interests.isNotEmpty) ? profile.interests : ['Tech Startups', 'AI & ML', 'Venture Capital', 'Aviation', 'Travel'];
        final List<String> skills = (profile.skills.isNotEmpty) ? profile.skills : ['Java', 'Spring Boot', 'Flutter', 'Dart', 'Cloud Architecture'];

        final String mainCardBg = (profile.cardImageUrl != null && profile.cardImageUrl!.isNotEmpty)
            ? profile.cardImageUrl!
            : 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=600&q=80';

        return Scaffold(
          backgroundColor: const Color(0xFFFAF7F5),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF7A432D)))
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
                          padding: const EdgeInsets.only(top: 50, left: 20, right: 20),
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
                                  const Icon(Icons.place_outlined, size: 14, color: Color(0xFF7A432D)),
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
                              const SizedBox(height: 8),
                              // Connections stats
                              Text(
                                '${profile.connectionCount} connections · ${profile.followerCount} followers',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7A432D),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Action Sync Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0077B5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      icon: const Icon(Icons.sync, size: 16, color: Colors.white),
                                      label: const Text(
                                        'Sync LinkedIn',
                                        style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      onPressed: () async {
                                        final String redirectUri = LinkedInOAuthConfig.redirectUri;
                                        final String authUrl = LinkedInOAuthConfig.authorizationUrl(
                                          redirectUri: redirectUri,
                                        );

                                        if (kIsWeb) {
                                          final storage = const FlutterSecureStorage();
                                          await storage.write(key: 'linkedin_sync_pending_uid', value: profile.uid);
                                        }

                                        final String? authCode = await showLinkedInWebView(context, authUrl);

                                        if (authCode == null) {
                                          return;
                                        }

                                        if (authCode.startsWith('error:')) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'LinkedIn login failed: ${authCode.replaceFirst('error:', '')}',
                                                ),
                                                backgroundColor: const Color(0xFF7A432D),
                                              ),
                                            );
                                          }
                                          return;
                                        }

                                        setState(() => _isLoading = true);
                                        try {
                                          await UserService().syncLinkedInProfile(profile.uid, authCode, redirectUri: redirectUri);
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('LinkedIn details synced!'), backgroundColor: Color(0xFF2E7D32)),
                                          );
                                          _showResumePromptDialog(context, profile.uid);
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('LinkedIn sync failed: $e'), backgroundColor: Color(0xFFC62828)),
                                          );
                                        } finally {
                                          if (mounted) {
                                            setState(() => _isLoading = false);
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFF7A432D)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF7A432D)),
                                      label: const Text(
                                        'Parse Resume',
                                        style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7A432D)),
                                      ),
                                      onPressed: () => _handleResumeUpload(profile.uid),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

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
                                    final int count = chatSnapshot.hasData ? chatSnapshot.data!.docs.length : profile.connectionsCount;
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
                                  stream: FirebaseFirestore.instance.collection('events').where('attendees', arrayContains: profile.uid).snapshots(),
                                  builder: (context, joinedSnapshot) {
                                    final int count = joinedSnapshot.hasData ? joinedSnapshot.data!.docs.length : profile.eventsJoinedCount;
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
                                  stream: EventService().streamEventsByUser(profile.uid),
                                  builder: (context, hostedSnapshot) {
                                    final int count = hostedSnapshot.hasData ? hostedSnapshot.data!.docs.length : profile.eventsHostedCount;
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
                            content: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: skills.map((s) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAF7F5),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFE8E2DD)),
                                  ),
                                  child: Text(
                                    s,
                                    style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: Color(0xFF3E1F11)),
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
                                _buildProfileFieldColumn('Experience', experience),
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
                                  child: CustomPaint(painter: ConstellationPainter()),
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
                            content: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: interests.map((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFE8E2DD)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_getInterestIcon(tag), size: 14, color: const Color(0xFF7A432D)),
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

                        // Digital Card Deck
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildSectionCard(
                            icon: Icons.qr_code_rounded,
                            title: 'Digital Card Deck',
                            content: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Container(
                                      width: 300,
                                      height: 190,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFFE8E2DD), width: 0.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                        image: DecorationImage(
                                          image: NetworkImage(mainCardBg),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.black.withValues(alpha: 0.15),
                                              Colors.black.withValues(alpha: 0.65),
                                            ],
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text(
                                                  'BOARDINGPAUSE',
                                                  style: TextStyle(
                                                    fontFamily: 'PlusJakartaSans',
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 2.0,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Text(
                                                    'MEMBER',
                                                    style: TextStyle(
                                                      fontFamily: 'PlusJakartaSans',
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        name,
                                                        style: const TextStyle(
                                                          fontFamily: 'PlayfairDisplay',
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        '$role · $company',
                                                        style: const TextStyle(
                                                          fontFamily: 'PlusJakartaSans',
                                                          fontSize: 11,
                                                          color: Colors.white70,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        workingLocation,
                                                        style: const TextStyle(
                                                          fontFamily: 'PlusJakartaSans',
                                                          fontSize: 10,
                                                          color: Colors.white54,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withValues(alpha: 0.9),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  padding: const EdgeInsets.all(4),
                                                  child: const Icon(
                                                    Icons.qr_code_2_rounded,
                                                    size: 36,
                                                    color: Color(0xFF3E1F11),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  ...profile.customCards.map((card) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 16),
                                      child: PremiumCustomCard(card: card),
                                    );
                                  }),
                                ],
                              ),
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
                              border: Border.all(color: const Color(0xFFE8E2DD)),
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
                  border: Border.all(color: const Color(0xFFE8E2DD), width: 0.5),
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
    return Container(
      width: 1,
      height: 24,
      color: const Color(0xFFE8E2DD),
    );
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
    final iconColor = isLogout ? const Color(0xFF8B2500) : const Color(0xFF7A432D);

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
                Icon(Icons.chevron_right_rounded, size: 18, color: isLogout ? const Color(0xFF8B2500) : const Color(0xFF8C736B)),
              ],
            ),
          ),
          if (!isLogout)
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Container(
                height: 0.5,
                color: const Color(0xFFE8E2DD),
              ),
            ),
        ],
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
      points.add(Offset(
        center.dx + radius * 0.7 * cos(angle),
        center.dy + radius * 0.7 * sin(angle),
      ));
    }

    final int innerCount = 4;
    for (int i = 0; i < innerCount; i++) {
      final double angle = (i * 2 * pi) / innerCount + 0.7;
      points.add(Offset(
        center.dx + radius * 0.35 * cos(angle),
        center.dy + radius * 0.35 * sin(angle),
      ));
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
  late final TextEditingController _cardImageUrlController;
  late final TextEditingController _newCardUrlController;
  late final TextEditingController _profileImageUrlController;
  late final TextEditingController _coverImageUrlController;
  late final TextEditingController _connectionCountController;
  late final TextEditingController _followerCountController;

  // New item text controllers for timeline and skills
  final TextEditingController _newRoleController = TextEditingController();
  final TextEditingController _newCompanyController = TextEditingController();
  final TextEditingController _newDurationController = TextEditingController();
  final TextEditingController _newDescController = TextEditingController();

  final TextEditingController _newSchoolController = TextEditingController();
  final TextEditingController _newDegreeController = TextEditingController();
  final TextEditingController _newEduDurationController = TextEditingController();

  final TextEditingController _newSkillController = TextEditingController();

  // Custom Card Editor Fields
  late final TextEditingController _newCardTitleController;
  late final TextEditingController _newCardDescController;
  late final TextEditingController _newCardImageController;
  String _selectedCardTemplate = 'Image Overlay';
  int? _editingCardIndex;

  bool _isLoading = false;
  late List<CustomCard> _localCustomCards;
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
    'Other'
  ];

  final List<String> _travelFrequencies = [
    'Rarely',
    'Occasional',
    'Frequent',
    'Never'
  ];

  final List<Map<String, String>> _cardPresets = [
    {'name': 'Terracotta', 'url': 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=600&q=80'},
    {'name': 'Midnight', 'url': 'https://images.unsplash.com/photo-1618005198143-e5283b519a7f?w=600&q=80'},
    {'name': 'Emerald', 'url': 'https://images.unsplash.com/photo-1634017839464-5c339ebe3cb4?w=600&q=80'},
    {'name': 'Golden', 'url': 'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=600&q=80'},
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
    _selectedIndustry = _industries.contains(initialIndustry) ? initialIndustry : 'Other';
    _industryController = TextEditingController(text: widget.profile.industry ?? '');

    final initialTravel = widget.profile.travelFrequency ?? 'Occasional';
    _selectedTravelFrequency = _travelFrequencies.contains(initialTravel) ? initialTravel : 'Occasional';

    _parseHomeBase(widget.profile.homeBase);
    _parseCurrentLocation(widget.profile.currentLocationName);

    _experienceController = TextEditingController(text: widget.profile.experience ?? '');
    _cardImageUrlController = TextEditingController(text: widget.profile.cardImageUrl ?? '');
    _newCardUrlController = TextEditingController();
    _profileImageUrlController = TextEditingController(text: widget.profile.profileImageUrl ?? '');
    _coverImageUrlController = TextEditingController(text: widget.profile.coverImageUrl ?? '');
    _connectionCountController = TextEditingController(text: widget.profile.connectionCount.toString());
    _followerCountController = TextEditingController(text: widget.profile.followerCount.toString());

    _newCardTitleController = TextEditingController();
    _newCardDescController = TextEditingController();
    _newCardImageController = TextEditingController();

    _localCustomCards = List<CustomCard>.from(widget.profile.customCards);
    _localCareerTimeline = List<Map<String, dynamic>>.from(widget.profile.careerTimeline);
    _localEducationTimeline = List<Map<String, dynamic>>.from(widget.profile.educationTimeline);
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
      _homeBaseCountry = country.contains('   ') ? country.split('   ').last : country;
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
      _currentLocationCountry = country.contains('   ') ? country.split('   ').last : country;
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
    _cardImageUrlController.dispose();
    _newCardUrlController.dispose();
    _profileImageUrlController.dispose();
    _coverImageUrlController.dispose();
    _connectionCountController.dispose();
    _followerCountController.dispose();

    _newRoleController.dispose();
    _newCompanyController.dispose();
    _newDurationController.dispose();
    _newDescController.dispose();

    _newSchoolController.dispose();
    _newDegreeController.dispose();
    _newEduDurationController.dispose();

    _newSkillController.dispose();

    _newCardTitleController.dispose();
    _newCardDescController.dispose();
    _newCardImageController.dispose();
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
        cardImageUrl: _cardImageUrlController.text.trim(),
        profileImageUrl: _profileImageUrlController.text.trim(),
        customCards: _localCustomCards,
        coverImageUrl: _coverImageUrlController.text.trim(),
        connectionCount: int.tryParse(_connectionCountController.text) ?? widget.profile.connectionCount,
        followerCount: int.tryParse(_followerCountController.text) ?? widget.profile.followerCount,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
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
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7A432D)),
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
                    // Profile Image Editor
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Profile Image',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8C736B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE8E2DD),
                            border: Border.all(color: const Color(0xFF7A432D), width: 1.5),
                          ),
                          child: ClipOval(
                            child: _profileImageUrlController.text.isNotEmpty
                                ? Image.network(
                                    _profileImageUrlController.text,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.person, size: 32, color: Color(0xFF7A432D)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final ImagePicker picker = ImagePicker();
                              final XFile? pickedFile = await picker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 70,
                              );
                              if (pickedFile == null) return;
                              setState(() => _isLoading = true);
                              final bytes = await pickedFile.readAsBytes();
                              final storageRef = FirebaseStorage.instance
                                  .ref()
                                  .child('profile_images')
                                  .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
                              final uploadTask = storageRef.putData(
                                bytes,
                                SettableMetadata(contentType: 'image/jpeg'),
                              );
                              final snapshot = await uploadTask;
                              final downloadUrl = await snapshot.ref.getDownloadURL();
                              setState(() {
                                _profileImageUrlController.text = downloadUrl;
                                _isLoading = false;
                              });
                            } catch (e) {
                              setState(() => _isLoading = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to upload image: $e')),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7A432D),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.white),
                          label: const Text(
                            'Upload Photo',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildTextField('Profile Photo URL', _profileImageUrlController),
                    _buildTextField('Cover Photo URL', _coverImageUrlController),
                    const SizedBox(height: 12),
                    _buildTextField('Name', _nameController),
                    _buildTextField('Headline', _headlineController),
                    _buildTextField('Bio / Description', _bioController, maxLines: 3),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Company', _companyController)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('Role', _roleController)),
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
                                ? _buildTextField('Custom Industry', _industryController)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('Experience', _experienceController)),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('LinkedIn Connections Count', _connectionCountController)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('LinkedIn Followers Count', _followerCountController)),
                      ],
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
                        border: Border.all(color: const Color(0xFFE8E2DD), width: 1.5),
                      ),
                      disabledDropdownDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFFFAF7F5),
                        border: Border.all(color: const Color(0xFFE8E2DD), width: 1.5),
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
                        border: Border.all(color: const Color(0xFFE8E2DD), width: 1.5),
                      ),
                      disabledDropdownDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFFFAF7F5),
                        border: Border.all(color: const Color(0xFFE8E2DD), width: 1.5),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE8E2DD))),
                        child: ListTile(
                          title: Text('${item['role']} at ${item['company']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF3E1F11))),
                          subtitle: Text('${item['duration']}\n${item['description']}', style: const TextStyle(fontSize: 11, color: Color(0xFF8C736B))),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
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
                          const Text('Add Work Experience', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF3E1F11))),
                          const SizedBox(height: 8),
                          _buildTextField('Role / Job Title', _newRoleController),
                          _buildTextField('Company', _newCompanyController),
                          _buildTextField('Duration (e.g. Jan 2023 - Present)', _newDurationController),
                          _buildTextField('Description', _newDescController, maxLines: 2),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A432D)),
                              onPressed: () {
                                if (_newRoleController.text.trim().isEmpty || _newCompanyController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill Role and Company')));
                                  return;
                                }
                                setState(() {
                                  _localCareerTimeline.add({
                                    'role': _newRoleController.text.trim(),
                                    'company': _newCompanyController.text.trim(),
                                    'duration': _newDurationController.text.trim(),
                                    'description': _newDescController.text.trim(),
                                  });
                                  _newRoleController.clear();
                                  _newCompanyController.clear();
                                  _newDurationController.clear();
                                  _newDescController.clear();
                                });
                              },
                              child: const Text('Add Experience', style: TextStyle(fontFamily: 'PlusJakartaSans', color: Colors.white, fontWeight: FontWeight.bold)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE8E2DD))),
                        child: ListTile(
                          title: Text('${item['degree']} at ${item['school']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF3E1F11))),
                          subtitle: Text('${item['duration']}', style: const TextStyle(fontSize: 11, color: Color(0xFF8C736B))),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
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
                          const Text('Add Education', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF3E1F11))),
                          const SizedBox(height: 8),
                          _buildTextField('Degree / Course', _newDegreeController),
                          _buildTextField('School / University', _newSchoolController),
                          _buildTextField('Duration (e.g. 2013 - 2017)', _newEduDurationController),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A432D)),
                              onPressed: () {
                                if (_newDegreeController.text.trim().isEmpty || _newSchoolController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill Degree and School')));
                                  return;
                                }
                                setState(() {
                                  _localEducationTimeline.add({
                                    'degree': _newDegreeController.text.trim(),
                                    'school': _newSchoolController.text.trim(),
                                    'duration': _newEduDurationController.text.trim(),
                                  });
                                  _newDegreeController.clear();
                                  _newSchoolController.clear();
                                  _newEduDurationController.clear();
                                });
                              },
                              child: const Text('Add Education', style: TextStyle(fontFamily: 'PlusJakartaSans', color: Colors.white, fontWeight: FontWeight.bold)),
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
                      children: _localSkills.map((s) => Chip(
                        backgroundColor: Colors.white,
                        label: Text(s, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: Color(0xFF3E1F11))),
                        onDeleted: () {
                          setState(() {
                            _localSkills.remove(s);
                          });
                        },
                      )).toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Add Skill', _newSkillController)),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A432D)),
                            onPressed: () {
                              final text = _newSkillController.text.trim();
                              if (text.isNotEmpty && !_localSkills.contains(text)) {
                                setState(() {
                                  _localSkills.add(text);
                                });
                                _newSkillController.clear();
                              }
                            },
                            child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        )
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFE8E2DD), thickness: 1),
                    const SizedBox(height: 12),

                    // Card deck Customizer
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Customize My Share Cards',
                        style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildTextField('Main Card Background Image URL', _cardImageUrlController),
                    
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Choose background preset:',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8C736B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 36,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _cardPresets.length,
                        itemBuilder: (context, idx) {
                          final preset = _cardPresets[idx];
                          final isSelected = _cardImageUrlController.text == preset['url'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              label: Text(
                                preset['name']!,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : const Color(0xFF7A432D),
                                ),
                              ),
                              backgroundColor: isSelected ? const Color(0xFF7A432D) : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected ? const Color(0xFF7A432D) : const Color(0xFFE8E2DD),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _cardImageUrlController.text = preset['url']!;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Additional Deck Cards',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (_localCustomCards.isNotEmpty)
                      Column(
                        children: List.generate(_localCustomCards.length, (idx) {
                          final card = _localCustomCards[idx];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE8E2DD)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 80,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    image: card.imageUrl.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(card.imageUrl),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                    color: const Color(0xFFE8E2DD),
                                  ),
                                  child: card.imageUrl.isEmpty
                                      ? const Icon(Icons.image_outlined, size: 20, color: Color(0xFF8C736B))
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        card.title.isNotEmpty ? card.title : 'No Title',
                                        style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF3E1F11),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Layout: ${card.template}',
                                        style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 10,
                                          color: Color(0xFF8C736B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, color: Color(0xFF7A432D), size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _editingCardIndex = idx;
                                      _newCardTitleController.text = card.title;
                                      _newCardDescController.text = card.description;
                                      _newCardImageController.text = card.imageUrl;
                                      _selectedCardTemplate = card.template;
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _localCustomCards.removeAt(idx);
                                      if (_editingCardIndex == idx) {
                                        _editingCardIndex = null;
                                        _newCardTitleController.clear();
                                        _newCardDescController.clear();
                                        _newCardImageController.clear();
                                      } else if (_editingCardIndex != null && _editingCardIndex! > idx) {
                                        _editingCardIndex = _editingCardIndex! - 1;
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE8E2DD)),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'No additional cards in deck. Add one below!',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            color: Color(0xFF8C736B),
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFE8E2DD), thickness: 1),
                    const SizedBox(height: 12),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _editingCardIndex == null ? 'Create New Deck Card' : 'Edit Deck Card',
                        style: const TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildTextField('Card Title', _newCardTitleController, onChanged: (v) => setState(() {})),
                    _buildTextField('Card Description', _newCardDescController, maxLines: 3, onChanged: (v) => setState(() {})),
                    _buildTextField('Card Image URL', _newCardImageController, onChanged: (v) => setState(() {})),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Choose background image preset:',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8C736B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildPresetChip('Lounge', 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=600&q=80'),
                          _buildPresetChip('Coffee', 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=600&q=80'),
                          _buildPresetChip('Airport', 'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=600&q=80'),
                          _buildPresetChip('Office', 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=600&q=80'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Layout Template',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8C736B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE8E2DD)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCardTemplate,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF7A432D)),
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                color: Color(0xFF3E1F11),
                              ),
                              items: ['50-50 Split', 'Image Overlay', 'Top Image / Bottom Text'].map((String val) {
                                return DropdownMenuItem<String>(
                                  value: val,
                                  child: Text(val),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedCardTemplate = val);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Live Card Preview',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: PremiumCustomCard(
                        card: CustomCard(
                          title: _newCardTitleController.text.trim().isNotEmpty 
                              ? _newCardTitleController.text.trim() 
                              : 'Card Title Preview',
                          description: _newCardDescController.text.trim().isNotEmpty 
                              ? _newCardDescController.text.trim() 
                              : 'Enter a card description above to preview.',
                          imageUrl: _newCardImageController.text.trim().isNotEmpty 
                              ? _newCardImageController.text.trim() 
                              : 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=600&q=80',
                          template: _selectedCardTemplate,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_editingCardIndex != null) ...[
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF7A432D),
                              side: const BorderSide(color: Color(0xFFE8E2DD)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: () {
                              setState(() {
                                _editingCardIndex = null;
                                _newCardTitleController.clear();
                                _newCardDescController.clear();
                                _newCardImageController.clear();
                                _selectedCardTemplate = 'Image Overlay';
                              });
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 10),
                        ],
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7A432D),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onPressed: () {
                            final title = _newCardTitleController.text.trim();
                            final desc = _newCardDescController.text.trim();
                            final imgUrl = _newCardImageController.text.trim();
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a card title')),
                              );
                              return;
                            }
                            final card = CustomCard(
                              title: title,
                              description: desc,
                              imageUrl: imgUrl,
                              template: _selectedCardTemplate,
                            );
                            setState(() {
                              if (_editingCardIndex == null) {
                                _localCustomCards.add(card);
                              } else {
                                _localCustomCards[_editingCardIndex!] = card;
                                _editingCardIndex = null;
                              }
                              _newCardTitleController.clear();
                              _newCardDescController.clear();
                              _newCardImageController.clear();
                              _selectedCardTemplate = 'Image Overlay';
                            });
                          },
                          child: Text(
                            _editingCardIndex == null ? 'Add to Deck' : 'Update Card',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, String url) {
    final isSelected = _newCardImageController.text == url;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        label: Text(
          label,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : const Color(0xFF7A432D),
          ),
        ),
        backgroundColor: isSelected ? const Color(0xFF7A432D) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? const Color(0xFF7A432D) : const Color(0xFFE8E2DD),
          ),
        ),
        onPressed: () {
          setState(() {
            _newCardImageController.text = url;
          });
        },
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, ValueChanged<String>? onChanged}) {
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
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              color: Color(0xFF3E1F11),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8E2DD)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentValue,
                isExpanded: true,
                dropdownColor: Colors.white,
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF7A432D)),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  color: Color(0xFF3E1F11),
                ),
                items: items.map((String val) {
                  return DropdownMenuItem<String>(
                    value: val,
                    child: Text(val),
                  );
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

  const _ResumePreviewDialog({
    required this.parsedData,
    required this.onSave,
  });

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
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _educationTimeline = (widget.parsedData['educationTimeline'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
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

  Widget _buildField(String label, String value, Function(String) onChanged, {int maxLines = 1}) {
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
                            style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: Color(0xFF3E1F11)),
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
                            style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Add a skill...',
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          child: const Text('Add', style: TextStyle(fontFamily: 'PlusJakartaSans', color: Colors.white, fontSize: 12)),
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
                                  icon: const Icon(Icons.delete, color: Color(0xFFC62828), size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _careerTimeline.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                            _buildField('Job Title / Role', item['role'] ?? '', (val) {
                              item['role'] = val;
                            }),
                            _buildField('Company', item['company'] ?? '', (val) {
                              item['company'] = val;
                            }),
                            _buildField('Duration', item['duration'] ?? '', (val) {
                              item['duration'] = val;
                            }),
                            _buildField('Description', item['description'] ?? '', (val) {
                              item['description'] = val;
                            }, maxLines: 2),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16, color: Color(0xFF7A432D)),
                      label: const Text('Add Work Experience', style: TextStyle(fontFamily: 'PlusJakartaSans', color: Color(0xFF7A432D), fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          _careerTimeline.add({
                            'role': '',
                            'company': '',
                            'duration': '',
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
                                  icon: const Icon(Icons.delete, color: Color(0xFFC62828), size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _educationTimeline.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                            _buildField('Degree / Certificate', item['degree'] ?? '', (val) {
                              item['degree'] = val;
                            }),
                            _buildField('School / Institution', item['school'] ?? '', (val) {
                              item['school'] = val;
                            }),
                            _buildField('Duration', item['duration'] ?? '', (val) {
                              item['duration'] = val;
                            }),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16, color: Color(0xFF7A432D)),
                      label: const Text('Add Education', style: TextStyle(fontFamily: 'PlusJakartaSans', color: Color(0xFF7A432D), fontSize: 12)),
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
                            style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: Color(0xFF3E1F11)),
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
                            style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Add an interest...',
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          child: const Text('Add', style: TextStyle(fontFamily: 'PlusJakartaSans', color: Colors.white, fontSize: 12)),
                        ),
                      ],
                    ),

                    // --- Professional Interests ---
                    _buildSectionHeader('Professional Interests', Icons.handshake),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _professionalInterests.map((interest) {
                        return Chip(
                          label: Text(
                            interest,
                            style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: Color(0xFF3E1F11)),
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
                            style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Add a professional interest...',
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onPressed: () {
                            final text = _profInterestInputController.text.trim();
                            if (text.isNotEmpty && !_professionalInterests.contains(text)) {
                              setState(() {
                                _professionalInterests.add(text);
                                _profInterestInputController.clear();
                              });
                            }
                          },
                          child: const Text('Add', style: TextStyle(fontFamily: 'PlusJakartaSans', color: Colors.white, fontSize: 12)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
