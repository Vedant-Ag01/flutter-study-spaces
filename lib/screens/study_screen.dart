import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/flashcards_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_spaces/providers/comments_provider.dart';
import 'package:shimmer/shimmer.dart';

class StudyScreen extends ConsumerStatefulWidget {
  final String deckId;
  final String deckTitle;
  final String spaceId;

  const StudyScreen({
    super.key,
    required this.deckId,
    required this.deckTitle,
    required this.spaceId,
  });

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  //SRS Algorithm
  Future<void> _processReview(
    Map<String, dynamic> card,
    String difficulty,
  ) async {
    int currentBox = card['box_level'] ?? 1;
    int newBox;
    DateTime nextReview;

    final now = DateTime.now();

    if (difficulty == 'hard') {
      // Reset to Box 1, see it again immediately
      newBox = 1;
      nextReview = now;
    } else if (difficulty == 'good') {
      // Kept pace. Stay in the same box, see it tomorrow.
      newBox = currentBox;
      nextReview = now.add(const Duration(days: 1));
    } else {
      // 'easy' - Promoted! 2^box_level days in the future
      newBox = currentBox + 1;
      int daysToWait = pow(2, currentBox).toInt();
      nextReview = now.add(Duration(days: daysToWait));
    }

    try {
      await Supabase.instance.client
          .from('flashcards')
          .update({
            'box_level': newBox,
            'next_review_date': nextReview.toIso8601String(),
          })
          .eq('id', card['id']);
      // Move to the next card so the user can keep studying
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving progress: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // We grab the exact same provider we used on the DeckScreen
    final cardsAsync = ref.watch(flashcardsStreamProvider(widget.deckId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Studying: ${widget.deckTitle}'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.forum),
            tooltip: 'Open Discussion',
            onPressed: () {
              // THIS OPENS THE BOTTOM SHEET
              showModalBottomSheet(
                context: context,
                isScrollControlled:
                    true, // Allows the sheet to move with the keyboard
                builder: (context) => ChatBottomSheet(
                  itemId: widget.deckId,
                  spaceId: widget
                      .spaceId, // We'll need to pass the spaceId from the previous screen
                ),
              );
            },
          ),
        ],
      ),
      body: cardsAsync.when(
        loading: () => const CardLoadingSkeleton(),
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
        data: (allCards) {
          // SCENARIO 1: The deck is completely empty. No cards created yet.
          if (allCards.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox,
                    size: 80,
                    color: Colors.deepPurple.shade200,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This deck is empty!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Go back and add some flashcards to start studying.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // FILTER: Now we filter out the future cards in the UI!
          final now = DateTime.now();
          final dueCards = allCards.where((card) {
            if (card['next_review_date'] == null) return true;
            final reviewDate = DateTime.parse(card['next_review_date']);
            return reviewDate.isBefore(now) || reviewDate.isAtSameMomentAs(now);
          }).toList();

          // SCENARIO 2: Deck has cards, but the user finished studying them today.
          if (dueCards.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: Colors.green.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'You\'re all caught up!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Come back tomorrow to review more cards.',
                    style: TextStyle(fontSizSRe: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Progress Tracker
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  // IMPORTANT: Changed 'cards.length' to 'dueCards.length'
                  'Card ${_currentIndex + 1} of ${dueCards.length}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),

              // The Swipeable Deck
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  // IMPORTANT: Changed 'cards.length' to 'dueCards.length'
                  itemCount: dueCards.length,
                  itemBuilder: (context, index) {
                    // IMPORTANT: Changed 'cards[index]' to 'dueCards[index]'
                    final card = dueCards[index];

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: FlipCard(
                              frontText: card['front'],
                              backText: card['back'],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 32.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade100,
                                ),
                                onPressed: () => _processReview(card, 'hard'),
                                child: const Text(
                                  'Hard',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade100,
                                ),
                                onPressed: () => _processReview(card, 'good'),
                                child: const Text(
                                  'Good',
                                  style: TextStyle(color: Colors.orange),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade100,
                                ),
                                onPressed: () => _processReview(card, 'easy'),
                                child: const Text(
                                  'Easy',
                                  style: TextStyle(color: Colors.green),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}

// THE 3D FLIP ANIMATION ENGINE
class FlipCard extends StatefulWidget {
  final String frontText;
  final String backText;

  const FlipCard({super.key, required this.frontText, required this.backText});

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    // This controls the speed of the flip (400ms is a smooth swing)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    // This tells the animation to go from 0 to 1
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    _isFront = !_isFront;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          // pi is roughly 3.14 (180 degrees). We multiply our 0-to-1 animation by pi.
          final angle = _animation.value * pi;

          // Are we past the 90-degree mark? (Halfway flipped)
          final isUnder90Degrees = angle < pi / 2;

          return Transform(
            // THE 3D MATH: Matrix4 adds the actual perspective depth!
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isUnder90Degrees
                ? _buildSide(widget.frontText, Colors.white, Colors.black)
                : Transform(
                    // If we don't flip the back 180 degrees, the text will be backwards!
                    transform: Matrix4.identity()..rotateY(pi),
                    alignment: Alignment.center,
                    child: _buildSide(
                      widget.backText,
                      Colors.deepPurple.shade50,
                      Colors.deepPurple,
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildSide(String text, Color bgColor, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: SingleChildScrollView(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

//with name comment tile , self defined widget
class CommentTile extends ConsumerWidget {
  final Map<String, dynamic> comment;

  const CommentTile({super.key, required this.comment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We pass the user_id from the comment to our new provider
    final profileAsync = ref.watch(userProfileProvider(comment['user_id']));

    return profileAsync.when(
      // 1. Loading State
      loading: () => const ListTile(
        leading: CircleAvatar(child: CircularProgressIndicator(strokeWidth: 2)),
        title: Text('Loading...'),
      ),

      // 2. Error State
      error: (err, stack) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.error)),
        title: const Text('Unknown User'),
        subtitle: Text(comment['content']),
      ),

      // 3. Success State!
      data: (profile) {
        // Fallbacks just in case the database row is empty
        final name = profile?['name'] ?? 'Anonymous Student';
        final avatarUrl = profile != null && profile.containsKey('avatar_url')
            ? profile['avatar_url']
            : null;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.deepPurple.shade100,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? const Icon(Icons.person, color: Colors.deepPurple)
                : null,
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          subtitle: Text(
            comment['content'],
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
        );
      },
    );
  }
}

//Chat UI
class ChatBottomSheet extends ConsumerStatefulWidget {
  final String itemId;
  final String spaceId; // Needed so we know which room this is in

  const ChatBottomSheet({
    super.key,
    required this.itemId,
    required this.spaceId,
  });

  @override
  ConsumerState<ChatBottomSheet> createState() => _ChatBottomSheetState();
}

class _ChatBottomSheetState extends ConsumerState<ChatBottomSheet> {
  final _messageController = TextEditingController();
  //message sending
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear(); // Clear the box immediately for good UX

    try {
      final supabase = Supabase.instance.client;
      // SENDING TO THE CLOUD
      await supabase.from('comments').insert({
        'space_id': widget.spaceId,
        'item_id': widget.itemId,
        'user_id': supabase.auth.currentUser!.id,
        'content': text,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // LISTENING TO THE WEBSOCKET
    final commentsAsync = ref.watch(commentsStreamProvider(widget.itemId));

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(
          context,
        ).viewInsets.bottom, // Moves up when keyboard opens
      ),
      height:
          MediaQuery.of(context).size.height *
          0.6, // Takes up 60% of the screen
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Live Discussion',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),

          // THE CHAT MESSAGES
          Expanded(
            child: commentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (comments) {
                if (comments.isEmpty) {
                  return const Center(child: Text('Be the first to comment!'));
                }
                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return CommentTile(comment: comment);
                  },
                );
              },
            ),
          ),

          // THE TEXT INPUT
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Ask a question...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _sendMessage(), // Send on enter key
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurple),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//loading skeleton
class CardLoadingSkeleton extends StatelessWidget {
  const CardLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Container(
          height: 400, // Matches roughly the size of flip card
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}
