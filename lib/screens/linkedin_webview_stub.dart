import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Web implementation of LinkedIn OAuth.
///
/// Instead of opening a popup or external tab, this redirects the CURRENT
/// browser tab to LinkedIn's authorization page. After the user authorizes,
/// LinkedIn redirects back to the app's own URL with ?code=XXX in the URL.
/// The code is then picked up automatically by main.dart on page reload.
Future<String?> showLinkedInWebView(BuildContext context, String authUrl) async {
  final Uri uri = Uri.parse(authUrl);
  try {
    // webOnlyWindowName: '_self' redirects the current tab instead of opening a new one
    await launchUrl(
      uri,
      webOnlyWindowName: '_self',
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not launch LinkedIn login: $e'),
          backgroundColor: const Color(0xFF7A432D),
        ),
      );
    }
  }
  // The page will navigate away to LinkedIn; return null as a formality.
  // When LinkedIn redirects back, main.dart handles the code from the URL.
  return null;
}
