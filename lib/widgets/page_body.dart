import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Keeps short pages spacious and lets small screens / large text scroll.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 460,
              minHeight: math.max(0, constraints.maxHeight - 48),
            ),
            child: IntrinsicHeight(child: child),
          ),
        ),
      ),
    ),
  );
}
