import 'package:flutter/material.dart';
import 'package:Mirarr/utils/expressive_motion.dart';

/// Custom Material 3 Expressive Page Transition Route.
/// Fast, lock-tight 120 FPS page transition utilizing Spatial Spring scale morphing
/// and Effects Spring fade transitions.
class ExpressivePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final ExpressiveSpeed speed;

  ExpressivePageRoute({
    required this.page,
    this.speed = ExpressiveSpeed.defaultSpeed,
    super.settings,
  }) : super(
          transitionDuration: speed.duration,
          reverseTransitionDuration: speed.duration,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final Curve spatialCurve = ExpressiveMotion.getSpatialCurve(speed);
            final Curve effectsCurve = ExpressiveMotion.getEffectsCurve(speed);

            final CurvedAnimation spatialAnim = CurvedAnimation(
              parent: animation,
              curve: spatialCurve,
              reverseCurve: spatialCurve,
            );

            final CurvedAnimation effectsAnim = CurvedAnimation(
              parent: animation,
              curve: effectsCurve,
              reverseCurve: effectsCurve,
            );

            final Animation<double> scaleAnimation = Tween<double>(
              begin: 0.94,
              end: 1.0,
            ).animate(spatialAnim);

            return FadeTransition(
              opacity: effectsAnim,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: child,
              ),
            );
          },
        );
}
