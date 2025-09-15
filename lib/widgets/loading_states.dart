// lib/widgets/loading_states.dart

import 'package:flutter/material.dart';
import '../constants/app_strings.dart';

/// Standardized loading states for consistent UI across the app
class LoadingStates {
  // Private constructor to prevent instantiation
  LoadingStates._();

  /// Standard circular progress indicator with consistent styling
  static Widget circular({
    double? size,
    Color? color,
    double strokeWidth = 2.0,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color,
      ),
    );
  }

  /// Linear progress indicator with consistent styling
  static Widget linear({
    double? value,
    Color? backgroundColor,
    Color? valueColor,
    double minHeight = 4.0,
  }) {
    return LinearProgressIndicator(
      value: value,
      backgroundColor: backgroundColor,
      valueColor: valueColor != null ? AlwaysStoppedAnimation(valueColor) : null,
      minHeight: minHeight,
    );
  }

  /// Full screen loading overlay
  static Widget fullScreen({
    String? message,
    bool showMessage = true,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          circular(size: 48),
          if (showMessage) ...[
            const SizedBox(height: 16),
            Text(
              message ?? AppStrings.loading,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ],
      ),
    );
  }

  /// Compact loading state for inline use
  static Widget inline({
    String? message,
    bool showMessage = false,
    MainAxisAlignment alignment = MainAxisAlignment.center,
  }) {
    return Row(
      mainAxisAlignment: alignment,
      children: [
        circular(size: 16),
        if (showMessage && message != null) ...[
          const SizedBox(width: 8),
          Text(message, style: const TextStyle(fontSize: 12)),
        ],
      ],
    );
  }

  /// Loading button state
  static Widget button({
    double size = 20,
    Color? color,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color ?? Colors.white,
      ),
    );
  }

  /// Loading overlay for specific widgets
  static Widget overlay({
    required Widget child,
    bool isLoading = false,
    String? loadingMessage,
  }) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: fullScreen(message: loadingMessage),
          ),
      ],
    );
  }

  /// Shimmer-style loading placeholder
  static Widget shimmer({
    required double width,
    required double height,
    BorderRadius? borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius ?? BorderRadius.circular(4),
      ),
      child: const _ShimmerEffect(),
    );
  }
}

/// Loading state enum for standardized state management
enum LoadingState {
  idle,
  loading,
  success,
  error,
}

/// Mixin for standardized loading state management
mixin LoadingStateMixin<T extends StatefulWidget> on State<T> {
  LoadingState _loadingState = LoadingState.idle;
  String? _errorMessage;

  LoadingState get loadingState => _loadingState;
  bool get isLoading => _loadingState == LoadingState.loading;
  bool get hasError => _loadingState == LoadingState.error;
  String? get errorMessage => _errorMessage;

  void setLoadingState(LoadingState state, {String? error}) {
    if (mounted) {
      setState(() {
        _loadingState = state;
        _errorMessage = error;
      });
    }
  }

  void setLoading() => setLoadingState(LoadingState.loading);
  void setSuccess() => setLoadingState(LoadingState.success);
  void setError(String error) => setLoadingState(LoadingState.error, error: error);
  void setIdle() => setLoadingState(LoadingState.idle);

  /// Execute async operation with automatic loading state management
  Future<void> executeWithLoading(Future<void> Function() operation) async {
    setLoading();
    try {
      await operation();
      setSuccess();
    } catch (e) {
      setError(e.toString());
    }
  }
}

/// Shimmer effect widget for loading placeholders
class _ShimmerEffect extends StatefulWidget {
  const _ShimmerEffect();

  @override
  State<_ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<_ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.grey[300]!,
                Colors.grey[100]!,
                Colors.grey[300]!,
              ],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}