import 'package:flutter/material.dart';
import 'user_profile.dart'; // To access CustomCard

class Candidate {
  final String? uid;
  final String name;
  final String role;
  final String org;
  final String loc;
  final int match;
  final String intent;
  final List<String> tags;
  final String bio;
  final String initials;
  final String? profileImageUrl;
  final Color primaryColor;
  final List<CustomCard> customCards;
  final List<String> interests;
  final List<String> skills;
  final String homeBase;
  final String industry;

  const Candidate({
    this.uid,
    required this.name,
    required this.role,
    required this.org,
    required this.loc,
    required this.match,
    required this.intent,
    required this.tags,
    required this.bio,
    required this.initials,
    this.profileImageUrl,
    required this.primaryColor,
    this.customCards = const [],
    this.interests = const [],
    this.skills = const [],
    this.homeBase = '',
    this.industry = '',
  });
}
