// lib/utils/animation_utils.dart - Animation utilities for smooth transitions

import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class AnimationUtils {
  // Standard animation durations
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = AppConstants.animationDuration;
  static const Duration slow = Duration(milliseconds: 500);
  
  // Ultra-fast for dialog lists to prevent blank appearance
  static const Duration ultraFast = Duration(milliseconds: 80);
  
  // Standard curves
  static const Curve slideInCurve = Curves.easeOutCubic;
  static const Curve slideOutCurve = Curves.easeInCubic;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve smoothCurve = Curves.easeInOutCubic;
  
  // Fade transition
  static Widget fadeTransition({
    required Widget child,
    required Animation<double> animation,
    Duration? duration,
  }) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }
  
  // Slide transition from bottom
  static Widget slideUpTransition({
    required Widget child,
    required Animation<double> animation,
    double offset = 1.0,
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0, offset),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: slideInCurve,
      )),
      child: child,
    );
  }
  
  // Scale transition
  static Widget scaleTransition({
    required Widget child,
    required Animation<double> animation,
    double startScale = 0.8,
  }) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: startScale,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: smoothCurve,
      )),
      child: child,
    );
  }
  
  // Combined fade + slide transition
  static Widget fadeSlideTransition({
    required Widget child,
    required Animation<double> animation,
    double slideOffset = 0.5,
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0, slideOffset),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: slideInCurve,
      )),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
  
  // Page transition builder
  static Widget buildPageTransition({
    required Widget child,
    required Animation<double> animation,
    PageTransitionType type = PageTransitionType.slideUp,
  }) {
    switch (type) {
      case PageTransitionType.fade:
        return fadeTransition(child: child, animation: animation);
      case PageTransitionType.slideUp:
        return slideUpTransition(child: child, animation: animation);
      case PageTransitionType.scale:
        return scaleTransition(child: child, animation: animation);
      case PageTransitionType.fadeSlide:
        return fadeSlideTransition(child: child, animation: animation);
    }
  }
  
  // Stagger animations helper
  static List<AnimationController> createStaggeredControllers({
    required TickerProvider vsync,
    required int count,
    Duration duration = normal,
    Duration staggerDelay = const Duration(milliseconds: 100),
  }) {
    final controllers = <AnimationController>[];
    for (int i = 0; i < count; i++) {
      final controller = AnimationController(
        duration: duration,
        vsync: vsync,
      );
      controllers.add(controller);
    }
    return controllers;
  }
  
  // Start staggered animations
  static void startStaggeredAnimations({
    required List<AnimationController> controllers,
    Duration staggerDelay = const Duration(milliseconds: 100),
  }) {
    for (int i = 0; i < controllers.length; i++) {
      Future.delayed(staggerDelay * i, () {
        if (!controllers[i].isCompleted) {
          controllers[i].forward();
        }
      });
    }
  }
  
  // Dispose staggered controllers
  static void disposeStaggeredControllers(List<AnimationController> controllers) {
    for (final controller in controllers) {
      controller.dispose();
    }
  }
}

enum PageTransitionType {
  fade,
  slideUp,
  scale,
  fadeSlide,
}

// Custom route with animation
class AnimatedRoute<T> extends MaterialPageRoute<T> {
  final PageTransitionType transitionType;
  final Duration _transitionDuration;
  
  AnimatedRoute({
    required super.builder,
    super.settings,
    this.transitionType = PageTransitionType.slideUp,
    Duration transitionDuration = AnimationUtils.normal,
  }) : _transitionDuration = transitionDuration;
  
  @override
  Duration get transitionDuration => _transitionDuration;
  
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return AnimationUtils.buildPageTransition(
      child: child,
      animation: animation,
      type: transitionType,
    );
  }
}

// Animated list item widget with scroll-responsive animations
class AnimatedListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;
  final bool enableScrollAdaptation;
  
  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 100),
    this.duration = AnimationUtils.normal,
    this.enableScrollAdaptation = true,
  });
  
  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    _animation = CurvedAnimation(
      parent: _controller,
      curve: AnimationUtils.smoothCurve,
    );
    
    if (widget.enableScrollAdaptation) {
      // For dialog lists, use minimal delay to prevent blank appearance
      final adaptedDelay = Duration(milliseconds: (widget.delay.inMilliseconds * 0.2).round()); // 80% faster
      final maxDelay = const Duration(milliseconds: 100); // Cap total delay
      final actualDelay = Duration(
        milliseconds: (adaptedDelay * widget.index).inMilliseconds.clamp(0, maxDelay.inMilliseconds)
      );
      
      Future.delayed(actualDelay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    } else {
      // Standard delay for non-dialog items
      Future.delayed(widget.delay * widget.index, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimationUtils.fadeSlideTransition(
      animation: _animation,
      child: widget.child,
    );
  }
}