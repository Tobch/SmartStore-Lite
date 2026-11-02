import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsVM = context.watch<SettingsViewModel>();
    final authVM = context.watch<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('User Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(authVM.currentUser?.name ?? 'Guest User'),
            subtitle: Text(authVM.currentUser?.email ?? 'No Email'),
            trailing: Chip(label: Text(authVM.currentUser?.role ?? 'Staff')),
          ),
          const Divider(height: 32),
          const Text('Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          SwitchListTile(
            title: const Text('Dark Theme'),
            value: settingsVM.isDarkMode,
            onChanged: (val) => settingsVM.toggleTheme(val),
          ),
          ListTile(
            title: const Text('Global Low-Stock Threshold'),
            subtitle: Text('Current warning limit: ${settingsVM.globalLowStockThreshold} units'),
            trailing: SizedBox(
              width: 80,
              child: TextField(
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: settingsVM.globalLowStockThreshold.toString()),
                onSubmitted: (val) {
                  int? parsed = int.tryParse(val);
                  if (parsed != null) settingsVM.updateThreshold(parsed);
                },
              ),
            ),
          ),
          const Divider(height: 32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100, foregroundColor: Colors.red.shade900),
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            onPressed: () async {
              await authVM.logout();
              if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
    );
  }
}