
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
  if (currentUid == targetUid) return 100;

  // 1. Stable base score based on UIDs hash so that it stays consistent
  final combinedString = '${currentUid}_$targetUid';
  int hash = 0;
  for (int i = 0; i < combinedString.length; i++) {
    hash = combinedString.codeUnitAt(i) + ((hash << 5) - hash);
  }
  // Map hash to a base score between 72 and 86
  int baseScore = 72 + (hash.abs() % 15);

  // 2. Normalize and compute intersections
  Set<String> cleanUserSkills = {...currentSkills, ...currentExpertise}
      .map((s) => s.toLowerCase().trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  Set<String> cleanTargetSkills = {...targetSkills, ...targetExpertise}
      .map((s) => s.toLowerCase().trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  int skillOverlap = cleanUserSkills.intersection(cleanTargetSkills).length;

  Set<String> cleanUserInterests = currentInterests
      .map((s) => s.toLowerCase().trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  Set<String> cleanTargetInterests = targetInterests
      .map((s) => s.toLowerCase().trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  int interestOverlap = cleanUserInterests.intersection(cleanTargetInterests).length;

  Set<String> cleanUserIntents = currentIntents
      .map((s) => s.toLowerCase().trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  Set<String> cleanTargetIntents = targetIntents
      .map((s) => s.toLowerCase().trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  int intentOverlap = cleanUserIntents.intersection(cleanTargetIntents).length;

  // 3. Compute overlap bonus
  int bonus = (skillOverlap * 5) + (interestOverlap * 3) + (intentOverlap * 4);
  int finalScore = baseScore + bonus;

  // Clamp final score between 70% and 98%
  if (finalScore > 98) finalScore = 98;
  if (finalScore < 70) finalScore = 70;

  return finalScore;
}
