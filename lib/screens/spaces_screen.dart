import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class SpacesScreen extends StatelessWidget {
  const SpacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Study Spaces'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // 1. Tell Supabase to destroy the session
              await Supabase.instance.client.auth.signOut();
              // 2. Tell GoRouter to kick them back to login
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: const Center(child: Text('You made it past the bouncer!')),
    );
  }
}
