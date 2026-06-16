import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final Color? color;
  final Color? iconColor;

  const AppLogo({
    super.key,
    this.size = 28,
    this.showText = true,
    this.color,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final primary = color ?? const Color(0xFF3E1F11);
    final secondary = iconColor ?? const Color(0xFFB06F4D);

    Widget logoIcon = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer connection loop
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: secondary.withValues(alpha: 0.35),
                width: size * 0.08,
              ),
            ),
          ),
          // Inner network ring
          Container(
            margin: EdgeInsets.all(size * 0.15),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: secondary,
                width: size * 0.08,
              ),
            ),
          ),
          // The twin pause bars representing taking a break/pause
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: size * 0.09,
                height: size * 0.35,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(size * 0.04),
                ),
              ),
              SizedBox(width: size * 0.08),
              Container(
                width: size * 0.09,
                height: size * 0.35,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(size * 0.04),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (!showText) {
      return logoIcon;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        logoIcon,
        SizedBox(width: size * 0.3),
        Text(
          'Boarding Pause',
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: size * 0.72,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: primary,
          ),
        ),
      ],
    );
  }
}
