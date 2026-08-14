import 'package:flutter/material.dart';
import 'package:akonssquare/Common/theme_manager.dart';

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
    // CENTRALIZED STYLE CONFIG
    const double mainFontSize = 8.0;
    const double statusFontSize = 7.0;

    final effectiveColor = color ?? Theme.of(context).colorScheme.tertiary;
    
    // Logic for status message color and text
    bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
    Color effectiveSecondary = secondaryColor ?? (isOutline ? Colors.black : Theme.of(context).colorScheme.secondary);
    String displayDBText = "DB V-$dbVersion";
    
    if (statusMessage != null && statusMessage!.isNotEmpty) {
      displayDBText = statusMessage!;
      if (statusMessage!.contains("Delet") || statusMessage!.contains("Failed") || statusMessage!.contains("Backup")) {
        effectiveSecondary = Theme.of(context).colorScheme.error;
      }
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: "V: $version", 
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isOutline ? Colors.black : effectiveColor, 
                    fontWeight: FontWeight.bold, 
                    fontSize: mainFontSize
                  )
                ),
                if (isOutdated && latestVersion != null) ...[
                  TextSpan(
                    text: " | ", 
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isOutline ? Colors.black : Theme.of(context).colorScheme.outline, 
                      fontSize: mainFontSize
                    )
                  ),
                  TextSpan(
                    text: "Latest V: $latestVersion", 
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.error, 
                      fontWeight: FontWeight.bold, 
                      fontSize: mainFontSize
                    )
                  ),
                ]
              ]
            ),
          ),
          if (showLogoutIcon) ...[
            const SizedBox(height: 1),
            const Icon(
              Icons.logout, 
              size: 18, 
              color: Colors.red,
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
          if (connectionStatus != null && connectionStatus!.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              connectionStatus!,
              style: TextStyle(
                fontSize: statusFontSize,
                color: connectionColor ?? Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
