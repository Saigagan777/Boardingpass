import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';
import 'services/event_service.dart';
import 'services/checkin_service.dart';
import 'services/chat_service.dart';
import 'models/candidate.dart';
import 'models/checkin.dart';
import 'models/event.dart';
import 'models/message.dart';
import 'models/user_profile.dart'; // Added import for CustomCard
import 'utils/match_calculator.dart';
import 'utils/google_search_helper.dart';

enum AppScreen { hub, profile, checkin, events, discover, chat, meeting }

enum ConnectionRequestResult { sent, accepted, alreadyPending, failed }

class AdminLog {
  final String id;
  final String title;
  final String details;
  final String timeAgo;
  final String reporter;
  bool isResolved;

  AdminLog({
    required this.id,
    required this.title,
    required this.details,
    required this.timeAgo,
    required this.reporter,
    this.isResolved = false,
  });
}

class AppStateManager extends ChangeNotifier {
  static final AppStateManager _instance = AppStateManager._internal();
  factory AppStateManager() => _instance;
  AppStateManager._internal();

  /// Debug flag: Set to true to always force the onboarding screen on app launch for testing.
  /// Set to false to allow Firebase Auth to persist sessions across launches.
  static const bool forceOnboardingOnLaunch = false;

  // Stream Subscriptions for real-time Firebase syncing
  StreamSubscription? _eventsSubscription;
  StreamSubscription? _checkinsSubscription;
  StreamSubscription? _profileSubscription;
  Timer? _presenceTimer;

  void _cancelSubscriptions() {
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _checkinsSubscription?.cancel();
    _checkinsSubscription = null;
    _profileSubscription?.cancel();
    _profileSubscription = null;
    _presenceTimer?.cancel();
    _presenceTimer = null;
  }

  // Navigation and View Modes
  AppScreen _currentScreen = AppScreen.hub;
  bool _isAdminView = false;
  String? _activeChatContact;
  Offset? _lastTappedSegmentCenter;
  List<String>? _activityOrder;

  AppScreen get currentScreen => _currentScreen;
  bool get isAdminView => _isAdminView;
  String? get activeChatContact => _activeChatContact;
  Offset? get lastTappedSegmentCenter => _lastTappedSegmentCenter;
  List<String>? get activityOrder => _activityOrder;

  set currentScreen(AppScreen screen) {
    _currentScreen = screen;
    notifyListeners();
  }

  set isAdminView(bool value) {
    _isAdminView = value;
    notifyListeners();
  }

  set activeChatContact(String? val) {
    _activeChatContact = val;
    notifyListeners();
  }

  set lastTappedSegmentCenter(Offset? val) {
    _lastTappedSegmentCenter = val;
  }

  set activityOrder(List<String>? val) {
    _activityOrder = val;
  }

  int _meetingInitialTab = 0;
  int get meetingInitialTab => _meetingInitialTab;
  set meetingInitialTab(int val) {
    _meetingInitialTab = val;
    notifyListeners();
  }

  // Authentication State
  bool _isInitialized = false;
  bool _isLoggedIn = false;
  bool _isAuthCallbackInProgress = false;
  bool isRegistering = false;
  Map<String, String>? _profileData;
  UserProfile? _currentUserProfile;

  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _isLoggedIn;
  bool get isAuthCallbackInProgress => _isAuthCallbackInProgress;
  Map<String, String>? get profileData => _profileData;
  UserProfile? get currentUserProfile => _currentUserProfile;

  bool get isProfileLoading => _isLoggedIn && _currentUserProfile == null;

  bool get isProfileComplete {
    if (_currentUserProfile == null) return false;
    final p = _currentUserProfile!;
    final hasSkills = p.skills.isNotEmpty || p.expertise.isNotEmpty;
    final hasInterests = p.interests.isNotEmpty || p.intents.isNotEmpty;
    final hasRole = p.role != null && p.role!.trim().isNotEmpty;
    final hasCompany = p.company != null && p.company!.trim().isNotEmpty;
    final hasBio = p.bio != null && p.bio!.trim().isNotEmpty;
    final hasExperience =
        p.experience != null && p.experience!.trim().isNotEmpty;

    return hasRole &&
        hasCompany &&
        hasBio &&
        hasExperience &&
        hasSkills &&
        hasInterests;
  }

