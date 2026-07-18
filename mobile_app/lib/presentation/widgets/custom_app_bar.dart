import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final List<Widget>? leadingActions;
  final Widget? leading;
  final bool showBackButton;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? backButtonBackgroundColor;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leadingActions,
    this.leading,
    this.showBackButton = true,
    this.backgroundColor,
    this.textColor,
    this.backButtonBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? theme.colorScheme.surface;
    final fgColor = textColor ?? theme.colorScheme.onSurface;
    final canPopContext = Navigator.canPop(context);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            children: [
              // Left section: expandable, left-aligned
              Flexible(
                flex: 1,
                child: Row(
                  children: [
                    // Back button
                    if (leading != null)
                      leading!
                    else if (showBackButton && canPopContext)
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                backButtonBackgroundColor ??
                                theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: fgColor,
                            size: 20,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    // Leading actions
                    if (leadingActions != null && leadingActions!.isNotEmpty)
                      ...leadingActions!,
                  ],
                ),
              ),

              // Center: title
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: fgColor,
                    ),
                  ),
                ),
              ),

              // Right section: expandable, right-aligned
              Flexible(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [...?actions],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
