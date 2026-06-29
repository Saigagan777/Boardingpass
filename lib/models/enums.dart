enum MeetingStatus {
  pending,
  scheduled,
  pollOpen,
  pollClosed,
  rescheduleRequested,
  rescheduled,
  completed,
  cancelled,
  expired,
}

extension MeetingStatusExtension on MeetingStatus {
  String get name {
    switch (this) {
      case MeetingStatus.pending:
        return 'pending';
      case MeetingStatus.scheduled:
        return 'scheduled';
      case MeetingStatus.pollOpen:
        return 'pollOpen';
      case MeetingStatus.pollClosed:
        return 'pollClosed';
      case MeetingStatus.rescheduleRequested:
        return 'rescheduleRequested';
      case MeetingStatus.rescheduled:
        return 'rescheduled';
      case MeetingStatus.completed:
        return 'completed';
      case MeetingStatus.cancelled:
        return 'cancelled';
      case MeetingStatus.expired:
        return 'expired';
    }
  }

  static MeetingStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return MeetingStatus.pending;
      case 'scheduled':
      case 'confirmed': // handles legacy status
      case 'approved': // handles legacy status
        return MeetingStatus.scheduled;
      case 'pollopen':
      case 'poll_open':
        return MeetingStatus.pollOpen;
      case 'pollclosed':
      case 'poll_closed':
        return MeetingStatus.pollClosed;
      case 'reschedulerequested':
      case 'reschedule_requested':
        return MeetingStatus.rescheduleRequested;
      case 'rescheduled':
        return MeetingStatus.rescheduled;
      case 'completed':
        return MeetingStatus.completed;
      case 'cancelled':
        return MeetingStatus.cancelled;
      case 'expired':
        return MeetingStatus.expired;
      default:
        return MeetingStatus.pending;
    }
  }
}

enum MeetingPurpose {
  interview,
  coffeeChat,
  clientMeeting,
  networking,
  teamLunch,
  presentation,
  custom,
}

extension MeetingPurposeExtension on MeetingPurpose {
  String get name {
    switch (this) {
      case MeetingPurpose.interview:
        return 'interview';
      case MeetingPurpose.coffeeChat:
        return 'coffeeChat';
      case MeetingPurpose.clientMeeting:
        return 'clientMeeting';
      case MeetingPurpose.networking:
        return 'networking';
      case MeetingPurpose.teamLunch:
        return 'teamLunch';
      case MeetingPurpose.presentation:
        return 'presentation';
      case MeetingPurpose.custom:
        return 'custom';
    }
  }

  String get displayName {
    switch (this) {
      case MeetingPurpose.interview:
        return 'Interview';
      case MeetingPurpose.coffeeChat:
        return 'Coffee Chat';
      case MeetingPurpose.clientMeeting:
        return 'Client Meeting';
      case MeetingPurpose.networking:
        return 'Networking Event';
      case MeetingPurpose.teamLunch:
        return 'Team Lunch';
      case MeetingPurpose.presentation:
        return 'Presentation';
      case MeetingPurpose.custom:
        return 'Custom Purpose';
    }
  }

  static MeetingPurpose fromString(String purpose) {
    switch (purpose.toLowerCase()) {
      case 'interview':
        return MeetingPurpose.interview;
      case 'coffeechat':
      case 'coffee_chat':
        return MeetingPurpose.coffeeChat;
      case 'clientmeeting':
      case 'client_meeting':
        return MeetingPurpose.clientMeeting;
      case 'networking':
        return MeetingPurpose.networking;
      case 'teamlunch':
      case 'team_lunch':
        return MeetingPurpose.teamLunch;
      case 'presentation':
        return MeetingPurpose.presentation;
      case 'custom':
      default:
        return MeetingPurpose.custom;
    }
  }
}

enum VenueCategory {
  restaurant,
  hotel,
  cafe,
  coworking,
  conferenceRoom,
  businessCenter,
  library,
  airportLounge,
  custom,
}

extension VenueCategoryExtension on VenueCategory {
  String get name {
    switch (this) {
      case VenueCategory.restaurant:
        return 'restaurant';
      case VenueCategory.hotel:
        return 'hotel';
      case VenueCategory.cafe:
        return 'cafe';
      case VenueCategory.coworking:
        return 'coworking';
      case VenueCategory.conferenceRoom:
        return 'conferenceRoom';
      case VenueCategory.businessCenter:
        return 'businessCenter';
      case VenueCategory.library:
        return 'library';
      case VenueCategory.airportLounge:
        return 'airportLounge';
      case VenueCategory.custom:
        return 'custom';
    }
  }

  String get displayName {
    switch (this) {
      case VenueCategory.restaurant:
        return 'Restaurant';
      case VenueCategory.hotel:
        return 'Hotel';
      case VenueCategory.cafe:
        return 'Café';
      case VenueCategory.coworking:
        return 'Coworking Space';
      case VenueCategory.conferenceRoom:
        return 'Conference Room';
      case VenueCategory.businessCenter:
        return 'Business Center';
      case VenueCategory.library:
        return 'Library';
      case VenueCategory.airportLounge:
        return 'Airport Lounge';
      case VenueCategory.custom:
        return 'Other Location';
    }
  }

  static VenueCategory fromString(String category) {
    switch (category.toLowerCase()) {
      case 'restaurant':
        return VenueCategory.restaurant;
      case 'hotel':
        return VenueCategory.hotel;
      case 'cafe':
      case 'café':
        return VenueCategory.cafe;
      case 'coworking':
      case 'coworking_space':
      case 'coworking space':
        return VenueCategory.coworking;
      case 'conferenceroom':
      case 'conference_room':
      case 'conference room':
        return VenueCategory.conferenceRoom;
      case 'businesscenter':
      case 'business_center':
      case 'business center':
        return VenueCategory.businessCenter;
      case 'library':
        return VenueCategory.library;
      case 'airportlounge':
      case 'airport_lounge':
      case 'airport lounge':
        return VenueCategory.airportLounge;
      case 'custom':
      default:
        return VenueCategory.custom;
    }
  }
}
