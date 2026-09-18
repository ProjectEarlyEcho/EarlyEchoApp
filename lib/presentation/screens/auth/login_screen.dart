import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/app_ui.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  AppUserRole _role = AppUserRole.parent;
  bool _createParentAccount = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(appAuthProvider.notifier);
    if (_createParentAccount) {
      await notifier.signUpParent(
        displayName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
    } else {
      await notifier.signIn(
        email: _emailController.text,
        password: _passwordController.text,
        expectedRole: _role,
      );
    }
    if (!mounted || !ref.read(appAuthProvider).signedIn) return;
    if (ref.read(appAuthProvider).canSyncScreenings) {
      await ref.read(syncProvider.notifier).syncNow();
    }
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(appAuthProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('EarlyEcho sign in')),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AppSurface(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _createParentAccount
                            ? 'Create a parent account'
                            : 'Sign in to EarlyEcho',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 20),
                      SegmentedButton<AppUserRole>(
                        segments: const [
                          ButtonSegment(
                            value: AppUserRole.parent,
                            label: Text('Parent'),
                          ),
                          ButtonSegment(
                            value: AppUserRole.careWorker,
                            label: Text('Care worker'),
                          ),
                        ],
                        selected: {_role},
                        onSelectionChanged: (selected) => setState(() {
                          _role = selected.first;
                          if (_role != AppUserRole.parent) {
                            _createParentAccount = false;
                          }
                        }),
                      ),
                      if (_createParentAccount) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Name'),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter your name'
                              : null,
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                        ),
                        validator: (value) =>
                            value == null || !value.contains('@')
                            ? 'Enter a valid email address'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                        validator: (value) => value == null || value.length < 8
                            ? 'Password must have at least 8 characters'
                            : null,
                      ),
                      if (auth.error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          auth.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: auth.loading ? null : _submit,
                        child: Text(
                          auth.loading
                              ? 'Please wait...'
                              : _createParentAccount
                              ? 'Create account'
                              : 'Sign in',
                        ),
                      ),
                      if (_role == AppUserRole.parent)
                        TextButton(
                          onPressed: () => setState(
                            () => _createParentAccount = !_createParentAccount,
                          ),
                          child: Text(
                            _createParentAccount
                                ? 'Already have an account? Sign in'
                                : 'Create a parent account',
                          ),
                        ),
                      if (_role == AppUserRole.careWorker)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Care-worker accounts are provisioned by your organisation.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
