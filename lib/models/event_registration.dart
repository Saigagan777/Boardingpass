import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of an event ticket registration.
enum RegistrationStatus {
  registered,
  checkedIn,
  cancelled,
}

/// A user's registration for an event, including ticket / QR pass data.
class EventRegistration {
  final String id;
  final String eventId;
  final String userId;
  final String organiserId;

  /// Basic details collected at registration.
  final String fullName;
  final String email;
  final String phone;
  final String? company;
  final String? role;
  final String? notes;

  /// Human-readable ticket id shown on the pass.
  final String ticketId;

  /// Opaque payload encoded in the QR code.
  final String qrPayload;

  final RegistrationStatus status;
  final DateTime registeredAt;
  final DateTime? checkedInAt;
  final DateTime? expiresAt;

  /// Denormalized event fields for offline-friendly pass display.
  final String eventTitle;
  final String eventLocation;
  final String eventTime;
  final String eventMonth;
  final String eventDay;
  final String eventPrice;
  final String? eventImageUrl;
  final String eventCategory;

  /// Whether the attendee saved this pass to their in-app wallet.
  final bool savedToWallet;

  const EventRegistration({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.organiserId,
    required this.fullName,
    required this.email,
    required this.phone,
    this.company,
    this.role,
    this.notes,
    required this.ticketId,
    required this.qrPayload,
    required this.status,
    required this.registeredAt,
    this.checkedInAt,
    this.expiresAt,
    required this.eventTitle,
    required this.eventLocation,
    required this.eventTime,
    required this.eventMonth,
    required this.eventDay,
    required this.eventPrice,
    this.eventImageUrl,
    this.eventCategory = 'Meetups',
    this.savedToWallet = false,
  });

  /// True when the QR should no longer be usable for entry.
  bool get isQrInvalid {
    if (status == RegistrationStatus.checkedIn) return true;
    if (status == RegistrationStatus.cancelled) return true;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return true;
    return false;
  }

  bool get isCheckedIn => status == RegistrationStatus.checkedIn;

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  String get statusLabel {
    if (isCheckedIn) return 'Checked in';
    if (isExpired || status == RegistrationStatus.cancelled) return 'Expired';
    return 'Valid';
  }

  factory EventRegistration.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return EventRegistration.fromMap(doc.id, data);
  }

  factory EventRegistration.fromMap(String id, Map<String, dynamic> data) {
    final statusStr = (data['status'] ?? 'registered').toString();
    final status = RegistrationStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => RegistrationStatus.registered,
    );

    DateTime? parseTs(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return EventRegistration(
      id: id,
      eventId: data['eventId']?.toString() ?? '',
      userId: data['userId']?.toString() ?? '',
      organiserId: data['organiserId']?.toString() ?? '',
      fullName: data['fullName']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      company: data['company']?.toString(),
      role: data['role']?.toString(),
      notes: data['notes']?.toString(),
      ticketId: data['ticketId']?.toString() ?? '',
      qrPayload: data['qrPayload']?.toString() ?? '',
      status: status,
      registeredAt: parseTs(data['registeredAt']) ?? DateTime.now(),
      checkedInAt: parseTs(data['checkedInAt']),
      expiresAt: parseTs(data['expiresAt']),
      eventTitle: data['eventTitle']?.toString() ?? '',
      eventLocation: data['eventLocation']?.toString() ?? '',
      eventTime: data['eventTime']?.toString() ?? '',
      eventMonth: data['eventMonth']?.toString() ?? '',
      eventDay: data['eventDay']?.toString() ?? '',
      eventPrice: data['eventPrice']?.toString() ?? 'Free',
      eventImageUrl: data['eventImageUrl']?.toString(),
      eventCategory: data['eventCategory']?.toString() ?? 'Meetups',
      savedToWallet: data['savedToWallet'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'userId': userId,
      'organiserId': organiserId,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'company': company,
      'role': role,
      'notes': notes,
      'ticketId': ticketId,
      'qrPayload': qrPayload,
      'status': status.name,
      'registeredAt': Timestamp.fromDate(registeredAt),
      'checkedInAt':
          checkedInAt != null ? Timestamp.fromDate(checkedInAt!) : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'eventTitle': eventTitle,
      'eventLocation': eventLocation,
      'eventTime': eventTime,
      'eventMonth': eventMonth,
      'eventDay': eventDay,
      'eventPrice': eventPrice,
      'eventImageUrl': eventImageUrl,
      'eventCategory': eventCategory,
      'savedToWallet': savedToWallet,
    };
  }
}
