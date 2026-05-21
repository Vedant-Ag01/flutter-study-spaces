import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/flashcards_provider.dart';

class StudyScreen extends ConsumerStatefulWidget {
  final String deckId;
  final String deckTitle;

  const StudyScreen({super.key, required this.deckId, required this.deckTitle});

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // We grab the exact same provider we used on the DeckScreen!
    final cardsAsync = ref.watch(flashcardsStreamProvider(widget.deckId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Studying: ${widget.deckTitle}'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: cardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (cards) {
          if (cards.isEmpty) {
            return const Center(child: Text('No cards to study!'));
          }

          return Column(
            children: [
              // Progress Tracker
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Card ${_currentIndex + 1} of ${cards.length}',
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
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    return Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: FlipCard(
                        frontText: card['front'],
                        backText: card['back'],
                      ),
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
