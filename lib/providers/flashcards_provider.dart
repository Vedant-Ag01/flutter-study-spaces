import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'spaces_provider.dart';

// This provider will require a 'deckId' so it knows which cards to fetch!
final flashcardsStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, deckId) {
      final supabase = ref.watch(supabaseProvider);

      // Fetch all flashcards belonging to this specific deck
      return supabase
          .from('flashcards')
          .stream(primaryKey: ['id'])
          .eq('deck_id', deckId)
          .order(
            'created_at',
            ascending: true,
          ); // Ascending so the oldest cards show first
    });
