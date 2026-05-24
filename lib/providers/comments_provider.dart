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

// The autoDispose modifier ensures the cache is shredded when the user leaves the screen, i used future provider here instead of
//stream as it will put a heavy load on the server if 30 websockets are open for 30 members in a single space just for looking for instantaneous name changes
final userProfileProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, userId) async {
      final supabase = Supabase.instance.client;

      try {
        final data = await supabase
            .from('profiles')
            .select('name, avatar_url')
            .eq('id', userId)
            .maybeSingle();

        return data;
      } catch (e) {
        return null;
      }
    });
