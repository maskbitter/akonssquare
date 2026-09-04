import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:akons_square/Admin/settings_page.dart';
import 'package:akons_square/main.dart';
import 'package:akons_square/Common/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:akons_square/Common/build_config.dart';
import 'package:akons_square/Common/update_guard.dart';
import 'package:akons_square/Common/theme_manager.dart';
import 'package:akons_square/Common/ui_helper.dart';
import 'package:akons_square/Common/share_helper.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  final DatabaseService _dbService = DatabaseService();
  String _appName = "";

  @override
  void initState() {
    super.initState();
    _loadAppName();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRollback());
  }

  Future<void> _loadAppName() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appName = packageInfo.appName;
      });
    }
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
          AppDialogActions(
            actions: [
              AppButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _dbService.clearRollbackSnapshot();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text("Ignore"),
              ),
              AppButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showRollbackProgressDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange, 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Rollback Now"),
              ),
            ],
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

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Center(child: Text("Logout Confirmation", style: Theme.of(context).textTheme.titleLarge)),
          content: Text("Are you sure you want to logout?", textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            AppDialogActions(
              actions: [
                AppButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant, 
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                AppButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error, 
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _handleLogout(context);
                  },
                  child: const Text("Logout"),
                ),
              ],
            ),
          ],
        );
      },
    );
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
    bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: isOutline ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.primary,
        foregroundColor: isOutline ? Colors.black : Theme.of(context).colorScheme.onPrimary,
        elevation: isOutline ? 0 : 2,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _appName.isEmpty ? "Loading..." : _appName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: isOutline ? Colors.black : Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "System",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isOutline ? Colors.black : Theme.of(context).colorScheme.onPrimary),
                ),
                Text(
                  " | ", 
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isOutline ? Colors.black.withValues(alpha: 0.5) : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)),
                ),
                Text(
                  "Super Admin(Master Access Mode)",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isOutline ? Colors.black : Theme.of(context).colorScheme.onPrimary, 
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_outlined, color: isOutline ? Colors.black : Theme.of(context).colorScheme.onPrimary),
            onPressed: () => ShareHelper.shareApp(context),
            tooltip: "Share App",
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: DatabaseService().getAppConfigStream(),
            builder: (context, configSnap) {
              return StreamBuilder<DocumentSnapshot>(
                stream: DatabaseService().getDatabaseInfoStream(),
                builder: (context, dbInfoSnap) {
                  String local = appVersion; // Instant update from build_config.dart
                  final configData = configSnap.data?.data() as Map<String, dynamic>?;
                  String? remote = configData?['requiredVersion'];
                  String dbVersion = "...";
                  if (dbInfoSnap.hasData && dbInfoSnap.data!.exists) {
                    var data = dbInfoSnap.data!.data() as Map<String, dynamic>?;
                    dbVersion = (data?['dbVersion'] ?? DatabaseService.defaultDbVersion).toDouble().toStringAsFixed(1);
                  }
                  
                  bool isOutdated = false;
                  if (remote != null && remote != local) {
                    try {
                      List<String> localParts = local.split('+');
                      List<String> serverParts = remote.split('+');
                      int localMain = int.tryParse(localParts[0].replaceAll('.', '')) ?? 0;
                      int serverMain = int.tryParse(serverParts[0].replaceAll('.', '')) ?? 0;
                      if (serverMain > localMain) {
                        isOutdated = true;
                      } else if (serverMain == localMain && serverParts.length > 1 && localParts.length > 1) {
                        int localBuild = int.tryParse(localParts[1]) ?? 0;
                        int serverBuild = int.tryParse(serverParts[1]) ?? 0;
                        if (serverBuild > localBuild) isOutdated = true;
                      }
                    } catch (e) { isOutdated = remote != local; }
                  }
                  
                  return InkWell(
                    onTap: () {
                      if (isOutdated) {
                        String dUrl = configData?['downloadUrl'] ?? "";
                        showUpdateLogoutDialog(
                          context: context, 
                          remoteVersion: remote ?? "Unknown", 
                          downloadUrl: dUrl, 
                          onLogout: () => _handleLogout(context)
                        );
                      } else {
                        _showLogoutConfirmationDialog();
                      }
                    },
                    child: AppVersionInfo(
                      version: local,
                      dbVersion: dbVersion,
                      latestVersion: remote,
                      isOutdated: isOutdated,
                      color: isOutline ? Colors.black : Theme.of(context).colorScheme.onPrimary,
                      secondaryColor: isOutline ? Colors.black : Theme.of(context).colorScheme.onPrimary,
                      showLogoutIcon: true,
                    ),
                  );
                }
              );
            }
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          _buildPermissionManagerSection(),
          const Divider(height: 1),
          const Expanded(child: SettingsPage()),
        ],
      ),
    );
  }

  Widget _buildPermissionManagerSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.admin_panel_settings_outlined, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text("Admin Permission Control", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Manage access levels for administrative accounts. Click an account to expand permissions.",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'admin').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              var admins = snapshot.data!.docs;
              if (admins.isEmpty) return const Text("No Admin accounts found.");

              return Column(
                children: admins.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String username = data['username'] ?? 'Admin';
                  Map<String, dynamic> perms = data['permissions'] ?? {
                    'canSeeSecurityLogs': false,
                    'canControlVisibility': false,
                    'canManageData': false,
                    'canManageAccounts': false,
                  };

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                    ),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Text(username[0].toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Account Permissions", style: Theme.of(context).textTheme.labelSmall),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      children: [
                        const Divider(),
                        _buildPermSwitch(doc.id, "Allow this admin to view and audit system security logs", perms['canSeeSecurityLogs'] ?? false, 'canSeeSecurityLogs', perms),
                        _buildPermSwitch(doc.id, "Allow this admin to control dashboard section visibility for all roles", perms['canControlVisibility'] ?? false, 'canControlVisibility', perms),
                        _buildPermSwitch(doc.id, "Allow this admin to perform critical data management (Backup, Restore, Wipe)", perms['canManageData'] ?? false, 'canManageData', perms),
                        _buildPermSwitch(doc.id, "Allow this admin to create and manage system access accounts", perms['canManageAccounts'] ?? false, 'canManageAccounts', perms),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPermSwitch(String docId, String fullSentence, bool value, String key, Map<String, dynamic> currentPerms) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(fullSentence, style: const TextStyle(fontSize: 12)),
      value: value,
      activeColor: Theme.of(context).colorScheme.primary,
      onChanged: (bool newVal) async {
        Map<String, bool> newPerms = Map<String, bool>.from(currentPerms.map((k, v) => MapEntry(k, v as bool)));
        newPerms[key] = newVal;
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await _dbService.updateUserPermissions(docId, newPerms, prefs.getString('username') ?? 'SuperAdmin');
        DatabaseService.vibrate();
      },
    );
  }

}
