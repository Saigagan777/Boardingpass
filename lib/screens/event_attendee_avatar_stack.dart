import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/user_service.dart';

/// Displays the real profile photos of the latest event attendees.
///
/// Attendee IDs are appended when someone marks an event as interested. This
/// keeps the stack to a maximum of four while prioritising the latest people.
class EventAttendeeAvatarStack extends StatefulWidget {
  const EventAttendeeAvatarStack({super.key, required this.attendeeIds});

  final List<String> attendeeIds;

  @override
  State<EventAttendeeAvatarStack> createState() =>
      _EventAttendeeAvatarStackState();
}

class _EventAttendeeAvatarStackState extends State<EventAttendeeAvatarStack> {
  List<UserProfile> _profiles = const [];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void didUpdateWidget(covariant EventAttendeeAvatarStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameAttendees(oldWidget.attendeeIds, widget.attendeeIds)) {
      _loadProfiles();
    }
  }

  bool _sameAttendees(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  Future<void> _loadProfiles() async {
    try {
      final latestIds = widget.attendeeIds.reversed.take(4).toList();
      final fetchedProfiles = await Future.wait(
        latestIds.map((id) => UserService().getUserProfile(id)),
      );

      if (!mounted) return;
      setState(() {
        _profiles = fetchedProfiles.whereType<UserProfile>().toList();
      });
    } catch (_) {
      // An attendee without a readable profile simply does not get an avatar.
      if (mounted) setState(() => _profiles = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_profiles.isEmpty) return const SizedBox.shrink();

    const avatarSize = 32.0;
    const overlap = 22.0;
    return SizedBox(
      width: avatarSize + (_profiles.length - 1) * overlap,
      height: avatarSize,
      child: Stack(
        children: [
          for (var index = 0; index < _profiles.length; index++)
            Positioned(
              left: index * overlap,
              child: _ProfileAvatar(profile: _profiles[index]),
            ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final imageUrl = profile.profileImageUrl?.trim() ?? '';
    final name = profile.name.trim();
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();

    return Tooltip(
      message: name,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF7A432D),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.8),
        ),
        child: ClipOval(
          child: imageUrl.isEmpty
              ? _ProfileInitial(initial: initial)
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _ProfileInitial(initial: initial),
                ),
        ),
      ),
    );
  }
}

class _ProfileInitial extends StatelessWidget {
  const _ProfileInitial({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
