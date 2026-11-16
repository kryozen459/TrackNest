import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.radius = 20,
    this.tint,
    this.width,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? tint;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final highlight = tint ?? Colors.white;
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: light ? .075 : .18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeInOutCubic,
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  highlight.withValues(
                    alpha: light
                        ? (tint == null ? .17 : .11)
                        : (tint == null ? .105 : .17),
                  ),
                  Colors.white.withValues(alpha: light ? .48 : .045),
                ],
              ),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: light ? .78 : .17),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeInOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: light
                  ? const [
                      Color(0xFFE8F5F1),
                      Color(0xFFF3F7FC),
                      Color(0xFFE9F0F7),
                    ]
                  : const [
                      Color(0xFF07141E),
                      Color(0xFF102630),
                      Color(0xFF0A1721),
                    ],
            ),
          ),
        ),
        const Positioned(
          top: -150,
          right: -90,
          child: _AmbientGlow(size: 430, color: Color(0xFF28CDB5), opacity: .2),
        ),
        const Positioned(
          left: -170,
          top: 300,
          child: _AmbientGlow(
            size: 440,
            color: Color(0xFF3976C9),
            opacity: .17,
          ),
        ),
        const Positioned(
          right: 120,
          bottom: -250,
          child: _AmbientGlow(
            size: 500,
            color: Color(0xFF396D83),
            opacity: .15,
          ),
        ),
        child,
      ],
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 86, sigmaY: 86),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
