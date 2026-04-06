import 'package:flutter/material.dart';

class BrandAssets {
  BrandAssets._();

  static const String _logoLight = 'assets/branding/logo/orchestrate_logo_light.png';
  static const String _logoDark = 'assets/branding/logo/orchestrate_logo_dark.png';
  static const String _symbolLight = 'assets/branding/logo/orchestrate_symbol_light.png';
  static const String _symbolDark = 'assets/branding/logo/orchestrate_symbol_dark.png';

  static String logoFor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? _logoDark : _logoLight;
  }

  static String symbolFor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? _symbolDark : _symbolLight;
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
  }) {
    return ExcludeSemantics(
      child: Image.asset(
        symbolFor(context),
        width: size,
        height: size,
        fit: fit,
        filterQuality: filterQuality,
        semanticLabel: semanticLabel,
      ),
    );
  }

  static Widget operatorLockup(
    BuildContext context, {
    double symbolSize = 34,
    double fontSize = 26,
    String label = 'Orchestrate',
  }) {
    final theme = Theme.of(context);

    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            symbolFor(context),
            width: symbolSize,
            height: symbolSize,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            semanticLabel: label,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.6,
                    height: 1,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
