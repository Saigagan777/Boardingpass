import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'firebase_options.dart';
import 'state_manager.dart';
import 'services/auth_service.dart';
import 'services/linkedin_oauth_config.dart';
import 'services/user_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/hub_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/checkin_screen.dart';
import 'screens/events_screen.dart';
import 'screens/discover_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/meet_screen.dart';
import 'screens/admin_panel.dart';
import 'utils/web_helper.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Web OAuth Redirect Handling ---
  // When LinkedIn redirects back to the app on Web, the URL contains ?code=XXX.
  // Capture it here before anything else.
  String? webOAuthCode;
  try {
    final uri = Uri.base;
    webOAuthCode = uri.queryParameters['code'];
    if (webOAuthCode != null && webOAuthCode.isNotEmpty && kIsWeb) {
      // Clean up the URL so that page refreshes do not re-run OAuth with stale codes
      cleanUrlQueryParameters();
    }
  } catch (_) {}

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // Always start the app immediately — never block on network calls
  final appState = AppStateManager();

  if (webOAuthCode != null && webOAuthCode.isNotEmpty) {
    appState.beginAuthCallback();
  }

  // Initialize notifications (non-blocking)
  try {
    await NotificationService().initialize();
    await NotificationService().requestPermission();
    await NotificationService().getAndStoreFcmToken();
  } catch (e) {
    debugPrint('Notification init error: $e');
  }

  appState.init();
  runApp(const MainApp());

  // Process OAuth code AFTER the app is visible (non-blocking)
  if (webOAuthCode != null && webOAuthCode.isNotEmpty) {
    debugPrint('LinkedIn web OAuth code detected.');
    try {
      String? pendingSyncUid;
      if (kIsWeb) {
        const storage = FlutterSecureStorage();
        pendingSyncUid = await storage.read(key: 'linkedin_sync_pending_uid');
      }

      if (pendingSyncUid != null && pendingSyncUid.isNotEmpty) {
        await UserService().syncLinkedInProfile(
          pendingSyncUid,
          webOAuthCode,
          redirectUri: LinkedInOAuthConfig.redirectUri,
        );
        if (kIsWeb) {
          const storage = FlutterSecureStorage();
          await storage.delete(key: 'linkedin_sync_pending_uid');
        }

        final user = AuthService().currentUser;
        if (user != null) {
          await appState.syncSignedInUser(user);
        } else {
          appState.endAuthCallback();
        }
        debugPrint('LinkedIn web profile sync successful!');
      } else {
        final credential = await AuthService().signInWithLinkedIn(
          webOAuthCode,
          redirectUri: LinkedInOAuthConfig.redirectUri,
        );
        final user = credential?.user ?? AuthService().currentUser;
        if (user != null) {
          await appState.syncSignedInUser(user);
        } else {
          appState.endAuthCallback();
        }
        debugPrint('LinkedIn web OAuth sign-in successful!');
      }
    } catch (e) {
      debugPrint('LinkedIn web OAuth error: $e');
      if (kIsWeb) {
        const storage = FlutterSecureStorage();
        await storage.delete(key: 'linkedin_sync_pending_uid');
      }
      appState.endAuthCallback();
    }
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NexMeet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // --- 60-30-10 Color System ---
        // 60% Dominant Color: Cream/off-white background for canvas and surface
        scaffoldBackgroundColor: const Color(0xFFFAF7F5),
        // 10% Accent Color: Vibrant terracotta for primary CTAs, links, and indicators
        primaryColor: const Color(0xFF7A432D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7A432D),
          // 10% Accent
          primary: const Color(0xFF7A432D),
          // 30% Secondary: Espresso for structural components, borders, and typography
          secondary: const Color(0xFF3E1F11),
          // 60% Dominant
          surface: const Color(0xFFFAF7F5),
          onSurface: const Color(0xFF3E1F11),
        ),
        fontFamily: 'PlusJakartaSans',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontWeight: FontWeight.bold,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontWeight: FontWeight.bold,
          ),
          headlineSmall: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontWeight: FontWeight.w600,
          ),
          titleLarge: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontWeight: FontWeight.bold,
          ),
          titleMedium: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w600,
          ),
          titleSmall: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(fontFamily: 'PlusJakartaSans'),
          bodyMedium: TextStyle(fontFamily: 'PlusJakartaSans'),
          bodySmall: TextStyle(fontFamily: 'PlusJakartaSans'),
          labelLarge: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.bold,
          ),
          labelMedium: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w600,
          ),
          labelSmall: TextStyle(fontFamily: 'PlusJakartaSans'),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFAF7F5),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E1F11),
          ),
        ),
        dividerColor: const Color(0xFFE8E2DD),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE8E2DD), width: 1),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7A432D),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ),
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  final AppStateManager _state = AppStateManager();
  // Session-level set of dismissed notification IDs (not marked as read in Firestore)
  final Set<String> _dismissedNotificationIds = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notificationSub;
  Map<String, dynamic>? _latestUnreadNotification;
  String? _latestUnreadNotificationId;
  bool _showNotificationBanner = false;
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _state.addListener(_onStateChanged);
    
    // Set initial uid and subscribe to notifications if logged in
    final initialUid =
        _state.profileData?['uid'] ?? FirebaseAuth.instance.currentUser?.uid;
    if (initialUid != null) {
      _currentUid = initialUid;
      _startNotificationStream(initialUid);
    }
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    _notificationSub?.cancel();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      final newUid =
          _state.profileData?['uid'] ?? FirebaseAuth.instance.currentUser?.uid;
      if (newUid != _currentUid) {
        _currentUid = newUid;
        if (newUid != null) {
          _startNotificationStream(newUid);
        } else {
          _notificationSub?.cancel();
          _notificationSub = null;
          setState(() {
            _latestUnreadNotificationId = null;
            _latestUnreadNotification = null;
            _showNotificationBanner = false;
          });
        }
      }
      setState(() {});
    }
  }

  void _startNotificationStream(String uid) {
    _notificationSub?.cancel();
    _notificationSub = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen(
          (snap) {
            if (mounted) {
              final unreadDocs = snap.docs.where((doc) {
                final data = doc.data();
                return (data['isRead'] as bool? ?? false) == false;
              }).toList();

              if (unreadDocs.isNotEmpty) {
                unreadDocs.sort((a, b) {
                  final aTime = a.data()['timestamp'] as Timestamp?;
                  final bTime = b.data()['timestamp'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return -1; // null (pending local write) is newest
                  if (bTime == null) return 1;
                  return bTime.compareTo(aTime); // descending
                });
                
                final doc = unreadDocs.first;
                final isNewBanner = doc.id != _latestUnreadNotificationId;
                final isDismissed = _dismissedNotificationIds.contains(doc.id);

                if (isNewBanner) {
                  _latestUnreadNotificationId = doc.id;
                  _latestUnreadNotification = doc.data();
                  _showNotificationBanner = !isDismissed;
                  setState(() {});
                } else {
                  // Same notification, just update fields (e.g. resolved server timestamp)
                  setState(() {
                    _latestUnreadNotification = doc.data();
                  });
                }
              } else {
                setState(() {
                  _latestUnreadNotificationId = null;
                  _latestUnreadNotification = null;
                  _showNotificationBanner = false;
                });
              }
            }
          },
          onError: (err) {
            debugPrint("Error listening to notifications: $err");
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    // Determine if banner should show
    final showBanner =
        _latestUnreadNotificationId != null &&
        _latestUnreadNotification != null &&
        _showNotificationBanner &&
        _latestUnreadNotification?['shouldShowBanner'] != false &&
        !_dismissedNotificationIds.contains(_latestUnreadNotificationId);

    return Scaffold(
      body: Stack(
        children: [
          // Main content
          (!_state.isInitialized || _state.isAuthCallbackInProgress)
              ? const AuthCallbackScreen()
              : (!_state.isLoggedIn
                    ? const OnboardingScreen()
                    : (_state.isAdminView
                          ? const AdminPanel()
                          : (_state.isProfileComplete
                                ? _buildMobileAppShell()
                                : const OnboardingScreen(completionMode: true)))),
          // In-app notification banner overlay
          if (showBanner && _state.isLoggedIn && _state.isProfileComplete)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: () async {
                    // Mark as read in Firestore and navigate
                    final notifId = _latestUnreadNotificationId;
                    final notifData = _latestUnreadNotification;
                    if (notifId != null) {
                      await FirebaseFirestore.instance
                          .collection('notifications')
                          .doc(notifId)
                          .update({'isRead': true});
                      setState(() {
                        _latestUnreadNotificationId = null;
                        _latestUnreadNotification = null;
                        _showNotificationBanner = false;
                      });
                      // Route based on type
                      final type = (notifData?['type'] as String? ?? '').toLowerCase();
                      if (type.contains('meeting')) {
                        _state.meetingInitialTab = 1;
                        _state.currentScreen = AppScreen.meeting;
                      } else if (type.contains('chat') ||
                          type.contains('group')) {
                        _state.currentScreen = AppScreen.chat;
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3E1F11),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.notifications_active,
                          color: Color(0xFFE5A475),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _latestUnreadNotification?['title'] ??
                                    'New Notification',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if ((_latestUnreadNotification?['body'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                Text(
                                  _latestUnreadNotification!['body'],
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11,
                                    color: Color(0xFFE8E2DD),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Close button — dismisses locally, does NOT mark as read
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _dismissedNotificationIds.add(
                                _latestUnreadNotificationId!,
                              );
                              _showNotificationBanner = false;
                            });
                          },
                          child: const Icon(
                            Icons.close,
                            color: Color(0xFF8C736B),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileAppShell() {
    return _buildAppNavigation();
  }

  // Standard standard app navigation flow with active screen selector
  Widget _buildAppNavigation() {
    Widget activeWidget = HubScreen();

    switch (_state.currentScreen) {
      case AppScreen.hub:
        activeWidget = HubScreen();
        break;
      case AppScreen.profile:
        activeWidget = ProfileScreen();
        break;
      case AppScreen.checkin:
        activeWidget = CheckinScreen();
        break;
      case AppScreen.events:
        activeWidget = EventsScreen();
        break;
      case AppScreen.discover:
        activeWidget = const DiscoverScreen();
        break;
      case AppScreen.chat:
        activeWidget = ChatScreen(
          name: _state.activeChatContact,
          onBack: () {
            if (_state.activeChatContact != null) {
              _state.activeChatContact = null;
            } else {
              _state.currentScreen = AppScreen.hub;
            }
          },
        );
        break;
      case AppScreen.meeting:
        activeWidget = MeetScreen(
          name: _state.activeChatContact,
          onBack: () {
            _state.currentScreen = AppScreen.hub;
          },
          onDone: () {
            _state.currentScreen = AppScreen.hub;
          },
        );
        break;
    }

    return activeWidget;
  }
}

class AuthCallbackScreen extends StatelessWidget {
  const AuthCallbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFFAF7F5),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7A432D)),
        ),
      ),
    );
  }
}
