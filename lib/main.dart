import 'package:flutter/material.dart';
import 'package:study_spaces/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:study_spaces/screens/login_screen.dart';
import 'package:study_spaces/screens/spaces_screen.dart';
import 'package:study_spaces/screens/chat_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/profile_screen.dart';
import 'package:study_spaces/screens/deck_screen.dart';
import 'screens/study_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase connection
  await Supabase.initialize(
    url: 'https://ouyxrjponhtmjrdnmojr.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im91eXhyanBvbmh0bWpyZG5tb2pyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NDU0NDMsImV4cCI6MjA5NDQyMTQ0M30.EshSlqq2h1H134-HAf1qVrTtZb8c9e5_zkstr5cTMRE',
  );

  runApp(const ProviderScope(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      // Checking if they are already logged in when the app opens
      initialLocation: Supabase.instance.client.auth.currentUser == null
          ? '/login'
          : '/spaces',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/spaces',
          builder: (context, state) => const SpacesScreen(),
        ),
        // Add this right inside your routes: [] list
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/deck/:deckId', // Yours might just be :id
          builder: (context, state) {
            final deckId = state
                .pathParameters['deckId']!; // Or 'id' depending on your setup
            final extraData =
                state.extra as Map<String, dynamic>; // 👈 Unpack the Map!

            return DeckScreen(
              deckId: deckId,
              deckTitle: extraData['title'],
              spaceId: extraData['spaceId'],
            );
          },
        ),
        GoRoute(
          path: '/chat/:id',
          builder: (context, state) {
            final spaceId = state.pathParameters['id']!;
            final spaceName = state.extra as String? ?? 'Study Space';
            return ChatScreen(spaceId: spaceId, spaceName: spaceName);
          },
        ),
        GoRoute(
          path: '/study/:deckId', // Yours might just be :id
          builder: (context, state) {
            final deckId = state
                .pathParameters['deckId']!; // Or 'id' depending on your setup
            final extraData =
                state.extra as Map<String, dynamic>; // 👈 Unpack the Map!

            return StudyScreen(
              deckId: deckId,
              deckTitle: extraData['title'],
              spaceId: extraData['spaceId'],
            );
          },
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Study Engine',
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
    );
  }
}
