import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:akonssquare/Admin/settings_page.dart';
import 'package:akonssquare/main.dart';

class SuperAdminDashboard extends StatelessWidget {
  const SuperAdminDashboard({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (context.mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("System Recovery", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text("Master Access Mode", style: TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.orangeAccent),
            onPressed: () => _handleLogout(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: const SettingsPage(),
    );
  }
}
