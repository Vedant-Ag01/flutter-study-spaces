import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/spaces_provider.dart';
import 'package:study_spaces/screens/notes_screen.dart';

class SpacesScreen extends ConsumerStatefulWidget {
  const SpacesScreen({super.key});

  @override
  ConsumerState<SpacesScreen> createState() => _SpacesScreenState();
}

// code generator
String _generateInviteCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rnd = Random();
  return String.fromCharCodes(
    Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
  );
}

class _SpacesScreenState extends ConsumerState<SpacesScreen> {
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
    String visibility = 'private'; // Default to private!

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
              const SizedBox(height: 16),
              // THE NEW VISIBILITY DROPDOWN
              DropdownButtonFormField<String>(
                value: visibility,
                decoration: const InputDecoration(labelText: 'Visibility'),
                items: const [
                  DropdownMenuItem(value: 'public', child: Text('Public')),
                  DropdownMenuItem(value: 'private', child: Text('Private')),
                ],
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    visibility = newValue;
                  }
                },
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

                final inviteCode = _generateInviteCode();

                try {
                  final newSpace = await supabase
                      .from('spaces')
                      .insert({
                        'name': name,
                        'description': desc,
                        'invite_code': inviteCode,
                        'visibility': visibility, // SAVE VISIBILITY TO DB
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
            icon: const Icon(Icons.edit_document),
            tooltip: 'Test Notes Screen',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const NotesScreen(spaceId: 'test_id_123'),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'My Profile',
            onPressed: () {
              context.push('/profile'); // This triggers the route we just made!
            },
          ),
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

      body: ref
          .watch(spacesStreamProvider)
          .when(
            // 1. The Loading State
            loading: () => const Center(child: CircularProgressIndicator()),

            // 2. The Error State
            error: (error, stackTrace) =>
                Center(child: Text('Error loading spaces: $error')),

            // 3. The Data / Empty State
            data: (spaces) {
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
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
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
