import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';

/// Substrate citation — mono file-path reference rendered at the
/// bottom of a substantive screen. Mirrors the citation footer on
/// the public website and the flagship cognition artifacts.
///
/// Per `company/visuals/system/annotations/annotation-grammar.md`
/// §10, every substantive runtime surface that derives from a real
/// backend substrate should cite that substrate by file path so
/// procurement reviewers, substantive engineers, and operators can
/// verify substrate claims. The citation is a first-class visual
/// element, not an afterthought.
///
/// Usage:
/// ```dart
/// SubstrateCitation(paths: [
///   'orchestrate_backend/src/runtime-truth/runtime-truth.types.ts',
///   'orchestrate_backend/src/governance/dispatch-governance.service.ts',
/// ])
/// ```
class SubstrateCitation extends StatelessWidget {
  const SubstrateCitation({
    super.key,
    required this.paths,
    this.padding = const EdgeInsets.only(top: 16),
    this.muted = true,
  });

  final List<String> paths;
  final EdgeInsetsGeometry padding;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final foreground = muted
        ? (isLight ? AppTheme.publicMuted : AppTheme.coMist)
        : (isLight ? AppTheme.publicText : AppTheme.coSnow);

    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Source:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: foreground,
              fontFamily: 'Inter',
            ),
          ),
          for (var i = 0; i < paths.length; i++) ...[
            SelectableText(
              paths[i],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: foreground,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
            if (i < paths.length - 1)
              Text(
                '·',
                style: TextStyle(
                  fontSize: 11,
                  color: foreground,
                  fontFamily: 'Inter',
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Substrate doctrine — a verbatim quotation from substrate canon,
/// rendered with a left-border accent. Used to anchor a substrate
/// claim with its canonical doctrine line.
///
/// Per `system/annotations/annotation-grammar.md` §9, doctrine
/// lines are verbatim from substrate — never paraphrased.
class SubstrateDoctrine extends StatelessWidget {
  const SubstrateDoctrine({
    super.key,
    required this.text,
    this.padding = const EdgeInsets.symmetric(vertical: 12),
  });

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final accent = isLight ? AppTheme.coTealDeep : AppTheme.coTeal;
    final foreground = isLight ? AppTheme.publicText : AppTheme.coSnow;

    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: accent, width: 2),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            color: foreground.withValues(alpha: 0.88),
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
