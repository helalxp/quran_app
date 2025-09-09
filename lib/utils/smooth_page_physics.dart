// lib/utils/smooth_page_physics.dart - Truly smooth page physics without bounce

import 'package:flutter/material.dart';

/// Minimal page physics - no bounce, just smooth page turns
class MinimalPagePhysics extends PageScrollPhysics {
  const MinimalPagePhysics({super.parent});

  @override
  MinimalPagePhysics applyTo(ScrollPhysics? ancestor) {
    return MinimalPagePhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
    mass: 5.0,        // Very heavy mass = dead stop
    stiffness: 50.0,  // Very low stiffness = no spring
    damping: 1.0,     // Maximum damping = zero bounce
  );

  @override
  double get dragStartDistanceMotionThreshold => 1.0;

  @override
  double get maxFlingVelocity => 800.0;  // Lower max velocity

  @override
  double get minFlingVelocity => 50.0;   // Lower min velocity

  @override
  Tolerance get tolerance => const Tolerance(
    velocity: 5.0,   // Very high tolerance = stops immediately
    distance: 1.0,   // High distance tolerance = less precise but smoother
  );
}

/// Butter-smooth physics with no spring bounce whatsoever  
class ButterSmoothPhysics extends ScrollPhysics {
  const ButterSmoothPhysics({super.parent});

  @override
  ButterSmoothPhysics applyTo(ScrollPhysics? ancestor) {
    return ButterSmoothPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
    mass: 2.0,        // Very heavy = no bounce at all
    stiffness: 80.0,  // Very low stiffness = gentle
    damping: 1.0,     // Maximum damping = dead stop
  );

  @override
  double get dragStartDistanceMotionThreshold => 2.0;

  @override
  double get maxFlingVelocity => 1500.0;

  @override
  double get minFlingVelocity => 80.0;

  @override
  Tolerance get tolerance => const Tolerance(
    velocity: 2.0,   // Very relaxed for smooth stop
    distance: 0.3,   // Allow more settling for smoothness
  );
}