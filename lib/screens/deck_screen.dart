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

  // The delete function
  Future<void> _deleteCard(String cardId) async {
    // Show a quick confirmation dialog first so users don't accidentally delete!
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Flashcard?'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final supabase = ref.read(supabaseProvider);
      // SEND DELETE TO CLOUD
      await supabase.from('flashcards').delete().eq('id', cardId);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Card deleted!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // The Edit Function
  Future<void> _showEditCardDialog(Map<String, dynamic> card) async {
    // Pre-fill the text boxes with the existing card data
    final frontController = TextEditingController(text: card['front']);
    final backController = TextEditingController(text: card['back']);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Flashcard'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: frontController,
              decoration: const InputDecoration(labelText: 'Question'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: backController,
              decoration: const InputDecoration(labelText: 'Answer'),
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
                // SEND UPDATE TO CLOUD
                await supabase
                    .from('flashcards')
                    .update({'front': front, 'back': back})
                    .eq('id', card['id']);

                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Save Changes'),
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
        error: (err, stackTrace) {
          final errorText = err.toString();
          final isOffline =
              errorText.contains('SocketException') ||
              errorText.contains('ClientException') ||
              errorText.contains('Failed host lookup');

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isOffline ? Icons.wifi_off : Icons.error_outline,
                  size: 60,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  isOffline ? 'Connection Lost' : 'Oops! Something broke.',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    isOffline
                        ? 'Please check your internet and try again.'
                        : errorText,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          );
        },
        data: (cards) {
          if (cards.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.style,
                    size: 80,
                    color: Colors.deepPurple.shade200,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'It’s quiet in here...',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the + button to add your first flashcard!',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
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
                  // We use a Stack so we can easily pin the menu button to the top right
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              right: 32.0,
                            ), // Make room for the button
                            child: Text(
                              'Q: ${card['front']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const Divider(),
                          Text(
                            'A: ${card['back']}',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),

                      // The action  menu
                      Positioned(
                        top: -12,
                        right: -12,
                        child: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showEditCardDialog(card);
                            } else if (value == 'delete') {
                              _deleteCard(card['id']);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 20),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
