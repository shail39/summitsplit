import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/user_profile.dart';

class OnboardingScreen extends StatefulWidget {
  final String? pendingDeepLink;
  const OnboardingScreen({super.key, this.pendingDeepLink});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await UserProfile.save(
      _nameCtrl.text.trim(),
      _emailCtrl.text.trim().toLowerCase(),
    );
    if (mounted) context.go(widget.pendingDeepLink ?? '/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome to\nSummit Split',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set up your profile so your friends can recognize you in trips.',
                    style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 36),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Your name',
                      hintText: 'e.g. Alex',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    autofocus: true,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'alex@example.com',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required';
                      if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your email is used to automatically identify you when you join trips.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _continue,
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Get Started', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
