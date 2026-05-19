import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final String spaceId;
  final String spaceName;

  const ChatScreen({super.key, required this.spaceId, required this.spaceName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final supabase = Supabase.instance.client;

  // deck creater dialog
  void _showCreateDeckDialog() {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Deck'),
          content: TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Deck Title (e.g. Physics Ch 1)',
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;

                try {
                  // Write the new deck to the database
                  await supabase.from('decks').insert({
                    'space_id': widget.spaceId,
                    'title': title,
                  });
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error creating deck')),
                    );
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
      appBar: AppBar(title: Text('${widget.spaceName} - Decks')),
      // 1. live updates
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('decks')
            .stream(primaryKey: ['id'])
            .eq('space_id', widget.spaceId)
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final decks = snapshot.data ?? [];

          // The Empty State
          if (decks.isEmpty) {
            return const Center(
              child: Text('No decks yet. Create your first flashcard deck!'),
            );
          }

          // The List of Decks
          return ListView.builder(
            itemCount: decks.length,
            itemBuilder: (context, index) {
              final deck = decks[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.style, color: Colors.deepPurple),
                  title: Text(deck['title']),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // flashcard ui should go here
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Opening ${deck['title']}... (Coming soon)',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      // 2. THE NEW BUTTON
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDeckDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Deck'),
      ),
    );
  }
}
