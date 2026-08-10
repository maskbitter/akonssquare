import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:akonssquare/Admin/settings_page.dart';
import 'package:akonssquare/main.dart';
import 'package:akonssquare/Common/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  final DatabaseService _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRollback());
  }

  Future<void> _checkRollback() async {
    bool hasSnapshot = await _dbService.hasRollbackSnapshot();
    if (!hasSnapshot) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text("Interrupted Job"),
          ],
        ),
        content: const Text("A previous database operation was interrupted. Rollback to safe state?"),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _dbService.clearRollbackSnapshot();
            },
            child: const Text("Ignore", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showRollbackProgressDialog();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text("Rollback Now"),
          ),
        ],
      ),
    );
  }

  void _showRollbackProgressDialog() {
    final progressNotifier = ValueNotifier<double>(0.0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Rolling Back...", textAlign: TextAlign.center),
        content: ValueListenableBuilder<double>(
          valueListenable: progressNotifier,
          builder: (context, value, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                LinearProgressIndicator(value: value),
                const SizedBox(height: 10),
                Text("${(value * 100).toStringAsFixed(1)}%", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            );
          },
        ),
      ),
    );

    _dbService.restoreFromRollback("SuperAdmin", onProgress: (p) {
      progressNotifier.value = p;
    }).then((_) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      DatabaseService.showToast(context, "Rollback Successful!");
    }).catchError((e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      DatabaseService.showToast(context, "Rollback Failed: $e", backgroundColor: Colors.red);
    });
  }

  Future<void> _handleLogout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("System Recovery", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onPrimary)),
            Text("Master Access Mode", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onPrimary)),
          ],
        ),
        actions: [
          InkWell(
            onTap: () => _handleLogout(context),
            child: StreamBuilder<DocumentSnapshot>(
              stream: DatabaseService().getAppConfigStream(),
              builder: (context, configSnap) {
                return StreamBuilder<DocumentSnapshot>(
                  stream: DatabaseService().getDatabaseInfoStream(),
                  builder: (context, dbInfoSnap) {
                    return FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, pSnap) {
                        String local = pSnap.hasData ? "${pSnap.data!.version}+${pSnap.data!.buildNumber}" : "...";
                        String? remote = configSnap.data?.exists == true ? configSnap.data!['requiredVersion'] : null;
                        String dbVersion = "...";
                        if (dbInfoSnap.hasData && dbInfoSnap.data!.exists) {
                          dbVersion = (dbInfoSnap.data!['dbVersion'] ?? 26.0).toStringAsFixed(1);
                        }
                        
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(local, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 9)),
                              if (remote != null && remote != local)
                                Text("Latest: $remote", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold, fontSize: 8)),
                              Icon(Icons.power_settings_new, color: Theme.of(context).colorScheme.error, size: 18),
                              Text("DB V-$dbVersion", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 9)),
                            ],
                          );
                      }
                    );
                  }
                );
              }
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: const SettingsPage(),
    );
  }
}
