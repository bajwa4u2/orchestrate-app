import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'surface.dart';

class AsyncSurface<T> extends StatelessWidget {
  const AsyncSurface({
    super.key,
    required this.future,
    required this.builder,
  });

  final Future<T> future;
  final Widget Function(BuildContext context, T? data) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AsyncLoadingSurface();
        }

        return builder(context, snapshot.hasData ? snapshot.data : null);
      },
    );
  }
}

class _AsyncLoadingSurface extends StatelessWidget {
  const _AsyncLoadingSurface();

  @override
  Widget build(BuildContext context) {
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _LoadingBar(width: 108, height: 14),
          SizedBox(height: 22),
          _LoadingBar(width: double.infinity, height: 44),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _LoadingBar(width: double.infinity, height: 72)),
              SizedBox(width: 12),
              Expanded(child: _LoadingBar(width: double.infinity, height: 72)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width == double.infinity ? null : width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.panelSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line.withOpacity(0.6)),
      ),
    );
  }
}
