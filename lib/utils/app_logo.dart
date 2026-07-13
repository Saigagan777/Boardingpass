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

    final logoIcon = Image.asset(
      'assets/images/app_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
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
        Flexible(
          child: Text(
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
          ),
        ),
      ],
    );
  }
}
