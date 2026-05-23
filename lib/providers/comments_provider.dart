import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// This provider takes an 'itemId' or deckId
// and listens for any comments tied exactly to that deck.
final commentsStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, itemId) {
      final supabase = Supabase.instance.client;

      return supabase
          .from('comments')
          .stream(primaryKey: ['id'])
          .eq('item_id', itemId) // Only get messages for this specific deck
          .order(
            'created_at',
            ascending: true,
          ); // Oldest at the top, newest at the bottom
    });
