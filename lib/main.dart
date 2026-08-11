import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:akonssquare/Common/database_service.dart';
import 'package:akonssquare/Admin/admin_dashboard.dart';
import 'package:akonssquare/Admin/super_admin_dashboard.dart';
import 'package:akonssquare/Operator/operator_dashboard.dart';
import 'package:akonssquare/Viewer/viewer_dashboard.dart';
import 'package:akonssquare/Users/user_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:akonssquare/Common/splash_screen.dart';
import 'package:akonssquare/Common/theme_manager.dart';
import 'package:flutter/services.dart';
import 'package:akonssquare/Common/build_config.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:akonssquare/Common/firebase_options.dart';

import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:akonssquare/Common/automation_guide.dart';
import 'package:device_info_plus/device_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await ThemeManager.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: ThemeManager.appThemeNotifier,
      builder: (context, themeName, child) {
        return ValueListenableBuilder<String>(
          valueListenable: ThemeManager.appFontNotifier,
          builder: (context, fontName, child) {
            return MaterialApp(
              title: 'AkonsSquare',
              debugShowCheckedModeBanner: false,
              theme: ThemeManager.getThemeByName(themeName, fontName: fontName),
              home: const SplashScreen(),
            );
          },
        );
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final DatabaseService _dbService = DatabaseService();
  String _appName = "";
  final String _currentVersion = "1.0.0+4";
  String? _selectedSubItemId;
  String? _temporaryMessage;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOffline = false;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAppConfig();
    _checkConnectivity();
  }

  void _checkConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      bool offline = results.contains(ConnectivityResult.none);
      if (offline != _isOffline) {
        setState(() { _isOffline = offline; });
        if (offline) {
          _showOfflineDialog();
        } else {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        }
      }
    });
  }

  void _showOfflineDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red),
              SizedBox(width: 10),
              Text("No Internet"),
            ],
          ),
          content: const Text("Device is offline. Please check your internet connection to resume using the app."),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAppConfig() async {
    try {
      var doc = await _dbService.getAppConfigStream().first;
      if (doc.exists) {
        setState(() {
          _appName = doc['appName'] ?? "AkonsSquare";
        });
      }
    } catch (e) {
      setState(() { _appName = "AkonsSquare"; });
    }
  }

  void _showTemporaryMessage(String msg) {
    setState(() { _temporaryMessage = msg; });
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() { _temporaryMessage = null; });
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Center(child: Text("Login Failed!", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
        content: Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error, 
                foregroundColor: Theme.of(context).colorScheme.onError,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("OK"),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loginBasicUser() async {
    if (_selectedSubItemId == null) { _showErrorDialog("Please select your name!"); return; }
    
    // Set global loading to prevent multiple clicks
    setState(() { _isOffline = _isOffline; }); // Dummy setstate to ensure context

    var snap = await FirebaseFirestore.instance.collection('sub_items').doc(_selectedSubItemId).get();
    if (!snap.exists) { _showErrorDialog("User not found!"); return; }
    var subData = snap.data() as Map<String, dynamic>;

    final passController = TextEditingController(); bool isAuthenticating = false;
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setST) {
          String tName = subData['TenantName'] ?? 'No Name';
          String unitName = subData['subItemName'] ?? 'Unit';
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(unitName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), Text("($tName)", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontStyle: FontStyle.italic))])),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text("Enter last 4 digits of your NID:", textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 12),
              TextField(
                controller: passController, 
                obscureText: true, 
                keyboardType: TextInputType.number, 
                maxLength: 4, 
                style: Theme.of(context).textTheme.bodyLarge, 
                onChanged: (v) => setST((){}), 
                decoration: const InputDecoration(
                  labelText: "Password", 
                  hintText: "Last 4 digits of NID",
                  prefixIcon: Icon(Icons.lock_outline), 
                  counterText: ""
                )
              ),
            ]),
            actions: [
              Row(children: [
                Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    backgroundColor: Theme.of(context).colorScheme.error,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ), 
                  onPressed: isAuthenticating ? null : () => Navigator.pop(ctx), 
                  child: const Text("Cancel")
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.tertiary, 
                    foregroundColor: Theme.of(context).colorScheme.onTertiary, 
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ), 
                  onPressed: (isAuthenticating || passController.text.length != 4) ? null : () async {
                  String input = passController.text.trim(); String storedNid = (subData['nidNumber'] ?? '').toString();
                  if (input.isEmpty || input.length != 4) { DatabaseService.showToast(context, "Enter 4 digits!", backgroundColor: Theme.of(context).colorScheme.secondary); return; }
                  setST(() => isAuthenticating = true);
                  String last4 = storedNid.length >= 4 ? storedNid.substring(storedNid.length - 4) : storedNid;
                  if (input == last4 && storedNid.isNotEmpty && storedNid != "No Number") {
                    String subId = snap.id; String catId = subData['categoryId'] ?? '';
                    String sessionId = DateTime.now().millisecondsSinceEpoch.toString();
                    await DatabaseService().updateUserSession('sub_items', subId, sessionId);
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('isLoggedIn', true); await prefs.setString('userRole', 'user');
                    await prefs.setString('subItemId', subId); await prefs.setString('categoryId', catId);
                    await prefs.setString('sessionId', sessionId);
                    if (mounted) { Navigator.pop(ctx); Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => UserDashboard(subItemId: subId, categoryId: catId))); }
                  } else {
                    if (context.mounted) DatabaseService.showToast(context, "Incorrect password!", backgroundColor: Theme.of(context).colorScheme.error);
                    setST(() => isAuthenticating = false);
                  }
                }, child: isAuthenticating ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onTertiary)) : const Text("Verify"))),
              ]),
            ],
          );
        },
      ),
    );
  }

  void _showHiddenLoginDialog() {
    final uC = TextEditingController(); final pC = TextEditingController(); bool isVerifying = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setST) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Center(child: Text("Access Login", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: uC, 
              decoration: const InputDecoration(
                labelText: "Username", 
                hintText: "Enter username",
                prefixIcon: Icon(Icons.person)
              ), 
              onChanged: (v) => setST((){})
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pC, 
              obscureText: true, 
              decoration: const InputDecoration(
                labelText: "Password", 
                hintText: "Enter password",
                prefixIcon: Icon(Icons.lock)
              ), 
              onChanged: (v) => setST((){})
            ),
          ]),
          actions: [
            Row(children: [
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  backgroundColor: Theme.of(context).colorScheme.error,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ), 
                onPressed: isVerifying ? null : () => Navigator.pop(ctx), child: const Text("Cancel"))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.tertiary, 
                  foregroundColor: Theme.of(context).colorScheme.onTertiary, 
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ), 
                onPressed: (isVerifying || uC.text.trim().isEmpty || pC.text.trim().isEmpty) ? null : () async {
                String u = uC.text.trim(); String p = pC.text.trim(); if (u.isEmpty || p.isEmpty) return;
                setST(() => isVerifying = true);
                try {
                  if (u == 'admin' && p == 'admin') {
                     var adminCheck = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'admin').get();
                     if (adminCheck.docs.isEmpty) {
                        SharedPreferences prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('isLoggedIn', true); await prefs.setString('userRole', 'admin');
                        await prefs.setString('username', u); await prefs.setString('savedPassword', p);
                        if (mounted) { Navigator.pop(ctx); Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminDashboard())); }
                        return;
                     }
                  }
                  QuerySnapshot userQuery = await FirebaseFirestore.instance.collection('users').where('username', isEqualTo: u).where('password', isEqualTo: p).limit(1).get();
                  if (userQuery.docs.isNotEmpty) {
                    var userDoc = userQuery.docs.first;
                    var userData = userDoc.data() as Map<String, dynamic>; String role = (userData['role'] ?? 'viewer').toString();
                    String sessionId = DateTime.now().millisecondsSinceEpoch.toString();
                    await DatabaseService().updateUserSession('users', userDoc.id, sessionId);
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('isLoggedIn', true); await prefs.setString('userRole', role);
                    await prefs.setString('username', u); await prefs.setString('savedPassword', p);
                    await prefs.setString('userDocId', userDoc.id);
                    await prefs.setString('sessionId', sessionId);
                    if (mounted) {
                      Navigator.pop(ctx);
                      if (role == 'admin') Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminDashboard()));
                      else if (role == 'operator') Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => OperatorDashboard(username: u)));
                      else Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ViewerDashboard()));
                    }
                    return;
                  }
                  if (context.mounted) DatabaseService.showToast(context, "Incorrect details!", backgroundColor: Theme.of(context).colorScheme.error);
                } catch (e) { /* ignore */ } finally { if (ctx.mounted) setST(() => isVerifying = false); }
              }, child: isVerifying ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Login"))),
            ]),
          ],
        ),
      ),
    );
  }

  void _showMasterKeyDialog() {
    final keyController = TextEditingController();
    bool isLoading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setST) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Center(child: Text("Master Access", style: TextStyle(fontWeight: FontWeight.bold))),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text("Enter secret key:", style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: keyController, 
              obscureText: true, 
              onChanged: (v) => setST((){}), 
              decoration: const InputDecoration(
                labelText: "Secret Key", 
                hintText: "Master password",
                prefixIcon: Icon(Icons.vpn_key_outlined)
              )
            ),
          ]),
          actions: [
            Row(children: [
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  backgroundColor: Theme.of(context).colorScheme.error,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ), 
                onPressed: () => Navigator.pop(ctx), 
                child: const Text("Cancel")
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.tertiary, 
                  foregroundColor: Theme.of(context).colorScheme.onTertiary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ), 
                onPressed: (isLoading || keyController.text.trim().isEmpty) ? null : () async {
                if (keyController.text.trim() == 'superadmin') {
                  setST(() => isLoading = true);
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('isLoggedIn', true); await prefs.setString('userRole', 'superadmin');
                  if (mounted) { Navigator.pop(ctx); Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SuperAdminDashboard())); }
                } else { if (context.mounted) DatabaseService.showToast(context, "Invalid!", backgroundColor: Theme.of(context).colorScheme.error); }
              }, child: isLoading ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Authorize"))),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: _dbService.getDatabaseInfoStream(),
          builder: (context, dbInfoSnap) {
            String serverStatus = 'completed';
            String dbVersion = "...";
            String bnText = "BN$buildNumber"; // Default to local BN
            if (dbInfoSnap.hasData && dbInfoSnap.data!.exists) {
              var info = dbInfoSnap.data!.data() as Map<String, dynamic>;
              serverStatus = info['serverStatus'] ?? 'completed';
              dbVersion = (info['dbVersion'] ?? 26.0).toStringAsFixed(1);
              int firestoreBN = info['buildNumber']?.toInt() ?? 0;
              // If server has a newer BN, show that, otherwise show local
              if (firestoreBN > buildNumber) {
                bnText = "BN$firestoreBN";
              }
              
              if (serverStatus == 'completed' && _temporaryMessage != null && _temporaryMessage!.contains("Updating")) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _showTemporaryMessage("Update Completed");
                });
              } else if (serverStatus == 'wipe_completed' && _temporaryMessage != null && _temporaryMessage!.contains("Deleting")) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _showTemporaryMessage("Delete Completed");
                });
              } else if (serverStatus == 'uploading') {
                _temporaryMessage = "Updating Database...";
              } else if (serverStatus == 'wiping') {
                _temporaryMessage = "Deleting Database...";
              } else if (serverStatus == 'exporting') {
                _temporaryMessage = "Backup Processing...";
              } else if (serverStatus == 'failed') {
                _temporaryMessage = "Operation Failed!";
              }
            }

            return StreamBuilder<DocumentSnapshot>(
              stream: _dbService.getAppConfigStream(),
              builder: (context, configSnap) {
                String latestV = "";
                if (configSnap.hasData && configSnap.data!.exists) {
                  latestV = configSnap.data!['requiredVersion'] ?? "";
                }
                bool isOutdated = latestV.isNotEmpty && latestV != _currentVersion;

                return Column(
                  children: [
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const AutomationGuidePage()));
                      },
                      onLongPress: _showMasterKeyDialog,
                      child: Column(
                        children: [
                          Text(
                            "AkonsSquare",
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary, 
                              letterSpacing: 0.5
                            ),
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(text: "V: $_currentVersion", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.tertiary, fontWeight: FontWeight.bold)),
                                TextSpan(text: "_$bnText", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.tertiary, fontWeight: FontWeight.bold)),
                                if (isOutdated) ...[
                                  TextSpan(text: " | ", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                                  TextSpan(text: "Latest V: $latestV", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)),
                                ]
                              ]
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _temporaryMessage ?? "DB V-$dbVersion",
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: (_temporaryMessage != null && (_temporaryMessage!.contains("Delet") || _temporaryMessage!.contains("Backup"))) 
                                ? Theme.of(context).colorScheme.error 
                                : Theme.of(context).colorScheme.secondary, 
                              fontWeight: FontWeight.bold, 
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Card(
                            elevation: 4,
                            margin: EdgeInsets.zero,
                            color: Theme.of(context).colorScheme.surface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            child: Padding(
                              padding: const EdgeInsets.all(1),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(23),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Welcome",
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.primary, 
                                        fontWeight: FontWeight.bold, 
                                      ),
                                    ),
                                    const SizedBox(height: 48),
                                    StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore.instance.collection('sub_items').snapshots(),
                                      builder: (context, snapshot) {
                                        List<Map<String, dynamic>> items = [];
                                        if (snapshot.hasData) {
                                          items = snapshot.data!.docs.map((doc) {
                                            var data = doc.data() as Map<String, dynamic>;
                                            data['id'] = doc.id;
                                            return data;
                                          }).toList();
                                          items.sort((a, b) => (a['subItemName'] ?? '').compareTo(b['subItemName'] ?? ''));
                                        }

                                        // Safety check: if selected ID is not in items, clear it
                                        if (_selectedSubItemId != null && !items.any((i) => i['id'] == _selectedSubItemId)) {
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            if (mounted) setState(() { _selectedSubItemId = null; });
                                          });
                                        }

                                        return DropdownButtonFormField<String>(
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            labelText: "Select User Name",
                                            labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                            prefixIcon: Icon(Icons.meeting_room_outlined, color: Theme.of(context).colorScheme.onSurface),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                                          ),
                                          icon: const Icon(Icons.arrow_drop_down),
                                          value: _selectedSubItemId,
                                          items: items.map((data) {
                                            String tName = data['TenantName'] ?? 'No Name';
                                            String unit = data['subItemName'] ?? 'Unit';
                                            return DropdownMenuItem<String>(value: data['id'], child: Text("$unit ($tName)", overflow: TextOverflow.ellipsis));
                                          }).toList(),
                                          onChanged: (v) => setState(() => _selectedSubItemId = v),
                                          hint: const Text("Select User Name"),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 32),
                                    SizedBox(
                                      width: double.infinity, height: 65, 
                                      child: ElevatedButton.icon(
                                        onLongPress: _isLoading ? null : () { HapticFeedback.heavyImpact(); _showHiddenLoginDialog(); },
                                        onPressed: _isLoading ? null : () { 
                                          HapticFeedback.mediumImpact(); 
                                          setState(() => _isLoading = true);
                                          _loginBasicUser().then((_) {
                                            if (mounted) setState(() => _isLoading = false);
                                          }).catchError((_) {
                                            if (mounted) setState(() => _isLoading = false);
                                          });
                                        },
                                        icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.dashboard_outlined),
                                        label: Text(_isLoading ? "Connecting..." : "Login to dashboard", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onTertiary), maxLines: 1),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(context).colorScheme.tertiary,
                                          foregroundColor: Theme.of(context).colorScheme.onTertiary,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          elevation: 2,
                                        ),
                                      )
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        children: [
                          Image.asset('assets/images/signature.png', height: 90, errorBuilder: (c, e, s) => const SizedBox.shrink()),
                          const SizedBox(height: 4),
                          Text(
                            "AkonsAutomation by AkonS",
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold, 
                              color: Theme.of(context).colorScheme.primary, 
                              letterSpacing: 0.5, 
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
            );
          }
        ),
      ),
    );
  }
}