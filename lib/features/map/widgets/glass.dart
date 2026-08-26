import 'dart:ui';

import 'package:flutter/material.dart';

/// Frosted map chrome. Readable in sun, dim in night driving.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.padding,
    this.onTap,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final r = BorderRadius.circular(borderRadius);
    final panel = ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: r,
            color: theme.colorScheme.surface.withValues(alpha: dark ? 0.88 : 0.94),
            border: Border.all(
              color: Colors.white.withValues(alpha: dark ? 0.08 : 0.45),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: padding == null
              ? child
              : Padding(padding: padding!, child: child),
        ),
      ),
    );
    if (onTap == null) return panel;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, borderRadius: r, child: panel),
    );
  }
}
