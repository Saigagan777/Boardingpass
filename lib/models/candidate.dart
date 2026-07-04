import 'package:flutter/material.dart';
import 'user_profile.dart'; // To access CustomCard

class Candidate {
  final String? uid;
  final String name;
  final String headline;
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
  final String experience;
  final List<Map<String, dynamic>> careerTimeline;
  final List<Map<String, dynamic>> educationTimeline;

  // V2 Profile Matching fields
  final List<Map<String, dynamic>> expertiseWithLevel;
  final List<Map<String, dynamic>> interestsWithPriority;
  final List<String> matchReasons;
  final List<String> conversationStarters;
  final List<String> badges;
  final int completedMentoringSessions;
  final int successfulCollaborations;

  const Candidate({
    this.uid,
    required this.name,
    this.headline = '',
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
    this.experience = '',
    this.careerTimeline = const [],
    this.educationTimeline = const [],
    this.expertiseWithLevel = const [],
    this.interestsWithPriority = const [],
    this.matchReasons = const [],
    this.conversationStarters = const [],
    this.badges = const [],
    this.completedMentoringSessions = 0,
    this.successfulCollaborations = 0,
  });
}
