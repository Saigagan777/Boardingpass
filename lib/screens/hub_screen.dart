import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../state_manager.dart';
import '../utils/image_helper.dart';
import '../services/sponsor_service.dart';
import '../services/meeting_service.dart';
import '../services/user_service.dart';
import '../models/user_profile.dart';
import '../models/checkin.dart';
import '../utils/app_logo.dart';
import '../services/location_service.dart';
import '../utils/google_search_helper.dart';

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
  int _hoverSequence = 0;
  int _tickerIndex = 0;
  Timer? _tickerTimer;
  int _carouselItemCount = 2;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _notificationsBadgeStream;

  Stream<QuerySnapshot<Map<String, dynamic>>>? get _badgeStream {
    if (_notificationsBadgeStream == null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        _notificationsBadgeStream = FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: uid)
            .where('isRead', isEqualTo: false)
            .snapshots();
      }
    }
    return _notificationsBadgeStream;
  }

  void _updateHoveredIndex(int? index) {
    if (_hoveredIndex != index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _hoveredIndex != index) {
          setState(() {
            _hoveredIndex = index;
            _hoverSequence++;
          });
        }
      });
    }
  }

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
    {
      'screen': AppScreen.events,
      'label': 'Events',
      'icon': Icons.confirmation_number_outlined,
      'hint': 'What\'s on',
      'color': const Color(0xFFEFF0EA),
      'textColor': const Color(0xFF4A5D4E),
    },
    {
      'screen': AppScreen.checkin,
      'label': 'Check-In',
      'icon': Icons.location_on_outlined,
      'hint': 'Where you are',
      'color': const Color(0xFFFDF0DD),
      'textColor': const Color(0xFF7A432D),
    },
  ];

  @override
  void initState() {
    super.initState();
    _state.addListener(_onStateChanged);
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 3500), (timer) {
      if (mounted && _carouselItemCount > 0) {
        setState(() {
          _tickerIndex = (_tickerIndex + 1) % _carouselItemCount;
        });
      }
    });
    // Trigger dynamic location detection on startup/load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoDetectAndUpdateLocation();
    });
  }

  Future<void> _autoDetectAndUpdateLocation() async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) return;

      // 1. Fetch current position from Geolocator
      final position = await LocationService().getCurrentPosition();
      final geoPoint = GeoPoint(position.latitude, position.longitude);
      final geohash = LocationService().generateGeohash(position.latitude, position.longitude);

      // 2. Perform reverse geocoding via Google Maps API
      final addressData = await reverseGeocodeAddress(position.latitude, position.longitude);
      if (addressData != null) {
        final city = addressData['city'] ?? '';
        final state = addressData['state'] ?? '';
        final country = addressData['country'] ?? '';
        if (city.isNotEmpty) {
          final detectedLocName = [city, state, country].where((e) => e.isNotEmpty).join(', ');

          // Only update if it has changed to save Firestore writes
          final savedLoc = _state.profileData?['location'];
          if (savedLoc != detectedLocName) {
            await FirebaseFirestore.instance.collection('users').doc(currentUid).update({
              'location': geoPoint,
              'geohash': geohash,
              'currentLocationName': detectedLocName,
              'lastSeen': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error auto-detecting location in Hub: $e');
    }
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    _tickerTimer?.cancel();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon';
    } else if (hour >= 17 && hour < 22) {
      return 'Good evening';
    } else {
      return 'Good night';
    }
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showNotificationSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return const SizedBox();
        return StreamBuilder<UserProfile?>(
          stream: UserService().streamUserProfile(uid),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const AlertDialog(
                backgroundColor: Color(0xFFFAF7F5),
                content: SizedBox(height: 50, child: Center(child: CircularProgressIndicator(color: Color(0xFF7A432D)))),
              );
            }
            final profile = snapshot.data!;
            final settings = profile.notificationSettings;
            final muteAll = settings['muteAll'] as bool? ?? false;
            final muteReminders = settings['muteReminders'] as bool? ?? false;
            final muteMentions = settings['muteMentions'] as bool? ?? false;
            final muteMeetings = settings['muteMeetings'] as bool? ?? false;

            return AlertDialog(
              backgroundColor: const Color(0xFFFAF7F5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Notification Preferences',
                style: TextStyle(fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold, color: Color(0xFF3E1F11)),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Mute All Notifications', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.bold)),
                    value: muteAll,
                    activeThumbColor: const Color(0xFF7A432D),
                    onChanged: (val) {
                      final updated = Map<String, dynamic>.from(settings);
                      updated['muteAll'] = val;
                      UserService().updateUserProfile(userId: uid, notificationSettings: updated);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Mute Reminders', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13)),
                    value: muteReminders,
                    activeThumbColor: const Color(0xFF7A432D),
                    onChanged: muteAll ? null : (val) {
                      final updated = Map<String, dynamic>.from(settings);
                      updated['muteReminders'] = val;
                      UserService().updateUserProfile(userId: uid, notificationSettings: updated);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Mute Mentions', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13)),
                    value: muteMentions,
                    activeThumbColor: const Color(0xFF7A432D),
                    onChanged: muteAll ? null : (val) {
                      final updated = Map<String, dynamic>.from(settings);
                      updated['muteMentions'] = val;
                      UserService().updateUserProfile(userId: uid, notificationSettings: updated);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Mute Meetings', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13)),
                    value: muteMeetings,
                    activeThumbColor: const Color(0xFF7A432D),
                    onChanged: muteAll ? null : (val) {
                      final updated = Map<String, dynamic>.from(settings);
                      updated['muteMeetings'] = val;
                      UserService().updateUserProfile(userId: uid, notificationSettings: updated);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done', style: TextStyle(fontFamily: 'PlusJakartaSans', color: Color(0xFF7A432D), fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNotificationsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xFFFAF7F5),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
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
                        'Notifications',
                        style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.done_all, color: Color(0xFF7A432D), size: 20),
                            tooltip: 'Mark all as read',
                            onPressed: () async {
                              if (uid == null) return;
                              final snap = await FirebaseFirestore.instance
                                  .collection('notifications')
                                  .where('userId', isEqualTo: uid)
                                  .where('isRead', isEqualTo: false)
                                  .get();
                              final batch = FirebaseFirestore.instance.batch();
                              for (final doc in snap.docs) {
                                batch.update(doc.reference, {'isRead': true});
                              }
                              await batch.commit();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, color: Color(0xFF7A432D), size: 20),
                            onPressed: () => _showNotificationSettingsDialog(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFE8E2DD)),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('notifications')
                          .where('userId', isEqualTo: uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'Error loading notifications:\n${snapshot.error}',
                                style: const TextStyle(color: Color(0xFFC62828), fontSize: 12, fontFamily: 'PlusJakartaSans'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Color(0xFF7A432D)));
                        }
                        final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.data?.docs ?? []);
                        docs.sort((a, b) {
                          final aTime = a.data()['timestamp'] as Timestamp?;
                          final bTime = b.data()['timestamp'] as Timestamp?;
                          if (aTime == null && bTime == null) return 0;
                          if (aTime == null) return 1; // Null/missing timestamps at the end
                          if (bTime == null) return -1;
                          return bTime.compareTo(aTime);
                        });
                        if (docs.isEmpty) {
                          return const Center(
                            child: Text(
                              'No notifications yet.',
                              style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: Color(0xFF8C736B)),
                            ),
                          );
                        }
                        return ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: docs.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE8E2DD)),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data();
                            final isRead = data['isRead'] as bool? ?? false;
                            final title = data['title'] as String? ?? 'Alert';
                            final body = data['body'] as String? ?? '';
                            final type = (data['type'] as String? ?? '').toLowerCase();
                            final Timestamp? timestamp = data['timestamp'] as Timestamp?;
                            
                            IconData iconData = Icons.notifications_outlined;
                            Color iconColor = const Color(0xFF7A432D);
                            if (type.contains('meeting')) {
                              iconData = Icons.event;
                              iconColor = const Color(0xFFEF6C00);
                            } else if (type.contains('group') || type.contains('chat')) {
                              iconData = Icons.chat_bubble_outline_rounded;
                              iconColor = const Color(0xFF1E3A5F);
                            }

                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: iconColor.withValues(alpha: 0.1),
                                ),
                                child: Icon(iconData, color: iconColor, size: 20),
                              ),
                              title: Text(
                                title,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                  color: const Color(0xFF3E1F11),
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    body,
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 12,
                                      color: isRead ? const Color(0xFF8C736B) : const Color(0xFF3E1F11),
                                    ),
                                  ),
                                  if (timestamp != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _timeAgo(timestamp.toDate()),
                                      style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, color: Color(0xFF8C736B)),
                                    ),
                                  ]
                                ],
                              ),
                              trailing: !isRead
                                  ? Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFFB06F4D),
                                      ),
                                    )
                                  : null,
                              onTap: () async {
                                await doc.reference.update({'isRead': true});
                                
                                if (context.mounted) Navigator.pop(context);
                                
                                if (type.contains('meeting')) {
                                  _state.currentScreen = AppScreen.meeting;
                                } else if (type.contains('group') || type.contains('chat')) {
                                  final chatId = data['metadata']?['chatId'] as String?;
                                  if (chatId != null) {
                                    final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
                                    if (chatDoc.exists) {
                                      final chatData = chatDoc.data()!;
                                      if (chatData['isGroup'] == true) {
                                        _state.activeChatContact = chatData['groupName'] as String?;
                                      } else {
                                        final participants = List<String>.from(chatData['participants'] ?? []);
                                        final otherUid = participants.firstWhere((p) => p != uid, orElse: () => '');
                                        if (otherUid.isNotEmpty) {
                                          final user = await UserService().getUserProfile(otherUid);
                                          _state.activeChatContact = user?.name;
                                        }
                                      }
                                      _state.currentScreen = AppScreen.chat;
                                    }
                                  }
                                }
                              },
                            );
                          },
                        );
                      },
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

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDiscoverable = _state.currentUserProfile?.isDiscoverable ?? true;

    final Map<String, dynamic>? focusedActivity =
        _hoveredIndex != null ? _activities[_hoveredIndex!] : null;

    final String fullName = _state.profileData?['name'] ?? 'User';
    final String userName = fullName.trim().split(' ').first;

    final activeCheckinId = _state.currentUserProfile?.currentCheckin;
    Checkin? activeCheckin;
    if (activeCheckinId != null) {
      for (final c in _state.checkins) {
        if (c.id == activeCheckinId) {
          activeCheckin = c;
          break;
        }
      }
    }

    String locationText = 'Not checked in';
    if (activeCheckin != null) {
      locationText = '${activeCheckin.location} · ${activeCheckin.name}';
    } else if (_state.profileData?['location']?.isNotEmpty == true) {
      locationText = _state.profileData!['location']!;
    }

    final nearbyCount = _state.candidates.length;
    final liveContextText = nearbyCount > 0 
        ? '$locationText · $nearbyCount nearby'
        : locationText;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF8F4),
            Color(0xFFFAF7F5),
            Color(0xFFEFE8E3),
          ],
          stops: [0.0, 0.5, 1.0],
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
                        const AppLogo(size: 22),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7A432D).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ACTIVITY HUB',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.5,
                              color: Color(0xFF7A432D),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_getGreeting()}, $userName',
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
                  Row(
                    children: [
                      // Discovery Switch
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (screenWidth >= 380) ...[
                            Text(
                              isDiscoverable ? 'Discovery ON' : 'Discovery OFF',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDiscoverable ? const Color(0xFF7A432D) : const Color(0xFF8C736B),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: isDiscoverable,
                              activeThumbColor: const Color(0xFF7A432D),
                              activeTrackColor: const Color(0xFF7A432D).withValues(alpha: 0.2),
                              inactiveThumbColor: const Color(0xFF8C736B),
                              inactiveTrackColor: const Color(0xFFE8E2DD),
                              onChanged: (value) async {
                                final uid = FirebaseAuth.instance.currentUser?.uid;
                                if (uid != null) {
                                  await UserService().updateUserProfile(
                                    userId: uid,
                                    isDiscoverable: value,
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      // Streamed Notifications Bell Icon with badge
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _badgeStream,
                        builder: (context, snapshot) {
                          final unreadCount = snapshot.data?.docs.length ?? 0;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.notifications_none_outlined, color: Color(0xFF7A432D), size: 22),
                                onPressed: () => _showNotificationsBottomSheet(context),
                              ),
                              if (unreadCount > 0)
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFC62828)),
                                    constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$unreadCount',
                                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: () {
                          _state.currentScreen = AppScreen.profile;
                        },
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFFE8D6),
                                Color(0xFFE8D5C4),
                              ],
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              )
                            ],
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                          child: ClipOval(
                            child: buildProfileImage(
                              _state.profileData?['picture'] ?? '',
                              width: 46,
                              height: 46,
                              fit: BoxFit.cover,
                              fallback: Center(
                                child: Text(
                                  userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'U',
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
                        ),
                      ),

                    ],
                  ),
                ],
              ),
            ),

            // Hexagon Stage
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double scale = (constraints.maxHeight < 340 || constraints.maxWidth < 320)
                      ? (constraints.maxHeight / 340 < constraints.maxWidth / 320
                          ? constraints.maxHeight / 340
                          : constraints.maxWidth / 320).clamp(0.6, 1.0)
                      : 1.0;

                  final double stageWidth = 320 * scale;
                  final double stageHeight = 340 * scale;
                  final double R = 106.0 * scale;

                  final List<Offset> positions = [
                    Offset(0, -R),
                    Offset(R * 0.866, -R * 0.5),
                    Offset(R * 0.866, R * 0.5),
                    Offset(0, R),
                    Offset(-R * 0.866, R * 0.5),
                    Offset(-R * 0.866, -R * 0.5),
                  ];

                  return Center(
                    child: SizedBox(
                      width: stageWidth,
                      height: stageHeight,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 280 * scale,
                            height: 280 * scale,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF7A432D).withValues(alpha: 0.08),
                                  const Color(0xFF7A432D).withValues(alpha: 0.02),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),

                          SizedBox(
                            width: 110 * scale,
                            height: 110 * scale,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: focusedActivity != null
                                  ? Column(
                                      key: ValueKey('hub_center_$_hoverSequence'),
                                      mainAxisAlignment: MainAxisAlignment.center,
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
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 10 * scale,
                                            color: const Color(0xFF8C736B),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      key: ValueKey('hub_center_$_hoverSequence'),
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 60 * scale,
                                          height: 60 * scale,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFF7A432D),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF7A432D).withValues(alpha: 0.22),
                                                blurRadius: 10 * scale,
                                                offset: Offset(0, 4 * scale),
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
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 10 * scale,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 2.5 * scale,
                                            color: const Color(0xFF7A432D),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          ...List.generate(6, (index) {
                            final act = _activities[index];
                            final pos = positions[index];
                            final isFocused = _hoveredIndex == index;
                            final isAnyFocused = _hoveredIndex != null;

                            return Positioned(
                              left: (stageWidth / 2) + pos.dx - (36 * scale),
                              top: (stageHeight / 2) + pos.dy - (40 * scale),
                              child: GestureDetector(
                                onPanDown: (_) => _updateHoveredIndex(index),
                                onPanCancel: () => _updateHoveredIndex(null),
                                onPanEnd: (_) => _updateHoveredIndex(null),
                                onTapDown: (_) => _updateHoveredIndex(index),
                                onTapUp: (_) => _updateHoveredIndex(null),
                                onTap: () {
                                  _state.currentScreen = act['screen'];
                                },
                                child: MouseRegion(
                                  onEnter: (_) => _updateHoveredIndex(index),
                                  onExit: (_) => _updateHoveredIndex(null),
                                  child: AnimatedScale(
                                    duration: const Duration(milliseconds: 200),
                                    scale: isFocused
                                        ? 1.15
                                        : (isAnyFocused ? 0.88 : 1.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (pos.dy < 0) ...[
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
                                          SizedBox(height: 4 * scale),
                                        ],
                                        Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Container(
                                              width: 58 * scale,
                                              height: 58 * scale,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(0xFF7A432D).withValues(alpha: isFocused ? 0.14 : 0.06),
                                                    blurRadius: isFocused ? 12 * scale : 6 * scale,
                                                    offset: Offset(0, isFocused ? 4 * scale : 2 * scale),
                                                  )
                                                ],
                                              ),
                                            ),
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
                                          ],
                                        ),
                                        if (pos.dy >= 0) ...[
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
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: _buildAdNotifCarousel(),
            ),

            SizedBox(height: screenHeight < 650 ? 4 : 10),

            // Location Strip
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: screenHeight < 650 ? screenHeight * 0.006 : screenHeight * 0.015,
              ),
              child: GestureDetector(
                onTap: () {
                  _state.currentScreen = AppScreen.checkin;
                },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.white, Color(0xFFFFF8F2)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFEDD8C4), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x10000000),
                        blurRadius: 12,
                        offset: Offset(0, 3),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFFFDF1E6), Color(0xFFFFE4CC)],
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.location_on,
                                color: Color(0xFF7A432D),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'LIVE CONTEXT',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF8C736B),
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  Text(
                                    liveContextText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF3E1F11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7A432D).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Update',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7A432D),
                          ),
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
    );
  }

  Widget _buildAdNotifCarousel() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: MeetingService().streamUserMeetings(),
      builder: (context, meetingSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: SponsorService().streamSponsors(),
          builder: (context, sponsorSnapshot) {
            final currentUid = FirebaseAuth.instance.currentUser?.uid;
            final List<Map<String, dynamic>> carouselItems = [];

            if (meetingSnapshot.hasData) {
              for (final doc in meetingSnapshot.data!.docs) {
                final data = doc.data();
                final status = data['status'] as String? ?? 'pending';
                final requesterId = data['requesterId'] as String? ?? '';
                final receiverId = data['receiverId'] as String? ?? '';
                final location = data['location'] as String? ?? 'Venue';
                final scheduledTimestamp = data['scheduledAt'] as Timestamp?;
                final scheduledAt = scheduledTimestamp?.toDate();

                if (status == 'confirmed') {
                  if (scheduledAt != null && scheduledAt.isAfter(DateTime.now())) {
                    final otherUserId = currentUid == receiverId ? requesterId : receiverId;
                    carouselItems.add({
                      'kind': 'meeting',
                      'meetingId': doc.id,
                      'otherUserId': otherUserId,
                      'title': 'Upcoming Meeting',
                      'body': 'At $location on ${_formatDateTime(scheduledAt)}',
                      'icon': Icons.calendar_month_outlined,
                      'scheduledAt': scheduledAt,
                    });
                  }
                } else if (status == 'pending' && receiverId == currentUid) {
                  carouselItems.add({
                    'kind': 'notif',
                    'meetingId': doc.id,
                    'otherUserId': requesterId,
                    'title': 'Meeting Request',
                    'body': 'Wants to meet at $location',
                    'icon': Icons.chat_bubble_outline_rounded,
                    'scheduledAt': scheduledAt,
                  });
                }
              }
            }

            carouselItems.sort((a, b) {
              final aTime = a['scheduledAt'] as DateTime?;
              final bTime = b['scheduledAt'] as DateTime?;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return aTime.compareTo(bTime);
            });

            if (sponsorSnapshot.hasData) {
              for (final doc in sponsorSnapshot.data!.docs) {
                final data = doc.data();
                final brand = data['brand'] ?? 'Sponsor';
                final title = data['title'] ?? '';
                final cta = data['cta'] ?? 'Learn';
                final url = data['url'] ?? '';
                final iconName = data['icon'] ?? 'star';

                IconData iconData = Icons.star_outline_rounded;
                if (iconName == 'coffee') iconData = Icons.coffee;
                if (iconName == 'flight') iconData = Icons.flight_outlined;
                if (iconName == 'percent') iconData = Icons.percent;
                if (iconName == 'business') iconData = Icons.business_outlined;

                carouselItems.add({
                  'kind': 'ad',
                  'brand': brand,
                  'title': title,
                  'cta': cta,
                  'url': url,
                  'icon': iconData,
                });
              }
            }

            if (carouselItems.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _carouselItemCount != 0) {
                  setState(() {
                    _carouselItemCount = 0;
                  });
                }
              });
              return const SizedBox.shrink();
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _carouselItemCount != carouselItems.length) {
                setState(() {
                  _carouselItemCount = carouselItems.length;
                });
              }
            });

            final index = _tickerIndex >= carouselItems.length ? 0 : _tickerIndex;
            final item = carouselItems[index];
            final isAd = item['kind'] == 'ad';
            final IconData icon = item['icon'] ?? Icons.notifications;

            if (!isAd) {
              final String otherUserId = item['otherUserId'] ?? '';
              return FutureBuilder<UserProfile?>(
                future: UserService().getUserProfile(otherUserId),
                builder: (context, profileSnapshot) {
                  final name = profileSnapshot.data?.name ?? 'Someone';
                  final titleText = item['kind'] == 'meeting'
                      ? 'Meeting with $name'
                      : 'Meeting request from $name';

                  return _buildCarouselCard(
                    keyVal: 'carousel_slot_$index',
                    tagText: item['kind'] == 'meeting' ? 'UPCOMING MEETING' : 'NOTIFICATION',
                    titleText: titleText,
                    bodyText: item['body'],
                    icon: icon,
                    isAd: false,
                    ctaText: 'View',
                    onCtaPressed: () {
                      _state.meetingInitialTab = 1;
                      _state.currentScreen = AppScreen.meeting;
                    },
                    dotsCount: carouselItems.length,
                    activeIndex: index,
                  );
                },
              );
            } else {
              return _buildCarouselCard(
                keyVal: 'carousel_slot_$index',
                tagText: 'SPONSORED · ${item['brand']}'.toUpperCase(),
                titleText: item['title'],
                bodyText: null,
                icon: icon,
                isAd: true,
                ctaText: item['cta'],
                onCtaPressed: () {
                  final url = item['url'] as String? ?? '';
                  if (url.isNotEmpty) {
                    _launchURL(url);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Details for ${item['brand']}')),
                    );
                  }
                },
                dotsCount: carouselItems.length,
                activeIndex: index,
              );
            }
          },
        );
      },
    );
  }

  Widget _buildCarouselCard({
    required String keyVal,
    required String tagText,
    required String titleText,
    required String? bodyText,
    required IconData icon,
    required bool isAd,
    required String ctaText,
    required VoidCallback onCtaPressed,
    required int dotsCount,
    required int activeIndex,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(keyVal),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFFFF8F2)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEDD8C4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7A432D).withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
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

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tagText,
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
                        titleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                      if (bodyText != null)
                        Text(
                          bodyText,
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

                Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7A432D),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextButton(
                    onPressed: onCtaPressed,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      ctaText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(dotsCount, (i) {
                final isActive = i == activeIndex;
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

  String _formatDateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hourStr = dt.hour.toString().padLeft(2, '0');
    final minStr = dt.minute.toString().padLeft(2, '0');
    return "${dt.day} ${months[dt.month - 1]} at $hourStr:$minStr";
  }

  void _launchURL(String urlString) async {
    if (urlString.isEmpty) return;
    final uri = Uri.tryParse(urlString);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
