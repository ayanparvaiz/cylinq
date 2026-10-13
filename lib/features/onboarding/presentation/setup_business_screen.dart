import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/auth_card.dart';
import '../../auth/data/auth_repository.dart';
import '../../session/session.dart';
import '../data/onboarding_repository.dart';

class SetupBusinessScreen extends ConsumerStatefulWidget {
  const SetupBusinessScreen({super.key});

  @override
  ConsumerState<SetupBusinessScreen> createState() => _SetupBusinessScreenState();
}

class _SetupBusinessScreenState extends ConsumerState<SetupBusinessScreen> {
  final _form = GlobalKey<FormState>();
  // Sign-up stores the name on the auth profile; the cached user object may
  // not have it yet, so it is shown here to confirm or fill in.
  late final _name = TextEditingController(text: ref.read(firebaseAuthProvider).currentUser?.displayName);
  final _business = TextEditingController();
  final _prefix = TextEditingController();
  final _phone = TextEditingController();
  bool _prefixEdited = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _business.dispose();
    _prefix.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final state = ref.read(sessionStateProvider);
    if (state is! NeedsBusiness || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = state.user;
      await ref.read(onboardingRepositoryProvider).createBusiness(
        owner: user,
        ownerName: _name.text,
        businessName: _business.text,
        labelPrefix: _prefix.text,
        phone: _phone.text,
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not create the business: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AuthCard(
      title: 'Set up your business',
      subtitle: 'This name and prefix are printed on every cylinder label.',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => v != null && v.trim().isNotEmpty ? null : 'Enter your name',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _business,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Business name',
                  hintText: 'Shanti Gas Agency',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                onChanged: (v) {
                  if (!_prefixEdited) _prefix.text = suggestPrefix(v);
                },
                validator: (v) => v != null && v.trim().isNotEmpty ? null : 'Enter the business name',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _prefix,
                textCapitalization: TextCapitalization.characters,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Label prefix',
                  helperText: 'Serials will look like SGA-00001',
                  prefixIcon: Icon(Icons.qr_code_2),
                ),
                onChanged: (_) => _prefixEdited = true,
                validator: (v) => v != null && RegExp(r'^[A-Za-z0-9]{1,4}$').hasMatch(v.trim())
                    ? null
                    : '1–4 letters or digits',
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (printed on labels)',
                  prefixIcon: Icon(Icons.call_outlined),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FormError(_error),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
              : const Text('Create business'),
        ),
        const SizedBox(height: 18),
        Text(
          'Working for someone? Ask the owner to add you from their Staff page, then sign in again.',
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
        TextButton(
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}
