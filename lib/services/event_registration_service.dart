import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/event.dart';
import '../models/event_registration.dart';

/// Result of a host QR scan / check-in attempt.
class CheckInResult {
  final bool success;
  final String message;
  final EventRegistration? registration;

  const CheckInResult({
    required this.success,
    required this.message,
    this.registration,
  });
}

/// Firestore-backed event registration, tickets, wallet, and QR check-in.
class EventRegistrationService {
  static final EventRegistrationService _instance =
      EventRegistrationService._internal();
  factory EventRegistrationService() => _instance;
  EventRegistrationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _regRef =>
      _firestore.collection('event_registrations');

  CollectionReference<Map<String, dynamic>> get _eventsRef =>
      _firestore.collection('events');

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static const _monthMap = {
    'JAN': 1,
    'FEB': 2,
    'MAR': 3,
    'APR': 4,
    'MAY': 5,
    'JUN': 6,
    'JUL': 7,
    'AUG': 8,
    'SEP': 9,
    'OCT': 10,
    'NOV': 11,
    'DEC': 12,
  };

  /// Builds a plausible end-of-day expiry from event month/day labels.
  DateTime? estimateEventExpiry(String month, String day, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final monthKey = month.trim().toUpperCase();
    final m = monthKey.isEmpty
        ? null
        : _monthMap[monthKey.length >= 3 ? monthKey.substring(0, 3) : monthKey];
    final d = int.tryParse(day.trim().replaceAll(RegExp(r'[^0-9]'), ''));
    if (m == null || d == null) {
      // Fallback: 7 days from now
      return DateTime(n.year, n.month, n.day, 23, 59, 59)
          .add(const Duration(days: 7));
    }

    var year = n.year;
    var candidate = DateTime(year, m, d, 23, 59, 59);
    // If the date already passed more than 1 day ago, assume next year was meant
    // when creating far-future events; for past events keep current year so QR expires.
    if (candidate.isBefore(n.subtract(const Duration(days: 180)))) {
      candidate = DateTime(year + 1, m, d, 23, 59, 59);
    }
    return candidate;
  }

