import 'package:flutter/material.dart';
import 'state_manager.dart';
import 'screens/onboarding_screen.dart';
import 'screens/hub_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/checkin_screen.dart';
import 'screens/events_screen.dart';
import 'screens/discover_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/meet_screen.dart';
import 'screens/admin_panel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppStateManager().init();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BoardingPause',
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
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, child) {
        return Scaffold(
          body: !_state.isLoggedIn
              ? const OnboardingScreen()
              : (_state.isAdminView ? const AdminPanel() : _buildMobileAppShell()),
        );
      },
    );
  }

  Widget _buildMobileAppShell() {
    return _buildAppNavigation();
  }

  // Standard standard app navigation flow with active screen selector
  Widget _buildAppNavigation() {
    Widget activeWidget = const HubScreen();

    switch (_state.currentScreen) {
      case AppScreen.hub:
        activeWidget = const HubScreen();
        break;
      case AppScreen.profile:
        activeWidget = const ProfileScreen();
        break;
      case AppScreen.checkin:
        activeWidget = const CheckinScreen();
        break;
      case AppScreen.events:
        activeWidget = const EventsScreen();
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
        activeWidget = const MeetScreen();
        break;
    }

    return activeWidget;
  }


}
