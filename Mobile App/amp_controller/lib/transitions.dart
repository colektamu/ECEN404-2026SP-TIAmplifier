// lib/transitions.dart
import 'package:flutter/material.dart';

class FadePageRoute<T> extends PageRouteBuilder<T> {
  FadePageRoute({required Widget child})
      : super(
          transitionDuration: const Duration(milliseconds: 180),
          reverseTransitionDuration: const Duration(milliseconds: 160),
          pageBuilder: (_, __, ___) => child,
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        );
}

class SlideRightRoute<T> extends PageRouteBuilder<T> {
  SlideRightRoute({required Widget child})
      : super(
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (_, __, ___) => child,
          transitionsBuilder: (_, animation, __, child) {
            final offset = Tween(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation);

            return SlideTransition(position: offset, child: child);
          },
        );
}
