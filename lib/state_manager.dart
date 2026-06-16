import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';
import 'services/event_service.dart';
import 'services/checkin_service.dart';
import 'models/candidate.dart';
import 'models/checkin.dart';
import 'models/event.dart';
import 'models/message.dart';
import 'models/user_profile.dart'; // Added import for CustomCard

enum AppScreen { hub, profile, checkin, events, discover, chat, meeting }

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

  void _cancelSubscriptions() {
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _checkinsSubscription?.cancel();
    _checkinsSubscription = null;
    _profileSubscription?.cancel();
    _profileSubscription = null;
  }

  // Navigation and View Modes
  AppScreen _currentScreen = AppScreen.hub;
  bool _isAdminView = false;
  String? _activeChatContact;

  AppScreen get currentScreen => _currentScreen;
  bool get isAdminView => _isAdminView;
  String? get activeChatContact => _activeChatContact;

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

  // Authentication State
  bool _isLoggedIn = false;
  bool _isAuthCallbackInProgress = false;
  Map<String, String>? _profileData;
  UserProfile? _currentUserProfile;

  bool get isLoggedIn => _isLoggedIn;
  bool get isAuthCallbackInProgress => _isAuthCallbackInProgress;
  Map<String, String>? get profileData => _profileData;
  UserProfile? get currentUserProfile => _currentUserProfile;

  bool get isProfileComplete {
    if (_currentUserProfile == null) return true; // Default to true to prevent screen flickering during load
    final p = _currentUserProfile!;
    return p.role != null && p.role!.trim().isNotEmpty &&
           p.company != null && p.company!.trim().isNotEmpty &&
           p.bio != null && p.bio!.trim().isNotEmpty &&
           p.experience != null && p.experience!.trim().isNotEmpty &&
           p.expertise.isNotEmpty &&
           p.intents.isNotEmpty;
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
      if (user != null) {
        await syncSignedInUser(user);
      } else if (!_isAuthCallbackInProgress) {
        _clearSignedOutState();
      }
      notifyListeners();
    });
  }

  Future<void> syncSignedInUser(User user) async {
    _cancelSubscriptions();

    _isLoggedIn = true;
    _isAuthCallbackInProgress = false;
    _currentScreen = AppScreen.hub;
    notifyListeners();

    try {
      final isAdminUser = await AuthService().isAdmin().timeout(
        const Duration(seconds: 4),
      );
      _isAdminView = isAdminUser;
    } catch (e) {
      _isAdminView = user.email == 'Gagan@gmail.com'; // Dev fallback
    }

    _profileSubscription = UserService().streamCurrentUserProfile().listen((profile) {
      if (profile != null) {
        _currentUserProfile = profile;
        _profileData = {
          'sub': user.uid,
          'name': profile.name.isNotEmpty ? profile.name : (user.displayName ?? user.email?.split('@')[0] ?? 'User'),
          'email': user.email ?? '',
          'location': profile.currentLocationName ?? profile.homeBase ?? '',
          'picture': profile.profileImageUrl ?? user.photoURL ?? '',
        };
        notifyListeners();
      }
    });

    // Fallback initially if profile stream is slow
    _profileData = {
      'sub': user.uid,
      'name': user.displayName ?? user.email?.split('@')[0] ?? 'User',
      'email': user.email ?? '',
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
            attendees: '${attendeesList.length} attending',
            category: data['category'] ?? 'Meetups',
            price: data['price'] ?? 'Free',
            mapUrl: data['mapUrl'],
            latitude: (data['latitude'] as num?)?.toDouble(),
            longitude: (data['longitude'] as num?)?.toDouble(),
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
      final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.docs);
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
      if (currentUid == null) return;

      // Query users collection
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('isDiscoverable', isEqualTo: true)
          .limit(20)
          .get();

      final loaded = querySnapshot.docs
          .where((doc) => doc.id != currentUid)
          .map((doc) {
            final data = doc.data();
            final expertise = List<String>.from(data['expertise'] ?? []);
            final intents = List<String>.from(data['intents'] ?? []);
            final customCardsData = data['customCards'] as List? ?? [];
            final customCards = customCardsData
                .map((item) => CustomCard.fromMap(Map<String, dynamic>.from(item)))
                .toList();

            return Candidate(
              uid: doc.id,
              name: data['name'] ?? '',
              role: data['role'] ?? '',
              org: data['company'] ?? '',
              loc: data['currentLocationName'] ?? data['homeBase'] ?? '',
              match: data['matchScore'] ?? 0,
              intent: intents.isNotEmpty ? intents.join(', ') : '',
              tags: expertise,
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
            );
          })
          .toList();

      _candidates.clear();
      _candidates.addAll(loaded);
      _activeCandidateIndex = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading candidates: $e');
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
