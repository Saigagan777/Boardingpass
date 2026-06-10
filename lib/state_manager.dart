import 'package:flutter/material.dart';
import 'models/candidate.dart';
import 'models/checkin.dart';
import 'models/event.dart';
import 'models/message.dart';

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
  Map<String, String>? _profileData;

  bool get isLoggedIn => _isLoggedIn;
  Map<String, String>? get profileData => _profileData;

  void logIn(Map<String, String> data, {bool isAdmin = false}) {
    _isLoggedIn = true;
    _profileData = data;
    _currentScreen = AppScreen.hub;
    _isAdminView = isAdmin;
    notifyListeners();
  }

  void logOut() {
    _isLoggedIn = false;
    _profileData = null;
    _currentScreen = AppScreen.hub;
    _isAdminView = false;
    _activeChatContact = null;
    _selectedCheckinType = CheckinType.event;
    
    // Reset lists to initial values
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

  void addCheckin(Checkin checkin) {
    _checkins.insert(0, checkin);
    notifyListeners();
  }

  // Events list
  final List<Event> _events = [];
  List<Event> get events => _events;

  void toggleJoinEvent(String id) {
    final index = _events.indexWhere((e) => e.id == id);
    if (index != -1) {
      _events[index].isJoined = !_events[index].isJoined;
      notifyListeners();
    }
  }

  void createEvent(Event newEvent) {
    _events.add(newEvent);
    notifyListeners();
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
  }

  void _initializeData() {
    // Checkins
    _checkins.clear();
    _checkins.addAll([
      const Checkin(
        id: 'c1',
        type: CheckinType.airport,
        name: 'BLR T2',
        location: 'Kempegowda International',
        checkinDate: '2024-06-15',
        checkinTime: '08:30',
        checkoutDate: '2024-06-15',
        checkoutTime: '11:55',
      ),
      const Checkin(
        id: 'c2',
        type: CheckinType.hotel,
        name: 'Taj West End',
        location: 'Bengaluru',
        checkinDate: '2024-06-14',
        checkinTime: '15:00',
        checkoutDate: '2024-06-16',
        checkoutTime: '11:00',
      ),
    ]);

    // Events
    _events.clear();
    _events.addAll([
      Event(
        id: 'e1',
        illustrationPath: 'assets/images/boarding_pass_illustration_4.png',
        month: 'MAY',
        day: '24',
        title: 'AI Leadership Summit',
        location: 'Hyderabad',
        time: 'Tomorrow • 7:00 PM',
        attendees: '120 attending',
      ),
      Event(
        id: 'e2',
        illustrationPath: 'assets/images/boarding_pass_illustration_5.png',
        month: 'MAY',
        day: '30',
        title: 'Product Growth Meetup',
        location: 'Bangalore',
        time: 'Friday • 6:30 PM',
        attendees: '85 attending',
      ),
      Event(
        id: 'e3',
        illustrationPath: 'assets/images/boarding_pass_illustration_3.png',
        month: 'JUN',
        day: '05',
        title: 'Founders Networking Night',
        location: 'Mumbai',
        time: 'Wednesday • 7:00 PM',
        attendees: '60 attending',
      ),
    ]);

    // Candidates
    _candidates.clear();
    _candidates.addAll([
      const Candidate(
        name: 'Ananya Rao',
        role: 'Partner',
        org: 'Lumen Ventures',
        loc: 'Same lounge · 30m',
        match: 94,
        intent: 'Investing in fintech seed',
        tags: ['Seed', 'Fintech', 'India'],
        bio: 'Led 14 fintech investments. Looking for SME credit and embedded finance founders this quarter.',
        initials: 'AR',
        primaryColor: Color(0xFFE5A475),
      ),
      const Candidate(
        name: 'Vikram Shah',
        role: 'VP Engineering',
        org: 'Stripe APAC',
        loc: 'Gate 14 · 4 min walk',
        match: 81,
        intent: 'Open to advising',
        tags: ['Payments', 'Scale', 'CTO'],
        bio: 'Scaled payments infra to 12 countries. Happy to swap notes on risk + ledger design.',
        initials: 'VS',
        primaryColor: Color(0xFF68B2DF),
      ),
      const Candidate(
        name: 'Priya Iyer',
        role: 'Head of SME',
        org: 'HDFC Bank',
        loc: 'Plaza Premium · now',
        match: 76,
        intent: 'Exploring design partners',
        tags: ['SME', 'BFSI', 'Distribution'],
        bio: 'Runs SME products. Looking for fintech partners for co-lending pilots.',
        initials: 'PI',
        primaryColor: Color(0xFFE9659A),
      ),
    ]);
    _activeCandidateIndex = 0;

    // Chat messages
    _messages.clear();
    _messages.addAll([
      Message(
        id: 'm1',
        kind: MessageKind.text,
        from: MessageSender.them,
        text: 'Hi Rohan! Loved your SME thesis. Are you in the lounge?',
        time: '9:38',
      ),
      Message(
        id: 'm2',
        kind: MessageKind.voice,
        from: MessageSender.me,
        seconds: 14,
        time: '9:39',
        reactions: ['🔥'],
      ),
      Message(
        id: 'm3',
        kind: MessageKind.pin,
        from: MessageSender.me,
        place: 'Plaza Premium · Gate 12',
        meta: '4 min walk · 22 nearby',
        time: '9:39',
      ),
      Message(
        id: 'm4',
        kind: MessageKind.text,
        from: MessageSender.them,
        text: "Perfect. I'd love to hear about your underwriting model.",
        time: '9:40',
      ),
      Message(
        id: 'm5',
        kind: MessageKind.poll,
        from: MessageSender.them,
        question: 'When are you free for a quick chat?',
        options: ['Right now', 'In 30 mins', 'After boarding'],
        time: '9:40',
      ),
    ]);

    // Admin Logs
    _adminLogs.clear();
    _adminLogs.addAll([
      AdminLog(
        id: 'a1',
        title: 'Spam Report: John Doe',
        details: 'User sent 12 unsolicited pitch deck links in the general chat room within 5 minutes.',
        timeAgo: '2h ago',
        reporter: 'Priya Sharma',
      ),
      AdminLog(
        id: 'a2',
        title: 'Inappropriate Event Name',
        details: 'Event named "Crypto Get-Rich-Quick Meetup" flagged as MLM/spam solicitation.',
        timeAgo: '4h ago',
        reporter: 'Aarav Mehta',
      ),
    ]);
  }
}
