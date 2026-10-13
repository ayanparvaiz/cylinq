import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/auth_card.dart';
import '../../auth/data/auth_repository.dart';

class NoAccessScreen extends ConsumerWidget {
  const NoAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuthCard(
      title: 'Access paused',
      subtitle: 'Your login works, but the business owner has switched off your access. '
          'Ask them to turn it back on from the Staff page.',
      children: [
        FilledButton.tonal(
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}
