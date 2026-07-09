import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  const GlassCard({
    super.key,
    required this.child,
    this.accent = const Color(0xFF3B82F6),
    this.padding = const EdgeInsets.all(12),
    this.onTap,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.9, -0.75),
                  radius: 1.45,
                  colors: [
                    accent.withValues(alpha: 0.24),
                    const Color(0xFF4A90E2).withValues(alpha: 0.12),
                    const Color(0xFF7C8CFF).withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.08),
                  ],
                  stops: const [0.0, 0.34, 0.68, 1.0],
                ),
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.75),
                  width: 1.05,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF13325B).withValues(alpha: 0.13),
                    blurRadius: 20,
                    spreadRadius: -6,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: -32,
                    top: -34,
                    child: IgnorePointer(
                      child: Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              accent.withValues(alpha: 0.22),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.90),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: onTap == null
                            ? body
                            : Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: onTap,
                                  splashColor: accent.withValues(alpha: 0.14),
                                  highlightColor: Colors.white.withValues(alpha: 0.08),
                                  child: body,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
