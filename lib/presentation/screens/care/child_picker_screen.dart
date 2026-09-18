import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/care_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_ui.dart';

class ChildPickerScreen extends ConsumerWidget {
  const ChildPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(accessibleChildrenProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Select a child')),
      body: SafeArea(
        top: false,
        child: children.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('Could not load assigned children.')),
          data: (items) {
            if (items.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No children are assigned to this care-worker account yet.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final child = items[index];
                return AppSurface(
                  onTap: () {
                    ref.read(sessionProvider.notifier).selectCareChild(child);
                    context.push('/child-profile');
                  },
                  child: Row(
                    children: [
                      const AppIconBadge(
                        icon: Icons.child_care_outlined,
                        size: 44,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          child.displayName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
