import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class SpacesScreen extends StatefulWidget {
  const SpacesScreen({super.key});

  @override
  State<SpacesScreen> createState() => _SpacesScreenState();
}

class _SpacesScreenState extends State<SpacesScreen> {
  final supabase = Supabase.instance.client;

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

                if (name.isEmpty) return; // Don't allow blank names
                print(
                  'DEBUG: Current User ID is ${supabase.auth.currentUser?.id}',
                );
                try {
                  // 1. Create the room in the 'spaces' table and grab its new ID
                  final newSpace = await supabase
                      .from('spaces')
                      .insert({'name': name, 'description': desc})
                      .select()
                      .single();

                  // 2. Add yourself to the 'space_members' ledger using that ID
                  await supabase.from('space_members').insert({
                    'space_id': newSpace['id'],
                    'user_id': supabase.auth.currentUser!.id,
                  });

                  if (context.mounted) {
                    Navigator.pop(context); // Close the popup
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Space created successfully!'),
                      ),
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
        title: const Text('My Study Spaces'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      // Replace your old body: const Center(...) with this:
      body: FutureBuilder<List<Map<String, dynamic>>>(
        // 1. The Database Query
        future: supabase
            .from('spaces')
            .select('*, space_members!inner(user_id)')
            .eq('space_members.user_id', supabase.auth.currentUser!.id),

        // 2. The UI Builder
        builder: (context, snapshot) {
          // State A: Still waiting for the internet
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // State B: Something went wrong
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final spaces = snapshot.data ?? [];

          // State C: Successful query, but no spaces exist
          if (spaces.isEmpty) {
            return const Center(
              child: Text(
                'You haven\'t joined any spaces yet! Click + to create one.',
              ),
            );
          }

          // State D: We have data! Draw the list.
          return ListView.builder(
            itemCount: spaces.length,
            itemBuilder: (context, index) {
              final space = spaces[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.group)),
                  title: Text(space['name'] ?? 'Unnamed Space'),
                  subtitle: Text(space['description'] ?? 'No description'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Tomorrow, we will route this to the actual chat room!
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Opening ${space['name']}...')),
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
