import 'package:flutter/material.dart';
import 'package:akons_square/Common/theme_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:ota_update/ota_update.dart';
import 'package:akons_square/main.dart';

class AppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Widget child;
  final ButtonStyle? style;
  final Widget? icon;

  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.onLongPress,
    this.style,
  }) : icon = null;

  const AppButton.icon({
    super.key,
    required this.onPressed,
    required this.child,
    required this.icon,
    this.onLongPress,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final themeStyle = Theme.of(context).elevatedButtonTheme.style;
    
    // Explicit override for Outline Theme to ensure no fill and black text
    ButtonStyle? effectiveStyle;
    if (ThemeManager.appThemeNotifier.value == "Outline Theme") {
      effectiveStyle = themeStyle?.copyWith(
        backgroundColor: WidgetStateProperty.all(Colors.transparent),
        shadowColor: WidgetStateProperty.all(Colors.transparent),
        foregroundColor: WidgetStateProperty.all(Colors.black),
        elevation: WidgetStateProperty.all(0),
      ).merge(style);
    } else {
      effectiveStyle = themeStyle?.merge(style) ?? style;
    }

    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        onLongPress: onLongPress,
        style: effectiveStyle,
        icon: icon!,
        label: child,
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      style: effectiveStyle,
      child: child,
    );
  }
}

class AppDialogActions extends StatelessWidget {
  final List<Widget> actions;

  const AppDialogActions({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    if (actions.length == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: SizedBox(
          width: double.infinity,
          child: actions.first,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: actions.map((action) {
          int index = actions.indexOf(action);
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : 8,
                right: index == actions.length - 1 ? 0 : 8,
              ),
              child: action,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class AppVersionInfo extends StatefulWidget {
  final String version;
  final String dbVersion;
  final String? latestVersion;
  final String? statusMessage;
  final bool isOutdated;
  final bool animate;
  final Color? color;
  final Color? secondaryColor;
  final CrossAxisAlignment crossAxisAlignment;
  final bool showLogoutIcon;
  final String? connectionStatus;
  final Color? connectionColor;

  const AppVersionInfo({
    super.key,
    required this.version,
    required this.dbVersion,
    this.latestVersion,
    this.statusMessage,
    this.isOutdated = false,
    this.animate = true,
    this.color,
    this.secondaryColor,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.showLogoutIcon = false,
    this.connectionStatus,
    this.connectionColor,
  });

  @override
  State<AppVersionInfo> createState() => _AppVersionInfoState();
}

class _AppVersionInfoState extends State<AppVersionInfo> {
  bool _showUpdateInfo = false;
  Timer? _timer;
  StreamSubscription? _connectivitySub;
  bool _isInternalOffline = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    if (widget.isOutdated && widget.animate) {
      _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (mounted) {
          setState(() {
            _showUpdateInfo = !_showUpdateInfo;
          });
        }
      });
    }
  }

  void _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isInternalOffline = results.contains(ConnectivityResult.none);
      });
    }
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) {
        setState(() {
          _isInternalOffline = results.contains(ConnectivityResult.none);
        });
      }
    });
  }

  @override
  void didUpdateWidget(AppVersionInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOutdated && widget.animate && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (mounted) {
          setState(() {
            _showUpdateInfo = !_showUpdateInfo;
          });
        }
      });
    } else if ((!widget.isOutdated || !widget.animate) && _timer != null) {
      _timer?.cancel();
      _timer = null;
      _showUpdateInfo = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // CENTRALIZED STYLE CONFIG
    const double mainFontSize = 8.0;
    const double statusFontSize = 9.0;

    final effectiveColor = widget.color ?? Theme.of(context).colorScheme.tertiary;
    
    // Logic for status message color and text
    bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
    Color effectiveSecondary = widget.secondaryColor ?? (isOutline ? Colors.black : Theme.of(context).colorScheme.secondary);
    String displayDBText = "DB V-${widget.dbVersion}";
    
    if (widget.statusMessage != null && widget.statusMessage!.isNotEmpty) {
      displayDBText = widget.statusMessage!;
      if (widget.statusMessage!.contains("Delet") || widget.statusMessage!.contains("Failed") || widget.statusMessage!.contains("Backup")) {
        effectiveSecondary = Theme.of(context).colorScheme.error;
      }
    }

    // Toggle logic for update notification
    bool isShowingUpdateIcon = widget.isOutdated && _showUpdateInfo;

    // Determine connectivity info (Prioritize widget prop if provided)
    final bool showOffline = widget.connectionStatus != null 
        ? widget.connectionStatus == "Offline" 
        : _isInternalOffline;
    
    final String? statusText = widget.connectionStatus ?? (showOffline ? "Offline" : null);
    final Color statusColor = widget.connectionColor ?? (showOffline ? Colors.red : Colors.green);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: widget.crossAxisAlignment,
        children: [
          RichText(
            textAlign: widget.crossAxisAlignment == CrossAxisAlignment.center ? TextAlign.center : TextAlign.start,
            text: TextSpan(
              children: [
                if (widget.isOutdated && widget.latestVersion != null) ...[
                  TextSpan(
                    text: "Latest V: ${widget.latestVersion}", 
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isOutline ? Colors.black : Colors.red, 
                      fontWeight: FontWeight.bold, 
                      fontSize: mainFontSize
                    )
                  ),
                ] else ...[
                  TextSpan(
                    text: "V: ${widget.version}", 
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isOutline ? Colors.black : Colors.green, 
                      fontWeight: FontWeight.bold, 
                      fontSize: mainFontSize
                    )
                  ),
                ]
              ]
            ),
          ),
          if (widget.showLogoutIcon) ...[
            const SizedBox(height: 1),
            Icon(
              isShowingUpdateIcon ? Icons.system_update_alt : Icons.logout, 
              size: 18, 
              color: isShowingUpdateIcon ? Theme.of(context).colorScheme.primary : Colors.red,
            ),
          ],
          const SizedBox(height: 1),
          Text(
            displayDBText,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: mainFontSize,
              color: (isOutline && !displayDBText.contains("BN")) ? Colors.black : effectiveSecondary, 
              fontWeight: FontWeight.bold, 
            ),
          ),
          // FIXED HEIGHT STATUS AREA to prevent layout jumps
          SizedBox(
            height: 14,
            child: (statusText != null) 
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.4),
                            blurRadius: 2,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: statusFontSize,
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// --- UPDATE DIALOGS ---

