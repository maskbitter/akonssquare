import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:akonssquare/Common/database_service.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:akonssquare/Common/theme_manager.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final DatabaseService _dbService = DatabaseService();
  bool _isProcessing = false;
  double _progress = 0.0;
  String _selectedRoleForVisibility = 'admin';

  String _getBackupFileName(num version) {
    DateTime now = DateTime.now();
    String d = now.day.toString().padLeft(2, '0');
    String m = now.month.toString().padLeft(2, '0');
    String y = now.year.toString();
    String h = now.hour.toString().padLeft(2, '0');
    String min = now.minute.toString().padLeft(2, '0');
    String s = now.second.toString().padLeft(2, '0');
    String vStr = version is int ? "${version}.0" : version.toString();
    return "akonssquare_v_${vStr}_${d}${m}${y}_${h}${min}${s}.json";
  }

  Future<void> _handleBackup(BuildContext context) async {
    HapticFeedback.mediumImpact();
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _progress = 0.0;
    });
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String actor = prefs.getString('username') ?? "Unknown";
      Map<String, dynamic> data = await _dbService.exportDatabase(
        actor,
        onProgress: (p) => setState(() => _progress = p),
      );
      String jsonStr = await compute(jsonEncode, data);
      final directory = await getTemporaryDirectory();
      String fileName = _getBackupFileName(data['dbVersion'] ?? 0);
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonStr);
      await Share.shareXFiles([XFile(file.path)], text: 'Database Backup v${data['dbVersion']}');
    } catch (e) {
      if (context.mounted) DatabaseService.showToast(context, "Backup Error: $e", backgroundColor: Theme.of(context).colorScheme.error);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleLocalSave(BuildContext context) async {
    HapticFeedback.mediumImpact();
    if (_isProcessing) return;
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String actor = prefs.getString('username') ?? "Unknown";
      setState(() {
        _isProcessing = true;
        _progress = 0.0;
      });
      Map<String, dynamic> data = await _dbService.exportDatabase(
        actor,
        onProgress: (p) => setState(() => _progress = p),
      );
      String jsonStr = await compute(jsonEncode, data);
      String fileName = _getBackupFileName(data['dbVersion'] ?? 0);
      final Uint8List bytes = Uint8List.fromList(utf8.encode(jsonStr));
      String? result = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (context.mounted && result != null) {
        DatabaseService.showToast(context, "Backup saved: $fileName");
      }
    } catch (e) {
      if (context.mounted) DatabaseService.showToast(context, "Local Save Error: $e", backgroundColor: Theme.of(context).colorScheme.error);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleRestore(BuildContext context) async {
    HapticFeedback.mediumImpact();
    if (_isProcessing) return;
    try {
      final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result == null || result.files.single.path == null) return;
      setState(() {
        _isProcessing = true;
        _progress = 0.0;
      });
      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      Map<String, dynamic> importData = await compute(_parseJson, content);
      num backupVersion = importData['dbVersion'] ?? 1.0;
      double serverVersion = await _dbService.getDBVersion();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String role = prefs.getString('userRole') ?? 'admin';
      bool proceed = false;
      if (role == 'superadmin') {
        if (backupVersion > serverVersion) proceed = await _showConfirmDialog(context, "Restore New Data?", "This will overwrite all current data with backup v$backupVersion.");
        else if (backupVersion == serverVersion) proceed = await _showConfirmDialog(context, "Re-upload Version?", "This backup matches the current server.");
        else {
          bool first = await _showConfirmDialog(context, "WARNING: Older Version", "This backup is OLDER than current. Restore anyway?");
          if (first) proceed = await _showConfirmDialog(context, "Final Verification", "Downgrade server data?");
        }
      } else {
        if (backupVersion > serverVersion) proceed = await _showConfirmDialog(context, "Restore Data?", "Update server data to v$backupVersion?");
        else if (backupVersion == serverVersion) {
          if (context.mounted) _showInfoDialog(context, "Already Restored", "The database is already at version $serverVersion.");
          setState(() => _isProcessing = false); return;
        } else {
          if (context.mounted) _showInfoDialog(context, "Update Denied", "Higher version required.");
          setState(() => _isProcessing = false); return;
        }
      }
      if (proceed && context.mounted) {
        String actor = prefs.getString('username') ?? "Unknown";
        await _dbService.setServerStatus('uploading');
        await _dbService.importDatabase(importData, actor, onProgress: (p) => setState(() => _progress = p));
        await _dbService.setServerStatus('completed');
        if (context.mounted) DatabaseService.showToast(context, "Database Restored Successfully!", backgroundColor: Colors.green);
      }
    } catch (e) {
       if (context.mounted) DatabaseService.showToast(context, "Restore Error: $e", backgroundColor: Theme.of(context).colorScheme.error);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  static Map<String, dynamic> _parseJson(String jsonStr) => jsonDecode(jsonStr);

  Future<void> _handleWipe(BuildContext context) async {
    if (_isProcessing) return;
    try {
      DocumentSnapshot backupInfo = await FirebaseFirestore.instance.collection('app_config').doc('database_info').get();
      bool hasBackup = backupInfo.exists && (backupInfo.data() as Map).containsKey('lastBackupAt');
      bool proceed = false;
      if (!hasBackup) {
        bool backupNow = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Center(child: Text("Backup Required!", style: TextStyle(fontWeight: FontWeight.bold))),
            content: const Text("It is strongly recommended to backup before wiping all data.", textAlign: TextAlign.center),
            actions: [
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel"))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Backup Now"))),
              ]),
            ],
          ),
        ) ?? false;
        if (backupNow) { if (context.mounted) await _handleBackup(context); }
        return;
      }
      bool confirm1 = await _showConfirmDialog(context, "Initial Confirmation", "Delete ALL data?");
      if (confirm1) proceed = await _showConfirmDialog(context, "FINAL WARNING", "Erase all records. PROCEED?");
      if (proceed && context.mounted) {
        setState(() { _isProcessing = true; _progress = 1.0; });
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String actor = prefs.getString('username') ?? "Unknown";
        await _dbService.setServerStatus('wiping');
        await _dbService.wipeDatabase(actor, onProgress: (p) => setState(() => _progress = p));
        await _dbService.setServerStatus('wipe_completed');
        if (context.mounted) DatabaseService.showToast(context, "Server Wiped Successfully!", backgroundColor: Theme.of(context).colorScheme.error);
      }
    } catch (e) {
      if (context.mounted) DatabaseService.showToast(context, "Wipe Error: $e", backgroundColor: Theme.of(context).colorScheme.error);
    } finally { if (mounted) setState(() => _isProcessing = false); }
  }

  void _showInfoDialog(BuildContext context, String title, String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Center(child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
        content: Text(msg, textAlign: TextAlign.center),
        actions: [
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.tertiary, foregroundColor: Theme.of(context).colorScheme.onTertiary),
            onPressed: () => Navigator.pop(ctx), child: const Text("OK"))),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog(BuildContext context, String title, String msg) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Center(child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
        content: Text(msg, textAlign: TextAlign.center),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error, side: BorderSide(color: Theme.of(context).colorScheme.error)), onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel"))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.tertiary, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: const Text("Proceed"))),
          ]),
        ],
      ),
    ) ?? false;
  }

  Widget _buildVisibilitySwitch(String title, bool value, Function(bool) onChanged, {bool isSub = false, IconData? icon}) {
    return SwitchListTile(
      secondary: icon != null ? Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20) : null,
      title: Text(title, style: isSub ? Theme.of(context).textTheme.bodyMedium : Theme.of(context).textTheme.bodyLarge),
      value: value,
      activeColor: Theme.of(context).colorScheme.primary,
      onChanged: (val) { HapticFeedback.selectionClick(); onChanged(val); },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: _dbService.getAppConfigStream(),
              builder: (context, snapshot) {
                bool isEnabled = true;
                if (snapshot.hasData && snapshot.data!.exists) {
                  var data = snapshot.data!.data() as Map<String, dynamic>?;
                  isEnabled = data?['isPopupEnabled'] ?? true;
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    elevation: 2, color: Theme.of(context).colorScheme.primaryContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ExpansionTile(
                      leading: Icon(Icons.settings_suggest_outlined, color: Theme.of(context).colorScheme.primary),
                      title: Text("System Configuration", style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                      subtitle: Text("Control system notifications", style: Theme.of(context).textTheme.bodySmall),
                      children: [
                        SwitchListTile(
                          title: Text("Enable Update Notifications", style: Theme.of(context).textTheme.bodyLarge),
                          value: isEnabled, activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (val) async {
                            await _dbService.updatePopupStatus(val);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                elevation: 2, color: Theme.of(context).colorScheme.secondaryContainer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ExpansionTile(
                  leading: Icon(Icons.security_outlined, color: Theme.of(context).colorScheme.secondary),
                  title: Text("Dashboard Visibility", style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.secondary)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(children: [
                        Icon(Icons.person_search_outlined, size: 20, color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 12),
                        Text("Role:", style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: _selectedRoleForVisibility,
                          items: const [DropdownMenuItem(value: 'admin', child: Text("Admin")), DropdownMenuItem(value: 'operator', child: Text("Operator")), DropdownMenuItem(value: 'viewer', child: Text("Viewer"))],
                          onChanged: (val) { if (val != null) setState(() => _selectedRoleForVisibility = val); },
                        ),
                      ]),
                    ),
                    StreamBuilder<DocumentSnapshot>(
                      stream: _dbService.getDashboardVisibilityStream(_selectedRoleForVisibility),
                      builder: (context, snapshot) {
                        Map<String, bool> settings = {'showAccounts': true, 'showElectricity': true, 'showMainVsSub': true, 'showMainVsGovt': true, 'showCategory': true};
                        if (snapshot.hasData && snapshot.data!.exists) {
                          var data = snapshot.data!.data() as Map<String, dynamic>;
                          (data['settings'] ?? {}).forEach((k, v) => settings[k] = v as bool);
                        }
                        return Column(children: [
                          _buildVisibilitySwitch("Show Accounts", settings['showAccounts']!, (val) { settings['showAccounts'] = val; _dbService.updateDashboardVisibility(_selectedRoleForVisibility, settings); }, icon: Icons.account_balance_wallet_outlined),
                          _buildVisibilitySwitch("Show Electricity", settings['showElectricity']!, (val) { settings['showElectricity'] = val; _dbService.updateDashboardVisibility(_selectedRoleForVisibility, settings); }, icon: Icons.electric_bolt_outlined),
                          _buildVisibilitySwitch("Show Category", settings['showCategory']!, (val) { settings['showCategory'] = val; _dbService.updateDashboardVisibility(_selectedRoleForVisibility, settings); }, icon: Icons.category_outlined),
                        ]);
                      }
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                elevation: 2, color: Theme.of(context).colorScheme.tertiaryContainer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ExpansionTile(
                  leading: Icon(Icons.storage_outlined, color: Theme.of(context).colorScheme.tertiary),
                  title: Text("Data Management", style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.tertiary)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(children: [
                        Row(children: [
                          Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.tertiary, foregroundColor: Colors.white), onPressed: _isProcessing ? null : () => _handleBackup(context), child: const Text("Backup"))),
                          const SizedBox(width: 12),
                          Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.tertiary, foregroundColor: Colors.white), onPressed: _isProcessing ? null : () => _handleRestore(context), child: const Text("Restore"))),
                        ]),
                        const SizedBox(height: 12),
                        SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white), onPressed: _isProcessing ? null : () => _handleLocalSave(context), child: const Text("Save Locally"))),
                        if (_isProcessing) LinearProgressIndicator(value: _progress, color: Theme.of(context).colorScheme.primary),
                        FutureBuilder<SharedPreferences>(
                          future: SharedPreferences.getInstance(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data!.getString('userRole') == 'superadmin') {
                              return Column(children: [
                                const Divider(),
                                SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Colors.white), onPressed: _isProcessing ? null : () => _handleWipe(context), child: const Text("Wipe Data"))),
                              ]);
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                elevation: 2, color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ExpansionTile(
                  leading: Icon(Icons.manage_accounts_outlined, color: Theme.of(context).colorScheme.primary),
                  title: Text("Account Management", style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(children: [
                        SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.tertiary, foregroundColor: Colors.white), onPressed: () => _showUserDialog(context), child: const Text("Add Account"))),
                        const SizedBox(height: 12),
                        _buildUsersTable(),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                elevation: 2, color: Theme.of(context).colorScheme.surfaceContainer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ExpansionTile(
                  leading: Icon(Icons.palette_outlined, color: Theme.of(context).colorScheme.primary),
                  title: Text("Theme & Appearance", style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.tertiary, foregroundColor: Colors.white), onPressed: () => _showThemeSelectionDialog(context), child: const Text("Change Theme"))),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeSelectionDialog(BuildContext context) {
    String localSelectedTheme = ThemeManager.appThemeNotifier.value;
    final List<String> themes = ["Default Theme"];
    bool isApplying = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: isApplying ? null : Center(child: Text("Select Theme", style: Theme.of(context).textTheme.titleLarge)),
          content: isApplying ? const CircularProgressIndicator() : DropdownButton<String>(
            value: localSelectedTheme, isExpanded: true,
            items: themes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (val) { if (val != null) setDialogState(() => localSelectedTheme = val); },
          ),
          actions: isApplying ? null : [
            Row(children: [
              Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error, side: BorderSide(color: Theme.of(context).colorScheme.error)), onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.tertiary, foregroundColor: Colors.white), onPressed: () async {
                setDialogState(() => isApplying = true);
                await Future.delayed(const Duration(milliseconds: 500));
                await ThemeManager.setTheme(localSelectedTheme);
                if (ctx.mounted) Navigator.pop(ctx);
              }, child: const Text("Apply"))),
            ]),
          ],
        );
      }),
    );
  }

  Widget _buildUsersTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getUsersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        var users = snapshot.data!.docs;
        return Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            ...users.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              return TableRow(children: [
                Padding(padding: const EdgeInsets.all(8.0), child: Text(data['username'] ?? '')),
                Padding(padding: const EdgeInsets.all(8.0), child: Text(data['role'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                IconButton(icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary), onPressed: () => _showUserDialog(context, docId: doc.id, currentData: data)),
                IconButton(icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error), onPressed: () => _confirmRemove(doc.id, data['username'])),
              ]);
            }).toList(),
          ],
        );
      },
    );
  }

  void _showUserDialog(BuildContext context, {String? docId, Map<String, dynamic>? currentData}) {
    final userController = TextEditingController(text: currentData?['username'] ?? '');
    final passController = TextEditingController(text: currentData?['password'] ?? '');
    String selectedRole = currentData?['role'] ?? 'operator';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Center(child: Text(docId == null ? "Add Account" : "Edit Account", style: Theme.of(context).textTheme.titleLarge)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: userController, decoration: const InputDecoration(labelText: "Username")),
            TextField(controller: passController, decoration: const InputDecoration(labelText: "Password")),
            DropdownButton<String>(value: selectedRole, items: const [DropdownMenuItem(value: 'admin', child: Text("Admin")), DropdownMenuItem(value: 'operator', child: Text("Operator")), DropdownMenuItem(value: 'viewer', child: Text("Viewer"))], onChanged: (v) => setDialogState(() => selectedRole = v!)),
          ]),
          actions: [
            Row(children: [
              Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error, side: BorderSide(color: Theme.of(context).colorScheme.error)), onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white), onPressed: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await _dbService.saveUser(userController.text, passController.text, selectedRole, prefs.getString('username') ?? '', docId: docId);
                if (ctx.mounted) Navigator.pop(ctx);
              }, child: const Text("Save"))),
            ]),
          ],
        );
      }),
    );
  }

  void _confirmRemove(String docId, String username) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Remove Account?"),
        content: Text("Are you sure you want to remove user '$username'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(onPressed: () async {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await _dbService.removeUser(docId, prefs.getString('username') ?? '');
            if (mounted) Navigator.pop(ctx);
          }, child: const Text("Remove", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
