import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:akons_square/Common/theme_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:ota_update/ota_update.dart';
import 'package:akons_square/main.dart';
import 'package:akons_square/Common/update_manager.dart';
import 'package:akons_square/Common/app_animations.dart';
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
  final bool isIcon;
  final Widget? icon;

  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.onLongPress,
  }) : isIcon = false, icon = null;

  const AppButton.icon({
    super.key,
    required this.onPressed,
    required this.child,
    required this.icon,
    this.style,
    this.onLongPress,
  }) : isIcon = true;

  @override
  Widget build(BuildContext context) {
    if (isIcon) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        onLongPress: onLongPress,
        icon: icon!,
        label: child,
        style: style,
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      style: style,
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
        if (connectionStatus != null) ...[
          const SizedBox(height: 2),
          Text(
            connectionStatus!,
            style: TextStyle(
              color: connectionColor ?? Colors.grey,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }
}

class UpdateProgressDialog extends StatefulWidget {
  const UpdateProgressDialog({super.key});

  @override
  State<UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<UpdateProgressDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateManager.instance.setDialogVisible(true);
    });
  }

  @override
  void dispose() {
    UpdateManager.instance.setDialogVisible(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UpdateManager.instance,
      builder: (context, _) {
        final manager = UpdateManager.instance;
        final progress = manager.progress;
        final status = manager.status;
        final error = manager.error;

        return PopScope(
          canPop: true,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                            ? ThemeManager.outlineBackground 
                            : (error != null ? Colors.red.withValues(alpha: 0.1) : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
                        shape: BoxShape.circle,
                        border: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                            ? Border.all(color: error != null ? Colors.red : Theme.of(context).colorScheme.primary, width: 1.5) 
                            : null,
                      ),
                      child: Icon(
                        error != null ? Icons.error_outline : Icons.download_rounded, 
                        color: error != null ? Colors.red : Theme.of(context).colorScheme.primary, 
                        size: 40
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      error != null 
                        ? "Update Failed" 
                        : (status == AppUpdateStatus.readyToInstall 
                            ? "Update Ready" 
                            : "Downloading Update"), 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                    ),
                    const SizedBox(height: 16),
                    if (error != null)
                      Text(
                        error, 
                        style: const TextStyle(color: Colors.red, fontSize: 13), 
                        textAlign: TextAlign.center
                      )
                    else ...[
                      Text(
                        status == AppUpdateStatus.readyToInstall
                            ? (progress > 0.99 ? "Preparing Installation..." : "The download is complete. Please install the update to continue.")
                            : "Please wait while we prepare your update.", 
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                        minHeight: 10,
                        color: status == AppUpdateStatus.readyToInstall ? Colors.green : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            status == AppUpdateStatus.readyToInstall ? "Finished!" : "${(progress * 100).toInt()}% Complete",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: status == AppUpdateStatus.readyToInstall ? Colors.green : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          if (manager.lastEvent != null)
                            Text(
                              manager.lastEvent!.status == OtaStatus.INSTALLING || status == AppUpdateStatus.readyToInstall
                                ? "Status: Ready to Install" 
                                : "Status: ${manager.lastEvent!.status.name}",
                              style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    AppDialogActions(
                      actions: [
                        if (error != null) ...[
                          AppButton(
                            onPressed: () {
                              manager.reset();
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text("Cancel"),
                          ),
                          AppButton(
                            onPressed: () => manager.startUpdate(manager.downloadUrl!),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Retry"),
                          ),
                        ] else if (status == AppUpdateStatus.readyToInstall) ...[
                          AppButton(
                            onPressed: () {
                              manager.reset();
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text("Cancel"),
                          ),
                          AppButton(
                            onPressed: () => manager.triggerInstall(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Install Now"),
                          ),
                        ] else ...[
                          AppButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text("Background"),
                          ),
                          AppButton(
                            onPressed: () {
                              manager.reset();
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.errorContainer,
                              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                            child: const Text("Cancel"),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    );
  }
}

class GlobalUpdateOverlay extends StatelessWidget {
  final Widget child;
  const GlobalUpdateOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ListenableBuilder(
          listenable: UpdateManager.instance,
          builder: (context, _) {
            final manager = UpdateManager.instance;
            if (!manager.hasActiveUpdate || manager.isDialogVisible) return const SizedBox.shrink();

            return Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Material(
                elevation: 8,
                color: Colors.white,
                child: InkWell(
                  onTap: () {
                    final navContext = navigatorKey.currentContext;
                    if (navContext != null) {
                      AppAnimations.showSmoothDialog(
                        context: navContext,
                        barrierDismissible: false,
                        builder: (context) => const UpdateProgressDialog(),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              manager.status == AppUpdateStatus.readyToInstall 
                                ? Icons.check_circle_outline 
                                : Icons.downloading, 
                              size: 16, 
                              color: manager.status == AppUpdateStatus.readyToInstall 
                                ? Colors.green 
                                : Theme.of(context).colorScheme.primary
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                manager.status == AppUpdateStatus.readyToInstall
                                  ? "Update ready to install"
                                  : "Downloading update...", 
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
                              ),
                            ),
                            Text("${(manager.progress * 100).toInt()}%", style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: manager.progress,
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                          color: manager.status == AppUpdateStatus.readyToInstall 
                            ? Colors.green 
                            : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

void showUpdateDialog({
  required BuildContext context,
  required String remoteVersion,
  required String downloadUrl,
}) {
  AppAnimations.showSmoothDialog(
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
                
                // Use UpdateManager to start the update
                UpdateManager.instance.startUpdate(downloadUrl);
                
                AppAnimations.showSmoothDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const UpdateProgressDialog(),
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
  AppAnimations.showSmoothDialog(
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
                
                // Use UpdateManager to start the update
                UpdateManager.instance.startUpdate(downloadUrl);
                
                AppAnimations.showSmoothDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const UpdateProgressDialog(),
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
    AppAnimations.showSmoothDialog(
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
