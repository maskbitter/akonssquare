import 'package:flutter/material.dart';

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
    final defaultStyle = ElevatedButton.styleFrom(
      elevation: 2, // Card-like elevation
      shadowColor: Theme.of(context).colorScheme.shadow.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    );

    final effectiveStyle = style != null ? defaultStyle.merge(style) : defaultStyle;

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
  final bool isOutdated;
  final Color? color;
  final Color? secondaryColor;
  final CrossAxisAlignment crossAxisAlignment;

  const AppVersionInfo({
    super.key,
    required this.version,
    required this.dbVersion,
    this.latestVersion,
    this.isOutdated = false,
    this.color,
    this.secondaryColor,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    // CENTRALIZED STYLE CONFIG
    const double mainFontSize = 8.0;
    const double secondaryFontSize = 7.0;

    final effectiveColor = color ?? Theme.of(context).colorScheme.tertiary;
    final effectiveSecondary = secondaryColor ?? Theme.of(context).colorScheme.secondary;

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: "V: $version", 
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: effectiveColor, 
                  fontWeight: FontWeight.bold, 
                  fontSize: mainFontSize
                )
              ),
              if (isOutdated && latestVersion != null) ...[
                TextSpan(
                  text: " | ", 
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline, 
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
        const SizedBox(height: 1),
        Text(
          "DB V-$dbVersion",
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: mainFontSize,
            color: effectiveSecondary, 
            fontWeight: FontWeight.bold, 
          ),
        ),
      ],
    );
  }
}
