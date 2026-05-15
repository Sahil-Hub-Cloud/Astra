import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../login_screen.dart';
import '../../home_screen.dart';
import '../../contacts_screen.dart';
import '../../history_screen.dart';
import '../../settings_screen.dart';
import '../../profile_screen.dart';
import '../services/supabase_client.dart';

final goRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final session = supabase.auth.currentSession;

    if (session == null) {
      if (state.uri.path != '/login') {
        return '/login';
      }
    } else {
      if (state.uri.path == '/login') {
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
  ],
);
