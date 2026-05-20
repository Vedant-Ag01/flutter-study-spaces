import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'spaces_provider.dart';

// This provider will require a 'spaceId' so it knows WHICH room's decks to fetch!
final decksStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, spaceId) {
      final supabase = ref.watch(supabaseProvider);

      // Fetch all decks where the space_id matches the room we are currently inside
      return supabase
          .from('decks')
          .stream(primaryKey: ['id'])
          .eq('space_id', spaceId)
          .order('created_at', ascending: false);
    });
