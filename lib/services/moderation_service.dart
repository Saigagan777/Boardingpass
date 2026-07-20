import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firestore-backed safety workflow. Reports are unique per reporter/target
/// pair, so a person cannot inflate a report count by submitting repeatedly.
class ModerationService {
  ModerationService._();
  static final ModerationService instance = ModerationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int restrictionThreshold = 10;

  Future<void> reportUser({
    required String reportedUserId,
    required String reason,
    String? chatId,
  }) async {
    final reporterId = FirebaseAuth.instance.currentUser?.uid;
    final cleanReason = reason.trim();
    if (reporterId == null) throw Exception('Please sign in before reporting.');
    if (reporterId == reportedUserId) throw Exception('You cannot report yourself.');
    if (cleanReason.length < 10) {
      throw Exception('Please give at least 10 characters so moderators can act.');
    }

    final reportId = '${reportedUserId}_$reporterId';
    final reportRef = _firestore.collection('reports').doc(reportId);
    final userRef = _firestore.collection('users').doc(reportedUserId);

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(reportRef);
      if (existing.exists) {
        throw Exception('You have already reported this user.');
      }
      final user = await transaction.get(userRef);
      if (!user.exists) throw Exception('This user account no longer exists.');

      final data = user.data() ?? <String, dynamic>{};
      final currentCount = (data['reportCount'] as num?)?.toInt() ?? 0;
      final nextCount = currentCount + 1;
      final shouldRestrict = nextCount >= restrictionThreshold;

      transaction.set(reportRef, {
        'reportedUserId': reportedUserId,
        'reporterId': reporterId,
        'reason': cleanReason,
        'chatId': chatId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(userRef, {
        'reportCount': nextCount,
        'lastReportedAt': FieldValue.serverTimestamp(),
        if (shouldRestrict) 'isDiscoverable': false,
        if (shouldRestrict) 'isLoginRestricted': true,
        if (shouldRestrict) 'moderationStatus': 'restricted',
        if (shouldRestrict) 'restrictedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> setUserRestriction(String userId, bool restricted) {
    return _firestore.collection('users').doc(userId).update({
      'isLoginRestricted': restricted,
      'isDiscoverable': !restricted,
      'moderationStatus': restricted ? 'restricted' : 'active',
      'moderationUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setReportStatus(String reportId, String status) {
    return _firestore.collection('reports').doc(reportId).update({
      'status': status,
      'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }
}
