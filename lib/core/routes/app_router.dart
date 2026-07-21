import "package:go_router/go_router.dart";
import 'package:shared_preferences/shared_preferences.dart';

import '../../login_screen.dart';
import '../../home_screen.dart';
import '../../contacts_screen.dart';
import '../../history_screen.dart';
import '../../settings_screen.dart';
import '../../profile_screen.dart';
import '../../features/dashboard/safety_dashboard_screen.dart';
import '../../features/feed/community_feed_screen.dart';
import '../../features/fake_call/fake_call_screen.dart';
import '../../features/ai_companion/safety_companion_screen.dart';
import '../../features/onboarding/welcome_screen.dart';
import '../../features/onboarding/permissions_screen.dart';
import '../../features/onboarding/add_contact_screen.dart';
import '../../features/onboarding/tutorial_screen.dart';
import '../services/supabase_client.dart';

final goRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final session = supabase.auth.currentSession;
    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

    if (session == null) {
      if (state.uri.path != '/login') {
        return '/login';
      }
    } else {
      if (!onboardingComplete && !state.uri.path.startsWith('/onboarding')) {
        return '/onboarding';
      }
      if (onboardingComplete && state.uri.path == '/login') {
        return '/home';
      }
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'welcome',
      builder: (context, state) => const WelcomeScreen(),
      routes: [
        GoRoute(
          path: 'permissions',
          name: 'permissions',
          builder: (context, state) => const PermissionsScreen(),
        ),
        GoRoute(
          path: 'contacts',
          name: 'onboarding_contacts',
          builder: (context, state) => const AddContactScreen(),
        ),
        GoRoute(
          path: 'tutorial',
          name: 'tutorial',
          builder: (context, state) => const TutorialScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/contacts',
      name: 'contacts',
      builder: (context, state) => const ContactsScreen(),
    ),
    GoRoute(
      path: '/history',
      name: 'history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      name: 'dashboard',
      builder: (context, state) => const SafetyDashboardScreen(),
    ),
    GoRoute(
      path: '/feed',
      name: 'feed',
      builder: (context, state) => const CommunityFeedScreen(),
    ),
    GoRoute(
      path: '/ai-companion',
      name: 'ai_companion',
      builder: (context, state) => const SafetyCompanionScreen(),
    ),
    GoRoute(
      path: '/fake-call',
      name: 'fake_call',
      builder: (context, state) {
        final name = state.uri.queryParameters['name'] ?? 'Mom';
        return FakeCallScreen(callerName: name);
      },
    ),
  ],
);
