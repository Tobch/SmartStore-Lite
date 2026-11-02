import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'Staff'; // Default role

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Register for SmartStore',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter full name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email Address'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (v) => v == null || v.length < 6 ? 'Password must be >= 6 characters' : null,
                ),
                const SizedBox(height: 20),
                // Role Selection (Requirement #1)
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Account Role'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedRole,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'Staff', child: Text('Staff Member')),
                        DropdownMenuItem(value: 'Manager', child: Text('Manager')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedRole = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (authVM.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      authVM.errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ElevatedButton(
                  onPressed: authVM.isLoading
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            bool success = await context.read<AuthViewModel>().register(
                                  _nameController.text.trim(),
                                  _emailController.text.trim(),
                                  _passwordController.text.trim(),
                                  _selectedRole,
                                );
                            if (success && mounted) {
                              Navigator.pop(context);
                            }
                          }
                        },
                  child: authVM.isLoading
                      ? const CircularProgressIndicator()
                      : const Text('REGISTER'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}