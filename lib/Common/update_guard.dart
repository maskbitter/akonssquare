import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:akons_square/Common/database_service.dart';
import 'package:akons_square/Common/ui_helper.dart';
import 'package:akons_square/Common/build_config.dart';
import 'package:akons_square/main.dart';

class UpdateGuard extends StatefulWidget {
  final Widget child;
  const UpdateGuard({super.key, required this.child});

  @override
  State<UpdateGuard> createState() => _UpdateGuardState();
}

class _UpdateGuardState extends State<UpdateGuard> {
  final DatabaseService _dbService = DatabaseService();
  Timer? _nagTimer;
  bool _isPopupShowing = false;
  String? _localVersion;
  String? _remoteVersion;
  bool _isPopupEnabled = true;
  StreamSubscription? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    _initVersioning();
    _initSessionCheck();
  }

  Future<void> _initSessionCheck() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? role = prefs.getString('userRole');
    String? localSessionId = prefs.getString('sessionId');
    String? subItemId = prefs.getString('subItemId');
    String? userDocId = prefs.getString('userDocId');

    if (role == null || localSessionId == null) return;

    String collection = (role == 'user') ? 'sub_items' : 'users';
    String? docId = (role == 'user') ? subItemId : userDocId;

    if (docId == null) return;

    _sessionSubscription = _dbService.getSessionStream(collection, docId).listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data() as Map<String, dynamic>;
        String? remoteSessionId = data['currentSessionId'];
        if (remoteSessionId != null && remoteSessionId != localSessionId) {
          _handleForceLogout();
        }
      }
    });
  }

  void _handleForceLogout() async {
    _sessionSubscription?.cancel();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text("Logged Out")])),
          content: const Text("You have been logged out because someone else logged in using this account on another device.", textAlign: TextAlign.center),
          actions: [
            AppDialogActions(
              actions: [
                AppButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                      (route) => false,
                    );
                  },
                  child: const Text("Back to Login"),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  Future<void> _initVersioning() async {
    // 1. Get local version from build_config.dart
    _localVersion = appVersion;

    // 2. Listen to remote version and popup status from Firestore
    _dbService.getAppConfigStream().listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data() as Map<String, dynamic>;
        _remoteVersion = data['requiredVersion'];
        _isPopupEnabled = data['isPopupEnabled'] ?? true;
        _processVersioning();
      } else {
        // If config doc doesn't exist, create it with local version
        _dbService.updateRequiredVersion(_localVersion!);
      }
    });
  }

  void _processVersioning() {
    if (_localVersion == null || _remoteVersion == null) return;

    int cmp = _compareVersions(_localVersion!, _remoteVersion!);

    if (cmp > 0) {
      // Local is higher (developer built a new version) -> Update Firestore
      _dbService.updateRequiredVersion(_localVersion!);
      _stopNagging();
    } else if (cmp < 0 && _isPopupEnabled) {
      // Local is lower AND popup is enabled -> Start nagging
      _startNagging();
    } else {
      // Version match or popup disabled -> Stop any nagging
      _stopNagging();
    }
  }

  int _compareVersions(String v1, String v2) {
    // Handling v1.0.0+1 format
    String cleanV1 = v1.replaceFirst('v', '');
    String cleanV2 = v2.replaceFirst('v', '');

    // Split by '+' for build number
    List<String> p1 = cleanV1.split('+');
    List<String> p2 = cleanV2.split('+');

    // Compare versions (e.g. 1.0.0)
    List<String> digits1 = p1[0].split('.');
    List<String> digits2 = p2[0].split('.');

    for (int i = 0; i < 3; i++) {
      int n1 = i < digits1.length ? int.tryParse(digits1[i]) ?? 0 : 0;
      int n2 = i < digits2.length ? int.tryParse(digits2[i]) ?? 0 : 0;
      if (n1 > n2) return 1;
      if (n2 > n1) return -1;
    }

    // Compare build numbers if versions are equal
    int b1 = p1.length > 1 ? int.tryParse(p1[1]) ?? 0 : 0;
    int b2 = p2.length > 1 ? int.tryParse(p2[1]) ?? 0 : 0;

    if (b1 > b2) return 1;
    if (b2 > b1) return -1;

    return 0;
  }

  void _startNagging() {
    if (_nagTimer != null && _nagTimer!.isActive) return;

    // Show immediately
    _showUpdatePopup();

    // Repeat every 1 minute
    _nagTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _showUpdatePopup();
    });
  }

  void _stopNagging() {
    _nagTimer?.cancel();
    if (_isPopupShowing && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _isPopupShowing = false;
    }
  }

  void _showUpdatePopup() {
    if (_isPopupShowing) return;

    _isPopupShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.system_update, color: Colors.blue),
              SizedBox(width: 8),
              Text("Update Required", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "A new version of the app ($_remoteVersion) is available. Your current version is $_localVersion.",
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          AppDialogActions(
            actions: [
              AppButton(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant, 
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(ctx).pop(), 
                child: const Text("Later")
              ),
              AppButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                onPressed: () async {
                   // Fetch download URL and start progress dialog immediately
                   DocumentSnapshot snap = await FirebaseFirestore.instance.collection('app_config').doc('settings').get();
                   if (snap.exists) {
                     String dUrl = (snap.data() as Map<String, dynamic>)['downloadUrl'] ?? "";
                     if (dUrl.isNotEmpty) {
                        Navigator.of(ctx).pop(); // Close the notification popup
                        if (context.mounted) {
                          // Show the progress dialog directly
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => UpdateProgressDialog(url: dUrl),
                          );
                        }
                     } else {
                        DatabaseService.showToast(context, "Download link not found!");
                     }
                   }
                }, 
                child: const Text("Update Now")
              ),
            ],
          ),
        ],
      ),
    ).then((_) => _isPopupShowing = false);
  }

  @override
  void dispose() {
    _nagTimer?.cancel();
    _sessionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
