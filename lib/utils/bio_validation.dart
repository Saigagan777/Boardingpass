/// Validation rules for the user's short bio.
const int kBioMinChars = 100;
const int kBioMaxChars = 500;

/// Returns an error message if the bio is invalid, or `null` when valid.
///
/// Rules:
/// - Required (non-empty after trimming)
/// - At least [kBioMinChars] characters
/// - At most [kBioMaxChars] characters
String? validateBio(String? bio) {
  final trimmed = (bio ?? '').trim();
  if (trimmed.isEmpty) {
    return 'Please write a short bio about yourself.';
  }
  if (trimmed.length < kBioMinChars) {
    return 'Bio must be at least $kBioMinChars characters '
        '(currently ${trimmed.length}).';
  }
  if (trimmed.length > kBioMaxChars) {
    return 'Bio must be at most $kBioMaxChars characters '
        '(currently ${trimmed.length}).';
  }
  return null;
}
