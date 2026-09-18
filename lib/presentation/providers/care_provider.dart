import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_config.dart';
import '../../data/repositories/care_repository.dart';

final careRepositoryProvider = Provider<CareRepository?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  try {
    return CareRepository(Supabase.instance.client);
  } catch (_) {
    return null;
  }
});

final accessibleChildrenProvider = FutureProvider<List<CareChild>>((ref) async {
  final repository = ref.watch(careRepositoryProvider);
  if (repository == null) return const [];
  return repository.getAccessibleChildren();
});
