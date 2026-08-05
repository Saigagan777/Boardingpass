import 'package:flutter/material.dart';

import '../utils/bio_validation.dart';

/// Live character counter + validation message for the short bio field.
///
/// Shows `N / 100 min chars` (green when valid, brand/red while typing) and
/// an inline error message explaining what is wrong. Updates on every rebuild
/// because the surrounding screens already call `setState` on field changes.
class BioValidationLabel extends StatelessWidget {
  const BioValidationLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final length = text.trim().length;
    final error = validateBio(text);
    final tooLong = length > kBioMaxChars;
    final ok = error == null;

    final Color color;
    if (ok) {
      color = const Color(0xFF2E7D32);
    } else if (tooLong) {
      color = const Color(0xFFC62828);
    } else {
      color = const Color(0xFF7A432D);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.info_outline,
              size: 13,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              '$length / $kBioMinChars min chars',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                color: color,
                fontWeight: ok ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              error,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                color: Color(0xFFC62828),
              ),
            ),
          ),
      ],
    );
  }
}
