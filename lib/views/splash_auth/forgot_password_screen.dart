import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _message;

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      setState(() {
        _message = 'Password reset link sent! Check your inbox.';
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _message = e.message ?? 'An error occurred';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Password Recovery')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter your registered email to receive a password reset link.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email Address'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 24),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(_message!),
                ),
              ElevatedButton(
                onPressed: _isLoading ? null : _resetPassword,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('SEND RESET LINK'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}