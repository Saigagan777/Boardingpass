import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
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
      title: 'Boarding Pause',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAF7F5),
        primaryColor: const Color(0xFF7A432D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7A432D),
          primary: const Color(0xFF7A432D),
          secondary: const Color(0xFFB06F4D),
          surface: const Color(0xFFFAF7F5),
        ),
        fontFamily: 'PlusJakartaSans',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold),
          headlineSmall: TextStyle(fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w600),
          titleSmall: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontFamily: 'PlusJakartaSans'),
          bodyMedium: TextStyle(fontFamily: 'PlusJakartaSans'),
          bodySmall: TextStyle(fontFamily: 'PlusJakartaSans'),
          labelLarge: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.bold),
          labelMedium: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w600),
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

  @override
  void initState() {
    super.initState();
    _state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _state.isAuthCallbackInProgress
          ? const AuthCallbackScreen()
          : (!_state.isLoggedIn
                ? const OnboardingScreen()
                : (_state.isProfileComplete
                      ? (_state.isAdminView
                            ? const AdminPanel()
                            : _buildMobileAppShell())
                      : const OnboardingScreen(completionMode: true))),
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
        activeWidget = DiscoverScreen(
          onMatch: (name) {
            _state.activeChatContact = name;
            _state.currentScreen = AppScreen.chat;
          },
        );
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
            _state.currentScreen = AppScreen.chat;
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
