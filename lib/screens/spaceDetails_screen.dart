import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/decks_provider.dart';
import '../providers/spaces_provider.dart'; // To grab the master Supabase connection
import 'package:go_router/go_router.dart';

class SpaceDetailsScreen extends ConsumerStatefulWidget {
  final String spaceId;
  final String spaceName;

  const SpaceDetailsScreen({
    super.key,
    required this.spaceId,
    required this.spaceName,
  });

  @override
  ConsumerState<SpaceDetailsScreen> createState() => _SpaceDetailsScreenState();
}

class _SpaceDetailsScreenState extends ConsumerState<SpaceDetailsScreen> {
  // The popup to create a new flashcard folder/deck
  Future<void> _showCreateDeckDialog() async {
    final titleController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create a New Deck'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Deck Title (e.g., Biology 101)',
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
                final supabase = ref.read(supabaseProvider);

                // Insert the new deck into the database, linking it to THIS room
                await supabase.from('decks').insert({
                  'space_id': widget.spaceId,
                  'title': title,
                });

                if (mounted) {
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    //passing the spaceid to the stream provider
    final decksAsyncValue = ref.watch(decksStreamProvider(widget.spaceId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.spaceName), // Displays the name of the room
      ),

      body: decksAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),

        error: (error, stack) => Center(child: Text('Error: $error')),

        data: (decks) {
          // The Empty State
          if (decks.isEmpty) {
            return const Center(
              child: Text('No flashcard decks yet. Click + to create one!'),
            );
          }

          // The Data State
          return ListView.builder(
            itemCount: decks.length,
            itemBuilder: (context, index) {
              final deck = decks[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.style, color: Colors.deepPurple),
                  title: Text(
                    deck['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push(
                      '/deck/${deck['id']}',
                      extra: {
                        'title': deck['title'],
                        'spaceId': widget.spaceId,
                      },
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening deck soon...')),
                    );
                  },
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDeckDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
