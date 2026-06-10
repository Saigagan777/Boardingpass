import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String? linkedinId;
  final String? profileImageUrl;
  final String? headline;
  final String? company;
  final String? role;
  final String? bio;
  final GeoPoint? location;
  final String? geohash;
  final String? currentCheckin;
  final String? fcmToken;
  final List<String> expertise;
  final List<String> intents;
  final bool isDiscoverable;
  final bool isAdmin;
  final DateTime createdAt;
  final DateTime lastSeen;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.linkedinId,
    this.profileImageUrl,
    this.headline,
    this.company,
    this.role,
    this.bio,
    this.location,
    this.geohash,
    this.currentCheckin,
    this.fcmToken,
    this.expertise = const [],
    this.intents = const [],
    this.isDiscoverable = true,
    this.isAdmin = false,
    required this.createdAt,
    required this.lastSeen,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      linkedinId: data['linkedinId'],
      profileImageUrl: data['profileImageUrl'],
      headline: data['headline'],
      company: data['company'],
      role: data['role'],
      bio: data['bio'],
      location: data['location'] as GeoPoint?,
      geohash: data['geohash'],
      currentCheckin: data['currentCheckin'],
      fcmToken: data['fcmToken'],
      expertise: List<String>.from(data['expertise'] ?? []),
      intents: List<String>.from(data['intents'] ?? []),
      isDiscoverable: data['isDiscoverable'] ?? true,
      isAdmin: data['isAdmin'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'linkedinId': linkedinId,
      'profileImageUrl': profileImageUrl,
      'headline': headline,
      'company': company,
      'role': role,
      'bio': bio,
      'location': location,
      'geohash': geohash,
      'currentCheckin': currentCheckin,
      'fcmToken': fcmToken,
      'expertise': expertise,
      'intents': intents,
      'isDiscoverable': isDiscoverable,
      'isAdmin': isAdmin,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSeen': Timestamp.fromDate(lastSeen),
    };
  }

  UserProfile copyWith({
    String? name,
    String? email,
    String? linkedinId,
    String? profileImageUrl,
    String? headline,
    String? company,
    String? role,
    String? bio,
    GeoPoint? location,
    String? geohash,
    String? currentCheckin,
    String? fcmToken,
    List<String>? expertise,
    List<String>? intents,
    bool? isDiscoverable,
    bool? isAdmin,
    DateTime? lastSeen,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      linkedinId: linkedinId ?? this.linkedinId,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      headline: headline ?? this.headline,
      company: company ?? this.company,
      role: role ?? this.role,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      geohash: geohash ?? this.geohash,
      currentCheckin: currentCheckin ?? this.currentCheckin,
      fcmToken: fcmToken ?? this.fcmToken,
      expertise: expertise ?? this.expertise,
      intents: intents ?? this.intents,
      isDiscoverable: isDiscoverable ?? this.isDiscoverable,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
