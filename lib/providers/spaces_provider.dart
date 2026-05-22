import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseProvider = Provider((ref) => Supabase.instance.client);

final spacesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final supabase = ref.watch(supabaseProvider);

  return supabase
      .from('spaces')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: true);
});
