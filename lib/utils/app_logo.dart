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

    if (!showText) {
      return const SizedBox.shrink();
    }

    return Text(
      'NexMeet',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'PlayfairDisplay',
        fontSize: size * 0.72,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: primary,
      ),
    );
  }
}