class UpdateProgressDialog extends StatefulWidget {
  final String url;
  const UpdateProgressDialog({required this.url});

  @override
  State<UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<UpdateProgressDialog> {
  OtaEvent? currentEvent;
  String? error;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  void _startDownload() {
    try {
      final String filename = "update_${DateTime.now().millisecondsSinceEpoch}.apk";
      print("OTA: Starting download from ${widget.url} to $filename");
      OtaUpdate().execute(widget.url, destinationFilename: filename).listen(
        (OtaEvent event) {
          print("OTA Status: ${event.status}, Value: ${event.value}");
          setState(() {
            currentEvent = event;
            if (event.status == OtaStatus.INSTALLING) {
              Navigator.pop(context);
            } else if (event.status == OtaStatus.DOWNLOAD_ERROR || 
                       event.status == OtaStatus.INTERNAL_ERROR ||
                       event.status == OtaStatus.PERMISSION_NOT_GRANTED_ERROR) {
              error = "Update failed: ${event.status}. Please check internet or permissions.";
            }
          });
        },
        onError: (e) {
          print("OTA Error: $e");
          setState(() {
            error = "Download error: $e";
          });
        },
      );
    } catch (e) {
      print("OTA Exception: $e");
      setState(() {
        error = "System error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double progress = 0;
    if (currentEvent?.value != null) {
      progress = (double.tryParse(currentEvent!.value!) ?? 0) / 100;
    }

    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              const Text("Downloading", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error != null)
              Text("Error: $error", style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)
            else ...[
              const Text("Please wait while we prepare your update.", textAlign: TextAlign.center),
              const SizedBox(height: 24),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
                minHeight: 10,
              ),
              const SizedBox(height: 12),
              Text(
                "${(progress * 100).toInt()}% Complete",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ]
          ],
        ),
        actions: error != null ? [
          AppButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ] : [],
      ),
    );
  }
}

void showUpdateDialog({
  required BuildContext context,
  required String remoteVersion,
  required String downloadUrl,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.system_update, color: Colors.blue),
            SizedBox(width: 8),
            Text("Update Available", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.95,
        child: Text(
          "A new version of the app ($remoteVersion) is available. Update now to get the latest features.",
          textAlign: TextAlign.center,
        ),
      ),
      actions: [
        AppDialogActions(
          actions: [
             AppButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant, 
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Later"),
            ),
            AppButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: () async {
                if (downloadUrl.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Download link not available. Please contact admin.")),
                  );
                  return;
                }
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => UpdateProgressDialog(url: downloadUrl),
                );
              },
              child: const Text("Update Now"),
            ),
          ],
        ),
      ],
    ),
  );
}

void showUpdateLogoutDialog({
  required BuildContext context,
  required String remoteVersion,
  required String downloadUrl,
  required VoidCallback onLogout,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Center(
        child: Text("App Actions", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.95,
        child: Text(
          "New update ($remoteVersion) is available. What would you like to do?",
          textAlign: TextAlign.center,
        ),
      ),
      actions: [
        AppDialogActions(
          actions: [
             AppButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                onLogout();
              },
              child: const Text("Logout"),
            ),
            AppButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: () async {
                if (downloadUrl.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Download link not available. Please contact admin.")),
                  );
                  return;
                }
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => UpdateProgressDialog(url: downloadUrl),
                );
              },
              child: const Text("Update Now"),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: AppButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant, 
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Later"),
            ),
          ),
        ),
      ],
    ),
  );
}
