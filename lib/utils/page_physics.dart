// lib/utils/page_physics.dart - Custom page physics for smooth swiping

import 'package:flutter/material.dart';

/// Custom scroll physics for smoother page transitions in Quran reader
class SmoothPageScrollPhysics extends ScrollPhysics {
  const SmoothPageScrollPhysics({super.parent});

  @override
  SmoothPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SmoothPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
    mass: 0.5,      // Lighter feel
    stiffness: 150.0, // More responsive
    damping: 0.8,   // Less bouncy, smoother stop
  );

  @override
  double get dragStartDistanceMotionThreshold => 3.5;

  @override
  double get maxFlingVelocity => 2000.0; // Allow faster flings

  @override
  double get minFlingVelocity => 100.0;  // Lower threshold for fling

  @override
  Tolerance get tolerance => const Tolerance(
    velocity: 0.5,      // More precise velocity tolerance
    distance: 0.1,      // More precise distance tolerance
  );
}

/// Enhanced page physics that combines smooth scrolling with page snapping
class EnhancedPageScrollPhysics extends PageScrollPhysics {
  const EnhancedPageScrollPhysics({super.parent});

  @override
  EnhancedPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return EnhancedPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
    mass: 0.4,        // Even lighter for pages
    stiffness: 200.0, // More snappy page transitions
    damping: 0.85,    // Smooth settling
  );

  @override
  double get dragStartDistanceMotionThreshold => 2.0; // More sensitive

  @override
  double get maxFlingVelocity => 2500.0; // Fast page flips

  @override
  double get minFlingVelocity => 80.0;   // Easy page turns

  @override
  Tolerance get tolerance => const Tolerance(
    velocity: 0.3,  // Tighter velocity tolerance for pages
    distance: 0.05, // Very precise page positioning
  );

  // Custom friction would go here in newer Flutter versions
}

/// Ultra-smooth, non-bouncy physics for silk-like page transitions
class UltraSmoothPagePhysics extends ScrollPhysics {
  const UltraSmoothPagePhysics({super.parent});

  @override
  UltraSmoothPagePhysics applyTo(ScrollPhysics? ancestor) {
    return UltraSmoothPagePhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
    mass: 1.0,        // Heavier mass for less bouncy feel
    stiffness: 100.0, // Lower stiffness = less bouncy
    damping: 1.0,     // Maximum damping = no bounce
  );

  @override
  double get dragStartDistanceMotionThreshold => 3.0;

  @override
  double get maxFlingVelocity => 2000.0; 

  @override  
  double get minFlingVelocity => 100.0;

  @override
  Tolerance get tolerance => const Tolerance(
    velocity: 1.0,   // More relaxed for smoother stop
    distance: 0.1,   // Less precise for smoother feel
  );
}

/// Completely smooth physics with no bounce whatsoever
class SilkSmoothPhysics extends ScrollPhysics {
  const SilkSmoothPhysics({super.parent});

  @override
  SilkSmoothPhysics applyTo(ScrollPhysics? ancestor) {
    return SilkSmoothPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
    mass: 1.5,        // Heavy mass = no bounce
    stiffness: 80.0,  // Low stiffness = gentle movement
    damping: 1.0,     // Full damping = zero bounce
  );

  @override
  double get dragStartDistanceMotionThreshold => 2.0;

  @override
  double get maxFlingVelocity => 1500.0; 

  @override  
  double get minFlingVelocity => 80.0;

  @override
  Tolerance get tolerance => const Tolerance(
    velocity: 2.0,   // Very relaxed velocity
    distance: 0.2,   // Relaxed distance for smooth stop
  );
}