  void beginAuthCallback() {
    _isAuthCallbackInProgress = true;
    notifyListeners();
  }

  void endAuthCallback() {
    if (!_isAuthCallbackInProgress) return;
    _isAuthCallbackInProgress = false;
    notifyListeners();
  }

  void logIn(Map<String, String> data, {bool isAdmin = false}) {
    _isLoggedIn = true;
    _isAuthCallbackInProgress = false;
    _profileData = data;
    _currentScreen = AppScreen.hub;
    _isAdminView = isAdmin;
    notifyListeners();
  }

  void logOut() async {
    try {
      await AuthService().signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
    // Immediately clear state locally to ensure responsive UI updates.
    _isLoggedIn = false;
    _isAuthCallbackInProgress = false;
    _profileData = null;
    _isAdminView = false;
    _activeChatContact = null;
    _selectedCheckinType = CheckinType.event;
    _initializeData();
    notifyListeners();
  }

  // Active check-in tab selection
  CheckinType _selectedCheckinType = CheckinType.event;
  CheckinType get selectedCheckinType => _selectedCheckinType;
  set selectedCheckinType(CheckinType val) {
    _selectedCheckinType = val;
    notifyListeners();
  }

  // Check-ins list
  final List<Checkin> _checkins = [];
  List<Checkin> get checkins => List.unmodifiable(_checkins);

  void addCheckin(Checkin checkin) async {
    try {
      await CheckinService().createCheckin(
        checkin: checkin,
        location: const GeoPoint(12.9716, 77.5946),
        geohash: 'tdr1w',
      );
    } catch (e) {
      debugPrint('Error creating check-in: $e');
    }
  }

  // Events list
  final List<Event> _events = [];
  List<Event> get events => _events;

  void toggleJoinEvent(String id) async {
    try {
      await EventService().toggleJoinEvent(id);
    } catch (e) {
      debugPrint('Error toggling event join: $e');
    }
  }

  void createEvent(Event newEvent) async {
    try {
      await EventService().createEvent(
        title: newEvent.title,
        location: newEvent.location,
        time: newEvent.time,
        month: newEvent.month,
        day: newEvent.day,
        illustrationPath: newEvent.illustrationPath,
        category: newEvent.category,
        price: newEvent.price,
        mapUrl: newEvent.mapUrl,
        latitude: newEvent.latitude,
        longitude: newEvent.longitude,
        imageUrl: newEvent.imageUrl,
      );
    } catch (e) {
      debugPrint('Error creating event: $e');
    }
  }

  // Candidates list (Discover card stack)
  final List<Candidate> _candidates = [];
  List<Candidate> get candidates => _candidates;

  int _activeCandidateIndex = 0;
  int get activeCandidateIndex => _activeCandidateIndex;

  void nextCandidate() {
    if (_candidates.isNotEmpty) {
      _activeCandidateIndex = (_activeCandidateIndex + 1) % _candidates.length;
      notifyListeners();
    }
  }

  // Chat messages list
  final List<Message> _messages = [];
  List<Message> get messages => _messages;

  void addMessage(Message msg) {
    _messages.add(msg);
    notifyListeners();
  }

  void answerPoll(String messageId, int optionIndex) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1 && _messages[index].kind == MessageKind.poll) {
      _messages[index].picked = optionIndex;
      notifyListeners();
    }
  }

  // Admin Logs
  final List<AdminLog> _adminLogs = [];
  List<AdminLog> get adminLogs => _adminLogs;

  void resolveLog(String id) {
    final index = _adminLogs.indexWhere((log) => log.id == id);
    if (index != -1) {
      _adminLogs[index].isResolved = true;
      notifyListeners();
    }
  }

  void banUser(String id) {
    final index = _adminLogs.indexWhere((log) => log.id == id);
    if (index != -1) {
      _adminLogs.removeAt(index);
      notifyListeners();
    }
  }

  // Initialization
  void init() {
    _initializeData();

    if (forceOnboardingOnLaunch) {
      try {
        AuthService().signOut();
      } catch (e) {
        debugPrint('Error signing out on launch: $e');
      }
    }

    // Listen to Firebase Authentication state changes
    AuthService().authStateChanges.listen((User? user) async {
      if (isRegistering) {
        return;
      }
      if (user != null) {
        await syncSignedInUser(user);
      } else if (!_isAuthCallbackInProgress) {
        _clearSignedOutState();
        _isInitialized = true;
        notifyListeners();
      }
    });
  }

  Future<void> syncSignedInUser(User user) async {
    _cancelSubscriptions();

    _isLoggedIn = true;
    _isAuthCallbackInProgress = false;
    _currentScreen = AppScreen.hub;
    notifyListeners();

    // Start presence heartbeat
    try {
      UserService().touchLastSeen(user.uid);
    } catch (e) {
      debugPrint('Error touching lastSeen on sync: $e');
    }
    _presenceTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      try {
        UserService().touchLastSeen(user.uid);
      } catch (e) {
        debugPrint('Error touching lastSeen heartbeat: $e');
      }
    });

    try {
      final isAdminUser = await AuthService().isAdmin().timeout(
        const Duration(seconds: 4),
      );
      _isAdminView = isAdminUser;
    } catch (e) {
      _isAdminView =
          user.email?.toLowerCase() == 'gagan123@gmail.com'; // Dev fallback
    }

    _profileSubscription = UserService().streamCurrentUserProfile().listen((
      profile,
    ) async {
      if (profile != null) {
        final oldLoc = _currentUserProfile?.location;
        final oldCity = _currentUserProfile?.currentLocationName;

        _currentUserProfile = profile;
        _profileData = {
          'sub': user.uid,
          'name': profile.name.isNotEmpty
              ? profile.name
              : (user.displayName ?? user.email?.split('@')[0] ?? 'User'),
          // Display the real email stored in Firestore instead of the synthetic Firebase Auth email
          'email':
              (profile.email.isNotEmpty &&
                  !profile.email.startsWith('linkedin_'))
              ? profile.email
              : (user.email ?? ''),
          'location': profile.currentLocationName ?? profile.homeBase ?? '',
          'picture': profile.profileImageUrl ?? user.photoURL ?? '',
        };
        _isInitialized = true;
        notifyListeners();

        // Reload candidates to calculate correct distances if location gets initialized or changes
        if (oldLoc != profile.location || oldCity != profile.currentLocationName) {
          loadCandidates();
        }
      } else {
        // Avoid auto-creating a profile for synthetic LinkedIn users.
        // The LinkedIn login flow explicitly creates it with the real email.
        final isSynthetic =
            user.email != null &&
            user.email!.startsWith('linkedin_') &&
            user.email!.endsWith('@boardingpass.com');
        if (!isSynthetic) {
          try {
            await AuthService().ensureUserProfile();
          } catch (e) {
            debugPrint('Failed to auto-create user profile on login: $e');
          }
        }
        _isInitialized = true;
        notifyListeners();
      }
    });

    // Fallback initially if profile stream is slow
    final isSynthetic =
        user.email != null &&
        user.email!.startsWith('linkedin_') &&
        user.email!.endsWith('@boardingpass.com');
    _profileData = {
      'sub': user.uid,
      'name': user.displayName ?? user.email?.split('@')[0] ?? 'User',
      'email': isSynthetic ? '' : (user.email ?? ''),
      'location': '',
      'picture': user.photoURL ?? '',
    };

    // Subscribe to events stream
    _eventsSubscription = EventService().streamAllEvents().listen((snapshot) {
      _events.clear();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final attendeesList = List<String>.from(data['attendees'] ?? []);
        _events.add(
          Event(
            id: doc.id,
            illustrationPath:
                data['illustrationPath']?.toString().isNotEmpty == true
                ? data['illustrationPath']
                : 'assets/images/boarding_pass_illustration_6.png',
            month: data['month'] ?? 'JUN',
            day: data['day'] ?? '01',
            title: data['title'] ?? '',
            location: data['location'] ?? '',
            time: data['time'] ?? '',
            attendees: '${attendeesList.length} interested',
            attendeeIds: attendeesList,
            category: data['category'] ?? 'Meetups',
            price: data['price'] ?? 'Free',
            mapUrl: data['mapUrl'],
            latitude: (data['latitude'] as num?)?.toDouble(),
            longitude: (data['longitude'] as num?)?.toDouble(),
            imageUrl: data['imageUrl'],
            isJoined: attendeesList.contains(user.uid),
          ),
        );
      }
      notifyListeners();
    });

    // Subscribe to checkins stream
    _checkinsSubscription = CheckinService().streamUserCheckins().listen((
      snapshot,
    ) {
      _checkins.clear();
      final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
        snapshot.docs,
      );
      docs.sort((a, b) {
        final aTime = a.data()['createdAt'] as Timestamp?;
        final bTime = b.data()['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return -1;
        if (bTime == null) return 1;
        return bTime.compareTo(aTime);
      });
      for (final doc in docs) {
        final data = doc.data();
        _checkins.add(
          Checkin(
            id: doc.id,
            type: CheckinType.values.firstWhere(
              (t) => t.name == data['type'],
              orElse: () => CheckinType.event,
            ),
            name: data['name'] ?? '',
            location: data['location'] ?? '',
            link: data['link'],
            checkinDate: data['checkinDate'] ?? '',
            checkinTime: data['checkinTime'] ?? '',
            checkoutDate: data['checkoutDate'] ?? '',
            checkoutTime: data['checkoutTime'] ?? '',
          ),
        );
      }
      notifyListeners();
    });

    // Load candidates cards from Firestore discover list
    await loadCandidates();
  }

  void _clearSignedOutState() {
    _cancelSubscriptions();
    _isInitialized = false;
    _isLoggedIn = false;
    _isAuthCallbackInProgress = false;
    _profileData = null;
    _currentUserProfile = null;
    _isAdminView = false;
    _activeChatContact = null;
    _selectedCheckinType = CheckinType.event;
    _initializeData();
  }

  Future<void> loadCandidates() async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      debugPrint('[DEBUG loadCandidates] called. currentUid: $currentUid');
      if (currentUid == null) {
        debugPrint('[DEBUG loadCandidates] currentUid is null. Returning.');
        return;
      }

      // 1. Fetch current user's swipes to partition them
      final swipesSnapshot = await FirebaseFirestore.instance
          .collection('swipes')
          .where('fromUid', isEqualTo: currentUid)
          .get();

      // Fetch connection requests involving the current user
      final outgoingReqs = await FirebaseFirestore.instance
          .collection('connection_requests')
          .where('fromUid', isEqualTo: currentUid)
          .get();
      final incomingReqs = await FirebaseFirestore.instance
          .collection('connection_requests')
          .where('toUid', isEqualTo: currentUid)
          .get();

      final pendingReqUids = <String>{};
      final rejectedReqUids = <String>{};

      for (final doc in outgoingReqs.docs) {
        final data = doc.data();
        final toUid = data['toUid'] as String?;
        final status = data['status'] as String?;
        if (toUid == null) continue;
        if (status == 'pending') {
          pendingReqUids.add(toUid);
        } else if (status == 'rejected') {
          rejectedReqUids.add(toUid);
        }
      }

      for (final doc in incomingReqs.docs) {
        final data = doc.data();
        final fromUid = data['fromUid'] as String?;
        final status = data['status'] as String?;
        if (fromUid == null) continue;
        if (status == 'pending') {
          pendingReqUids.add(fromUid);
        } else if (status == 'rejected') {
          rejectedReqUids.add(fromUid);
        }
      }

      final permanentlyExcludedUids = <String>{};
      final temporaryExcludedUids = <String>{};
      final dislikeTimes = <String, DateTime>{};

      final now = DateTime.now();

      for (final doc in swipesSnapshot.docs) {
        final data = doc.data();
        final action = data['action'] as String?;
        final toUid = data['toUid'] as String?;
        if (toUid == null) continue;

        if (action == 'like') {
          if (!rejectedReqUids.contains(toUid)) {
            permanentlyExcludedUids.add(toUid);
          }
        } else if (action == 'dislike' || action == 'reject') {
          // Check if swipe is within 30 days
          final timestampField = data['timestamp'] ?? data['createdAt'];
          DateTime? swipeTime;
          if (timestampField is Timestamp) {
            swipeTime = timestampField.toDate();
          } else if (timestampField is String) {
            swipeTime = DateTime.tryParse(timestampField);
          }

          if (swipeTime != null) {
            final difference = now.difference(swipeTime).inDays;
            if (difference < 30) {
              temporaryExcludedUids.add(toUid);
              final existingTime = dislikeTimes[toUid];
              if (existingTime == null || swipeTime.isAfter(existingTime)) {
                dislikeTimes[toUid] = swipeTime;
              }
            }
          } else {
            // Default to excluding if timestamp is missing
            temporaryExcludedUids.add(toUid);
            dislikeTimes[toUid] = DateTime.fromMillisecondsSinceEpoch(0);
          }
        }
      }

      // Fetch connected user IDs
      final connSnap1 = await FirebaseFirestore.instance
          .collection('connections')
          .where('userA', isEqualTo: currentUid)
          .get();
      final connSnap2 = await FirebaseFirestore.instance
          .collection('connections')
          .where('userB', isEqualTo: currentUid)
          .get();
      final connectedUids = {
        ...connSnap1.docs.map((doc) => doc.data()['userB'] as String),
        ...connSnap2.docs.map((doc) => doc.data()['userA'] as String),
      };

      debugPrint('[DEBUG loadCandidates] swipes=${swipesSnapshot.docs.length}, conn=${connectedUids.length}, outgoing=${outgoingReqs.docs.length}, incoming=${incomingReqs.docs.length}');

      // 2. Query users collection
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .limit(100)
          .get();
      debugPrint('[DEBUG loadCandidates] users collection fetched count: ${querySnapshot.docs.length}');

      // 2.5 Fetch current user details to calculate dynamic match scores
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      final currentUserData = currentUserDoc.data() ?? {};
      final currentUserSkills = List<String>.from(
        currentUserData['skills'] ?? [],
      );
      final currentUserInterests = List<String>.from(
        currentUserData['interests'] ?? [],
      );
      final currentUserExpertise = List<String>.from(
        currentUserData['expertise'] ?? [],
      );
      final currentUserIntents = List<String>.from(
        currentUserData['intents'] ?? [],
      );
      final currentExpertiseMapList =
          (currentUserData['expertiseWithLevel'] as List?)
              ?.map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          [];
      final currentInterestsMapList =
          (currentUserData['interestsWithPriority'] as List?)
              ?.map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          [];
      final currentRole = currentUserData['role'] ?? '';

      final List<Candidate> allProfiles = [];
      final docsToProcess = querySnapshot.docs.where(
        (doc) {
          final data = doc.data();
          final isDiscoverable = data['isDiscoverable'] ?? true;
          final pass = doc.id != currentUid &&
              isDiscoverable &&
              !permanentlyExcludedUids.contains(doc.id) &&
              !pendingReqUids.contains(doc.id) &&
              !connectedUids.contains(doc.id);
          debugPrint('[DEBUG loadCandidates] User doc: ${doc.id}, name: ${data['name']}, isDiscoverable: $isDiscoverable, pass: $pass');
          return pass;
        },
      ).toList();
      debugPrint('[DEBUG loadCandidates] docsToProcess count: ${docsToProcess.length}');

      // Resolve current user's location once before the loop to avoid redundant geocoding queries
      GeoPoint? currentUserGeo = _currentUserProfile?.location;
      if (currentUserGeo == null) {
        final String userCity = (_currentUserProfile?.currentLocationName ?? _currentUserProfile?.homeBase ?? '').toString();
        if (userCity.isNotEmpty) {
          currentUserGeo = _getOfflineCoordinatesForCity(userCity);
          if (currentUserGeo == null) {
            try {
              final geocodeResults = await searchGoogleGeocoding(userCity).timeout(const Duration(seconds: 2));
              if (geocodeResults.isNotEmpty) {
                currentUserGeo = GeoPoint(
                  geocodeResults.first['lat'] as double,
                  geocodeResults.first['lon'] as double,
                );
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUid)
                    .update({'location': currentUserGeo}).catchError((_) => null);
              }
            } catch (_) {}
          }
        }
      }

      for (final doc in docsToProcess) {
        final data = doc.data();
        final expertise = List<String>.from(data['expertise'] ?? []);
        final intents = List<String>.from(data['intents'] ?? []);
        final interests = List<String>.from(data['interests'] ?? []);
        final skills = List<String>.from(data['skills'] ?? []);
        final customCardsData = data['customCards'] as List? ?? [];
        final customCards = customCardsData
            .map(
              (item) => CustomCard.fromMap(Map<String, dynamic>.from(item)),
            )
            .toList();
        final careerTimeline =
            (data['careerTimeline'] as List?)
                ?.map((item) => Map<String, dynamic>.from(item))
                .toList() ??
            [];
        final educationTimeline =
            (data['educationTimeline'] as List?)
                ?.map((item) => Map<String, dynamic>.from(item))
                .toList() ??
            [];

        final targetExpertiseMapList =
            (data['expertiseWithLevel'] as List?)
                ?.map((item) => Map<String, dynamic>.from(item))
                .toList() ??
            [];
        final targetInterestsMapList =
            (data['interestsWithPriority'] as List?)
                ?.map((item) => Map<String, dynamic>.from(item))
                .toList() ??
            [];
        final targetBadges = List<String>.from(data['badges'] ?? []);

        int sumEndorsements = 0;
        for (final exp in targetExpertiseMapList) {
          sumEndorsements += (exp['endorsements'] ?? 0) as int;
        }
        final targetSessions = data['completedMentoringSessions'] ?? 0;
        final targetCollaborations = data['successfulCollaborations'] ?? 0;

        final detailedMatch = calculateDetailedMatch(
          currentUid: currentUid,
          targetUid: doc.id,
          currentRole: currentRole,
          targetRole: data['role'] ?? '',
          currentExpertise: currentExpertiseMapList,
          currentInterests: currentInterestsMapList,
          targetExpertise: targetExpertiseMapList,
          targetInterests: targetInterestsMapList,
          currentSkills: [...currentUserSkills, ...currentUserExpertise],
          currentInterestsList: [
            ...currentUserInterests,
            ...currentUserIntents,
          ],
          targetSkills: [...skills, ...expertise],
          targetInterestsList: [...interests, ...intents],
          targetBadges: targetBadges,
          targetEndorsements: sumEndorsements,
          targetSessions: targetSessions,
        );

        double? distanceKm;
        GeoPoint? candidateGeo = data['location'] as GeoPoint?;
        if (candidateGeo == null) {
          final String candCity = (data['currentLocationName'] ?? data['homeBase'] ?? '').toString();
          if (candCity.isNotEmpty) {
            candidateGeo = _getOfflineCoordinatesForCity(candCity);
            if (candidateGeo == null) {
              try {
                final geocodeResults = await searchGoogleGeocoding(candCity).timeout(const Duration(milliseconds: 500));
                if (geocodeResults.isNotEmpty) {
                  candidateGeo = GeoPoint(
                    geocodeResults.first['lat'] as double,
                    geocodeResults.first['lon'] as double,
                  );
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(doc.id)
                      .update({'location': candidateGeo}).catchError((_) => null);
                }
              } catch (_) {}
            }
          }
        }

        if (candidateGeo != null && currentUserGeo != null) {
          try {
            final double distanceMeters = Geolocator.distanceBetween(
              currentUserGeo.latitude,
              currentUserGeo.longitude,
              candidateGeo.latitude,
              candidateGeo.longitude,
            );
            distanceKm = distanceMeters / 1000;
          } catch (_) {
            // Fail silently
          }
        }

        allProfiles.add(Candidate(
          uid: doc.id,
          name: data['name'] ?? '',
          headline: data['headline'] ?? '',
          role: data['role'] ?? '',
          org: data['company'] ?? '',
          loc: data['currentLocationName'] ?? data['homeBase'] ?? '',
          match: detailedMatch.score,
          intent: intents.isNotEmpty ? intents.join(', ') : '',
          tags: expertise,
          interests: interests,
          skills: skills,
          homeBase: data['homeBase'] ?? '',
          currentLocationName: data['currentLocationName'] ?? '',
          industry: data['industry'] ?? '',
          experience: data['experience'] ?? '',
          careerTimeline: careerTimeline,
          educationTimeline: educationTimeline,
          bio: data['bio'] ?? '',
          initials: (data['name'] as String?)?.isNotEmpty == true
              ? data['name']
                    .trim()
                    .split(' ')
                    .map((e) => e[0])
                    .take(2)
                    .join()
                    .toUpperCase()
              : 'P',
          profileImageUrl: data['profileImageUrl'],
          primaryColor: const Color(0xFFE5A475),
          customCards: customCards,
          expertiseWithLevel: targetExpertiseMapList,
          interestsWithPriority: targetInterestsMapList,
          matchReasons: detailedMatch.reasons,
          conversationStarters: detailedMatch.conversationStarters,
          badges: targetBadges,
          completedMentoringSessions: targetSessions,
          successfulCollaborations: targetCollaborations,
          distanceKm: distanceKm,
        ));
      }

      _candidates.clear();

      // Partition into non-disliked and disliked/rejected candidates
      final nonDisliked = <Candidate>[];
      final disliked = <Candidate>[];

      for (final candidate in allProfiles) {
        if (temporaryExcludedUids.contains(candidate.uid)) {
          disliked.add(candidate);
        } else {
          nonDisliked.add(candidate);
        }
      }

      // Sort non-disliked candidates by match score descending so high matches are shown first
      nonDisliked.sort((a, b) => b.match.compareTo(a.match));

      // Sort disliked candidates chronologically by swipe time (older dislikes first, newer dislikes last)
      disliked.sort((a, b) {
        final timeA =
            dislikeTimes[a.uid] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timeB =
            dislikeTimes[b.uid] ?? DateTime.fromMillisecondsSinceEpoch(0);
        return timeA.compareTo(timeB);
      });

      _candidates.addAll([...nonDisliked, ...disliked]);
      _activeCandidateIndex = 0;
      debugPrint('[DEBUG loadCandidates] finished. Final _candidates length: ${_candidates.length}');
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading candidates: $e');
    }
  }

  GeoPoint? _getOfflineCoordinatesForCity(String city) {
    if (city.isEmpty) return null;
    final Map<String, GeoPoint> cityCoords = {
      'vijayawada': const GeoPoint(16.5063, 80.6480),
      'hyderabad': const GeoPoint(17.3850, 78.4867),
      'bangalore': const GeoPoint(12.9716, 77.5946),
      'bengaluru': const GeoPoint(12.9716, 77.5946),
      'hanuman junction': const GeoPoint(16.6433, 80.8427),
      'delhi': const GeoPoint(28.6139, 77.2090),
      'mumbai': const GeoPoint(19.0760, 72.8777),
    };
    final lower = city.toLowerCase();
    for (final entry in cityCoords.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Instantly moves a candidate to the back of the local list in memory
  void moveCandidateToBack(String targetUid) {
    final index = _candidates.indexWhere((c) => c.uid == targetUid);
    if (index != -1) {
      final candidate = _candidates.removeAt(index);
      _candidates.add(candidate);
      notifyListeners();
    }
  }

  /// Instantly removes a candidate from the local list in memory (e.g. once liked/favorited)
  void removeCandidate(String targetUid) {
    final index = _candidates.indexWhere((c) => c.uid == targetUid);
    if (index != -1) {
      _candidates.removeAt(index);
      notifyListeners();
    }
  }

  /// Record a swipe gesture (like, reject, or favorite) in Firestore.
  /// If the swiped action is 'like' or 'favorite', check if the target candidate
  /// has also liked/favorited the current user. Returns true if it results in
  /// a mutual connection, false otherwise.
  Future<void> swipeCandidate({
    required String targetUid,
    required String action,
  }) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    try {
      final now = FieldValue.serverTimestamp();
      final docId = '${currentUid}_$targetUid';
      await FirebaseFirestore.instance.collection('swipes').doc(docId).set({
        'fromUid': currentUid,
        'toUid': targetUid,
        'action': action,
        'createdAt': now,
        'timestamp': now,
      });
    } catch (e) {
      debugPrint('Error swiping candidate: $e');
    }
  }

  Future<ConnectionRequestResult> sendOrAcceptConnection({
    required String targetUid,
  }) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return ConnectionRequestResult.failed;

    try {
      final now = FieldValue.serverTimestamp();

      // 1. Check if a pending connection request exists from targetUid to currentUid
      final incomingReqRef = FirebaseFirestore.instance
          .collection('connection_requests')
          .doc('${targetUid}_$currentUid');
      final incomingReqDoc = await incomingReqRef.get();

      if (incomingReqDoc.exists &&
          incomingReqDoc.data()?['status'] == 'pending') {
        // Acceptance flow!
        final batch = FirebaseFirestore.instance.batch();

        // Update connection request
        batch.update(incomingReqRef, {
          'status': 'accepted',
          'updatedAt': now,
          'respondedAt': now,
        });

        // Create connection document userA < userB
        final userA = currentUid.compareTo(targetUid) < 0
            ? currentUid
            : targetUid;
        final userB = currentUid.compareTo(targetUid) < 0
            ? targetUid
            : currentUid;
        final connectionRef = FirebaseFirestore.instance
            .collection('connections')
            .doc('${userA}_$userB');

        batch.set(connectionRef, {
          'connectionId': '${userA}_$userB',
          'userA': userA,
          'userB': userB,
          'connectedAt': now,
        });

        // Update connection count for both users
        final user1Ref = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid);
        final user2Ref = FirebaseFirestore.instance
            .collection('users')
            .doc(targetUid);
        batch.update(user1Ref, {'connectionCount': FieldValue.increment(1)});
        batch.update(user2Ref, {'connectionCount': FieldValue.increment(1)});

        await batch.commit();

        try {
          await ChatService().getOrCreateChat(
            userId1: currentUid,
            userId2: targetUid,
          );
        } catch (e) {
          debugPrint('Connection accepted, but chat creation failed: $e');
        }

        // Notify proposer of acceptance
        final currentUserName = _currentUserProfile?.name ?? 'Someone';
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': targetUid,
          'title': '🤝 Connection Request Accepted',
          'body': '$currentUserName accepted your connection request.',
          'type': 'connection_accept',
          'isRead': false,
          'metadata': {'acceptedBy': currentUid},
          'timestamp': now,
        });

        return ConnectionRequestResult.accepted; // Mutual connection accepted
      } else {
        // New request flow!
        final outgoingReqRef = FirebaseFirestore.instance
            .collection('connection_requests')
            .doc('${currentUid}_$targetUid');
        final outgoingReqDoc = await outgoingReqRef.get();
        final outgoingStatus = outgoingReqDoc.data()?['status'] as String?;

        if (!outgoingReqDoc.exists || outgoingStatus == 'rejected') {
          await outgoingReqRef.set({
            'requestId': '${currentUid}_$targetUid',
            'fromUid': currentUid,
            'toUid': targetUid,
            'status': 'pending',
            'createdAt': now,
            'updatedAt': now,
          });

          // Add notification to recipient
          final currentUserName = _currentUserProfile?.name ?? 'Someone';
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': targetUid,
            'title': '🤝 New Connection Request',
            'body': '$currentUserName wants to connect with you.',
            'type': 'connection_request',
            'isRead': false,
            'metadata': {
              'fromUid': currentUid,
              'requestId': '${currentUid}_$targetUid',
            },
            'timestamp': now,
          });

          return ConnectionRequestResult.sent;
        }

        if (outgoingStatus == 'accepted') {
          return ConnectionRequestResult.accepted;
        }

        return ConnectionRequestResult.alreadyPending;
      }
    } catch (e) {
      debugPrint('Error sending/accepting connection: $e');
      return ConnectionRequestResult.failed;
    }
  }

  void _initializeData() {
    _checkins.clear();
    _events.clear();
    _candidates.clear();
    _messages.clear();
    _adminLogs.clear();
    _activeCandidateIndex = 0;
  }
}
