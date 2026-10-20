import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// OSM's required attribution text and link target.
const osmAttributionText = '© OpenStreetMap contributors';
final osmCopyrightUri = Uri.parse('https://www.openstreetmap.org/copyright');

/// Map credit.
///
/// Expanded (the default) it shows the full attribution with a visible
/// "© OpenStreetMap contributors" link to the OSM copyright page, as the
/// OSMF attribution guidelines require. The parent may collapse it to a
/// small "©" after the user interacts with the map; tapping it expands again.
class AttributionChip extends StatefulWidget {
  const AttributionChip({
    super.key,
    required this.text,
    this.collapsed = false,
    this.onExpand,
    this.openUri,
  });

  final String text;

  /// Show only "©" (allowed once the user has interacted with the map).
  final bool collapsed;

  /// Called when the collapsed chip is tapped.
  final VoidCallback? onExpand;

  /// Opens a link; defaults to the platform browser (tests inject a fake).
  final Future<void> Function(Uri uri)? openUri;

  @override
  State<AttributionChip> createState() => _AttributionChipState();
}

class _AttributionChipState extends State<AttributionChip> {
  late final TapGestureRecognizer _osmTap = TapGestureRecognizer()
    ..onTap = _openCopyright;

  @override
  void dispose() {
    _osmTap.dispose();
    super.dispose();
  }

  Future<void> _openCopyright() async {
    final open = widget.openUri;
    if (open != null) {
      await open(osmCopyrightUri);
      return;
    }
    try {
      await launchUrl(osmCopyrightUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('open OSM copyright failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final base = theme.textTheme.labelSmall?.copyWith(
      fontSize: 11,
      height: 1.2,
      color: fg.withValues(alpha: 0.85),
    );

    if (widget.collapsed) {
      return Tooltip(
        message: widget.text,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: widget.onExpand,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                '©',
                semanticsLabel: widget.text,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  height: 1,
                  color: fg.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final text = widget.text;
    final i = text.indexOf(osmAttributionText);
    final before = i < 0 ? '' : text.substring(0, i);
    final after = i < 0
        ? ' $text'
        : text.substring(i + osmAttributionText.length);
    final link = TextSpan(
      text: osmAttributionText,
      recognizer: _osmTap,
      mouseCursor: SystemMouseCursors.click,
      style: base?.copyWith(
        color: theme.colorScheme.primary,
        decoration: TextDecoration.underline,
        fontWeight: FontWeight.w600,
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            if (before.isNotEmpty) TextSpan(text: before),
            link,
            if (after.trim().isNotEmpty) TextSpan(text: after),
          ],
        ),
        key: const ValueKey('attribution-text'),
      ),
    );
  }
}
