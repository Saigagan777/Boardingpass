import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/candidate.dart';
import '../models/user_profile.dart';
import 'match_calculator.dart';

class CandidateHelper {
  static Future<Candidate> fetchCandidate(
    String targetUid,
    String currentUid,
  ) async {
    final targetDocFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(targetUid)
        .get();
    final currentDocFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .get();

    final targetDoc = await targetDocFuture;
    final currentDoc = await currentDocFuture;

    return getCandidateFromDocs(targetDoc, currentDoc);
  }

  static Candidate getCandidateFromDocs(
    DocumentSnapshot targetDoc,
    DocumentSnapshot currentDoc,
  ) {
    final data = targetDoc.data() as Map<String, dynamic>? ?? {};
    final currentUserData = currentDoc.data() as Map<String, dynamic>? ?? {};

    final currentUid = currentDoc.id;
    final targetUid = targetDoc.id;

    final currentUserSkills = List<String>.from(
      currentUserData['skills'] ?? [],
    );
    final currentUserInterests = List<String>.from(
      currentUserData['interests'] ?? [],
    );
    final currentUserExpertise = List<String>.from(
      currentUserData['expertise'] ?? [],
    );
    final currentUserIntents = List<String>.from(
      currentUserData['intents'] ?? [],
    );
    final currentExpertiseMapList =
        (currentUserData['expertiseWithLevel'] as List?)
            ?.map((item) => Map<String, dynamic>.from(item))
            .toList() ??
        [];
    final currentInterestsMapList =
        (currentUserData['interestsWithPriority'] as List?)
            ?.map((item) => Map<String, dynamic>.from(item))
            .toList() ??
        [];
    final currentRole = currentUserData['role'] ?? '';

    final expertise = List<String>.from(data['expertise'] ?? []);
    final intents = List<String>.from(data['intents'] ?? []);
    final interests = List<String>.from(data['interests'] ?? []);
    final skills = List<String>.from(data['skills'] ?? []);
    final customCardsData = data['customCards'] as List? ?? [];
    final customCards = customCardsData
        .map((item) => CustomCard.fromMap(Map<String, dynamic>.from(item)))
        .toList();
    final careerTimeline =
        (data['careerTimeline'] as List?)
            ?.map((item) => Map<String, dynamic>.from(item))
            .toList() ??
        [];
    final educationTimeline =
        (data['educationTimeline'] as List?)
            ?.map((item) => Map<String, dynamic>.from(item))
            .toList() ??
        [];

    final targetExpertiseMapList =
        (data['expertiseWithLevel'] as List?)
            ?.map((item) => Map<String, dynamic>.from(item))
            .toList() ??
        [];
    final targetInterestsMapList =
        (data['interestsWithPriority'] as List?)
            ?.map((item) => Map<String, dynamic>.from(item))
            .toList() ??
        [];
    final targetBadges = List<String>.from(data['badges'] ?? []);

    int sumEndorsements = 0;
    for (final exp in targetExpertiseMapList) {
      sumEndorsements += (exp['endorsements'] ?? 0) as int;
    }
    final targetSessions = data['completedMentoringSessions'] ?? 0;
    final targetCollaborations = data['successfulCollaborations'] ?? 0;

    final detailedMatch = calculateDetailedMatch(
      currentUid: currentUid,
      targetUid: targetUid,
      currentRole: currentRole,
      targetRole: data['role'] ?? '',
      currentExpertise: currentExpertiseMapList,
      currentInterests: currentInterestsMapList,
      targetExpertise: targetExpertiseMapList,
      targetInterests: targetInterestsMapList,
      currentSkills: [...currentUserSkills, ...currentUserExpertise],
      currentInterestsList: [...currentUserInterests, ...currentUserIntents],
      targetSkills: [...skills, ...expertise],
      targetInterestsList: [...interests, ...intents],
      targetBadges: targetBadges,
      targetEndorsements: sumEndorsements,
      targetSessions: targetSessions,
    );

    return Candidate(
      uid: targetUid,
      name: data['name'] ?? '',
      role: data['role'] ?? '',
      org: data['company'] ?? '',
      loc: data['currentLocationName'] ?? data['homeBase'] ?? '',
      match: detailedMatch.score,
      intent: intents.isNotEmpty ? intents.join(', ') : '',
      tags: expertise,
      interests: interests,
      skills: skills,
      homeBase: data['homeBase'] ?? '',
      currentLocationName: data['currentLocationName'] ?? '',
      industry: data['industry'] ?? '',
      experience: data['experience'] ?? '',
      careerTimeline: careerTimeline,
      educationTimeline: educationTimeline,
      bio: data['bio'] ?? '',
      initials: (data['name'] as String?)?.isNotEmpty == true
          ? data['name']
                .trim()
                .split(' ')
                .map((e) => e[0])
                .take(2)
                .join()
                .toUpperCase()
          : 'P',
      profileImageUrl: data['profileImageUrl'],
      primaryColor: const Color(0xFFE5A475),
      customCards: customCards,
      expertiseWithLevel: targetExpertiseMapList,
      interestsWithPriority: targetInterestsMapList,
      matchReasons: detailedMatch.reasons,
      conversationStarters: detailedMatch.conversationStarters,
      badges: targetBadges,
      completedMentoringSessions: targetSessions,
      successfulCollaborations: targetCollaborations,
    );
  }
}
