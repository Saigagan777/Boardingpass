import 'package:flutter/material.dart';

class Candidate {
  final String name;
  final String role;
  final String org;
  final String loc;
  final int match;
  final String intent;
  final List<String> tags;
  final String bio;
  final String initials;
  final Color primaryColor;

  const Candidate({
    required this.name,
    required this.role,
    required this.org,
    required this.loc,
    required this.match,
    required this.intent,
    required this.tags,
    required this.bio,
    required this.initials,
    required this.primaryColor,
  });
}
