import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/flashcards_provider.dart';
import '../providers/spaces_provider.dart';
import 'package:go_router/go_router.dart';

class DeckScreen extends ConsumerStatefulWidget {
  final String deckId;
  final String deckTitle;
  final String spaceId;

  const DeckScreen({
    super.key,
    required this.deckId,
    required this.deckTitle,
    required this.spaceId,
  });

  @override
  ConsumerState<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends ConsumerState<DeckScreen> {
  // The popup to create a new flashcard
  Future<void> _showAddCardDialog() async {
    final frontController = TextEditingController();
    final backController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Flashcard'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: frontController,
              decoration: const InputDecoration(labelText: 'Front (Question)'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: backController,
              decoration: const InputDecoration(labelText: 'Back (Answer)'),
              maxLines: 3,
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
              final front = frontController.text.trim();
              final back = backController.text.trim();
              if (front.isEmpty || back.isEmpty) return;

              try {
                final supabase = ref.read(supabaseProvider);

                // Insert the new card into the database
                await supabase.from('flashcards').insert({
                  'deck_id': widget.deckId,
                  'front': front,
                  'back': back,
                });

                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Save Card'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(flashcardsStreamProvider(widget.deckId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deckTitle),
        actions: [
          // Wire this button up to the 3D Study Mode next
          IconButton(
            icon: const Icon(Icons.play_circle_fill, size: 28),
            tooltip: 'Study Deck',
            onPressed: () {
              context.push(
                '/study/${widget.deckId}',
                extra: {'title': widget.deckTitle, 'spaceId': widget.spaceId},
              );
            },
          ),
        ],
      ),

      body: cardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (cards) {
          if (cards.isEmpty) {
            return const Center(
              child: Text('No cards yet. Add your first one!'),
            );
          }

          return ListView.builder(
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Q: ${card['front']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Divider(),
                      Text(
                        'A: ${card['back']}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCardDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
