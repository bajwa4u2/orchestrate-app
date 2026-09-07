import 'package:flutter/material.dart';

class BrandAssets {
  BrandAssets._();

  static const String _logoLight =
      'assets/branding/logo/orchestrate_logo_light.png';
  static const String _logoDark =
      'assets/branding/logo/orchestrate_logo_dark.png';
  static const String _symbolLight =
      'assets/branding/logo/orchestrate_symbol_light.png';
  static const String _symbolDark =
      'assets/branding/logo/orchestrate_symbol_dark.png';

  static String logoFor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _logoDark
        : _logoLight;
  }

  /// Which mark to use.
  ///
  /// Normally the app's brightness decides. But a light theme may still place
  /// the mark on a deep field — the workspace rail does exactly that, because
  /// the deep field is what carries identity across from the public product —
  /// and there the asset must follow the SURFACE it sits on rather than the
  /// theme it inherits. Passing [onDark] says which one it is, instead of the
  /// caller faking a brightness to get the right file.
  static String symbolFor(BuildContext context, {bool? onDark}) {
    final dark = onDark ?? (Theme.of(context).brightness == Brightness.dark);
    return dark ? _symbolDark : _symbolLight;
  }

  static ImageProvider<Object> logoProvider(BuildContext context) {
    return AssetImage(logoFor(context));
  }

  static ImageProvider<Object> symbolProvider(BuildContext context) {
    return AssetImage(symbolFor(context));
  }

  static Widget logo(
    BuildContext context, {
    double height = 28,
    BoxFit fit = BoxFit.contain,
    String semanticLabel = 'Orchestrate',
    FilterQuality filterQuality = FilterQuality.high,
  }) {
    return ExcludeSemantics(
      child: Image.asset(
        logoFor(context),
        height: height,
        fit: fit,
        filterQuality: filterQuality,
        semanticLabel: semanticLabel,
      ),
    );
  }

  static Widget symbol(
    BuildContext context, {
    double size = 28,
    BoxFit fit = BoxFit.contain,
    String semanticLabel = 'Orchestrate',
    FilterQuality filterQuality = FilterQuality.high,
    bool? onDark,
  }) {
    return ExcludeSemantics(
      child: Image.asset(
        symbolFor(context, onDark: onDark),
        width: size,
        height: size,
        fit: fit,
        filterQuality: filterQuality,
        semanticLabel: semanticLabel,
      ),
    );
  }

  static Widget _wordmark({
    required String label,
    required double fontSize,
    required Color? color,
    required ThemeData theme,
    required bool flexible,
  }) {
    final text = Text(
      label,
      maxLines: 1,
      overflow: flexible ? TextOverflow.fade : TextOverflow.visible,
      softWrap: false,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
        height: 1,
        color: color,
      ),
    );
    return flexible ? Flexible(child: text) : text;
  }

  static Widget operatorLockup(
    BuildContext context, {
    double symbolSize = 34,
    double fontSize = 26,
    String label = 'Orchestrate',
    bool darkSurface = false,
    Color? color,
    /// Whether the wordmark may fade out when it does not fit.
    ///
    /// Fading is a reasonable default in a dense operator surface where the
    /// brand is incidental. It is the wrong answer on a public header, where a
    /// company introducing itself as "Orchest" is worse than a company whose
    /// name is a little smaller than intended.
    bool allowTruncation = true,
  }) {
    final theme = Theme.of(context);
    final symbol = darkSurface ? _symbolDark : symbolFor(context);

    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            symbol,
            width: symbolSize,
            height: symbolSize,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            semanticLabel: label,
          ),
          const SizedBox(width: 12),
          // Flexible is what allows the fade: it hands the text less width
          // than it asked for, and the text gives up the difference. Without
          // it the wordmark reports its true width, and a FittedBox above can
          // scale the whole lockup instead of the name losing letters.
          _wordmark(
            label: label,
            fontSize: fontSize,
            color: color,
            theme: theme,
            flexible: allowTruncation,
          ),
        ],
      ),
    );
  }
}
