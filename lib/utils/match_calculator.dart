
class MatchResult {
  final int score;
  final List<String> reasons;
  final List<String> conversationStarters;

  const MatchResult({
    required this.score,
    required this.reasons,
    required this.conversationStarters,
  });
}

// Predefined knowledge graph of Interest -> related Expertise
const Map<String, List<String>> interestToExpertiseMap = {
  'artificial intelligence': [
    'machine learning',
    'deep learning',
    'computer vision',
    'nlp',
    'mlops',
    'data engineering',
    'ai/ml',
    'data science',
    'artificial intelligence',
  ],
  'ai': [
    'machine learning',
    'deep learning',
    'computer vision',
    'nlp',
    'mlops',
    'data engineering',
    'ai/ml',
    'data science',
    'artificial intelligence',
  ],
  'investing': [
    'stock market',
    'investing',
    'portfolio management',
    'financial analysis',
    'risk management',
    'economics',
  ],
  'stock market': [
    'investing',
    'trading',
    'portfolio management',
    'financial analysis',
    'risk management',
    'economics',
  ],
  'startups': [
    'leadership',
    'product strategy',
    'ui/ux',
    'marketing',
    'sales',
    'public speaking',
    'flutter',
    'react',
    'spring boot',
    'data science',
    'startup founder',
  ],
  'entrepreneurship': [
    'leadership',
    'product strategy',
    'marketing',
    'sales',
    'public speaking',
    'startup founder',
  ],
  'design': [
    'ui/ux',
    'design',
    'product strategy',
    'marketing',
  ],
  'fitness': [
    'fitness',
    'leadership',
  ],
  'personal finance': [
    'investing',
    'stock market',
    'financial analysis',
    'risk management',
    'finance',
    'accountant',
  ],
  'public speaking': [
    'marketing',
    'leadership',
    'sales',
    'public speaking',
  ],
  'content creation': [
    'marketing',
    'photographer',
    'designer',
    'creator',
    'ui/ux',
    'writer',
  ],
};

/// Helper to determine if an expertise area satisfies a particular interest.
bool doesExpertiseSatisfyInterest(String expertise, String interest) {
  final exp = expertise.toLowerCase().trim();
  final intr = interest.toLowerCase().trim();

  if (exp == intr) return true;

  if (interestToExpertiseMap.containsKey(intr)) {
    final related = interestToExpertiseMap[intr]!;
    if (related.any((r) => exp.contains(r) || r.contains(exp))) {
      return true;
    }
  }

  // Fallback substring matching
  if (exp.contains(intr) || intr.contains(exp)) {
    return true;
  }

  return false;
}

