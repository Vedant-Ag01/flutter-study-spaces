import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'dart:math';

class SpacesScreen extends StatefulWidget {
  const SpacesScreen({super.key});

  @override
  State<SpacesScreen> createState() => _SpacesScreenState();
}

// code generator
String _generateInviteCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rnd = Random();
  return String.fromCharCodes(
    Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
  );
}

class _SpacesScreenState extends State<SpacesScreen> {
  final supabase = Supabase.instance.client;

  // join room feature
  void _showJoinDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Join a Study Space'),
          content: TextField(
            controller: codeController,
            decoration: const InputDecoration(
              labelText: 'Enter 6-character Code',
              border: OutlineInputBorder(),
            ),
            // Automatically make their keyboard type in UPPERCASE
            textCapitalization: TextCapitalization.characters,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final code = codeController.text.trim().toUpperCase();
                if (code.isEmpty) return;

                try {
                  // 1. Ask the database: "Does a room with this code exist?"
                  final space = await supabase
                      .from('spaces')
                      .select()
                      .eq('invite_code', code)
                      .maybeSingle(); // maybeSingle returns null if it doesn't exist!

                  // 2. If it doesn't exist, show an error and stop.
                  if (space == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invalid invite code!')),
                      );
                    }
                    return;
                  }

                  // 3. If it exists write the user's name on the ledger
                  await supabase.from('space_members').insert({
                    'space_id': space['id'],
                    'user_id': supabase.auth.currentUser!.id,
                  });

                  // 4. Close the popup and celebrate
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Successfully joined ${space['name']}!'),
                      ),
                    );
                    context.push(
                      '/chat/${space['id']}',
                      extra: space['name'] ?? 'Study Space',
                    );
                  }
                } catch (e) {
                  // This catches errors (like if they are already in the room)
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Error: Could not join (Are you already a member?)',
                        ),
                      ),
                    );
                  }
                }
              },
              child: const Text('Join'),
            ),
          ],
        );
      },
    );
  }

  // This function handles the popup and database logic
  Future<void> _showCreateSpaceDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create a New Space'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Space Name *'),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final desc = descController.text.trim();
                if (name.isEmpty) return;

                // 1. Generate the 6-character code!
                final inviteCode = _generateInviteCode();

                try {
                  final newSpace = await supabase
                      .from('spaces')
                      .insert({
                        'name': name,
                        'description': desc,
                        'invite_code':
                            inviteCode, // 2. Save it to the database!
                      })
                      .select()
                      .single();

                  await supabase.from('space_members').insert({
                    'space_id': newSpace['id'],
                    'user_id': supabase.auth.currentUser!.id,
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Space created! Code: $inviteCode'),
                      ),
                    );
                    context.push(
                      '/chat/${newSpace['id']}',
                      extra: newSpace['name'] ?? 'Study Space',
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Spaces'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: 'Join Space',
            onPressed: _showJoinDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();
              if (mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),

      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('spaces')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final spaces = snapshot.data ?? [];

          if (spaces.isEmpty) {
            return const Center(
              child: Text('No study spaces yet. Create one!'),
            );
          }

          return ListView.builder(
            itemCount: spaces.length,
            itemBuilder: (context, index) {
              final space = spaces[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(space['name'] ?? 'Unnamed Space'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (space['description'] != null)
                        Text(space['description']),
                      const SizedBox(height: 4),
                      Text(
                        'Invite Code: ${space['invite_code'] ?? 'None'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push(
                      '/chat/${space['id']}',
                      extra: space['name'] ?? 'Study Space',
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateSpaceDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
