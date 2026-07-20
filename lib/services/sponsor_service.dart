import 'package:cloud_firestore/cloud_firestore.dart';

/// Singleton service for the Firestore `sponsors` collection.
class SponsorService {
  static final SponsorService _instance = SponsorService._internal();
  factory SponsorService() => _instance;
  SponsorService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sponsorsRef =>
      _firestore.collection('sponsors');

  /// Adds a new sponsor document.
  Future<String> addSponsor({
    required String brand,
    required String title,
    required String cta,
    String? url,
    String? icon,
  }) async {
    try {
      final docRef = await _sponsorsRef.add({
        'brand': brand,
        'title': title,
        'cta': cta,
        'url': url ?? '',
        'icon': icon ?? 'star',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add sponsor: $e');
    }
  }

  /// Streams the list of all sponsors ordered by creation date (descending).
  Stream<QuerySnapshot<Map<String, dynamic>>> streamSponsors() {
    return _sponsorsRef.orderBy('createdAt', descending: true).snapshots();
  }

  /// Consumer clients ignore paused advertisements. This stays unfiltered so
  /// older records without an `isActive` field remain visible.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamActiveSponsors() {
    return _sponsorsRef.orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> setSponsorActive(String sponsorId, bool isActive) {
    return _sponsorsRef.doc(sponsorId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a sponsor document by its ID.
  Future<void> deleteSponsor(String sponsorId) async {
    try {
      await _sponsorsRef.doc(sponsorId).delete();
    } catch (e) {
      throw Exception('Failed to delete sponsor: $e');
    }
  }
}
