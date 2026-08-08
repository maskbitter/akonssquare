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
    // Format: akonssquare_v_12.0_05082026_132525.json
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

      // 1. Get Data (This generates the Map with incremented version)
      Map<String, dynamic> data = await _dbService.exportDatabase(
        actor,
        onProgress: (p) => setState(() => _progress = p),
      );

      // 2. Heavy JSON Encoding in background
      String jsonStr = await compute(jsonEncode, data);

      // 3. Save to Temp File
      final directory = await getTemporaryDirectory();
      String fileName = _getBackupFileName(data['dbVersion'] ?? 0);
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonStr);

      // 4. Share
      await Share.shareXFiles([XFile(file.path)], text: 'Database Backup v${data['dbVersion']}');
    } catch (e) {
      if (context.mounted) DatabaseService.showToast(context, "Backup Error: $e", backgroundColor: Colors.red);
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

      // 1. Get Data
      Map<String, dynamic> data = await _dbService.exportDatabase(
        actor,
        onProgress: (p) => setState(() => _progress = p),
      );

      // 2. Heavy JSON Encoding in background
      String jsonStr = await compute(jsonEncode, data);
      String fileName = _getBackupFileName(data['dbVersion'] ?? 0);

      // 3. Save File
      final Uint8List bytes = Uint8List.fromList(utf8.encode(jsonStr));
      String? result = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (context.mounted && result != null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        DatabaseService.showToast(context, "Backup saved: $fileName");
      }
    } catch (e) {
      if (context.mounted) DatabaseService.showToast(context, "Local Save Error: $e", backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleRestore(BuildContext context) async {
    HapticFeedback.mediumImpact();
    if (_isProcessing) return;
    try {
      // 1. Pick File
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) return;

      setState(() {
        _isProcessing = true;
        _progress = 0.0;
      });

      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      Map<String, dynamic> importData = await compute(_parseJson, content);

      // 2. Version Check & Permissions
      num backupVersion = importData['dbVersion'] ?? 1.0;
      double serverVersion = await _dbService.getDBVersion();
      
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String role = prefs.getString('userRole') ?? 'admin';

      bool proceed = false;
      
      if (role == 'superadmin') {
        // Superadmin bypass: can restore any version (higher, same, or lower)
        if (backupVersion > serverVersion) {
          proceed = await _showConfirmDialog(context, "Restore New Data?", "This will overwrite all current data with backup v$backupVersion.");
        } else if (backupVersion == serverVersion) {
          proceed = await _showConfirmDialog(context, "Re-upload Version?", "This backup (v$backupVersion) matches the current server. Overwrite anyway?");
        } else {
          // Lower version - Warn Superadmin
          bool first = await _showConfirmDialog(context, "WARNING: Older Version", "This backup (v$backupVersion) is OLDER than current (v$serverVersion). Restore anyway?");
          if (first) {
            proceed = await _showConfirmDialog(context, "Final Verification", "Are you 100% sure you want to downgrade server data to v$backupVersion?");
          }
        }
      } else {
        // Regular Admin permissions
        if (backupVersion > serverVersion) {
          proceed = await _showConfirmDialog(context, "Restore Data?", "This will update server data to v$backupVersion. This cannot be undone.");
        } else if (backupVersion == serverVersion) {
          if (context.mounted) {
            _showInfoDialog(context, "Already Restored", "The database is already at version $serverVersion. Please contact the system authority if a re-upload is required.");
          }
          setState(() => _isProcessing = false);
          return;
        } else {
          if (context.mounted) {
            _showInfoDialog(context, "Update Denied", "Admins can only restore backup versions HIGHER than the current server (v$serverVersion). Please contact the system authority for assistance.");
          }
          setState(() => _isProcessing = false);
          return;
        }
      }

      if (proceed && context.mounted) {
        String actor = prefs.getString('username') ?? "Unknown";
        
        await _dbService.setServerStatus('uploading');

        await _dbService.importDatabase(
          importData, 
          actor,
          onProgress: (p) => setState(() => _progress = p),
        );

        await _dbService.setServerStatus('completed');

        if (context.mounted) DatabaseService.showToast(context, "Database Restored Successfully!", backgroundColor: Colors.green);
      }
    } catch (e) {
       if (context.mounted) DatabaseService.showToast(context, "Restore Error: $e", backgroundColor: Colors.red);
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
            content: const Text("You haven't taken any backup yet. It is strongly recommended to backup before wiping all data.", textAlign: TextAlign.center),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            actions: [
              Row(
                children: [
                  Expanded(child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel"))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(ctx, true), child: const Text("Backup Now"))),
                ],
              ),
            ],
          ),
        ) ?? false;

        if (backupNow) {
          if (context.mounted) await _handleBackup(context);
        }
        return;
      }

      bool confirm1 = await _showConfirmDialog(context, "Initial Confirmation", "Are you sure you want to delete ALL data from the server? This cannot be undone unless you have a backup.");
      if (confirm1) {
        proceed = await _showConfirmDialog(context, "FINAL WARNING", "This will permanently ERASE all rooms, categories, users, and billing history. PROCEED?");
      }

      if (proceed && context.mounted) {
        setState(() {
          _isProcessing = true;
          _progress = 1.0; // Start at 100% for countdown
        });
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String actor = prefs.getString('username') ?? "Unknown";

        await _dbService.setServerStatus('wiping');

        await _dbService.wipeDatabase(
          actor,
          onProgress: (p) => setState(() => _progress = p),
        );

        await _dbService.setServerStatus('wipe_completed');

        if (context.mounted) DatabaseService.showToast(context, "Server Wiped Successfully!", backgroundColor: Colors.red);
      }
    } catch (e) {
      if (context.mounted) DatabaseService.showToast(context, "Wipe Error: $e", backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showInfoDialog(BuildContext context, String title, String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Center(child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
        content: Text(msg, textAlign: TextAlign.center),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, side: BorderSide(color: Colors.grey.shade300)),
              onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
          ),
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
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          Row(
            children: [
              Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel"))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true), child: const Text("Proceed"))),
            ],
          ),
        ],
      ),
    ) ?? false;
  }

  Widget _buildVisibilitySwitch(String title, bool value, Function(bool) onChanged, {bool isSub = false, IconData? icon}) {
    return SwitchListTile(
      secondary: icon != null ? Icon(icon, color: Colors.indigo, size: 20) : null,
      title: Text(title, style: TextStyle(fontSize: isSub ? 13 : 14, fontWeight: isSub ? FontWeight.normal : FontWeight.w500)),
      value: value,
      activeColor: Colors.indigo,
      onChanged: (val) {
        HapticFeedback.selectionClick();
        onChanged(val);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: System Configuration (Toggle)
            StreamBuilder<DocumentSnapshot>(
              stream: _dbService.getAppConfigStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text("Config Error: ${snapshot.error}");
                
                bool isEnabled = true;
                if (snapshot.hasData && snapshot.data!.exists) {
                  var data = snapshot.data!.data() as Map<String, dynamic>?;
                  isEnabled = data?['isPopupEnabled'] ?? true;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ExpansionTile(
                      leading: const Icon(Icons.settings_suggest, color: Colors.blue),
                      initiallyExpanded: false,
                      title: const Text(
                        "System Configuration",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      subtitle: const Text("Control system behavior and notifications", style: TextStyle(fontSize: 12)),
                      children: [
                        if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting)
                          const LinearProgressIndicator(),
                        SwitchListTile(
                          title: const Text("Enable Update Notifications", style: TextStyle(fontSize: 14)),
                          subtitle: const Text("If disabled, users won't see update popups.", style: TextStyle(fontSize: 11)),
                          value: isEnabled,
                          activeColor: Colors.blue,
                          onChanged: (val) async {
                            SharedPreferences prefs = await SharedPreferences.getInstance();
                            String actor = prefs.getString('username') ?? "Unknown";
                            await _dbService.updatePopupStatus(val);
                            await _dbService.logActivity(
                              actor: actor,
                              action: "Toggle Update Popup",
                              details: "Set update notifications to ${val ? 'ON' : 'OFF'}",
                              category: "System",
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }
            ),

            // Section 2: Dashboard Visibility Controls
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  leading: const Icon(Icons.security, color: Colors.indigo),
                  title: const Text(
                    "Dashboard Visibility Control",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                  subtitle: const Text("Control what sections are visible to different roles", style: TextStyle(fontSize: 12)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          const Icon(Icons.person_search_outlined, size: 20, color: Colors.indigo),
                          const SizedBox(width: 12),
                          const Text("Manage Visibility for:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: _selectedRoleForVisibility,
                            items: const [
                              DropdownMenuItem(value: 'admin', child: Text("Admin")),
                              DropdownMenuItem(value: 'operator', child: Text("Operator")),
                              DropdownMenuItem(value: 'viewer', child: Text("Viewer")),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedRoleForVisibility = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    StreamBuilder<DocumentSnapshot>(
                      stream: _dbService.getDashboardVisibilityStream(_selectedRoleForVisibility),
                      builder: (context, snapshot) {
                        Map<String, bool> settings = {
                          'showAccounts': true,
                          'showElectricity': true,
                          'showMainVsSub': true,
                          'showMainVsGovt': true,
                          'showCategory': true,
                        };

                        if (snapshot.hasData && snapshot.data!.exists) {
                          var data = snapshot.data!.data() as Map<String, dynamic>;
                          var s = data['settings'] ?? {};
                          s.forEach((k, v) => settings[k] = v as bool);
                        }

                        return Column(
                          children: [
                            _buildVisibilitySwitch("Show Accounts Section", settings['showAccounts']!, (val) {
                              settings['showAccounts'] = val;
                              _dbService.updateDashboardVisibility(_selectedRoleForVisibility, settings);
                            }, icon: Icons.account_balance_wallet_outlined),
                            _buildVisibilitySwitch("Show Electricity Section", settings['showElectricity']!, (val) {
                              settings['showElectricity'] = val;
                              _dbService.updateDashboardVisibility(_selectedRoleForVisibility, settings);
                            }, icon: Icons.electric_bolt_outlined),
                            Padding(
                              padding: const EdgeInsets.only(left: 32),
                              child: Column(
                                children: [
                                  _buildVisibilitySwitch("-> Main vs Sub-Meter", settings['showMainVsSub']!, (val) {
                                    settings['showMainVsSub'] = val;
                                    _dbService.updateDashboardVisibility(_selectedRoleForVisibility, settings);
                                  }, isSub: true, icon: Icons.compare_arrows_outlined),
                                  _buildVisibilitySwitch("-> Main vs Govt. Bill", settings['showMainVsGovt']!, (val) {
                                    settings['showMainVsGovt'] = val;
                                    _dbService.updateDashboardVisibility(_selectedRoleForVisibility, settings);
                                  }, isSub: true, icon: Icons.receipt_long_outlined),
                                ],
                              ),
                            ),
                            _buildVisibilitySwitch("Show Category Section", settings['showCategory']!, (val) {
                              settings['showCategory'] = val;
                              _dbService.updateDashboardVisibility(_selectedRoleForVisibility, settings);
                            }, icon: Icons.category_outlined),
                            const Divider(indent: 16, endIndent: 16),
                            FutureBuilder<SharedPreferences>(
                              future: SharedPreferences.getInstance(),
                              builder: (context, prefsSnap) {
                                bool haptic = prefsSnap.data?.getBool('isHapticEnabled') ?? true;
                                return SwitchListTile(
                                  secondary: const Icon(Icons.vibration, color: Colors.indigo, size: 20),
                                  title: const Text("Haptic Pulse Feedback", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                  subtitle: const Text("Vibrate phone on button clicks", style: TextStyle(fontSize: 11)),
                                  value: haptic,
                                  activeColor: Colors.indigo,
                                  onChanged: (val) async {
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setBool('isHapticEnabled', val);
                                    if (val) DatabaseService.vibrate();
                                    setState(() {});
                                  },
                                );
                              }
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      }
                    ),
                  ],
                ),
              ),
            ),

            // Section 3: Data Management (Backup/Restore/Wipe)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  leading: const Icon(Icons.storage, color: Colors.teal),
                  title: const Text(
                    "Data Management",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                  subtitle: const Text("Backup and restore database records", style: TextStyle(fontSize: 12)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green, 
                                    foregroundColor: Colors.white,
                                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: _isProcessing ? null : () => _handleBackup(context),
                                  child: _isProcessing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Backup Now"),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo, 
                                    foregroundColor: Colors.white,
                                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: _isProcessing ? null : () => _handleRestore(context),
                                  child: _isProcessing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Restore Data"),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey, 
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                              onPressed: _isProcessing ? null : () => _handleLocalSave(context),
                              child: _isProcessing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Save Locally"),
                            ),
                          ),
                          if (_isProcessing) ...[
                            const SizedBox(height: 16),
                            LinearProgressIndicator(
                              value: _progress,
                              backgroundColor: Colors.grey.shade200,
                              color: Colors.blue,
                              minHeight: 6,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${(_progress * 100).toStringAsFixed(1)}%",
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ],
                          const SizedBox(height: 8),
                          const Text(
                            "Backup generates a JSON file. Use Restore to upload a previous backup. Versioning ensures safety.",
                            style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                            textAlign: TextAlign.center,
                          ),
                          FutureBuilder<SharedPreferences>(
                            future: SharedPreferences.getInstance(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data!.getString('userRole') == 'superadmin') {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 16.0),
                                  child: Column(
                                    children: [
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red, 
                                            foregroundColor: Colors.white,
                                            textStyle: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: _isProcessing ? null : () => _handleWipe(context),
                                          child: _isProcessing 
                                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                                              : const Text("Wipe All Server Data (Excl. Users)"),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Section 3: Account Management
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                leading: const Icon(Icons.manage_accounts, color: Colors.indigo),
                title: const Text(
                  "Account Management",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
                subtitle: const Text("Create and manage Admin, Operator, or Viewer access", style: TextStyle(fontSize: 12)),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _showUserDialog(context),
                            child: const Text("Add New Account"),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text("Current System Accounts", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        const Text(
                          "Admin accounts have full control. Operators can manage daily tasks. Viewers can only see the dashboard summary.",
                          style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 12),
                        _buildUsersTable(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTable() {
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold);
    final dataStyle = Theme.of(context).textTheme.bodyMedium;

    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text("Error: ${snapshot.error}");
        if (!snapshot.hasData) return const Center(child: LinearProgressIndicator());
        
        var users = snapshot.data!.docs;
        if (users.isEmpty) return const Text("No accounts found. Use the button above to create one.", style: TextStyle(fontSize: 11, color: Colors.grey));

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                alignment: Alignment.center,
                width: MediaQuery.of(context).size.width > 500 ? null : MediaQuery.of(context).size.width - 40,
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5))),
                      children: [
                        Padding(padding: const EdgeInsets.all(12), child: Center(child: Text("Role", textAlign: TextAlign.center, style: textStyle))),
                        Padding(padding: const EdgeInsets.all(12), child: Center(child: Text("Username", textAlign: TextAlign.center, style: textStyle))),
                        Padding(padding: const EdgeInsets.all(12), child: Center(child: Text("Password", textAlign: TextAlign.center, style: textStyle))),
                        Padding(padding: const EdgeInsets.all(12), child: Center(child: Text("Action", textAlign: TextAlign.center, style: textStyle))),
                      ],
                    ),
                    ...users.asMap().entries.map((entry) {
                      int idx = entry.key;
                      var doc = entry.value;
                      final data = doc.data() as Map<String, dynamic>;
                      final String role = (data['role'] ?? 'viewer').toString().toUpperCase();
                      final String username = data['username'] ?? '';
                      final String password = data['password'] ?? '';
                      final rowColor = idx % 2 == 0 ? Colors.blue.shade50.withValues(alpha: 0.5) : Colors.transparent;

                      return TableRow(
                        decoration: BoxDecoration(color: rowColor),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: role == 'ADMIN' ? Colors.red.shade50 : role == 'OPERATOR' ? Colors.teal.shade50 : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  role, 
                                  style: (textStyle ?? const TextStyle()).copyWith(
                                    fontSize: 11,
                                    color: role == 'ADMIN' ? Colors.red : role == 'OPERATOR' ? Colors.teal : Colors.blue
                                  )
                                ),
                              ),
                            ),
                          ),
                          Padding(padding: const EdgeInsets.all(12), child: Center(child: Text(username, textAlign: TextAlign.center, style: dataStyle, overflow: TextOverflow.ellipsis))),
                          Padding(padding: const EdgeInsets.all(12), child: Center(child: Text(password, textAlign: TextAlign.center, style: dataStyle, overflow: TextOverflow.ellipsis))),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () => _showUserDialog(context, docId: doc.id, currentData: data),
                                    child: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                                  ),
                                  const SizedBox(width: 12),
                                  InkWell(
                                    onTap: () => _confirmRemove(doc.id, username),
                                    child: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.orange),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showUserDialog(BuildContext context, {String? docId, Map<String, dynamic>? currentData}) {
    final userController = TextEditingController(text: currentData?['username'] ?? '');
    final passController = TextEditingController(text: currentData?['password'] ?? '');
    String selectedRole = currentData?['role'] ?? 'operator';
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Center(child: Text(docId == null ? "Create Account" : "Edit Account", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: "Role", border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: "admin", child: Center(child: Text("Admin"))),
                    DropdownMenuItem(value: "operator", child: Center(child: Text("Operator"))),
                    DropdownMenuItem(value: "viewer", child: Center(child: Text("Viewer"))),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRole = val);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: userController,
                  decoration: const InputDecoration(labelText: "Username", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passController,
                  decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          actions: [
            Row(
              children: [
                Expanded(child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: isSaving ? null : () async {
                      String u = userController.text.trim();
                      String p = passController.text.trim();
                      if (u.isEmpty || p.isEmpty) return;

                      setDialogState(() => isSaving = true);
                      
                      showDialog(
                        context: context,
                        builder: (confirmCtx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Center(child: Text("Confirm Change", style: TextStyle(fontWeight: FontWeight.bold))),
                          content: const Text("Do you want to save these account details?", textAlign: TextAlign.center),
                          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          actions: [
                            Row(
                              children: [
                                Expanded(child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                  onPressed: () => Navigator.pop(confirmCtx), child: const Text("No"))),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                    onPressed: () async {
                                      Navigator.pop(confirmCtx);
                                      SharedPreferences prefs = await SharedPreferences.getInstance();
                                      String actor = prefs.getString('username') ?? "Unknown";
                                      await _dbService.saveUser(u, p, selectedRole, actor, docId: docId);
                                      if (ctx.mounted) {
                                        Navigator.pop(ctx);
                                        DatabaseService.showToast(context, "Account details saved!", backgroundColor: Colors.green);
                                      }
                                    },
                                    child: const Text("Yes"),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                      setDialogState(() => isSaving = false);
                    },
                    child: isSaving 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("Save"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemove(String docId, String username) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Center(child: Text("Remove Account?", style: TextStyle(fontWeight: FontWeight.bold))),
        content: Text("Are you sure you want to remove user '$username'? Their credentials will be moved to the archive.", textAlign: TextAlign.center),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          Row(
            children: [
              Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    String actor = prefs.getString('username') ?? "Unknown";
                    await _dbService.removeUser(docId, actor);
                    if (mounted) {
                      DatabaseService.showToast(context, "User removed and archived.", backgroundColor: Colors.orange);
                    }
                  },
                  child: const Text("Remove"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