  String _generateTicketId() {
    final rnd = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 13; i++) {
      buffer.write(rnd.nextInt(10));
    }
    return buffer.toString();
  }

  String buildQrPayload({
    required String registrationId,
    required String ticketId,
    required String eventId,
  }) {
    return 'NEXMEET|$registrationId|$ticketId|$eventId';
  }

  /// Parses QR payloads produced by [buildQrPayload].
  static Map<String, String>? parseQrPayload(String raw) {
    final parts = raw.trim().split('|');
    if (parts.length < 4) return null;
    if (parts[0] != 'NEXMEET') return null;
    return {
      'registrationId': parts[1],
      'ticketId': parts[2],
      'eventId': parts[3],
    };
  }

  // ---------------------------------------------------------------------------
  // Register
  // ---------------------------------------------------------------------------

  /// Registers the current user for [event] with the given basic details.
  ///
  /// Returns the created (or existing) [EventRegistration].
  Future<EventRegistration> registerForEvent({
    required Event event,
    required String fullName,
    required String email,
    required String phone,
    String? company,
    String? role,
    String? notes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in');

    final existing = await getUserRegistrationForEvent(event.id, user.uid);
    if (existing != null) return existing;

    // Resolve organiser from live event doc when available.
    String organiserId = event.organiserId ?? '';
    try {
      final eventDoc = await _eventsRef.doc(event.id).get();
      if (eventDoc.exists) {
        organiserId =
            eventDoc.data()?['organiserId']?.toString() ?? organiserId;
      }
    } catch (_) {}

    final docRef = _regRef.doc();
    final ticketId = _generateTicketId();
    final qrPayload = buildQrPayload(
      registrationId: docRef.id,
      ticketId: ticketId,
      eventId: event.id,
    );
    final now = DateTime.now();
    final expiresAt = estimateEventExpiry(event.month, event.day, now: now);

    final registration = EventRegistration(
      id: docRef.id,
      eventId: event.id,
      userId: user.uid,
      organiserId: organiserId,
      fullName: fullName.trim(),
      email: email.trim(),
      phone: phone.trim(),
      company: company?.trim().isEmpty == true ? null : company?.trim(),
      role: role?.trim().isEmpty == true ? null : role?.trim(),
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      ticketId: ticketId,
      qrPayload: qrPayload,
      status: RegistrationStatus.registered,
      registeredAt: now,
      expiresAt: expiresAt,
      eventTitle: event.title,
      eventLocation: event.location,
      eventTime: event.time,
      eventMonth: event.month,
      eventDay: event.day,
      eventPrice: event.price,
      eventImageUrl: event.imageUrl,
      eventCategory: event.category,
      savedToWallet: false,
    );

    await docRef.set({
      ...registration.toMap(),
      'registeredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Also mark user as an attendee on the event document.
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(_eventsRef.doc(event.id));
        if (!snap.exists) return;
        final attendees = List<String>.from(snap.data()?['attendees'] ?? []);
        if (!attendees.contains(user.uid)) {
          attendees.add(user.uid);
          tx.update(_eventsRef.doc(event.id), {
            'attendees': attendees,
            'attendeeCount': attendees.length,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (_) {
      // Non-fatal: registration still exists.
    }

    return registration;
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  Future<EventRegistration?> getRegistration(String registrationId) async {
    final doc = await _regRef.doc(registrationId).get();
    if (!doc.exists) return null;
    return EventRegistration.fromFirestore(doc);
  }

  Future<EventRegistration?> getUserRegistrationForEvent(
    String eventId,
    String userId,
  ) async {
    final q = await _regRef
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return EventRegistration.fromFirestore(q.docs.first);
  }

  Future<EventRegistration?> getMyRegistrationForEvent(String eventId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return getUserRegistrationForEvent(eventId, uid);
  }

  /// Streams all registrations for an event (host view).
  Stream<List<EventRegistration>> streamEventRegistrations(String eventId) {
    return _regRef
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map(EventRegistration.fromFirestore).toList(growable: false);
      final sorted = List<EventRegistration>.from(list)
        ..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
      return sorted;
    });
  }

  /// Streams the current user's registrations (all passes).
  Stream<List<EventRegistration>> streamMyRegistrations() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _regRef.where('userId', isEqualTo: uid).snapshots().map((snap) {
      final list =
          snap.docs.map(EventRegistration.fromFirestore).toList(growable: false);
      final sorted = List<EventRegistration>.from(list)
        ..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
      return sorted;
    });
  }

  /// Streams only wallet-saved passes for the current user.
  Stream<List<EventRegistration>> streamMyWalletPasses() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _regRef
        .where('userId', isEqualTo: uid)
        .where('savedToWallet', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map(EventRegistration.fromFirestore).toList(growable: false);
      final sorted = List<EventRegistration>.from(list)
        ..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
      return sorted;
    });
  }

  // ---------------------------------------------------------------------------
  // Wallet
  // ---------------------------------------------------------------------------

  Future<void> saveToWallet(String registrationId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');

    final doc = await _regRef.doc(registrationId).get();
    if (!doc.exists) throw Exception('Pass not found');
    if (doc.data()?['userId'] != uid) {
      throw Exception('You can only save your own pass');
    }

    await _regRef.doc(registrationId).update({
      'savedToWallet': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeFromWallet(String registrationId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');

    await _regRef.doc(registrationId).update({
      'savedToWallet': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // Check-in (host scans QR)
  // ---------------------------------------------------------------------------

  /// Validates a scanned QR payload and marks the attendee as checked in.
  ///
  /// Only the event organiser may check attendees in.
  Future<CheckInResult> checkInFromQr({
    required String rawPayload,
    String? expectedEventId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const CheckInResult(
        success: false,
        message: 'You must be signed in to scan tickets.',
      );
    }

    final parsed = parseQrPayload(rawPayload);
    if (parsed == null) {
      return const CheckInResult(
        success: false,
        message: 'Invalid ticket QR code.',
      );
    }

    final registrationId = parsed['registrationId']!;
    final ticketId = parsed['ticketId']!;
    final eventId = parsed['eventId']!;

    if (expectedEventId != null && expectedEventId != eventId) {
      return const CheckInResult(
        success: false,
        message: 'This ticket is for a different event.',
      );
    }

    try {
      return await _firestore.runTransaction<CheckInResult>((tx) async {
        final regRef = _regRef.doc(registrationId);
        final snap = await tx.get(regRef);
        if (!snap.exists) {
          return const CheckInResult(
            success: false,
            message: 'Ticket not found.',
          );
        }

        final reg = EventRegistration.fromFirestore(snap);

        if (reg.ticketId != ticketId || reg.eventId != eventId) {
          return const CheckInResult(
            success: false,
            message: 'Ticket data does not match.',
          );
        }

        // Verify scanner is the organiser.
        String organiserId = reg.organiserId;
        final eventSnap = await tx.get(_eventsRef.doc(eventId));
        if (eventSnap.exists) {
          organiserId =
              eventSnap.data()?['organiserId']?.toString() ?? organiserId;
        }

        if (organiserId.isEmpty || organiserId != uid) {
          return const CheckInResult(
            success: false,
            message: 'Only the event host can scan tickets.',
          );
        }

        if (reg.status == RegistrationStatus.cancelled) {
          return CheckInResult(
            success: false,
            message: 'This ticket was cancelled.',
            registration: reg,
          );
        }

        if (reg.status == RegistrationStatus.checkedIn) {
          return CheckInResult(
            success: false,
            message: '${reg.fullName} already checked in.',
            registration: reg,
          );
        }

        if (reg.expiresAt != null && DateTime.now().isAfter(reg.expiresAt!)) {
          return CheckInResult(
            success: false,
            message: 'This ticket has expired.',
            registration: reg,
          );
        }

        tx.update(regRef, {
          'status': RegistrationStatus.checkedIn.name,
          'checkedInAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'checkedInBy': uid,
        });

        final updated = EventRegistration(
          id: reg.id,
          eventId: reg.eventId,
          userId: reg.userId,
          organiserId: reg.organiserId,
          fullName: reg.fullName,
          email: reg.email,
          phone: reg.phone,
          company: reg.company,
          role: reg.role,
          notes: reg.notes,
          ticketId: reg.ticketId,
          qrPayload: reg.qrPayload,
          status: RegistrationStatus.checkedIn,
          registeredAt: reg.registeredAt,
          checkedInAt: DateTime.now(),
          expiresAt: reg.expiresAt,
          eventTitle: reg.eventTitle,
          eventLocation: reg.eventLocation,
          eventTime: reg.eventTime,
          eventMonth: reg.eventMonth,
          eventDay: reg.eventDay,
          eventPrice: reg.eventPrice,
          eventImageUrl: reg.eventImageUrl,
          eventCategory: reg.eventCategory,
          savedToWallet: reg.savedToWallet,
        );

        return CheckInResult(
          success: true,
          message: '${reg.fullName} checked in successfully!',
          registration: updated,
        );
      });
    } catch (e) {
      return CheckInResult(
        success: false,
        message: 'Check-in failed: $e',
      );
    }
  }
}
