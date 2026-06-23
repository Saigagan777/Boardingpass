import 'package:cloud_firestore/cloud_firestore.dart';

class CustomCard {
  final String title;
  final String description;
  final String imageUrl;
  final String template; // '50-50 Split', 'Image Overlay', 'Top Image / Bottom Text'

  const CustomCard({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.template,
  });

  factory CustomCard.fromMap(Map<String, dynamic> map) {
    return CustomCard(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      template: map['template'] ?? 'Image Overlay',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'template': template,
    };
  }
}

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String? industry;
  final String? experience;
  final String? homeBase;
  final String? currentLocationName;
  final String? travelFrequency;
  final int connectionsCount;
  final int eventsJoinedCount;
  final int eventsHostedCount;
  final String? cardImageUrl;
  final List<String> cardImages;
  final List<CustomCard> customCards;
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

  // New LinkedIn and Notification Fields
  final String? coverImageUrl;
  final String? linkedinProfileUrl;
  final int connectionCount;
  final int followerCount;
  final List<String> skills;
  final List<String> interests;
  final List<String> followedTopics;
  final List<String> professionalInterests;
  final List<Map<String, dynamic>> careerTimeline;
  final List<Map<String, dynamic>> educationTimeline;
  final Map<String, dynamic> notificationSettings;

  // Sync tracking fields
  final bool linkedinSynced;
  final DateTime? linkedinSyncedAt;
  final bool resumeParsed;
  final DateTime? resumeParsedAt;

  // Match score
  final int? matchScore;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.industry,
    this.experience,
    this.homeBase,
    this.currentLocationName,
    this.travelFrequency,
    this.connectionsCount = 0,
    this.eventsJoinedCount = 0,
    this.eventsHostedCount = 0,
    this.cardImageUrl,
    this.cardImages = const [],
    this.customCards = const [],
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
    this.coverImageUrl,
    this.linkedinProfileUrl,
    this.connectionCount = 0,
    this.followerCount = 0,
    this.skills = const [],
    this.interests = const [],
    this.followedTopics = const [],
    this.professionalInterests = const [],
    this.careerTimeline = const [],
    this.educationTimeline = const [],
    this.notificationSettings = const {},
    this.linkedinSynced = false,
    this.linkedinSyncedAt,
    this.resumeParsed = false,
    this.resumeParsedAt,
    this.matchScore,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      industry: data['industry'],
      experience: data['experience'],
      homeBase: data['homeBase'],
      currentLocationName: data['currentLocationName'],
      travelFrequency: data['travelFrequency'],
      connectionsCount: data['connectionsCount'] ?? 0,
      eventsJoinedCount: data['eventsJoinedCount'] ?? 0,
      eventsHostedCount: data['eventsHostedCount'] ?? 0,
      cardImageUrl: data['cardImageUrl'],
      cardImages: List<String>.from(data['cardImages'] ?? []),
      customCards: (data['customCards'] as List?)
              ?.map((item) => CustomCard.fromMap(Map<String, dynamic>.from(item)))
              .toList() ??
          [],
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
      coverImageUrl: data['coverImageUrl'],
      linkedinProfileUrl: data['linkedinProfileUrl'],
      connectionCount: data['connectionCount'] ?? 0,
      followerCount: data['followerCount'] ?? 0,
      skills: List<String>.from(data['skills'] ?? []),
      interests: List<String>.from(data['interests'] ?? []),
      followedTopics: List<String>.from(data['followedTopics'] ?? []),
      professionalInterests: List<String>.from(data['professionalInterests'] ?? []),
      careerTimeline: (data['careerTimeline'] as List?)
              ?.map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          [],
      educationTimeline: (data['educationTimeline'] as List?)
              ?.map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          [],
      notificationSettings: Map<String, dynamic>.from(data['notificationSettings'] ?? {}),
      linkedinSynced: data['linkedinSynced'] ?? false,
      linkedinSyncedAt: (data['linkedinSyncedAt'] as Timestamp?)?.toDate(),
      resumeParsed: data['resumeParsed'] ?? false,
      resumeParsedAt: (data['resumeParsedAt'] as Timestamp?)?.toDate(),
      matchScore: data['matchScore'] as int?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'industry': industry,
      'experience': experience,
      'homeBase': homeBase,
      'currentLocationName': currentLocationName,
      'travelFrequency': travelFrequency,
      'connectionsCount': connectionsCount,
      'eventsJoinedCount': eventsJoinedCount,
      'eventsHostedCount': eventsHostedCount,
      'cardImageUrl': cardImageUrl,
      'cardImages': cardImages,
      'customCards': customCards.map((c) => c.toMap()).toList(),
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
      'coverImageUrl': coverImageUrl,
      'linkedinProfileUrl': linkedinProfileUrl,
      'connectionCount': connectionCount,
      'followerCount': followerCount,
      'skills': skills,
      'interests': interests,
      'followedTopics': followedTopics,
      'professionalInterests': professionalInterests,
      'careerTimeline': careerTimeline,
      'educationTimeline': educationTimeline,
      'notificationSettings': notificationSettings,
      'linkedinSynced': linkedinSynced,
      'linkedinSyncedAt': linkedinSyncedAt != null ? Timestamp.fromDate(linkedinSyncedAt!) : null,
      'resumeParsed': resumeParsed,
      'resumeParsedAt': resumeParsedAt != null ? Timestamp.fromDate(resumeParsedAt!) : null,
      'matchScore': matchScore,
    };
  }

  UserProfile copyWith({
    String? name,
    String? email,
    String? industry,
    String? experience,
    String? homeBase,
    String? currentLocationName,
    String? travelFrequency,
    int? connectionsCount,
    int? eventsJoinedCount,
    int? eventsHostedCount,
    String? cardImageUrl,
    List<String>? cardImages,
    List<CustomCard>? customCards,
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
    String? coverImageUrl,
    String? linkedinProfileUrl,
    int? connectionCount,
    int? followerCount,
    List<String>? skills,
    List<String>? interests,
    List<String>? followedTopics,
    List<String>? professionalInterests,
    List<Map<String, dynamic>>? careerTimeline,
    List<Map<String, dynamic>>? educationTimeline,
    Map<String, dynamic>? notificationSettings,
    bool? linkedinSynced,
    DateTime? linkedinSyncedAt,
    bool? resumeParsed,
    DateTime? resumeParsedAt,
    int? matchScore,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      industry: industry ?? this.industry,
      experience: experience ?? this.experience,
      homeBase: homeBase ?? this.homeBase,
      currentLocationName: currentLocationName ?? this.currentLocationName,
      travelFrequency: travelFrequency ?? this.travelFrequency,
      connectionsCount: connectionsCount ?? this.connectionsCount,
      eventsJoinedCount: eventsJoinedCount ?? this.eventsJoinedCount,
      eventsHostedCount: eventsHostedCount ?? this.eventsHostedCount,
      cardImageUrl: cardImageUrl ?? this.cardImageUrl,
      cardImages: cardImages ?? this.cardImages,
      customCards: customCards ?? this.customCards,
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
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      linkedinProfileUrl: linkedinProfileUrl ?? this.linkedinProfileUrl,
      connectionCount: connectionCount ?? this.connectionCount,
      followerCount: followerCount ?? this.followerCount,
      skills: skills ?? this.skills,
      interests: interests ?? this.interests,
      followedTopics: followedTopics ?? this.followedTopics,
      professionalInterests: professionalInterests ?? this.professionalInterests,
      careerTimeline: careerTimeline ?? this.careerTimeline,
      educationTimeline: educationTimeline ?? this.educationTimeline,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      linkedinSynced: linkedinSynced ?? this.linkedinSynced,
      linkedinSyncedAt: linkedinSyncedAt ?? this.linkedinSyncedAt,
      resumeParsed: resumeParsed ?? this.resumeParsed,
      resumeParsedAt: resumeParsedAt ?? this.resumeParsedAt,
      matchScore: matchScore ?? this.matchScore,
    );
  }
}