/// Dynamic explainable matching algorithm returning score, reasons, and icebreakers
MatchResult calculateDetailedMatch({
  required String currentUid,
  required String targetUid,
  required String currentRole,
  required String targetRole,
  required List<Map<String, dynamic>> currentExpertise,
  required List<Map<String, dynamic>> currentInterests,
  required List<Map<String, dynamic>> targetExpertise,
  required List<Map<String, dynamic>> targetInterests,
  required List<String> currentSkills,
  required List<String> currentInterestsList,
  required List<String> targetSkills,
  required List<String> targetInterestsList,
  required List<String> targetBadges,
  required int targetEndorsements,
  int targetSessions = 0,
}) {
  if (currentUid == targetUid) {
    return const MatchResult(
      score: 100,
      reasons: ['This is your own profile.'],
      conversationStarters: [],
    );
  }

  // 1. Stable base score based on UIDs hash
  final combinedString = '${currentUid}_$targetUid';
  int hash = 0;
  for (int i = 0; i < combinedString.length; i++) {
    hash = combinedString.codeUnitAt(i) + ((hash << 5) - hash);
  }
  int baseScore = 70 + (hash.abs() % 10); // 70 to 79 base score

  List<String> reasons = [];
  List<String> starters = [];
  int scoreBoost = 0;

  // Normalize current expertise
  final List<Map<String, dynamic>> normCurrentExpertise = [];
  if (currentExpertise.isNotEmpty) {
    normCurrentExpertise.addAll(currentExpertise);
  } else {
    for (final s in currentSkills) {
      normCurrentExpertise.add({'name': s, 'level': 'Advanced'});
    }
  }

  // Normalize target expertise
  final List<Map<String, dynamic>> normTargetExpertise = [];
  if (targetExpertise.isNotEmpty) {
    normTargetExpertise.addAll(targetExpertise);
  } else {
    for (final s in targetSkills) {
      normTargetExpertise.add({'name': s, 'level': 'Advanced'});
    }
  }

  // Normalize current interests
  final List<Map<String, dynamic>> normCurrentInterests = [];
  if (currentInterests.isNotEmpty) {
    normCurrentInterests.addAll(currentInterests);
  } else {
    for (final i in currentInterestsList) {
      normCurrentInterests.add({'name': i, 'priority': 'Medium'});
    }
  }

  // Normalize target interests
  final List<Map<String, dynamic>> normTargetInterests = [];
  if (targetInterests.isNotEmpty) {
    normTargetInterests.addAll(targetInterests);
  } else {
    for (final i in targetInterestsList) {
      normTargetInterests.add({'name': i, 'priority': 'Medium'});
    }
  }

  // 2. Expertise satisfying Current User's Interests (Value Exchange: Target -> Current)
  int interestsSatisfiedByTarget = 0;
  for (final interestObj in normCurrentInterests) {
    final interestName = (interestObj['name'] ?? '').toString().trim();
    if (interestName.isEmpty) continue;
    final priority = (interestObj['priority'] ?? 'Medium').toString();

    // Priority weight
    int priorityWeight = 10;
    if (priority == 'High') priorityWeight = 15;
    if (priority == 'Medium') priorityWeight = 10;
    if (priority == 'Low') priorityWeight = 5;

    for (final expObj in normTargetExpertise) {
      final expName = (expObj['name'] ?? '').toString().trim();
      if (expName.isEmpty) continue;
      final level = (expObj['level'] ?? 'Intermediate').toString();

      if (doesExpertiseSatisfyInterest(expName, interestName)) {
        interestsSatisfiedByTarget++;

        // Level multiplier
        double multiplier = 0.8;
        if (level == 'Expert') multiplier = 1.2;
        if (level == 'Advanced') multiplier = 1.0;
        if (level == 'Intermediate') multiplier = 0.8;
        if (level == 'Beginner') multiplier = 0.5;

        scoreBoost += (priorityWeight * multiplier).round();
        reasons.add('Their $level-level expertise in $expName satisfies your interest in $interestName.');
        starters.add('I noticed you\'re experienced in $expName. I\'d love to learn how you started.');
        break; // Match each interest once
      }
    }
  }

  // 3. Current User's Expertise satisfying Target User's Interests (Value Exchange: Current -> Target)
  int interestsSatisfiedByCurrent = 0;
  for (final interestObj in normTargetInterests) {
    final interestName = (interestObj['name'] ?? '').toString().trim();
    if (interestName.isEmpty) continue;
    final priority = (interestObj['priority'] ?? 'Medium').toString();

    // Priority weight
    int priorityWeight = 8;
    if (priority == 'High') priorityWeight = 12;
    if (priority == 'Medium') priorityWeight = 8;
    if (priority == 'Low') priorityWeight = 4;

    for (final expObj in normCurrentExpertise) {
      final expName = (expObj['name'] ?? '').toString().trim();
      if (expName.isEmpty) continue;
      final level = (expObj['level'] ?? 'Intermediate').toString();

      if (doesExpertiseSatisfyInterest(expName, interestName)) {
        interestsSatisfiedByCurrent++;

        double multiplier = 0.8;
        if (level == 'Expert') multiplier = 1.2;
        if (level == 'Advanced') multiplier = 1.0;
        if (level == 'Intermediate') multiplier = 0.8;
        if (level == 'Beginner') multiplier = 0.5;

        scoreBoost += (priorityWeight * multiplier).round();
        reasons.add('Your $level-level expertise in $expName matches their interest in $interestName.');
        starters.add('I can help you with $expName development if you\'re interested.');
        break; // Match each interest once
      }
    }
  }

  // 4. Mutual Value Exchange (Reciprocal match bonus)
  if (interestsSatisfiedByTarget > 0 && interestsSatisfiedByCurrent > 0) {
    scoreBoost += 15;
    reasons.insert(0, 'You have a mutual value-exchange opportunity (both can help each other).');
  }

  // 5. Shared Interests
  final currentIntNames = normCurrentInterests.map((e) => e['name'].toString().toLowerCase().trim()).toSet();
  final targetIntNames = normTargetInterests.map((e) => e['name'].toString().toLowerCase().trim()).toSet();
  final sharedInterests = currentIntNames.intersection(targetIntNames);
  for (final shared in sharedInterests) {
    final originalName = normCurrentInterests.firstWhere((e) => e['name'].toString().toLowerCase().trim() == shared)['name'].toString();
    scoreBoost += 3;
    reasons.add('You both share an interest in $originalName.');
    starters.add('We both share an interest in $originalName.');
  }

  // 6. Occupation Synergy (informational relevance boost)
  final curRoleLower = currentRole.toLowerCase();
  final tarRoleLower = targetRole.toLowerCase();
  if (curRoleLower.contains('founder') || curRoleLower.contains('ceo')) {
    if (tarRoleLower.contains('cto') || tarRoleLower.contains('engineer') || tarRoleLower.contains('developer') || tarRoleLower.contains('pm') || tarRoleLower.contains('product')) {
      scoreBoost += 3;
      reasons.add('Occupation synergy: A $targetRole can help a founder/builder.');
    }
  }

  // 7. Reputation & Badges boost
  for (final badge in targetBadges) {
    scoreBoost += 2;
    reasons.add('Recommended as a $badge.');
  }
  if (targetEndorsements > 5) {
    scoreBoost += 2;
    reasons.add('Highly endorsed by the community ($targetEndorsements endorsements).');
  }
  if (targetSessions > 3) {
    scoreBoost += 2;
    reasons.add('Active mentor with $targetSessions completed sessions.');
  }

  int finalScore = baseScore + scoreBoost;
  if (finalScore > 98) finalScore = 98;
  if (finalScore < 70) finalScore = 70;

  // De-duplicate lists
  reasons = reasons.toSet().toList();
  starters = starters.toSet().toList();

  // If starters are empty, add a default fallback starter
  if (starters.isEmpty) {
    starters.add('Hi, I\'d love to connect and share some insights!');
  }

  return MatchResult(
    score: finalScore,
    reasons: reasons,
    conversationStarters: starters,
  );
}

/// Calculates a stable, positive match score (70% - 98%) between two profiles
/// based on their skills, interests, and intent overlap, as well as a stable UID hash.
int calculateMatchScore({
  required String currentUid,
  required String targetUid,
  required List<String> currentSkills,
  required List<String> currentInterests,
  required List<String> currentExpertise,
  required List<String> currentIntents,
  required List<String> targetSkills,
  required List<String> targetInterests,
  required List<String> targetExpertise,
  required List<String> targetIntents,
}) {
  final res = calculateDetailedMatch(
    currentUid: currentUid,
    targetUid: targetUid,
    currentRole: '',
    targetRole: '',
    currentExpertise: [],
    currentInterests: [],
    targetExpertise: [],
    targetInterests: [],
    currentSkills: [...currentSkills, ...currentExpertise],
    currentInterestsList: [...currentInterests, ...currentIntents],
    targetSkills: [...targetSkills, ...targetExpertise],
    targetInterestsList: [...targetInterests, ...targetIntents],
    targetBadges: [],
    targetEndorsements: 0,
  );
  return res.score;
}
