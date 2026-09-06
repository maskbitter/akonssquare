import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:akons_square/Common/theme_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:ota_update/ota_update.dart';
import 'package:akons_square/main.dart';
import 'dart:io';

class MacAddressFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(':', '').toUpperCase();
    if (text.length > 12) return oldValue;
    
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 2 == 0 && (i + 1) != text.length && (i + 1) < 12) {
        buffer.write(':');
      }
    }
    
    final newString = buffer.toString();
    return TextEditingValue(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }
}

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

class AppVersionInfo extends StatelessWidget {
  final String version;
  final String dbVersion;
  final String? latestVersion;
  final String? statusMessage;
  final bool isOutdated;
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
    this.color,
    this.secondaryColor,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.showLogoutIcon = false,
    this.connectionStatus,
    this.connectionColor,
  });

  @override
  Widget build(BuildContext context) {
    const double fontSize = 10.0;
    
    // Determine colors
    final bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
    final Color versionColor = isOutdated ? Colors.red : (color ?? Colors.green);
    final Color dbColor = secondaryColor ?? ThemeManager.brandBrown;

    String displayDBText = "DB V-$dbVersion";
    if (statusMessage != null && statusMessage!.isNotEmpty) {
      displayDBText = statusMessage!;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          "V: ${latestVersion ?? version}",
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: versionColor,
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
          ),
        ),
        if (showLogoutIcon) ...[
          const SizedBox(height: 2),
          Icon(
            isOutdated ? Icons.system_update_alt : Icons.logout, 
            size: 18, // SLIGHTLY LARGER
            color: isOutdated ? Colors.blue : Colors.red, // RED LOGOUT
          ),
          const SizedBox(height: 2),
        ],
        Text(
          displayDBText,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: isOutline ? Colors.black : dbColor,
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
          ),
        ),
      ],
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
  StreamSubscription? _subscription;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _startDownload() {
    try {
      // Using a stable filename for better FileProvider mapping reliability
      const String filename = "akons_square_update.apk";
      print("OTA: Starting download from ${widget.url} to $filename");
      
      _subscription = OtaUpdate().execute(
        widget.url, 
        destinationFilename: filename,
        // MUST match the authority in AndroidManifest.xml
        androidProviderAuthority: "com.example.akonssquare.ota_update_provider",
        usePackageInstaller: false, 
      ).listen(
        (OtaEvent event) {
          print("OTA Progress: Status=${event.status}, Value=${event.value}");
          
          if (event.status == OtaStatus.INSTALLING && !_isDismissed) {
            print("OTA: Installation started, dismissing progress dialog.");
            _isDismissed = true;
            Navigator.pop(context);
            return;
          }

          if (event.status == OtaStatus.ALREADY_RUNNING_ERROR) {
            print("OTA: Update already in progress.");
          }

          if (!mounted) return;

          setState(() {
            currentEvent = event;
            if (event.status == OtaStatus.DOWNLOAD_ERROR || 
                event.status == OtaStatus.INTERNAL_ERROR ||
                event.status == OtaStatus.PERMISSION_NOT_GRANTED_ERROR ||
                event.status == OtaStatus.CHECKSUM_ERROR) {
              print("OTA Terminal Error: ${event.status}");
              error = "Update failed: ${event.status}. Please check connection or permissions.";
            }
          });
        },
        onError: (e) {
          print("OTA Stream Error: $e");
          if (mounted) {
            setState(() {
              error = "Download error: $e";
            });
          }
        },
      );
    } catch (e) {
      print("OTA Exception: $e");
      if (mounted) {
        setState(() {
          error = "System error: $e";
        });
      }
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                    ? ThemeManager.outlineBackground 
                    : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                    ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5) 
                    : null,
              ),
              child: Icon(Icons.download, color: Theme.of(context).colorScheme.primary, size: 40),
            ),
            const SizedBox(height: 16),
            const Text("Downloading", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                  ? ThemeManager.outlineBackground 
                  : Colors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                  ? Border.all(color: Colors.blue, width: 1.5) 
                  : null,
            ),
            child: const Icon(Icons.system_update, color: Colors.blue, size: 40),
          ),
          const SizedBox(height: 16),
          const Text("Update Available", style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.95,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "A new version of the app ($remoteVersion) is available.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Update now to get the latest features and fixes. Android requires you to confirm the installation after downloading.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                  ? ThemeManager.outlineBackground 
                  : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                  ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5) 
                  : null,
            ),
            child: Icon(Icons.apps_outlined, color: Theme.of(context).colorScheme.primary, size: 40),
          ),
          const SizedBox(height: 16),
          const Text("App Actions", style: TextStyle(fontWeight: FontWeight.bold)),
        ],
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

class AppImageHelper {
  static void showInteractiveImage(BuildContext context, {String? url, File? file, required String title}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(0),
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: url != null 
                  ? Image.network(url, fit: BoxFit.contain, loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    })
                  : (file != null ? Image.file(file, fit: BoxFit.contain) : const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
  }
}
