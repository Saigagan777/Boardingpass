import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../state_manager.dart';
import '../models/user_profile.dart';
import '../services/meeting_service.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../utils/image_helper.dart';
import '../utils/match_calculator.dart';
import '../models/enums.dart';
import '../models/venue.dart';
import '../services/recommendation_engine.dart';
import 'location_search_section.dart';
import 'create_poll_dialog.dart';
import 'poll_widget.dart';


class MeetScreen extends StatefulWidget {
  final String? name;
  final VoidCallback? onBack;
  final VoidCallback? onDone;
  const MeetScreen({super.key, this.name, this.onBack, this.onDone});

  @override
  State<MeetScreen> createState() => _MeetScreenState();
}

class _MeetScreenState extends State<MeetScreen> {
  final AppStateManager _state = AppStateManager();

  int _activeTab = 0; // 0 = Request Meeting, 1 = My Meetings
  List<UserProfile> _connections = [];
  final Set<UserProfile> _selectedConnections = {};
  List<Map<String, dynamic>> _userGroups = [];
  Map<String, dynamic>? _selectedGroup;
  bool _loadingConnections = true;
  bool _submittingMeeting = false;
  String? _conflictWarning;
  String _searchQuery = '';
  UserProfile? _currentUserProfile;
  final Set<String> _expandedMeetingIds = {};

  String _meetingDate = '';
  String _meetingTime = '';
  String _selectedLocation = 'Plaza Premium Lounge';
  int _selectedReminderMinutes = 15;

  // New discovery & reschedule poll variables
  String _meetingCity = 'Vijayawada';
  MeetingPurpose _meetingPurpose = MeetingPurpose.coffeeChat;
  String _meetingType = 'in_person'; // 'in_person' or 'online'
  Venue? _selectedVenue;


  @override
  void initState() {
    super.initState();
    _activeTab = _state.meetingInitialTab;
    // Reset initial tab in state manager so future navigations default to 0
    _state.meetingInitialTab = 0;
    final now = DateTime.now();
    _meetingDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    _meetingTime = "${(now.hour + 1).toString().padLeft(2, '0')}:00";
    _fetchConnections();
  }

  Future<void> _fetchConnections() async {
    setState(() {
      _loadingConnections = true;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() {
          _loadingConnections = false;
        });
        return;
      }

      // Fetch current user profile
      _currentUserProfile = await UserService().getUserProfile(uid);

      // Query chats where current user is a participant
      final chatsSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: uid)
          .get();

      final seenUids = <String>{};
      final List<UserProfile> fetched = [];
      final List<Map<String, dynamic>> fetchedGroups = [];

      for (final doc in chatsSnapshot.docs) {
        final chatData = doc.data();
        final isGroup = chatData['isGroup'] as bool? ?? false;
        if (isGroup) {
          fetchedGroups.add({'id': doc.id, ...chatData});
          continue;
        }
        final participants = List<String>.from(chatData['participants'] ?? []);
        final otherUid = participants.firstWhere((p) => p != uid, orElse: () => '');
        if (otherUid.isNotEmpty && !seenUids.contains(otherUid)) {
          seenUids.add(otherUid);
          final profile = await UserService().getUserProfile(otherUid);
          if (profile != null) {
            fetched.add(profile);
          }
        }
      }

      setState(() {
        _connections = fetched;
        _userGroups = fetchedGroups;
      });

      // Pre-select connection or group if widget.name is passed
      if (widget.name != null) {
        final nameLower = widget.name!.toLowerCase();
        
        // 1. Check if it matches a group name
        final groupIndex = _userGroups.indexWhere((g) => (g['groupName'] as String? ?? '').toLowerCase() == nameLower);
        if (groupIndex != -1) {
          final group = _userGroups[groupIndex];
          _selectedGroup = group;
          final participantIds = List<String>.from(group['participants'] ?? []);
          for (final pid in participantIds) {
            if (pid == uid) continue;
            final profile = await UserService().getUserProfile(pid);
            if (profile != null) {
              _selectedConnections.add(profile);
            }
          }
        } else {
          // 2. Check if it matches a connection name
          final index = _connections.indexWhere((c) => c.name.toLowerCase() == nameLower);
          if (index != -1) {
            _selectedConnections.add(_connections[index]);
          } else {
            // 3. Try finding in users collection directly
            final usersSnapshot = await FirebaseFirestore.instance
                .collection('users')
                .where('name', isEqualTo: widget.name)
                .limit(1)
                .get();
            if (usersSnapshot.docs.isNotEmpty) {
              final profile = UserProfile.fromFirestore(usersSnapshot.docs.first);
              if (!_connections.any((c) => c.uid == profile.uid)) {
                _connections.add(profile);
              }
              _selectedConnections.add(profile);
            }
          }
        }
      }

      setState(() {
        _loadingConnections = false;
      });
      _checkConflicts();
      _updateDetectedCity();
    } catch (e) {
      setState(() {
        _loadingConnections = false;
      });
      debugPrint('Error fetching connections: $e');
    }
  }

  Future<void> _updateDetectedCity() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ids = [uid, ..._selectedConnections.map((c) => c.uid)];
    final result = await RecommendationEngine().detectMeetingCity(ids);
    if (mounted) {
      setState(() {
        _meetingCity = result.primaryCity;
      });
    }
  }

  Widget _buildTypeButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7A432D) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF7A432D) : const Color(0xFFE8E2DD),
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF3E1F11),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF3E1F11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkConflicts() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || _selectedConnections.isEmpty) {
      if (mounted) {
        setState(() {
          _conflictWarning = null;
        });
      }
      return;
    }

    try {
      final dateParts = _meetingDate.split('-');
      final timeParts = _meetingTime.split(':');
      if (dateParts.length < 3 || timeParts.length < 2) return;

      final proposedTime = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      final myConflict = await MeetingService().hasMeetingConflict(currentUid, proposedTime);
      if (myConflict) {
        if (mounted) {
          setState(() {
            _conflictWarning = "You already have a confirmed meeting around this time.";
          });
        }
        return;
      }

      final conflictingNames = <String>[];
      for (final conn in _selectedConnections) {
        final hasConflict = await MeetingService().hasMeetingConflict(conn.uid, proposedTime);
        if (hasConflict) {
          conflictingNames.add(conn.name);
        }
      }

      if (mounted) {
        setState(() {
          if (conflictingNames.isNotEmpty) {
            _conflictWarning = "${conflictingNames.join(', ')} already has/have a confirmed meeting around this time.";
          } else {
            _conflictWarning = null;
          }
        });
      }
    } catch (e) {
      debugPrint('Error validating conflicts: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7A432D),
              onPrimary: Colors.white,
              onSurface: Color(0xFF3E1F11),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _meetingDate = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
      _checkConflicts();
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7A432D),
              onPrimary: Colors.white,
              onSurface: Color(0xFF3E1F11),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _meetingTime = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      });
      _checkConflicts();
    }
  }

  Future<void> _requestMeeting() async {
    if (_selectedConnections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one connection to meet.'),
          backgroundColor: Color(0xFF7A432D),
        ),
      );
      return;
    }

    await _checkConflicts();
    if (_conflictWarning != null) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFFFAF7F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE8E2DD), width: 1.5),
          ),
          title: const Text(
            'Schedule Conflict',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E1F11),
            ),
          ),
          content: Text(
            _conflictWarning!,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: Color(0xFF3E1F11),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'OK',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7A432D),
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _submittingMeeting = true;
    });

    try {
      final dateParts = _meetingDate.split('-');
      final timeParts = _meetingTime.split(':');
      final scheduledAt = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      final attendeeIds = _selectedConnections.map((c) => c.uid).toList();
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) throw Exception('User not signed in');

      String? chatId;
      if (_selectedGroup != null) {
        chatId = _selectedGroup!['id'];
      } else if (attendeeIds.isNotEmpty) {
        chatId = await ChatService().getOrCreateChat(
          userId1: currentUid,
          userId2: attendeeIds.first,
        );
      }

      // Determine final location text
      final finalLocation = _meetingType == 'online'
          ? 'Online Meeting (Virtual)'
          : (_selectedVenue != null ? _selectedVenue!.name : _selectedLocation);

      // Create Firestore meeting document
      final meetingId = await MeetingService().createMeeting(
        attendeeIds: attendeeIds,
        scheduledAt: scheduledAt,
        location: finalLocation,
        reminderMinutes: _selectedReminderMinutes,
        chatId: chatId,
        meetingCity: _meetingCity,
        meetingPurpose: _meetingPurpose.name,
        meetingType: _meetingType,
        selectedVenueSnapshot: _selectedVenue?.toMap(),
        selectedVenueId: _selectedVenue?.id,
        selectedVenueProvider: _selectedVenue?.provider,
      );

      // Send text notifications in chats
      final formattedTime = "${scheduledAt.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][scheduledAt.month - 1]} at $_meetingTime";
      final notificationMsg = "📅 Meeting Request: Let's meet at $finalLocation on $formattedTime [meetingId:$meetingId]";

      // If we invited a group, send it to the group chat
      if (_selectedGroup != null) {
        await ChatService().sendTextMessage(
          chatId: _selectedGroup!['id'],
          text: notificationMsg,
        );
      } else {
        // Otherwise, send a text notification to each participant's 1-to-1 chat
        for (final otherUserId in attendeeIds) {
          final resolvedChatId = (otherUserId == attendeeIds.first && chatId != null)
              ? chatId
              : await ChatService().getOrCreateChat(
                  userId1: currentUid,
                  userId2: otherUserId,
                );
          await ChatService().sendTextMessage(
            chatId: resolvedChatId,
            text: notificationMsg,
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Meeting request sent to ${_selectedConnections.map((c) => c.name).join(", ")}!'),
          backgroundColor: const Color(0xFF7A432D),
        ),
      );

      // Reset submission status and switch to "My Meetings" tab
      setState(() {
        _submittingMeeting = false;
        _activeTab = 1;
      });
    } catch (e) {
      setState(() {
        _submittingMeeting = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to request meeting: $e'),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    }
  }

  Future<void> _updateMyStatus(
    String meetingId,
    String status,
    String location,
    String timeStr,
  ) async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) throw Exception('User not signed in');

      if (status == 'accepted') {
        final meetingDoc = await MeetingService().getMeeting(meetingId);
        final scheduledTimestamp = meetingDoc.data()?['scheduledAt'] as Timestamp?;
        if (scheduledTimestamp != null) {
          final scheduledAt = scheduledTimestamp.toDate();
          
          final myConflict = await MeetingService().hasMeetingConflict(currentUid, scheduledAt);
          if (myConflict) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cannot accept. You already have a confirmed meeting around this time.'),
                backgroundColor: Color(0xFFC62828),
              ),
            );
            return;
          }
        }

        await MeetingService().updateParticipantStatus(
          meetingId: meetingId,
          userId: currentUid,
          status: 'accepted',
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status updated to Accepted!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      } else if (status == 'tentative') {
        await MeetingService().updateParticipantStatus(
          meetingId: meetingId,
          userId: currentUid,
          status: 'tentative',
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status updated to Tentative.'),
            backgroundColor: Color(0xFFEF6C00),
          ),
        );
      } else if (status == 'cancelled') {
        await _showCancellationReasonDialogNew(meetingId, currentUid, location, timeStr);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    }
  }


  Future<void> _showCancellationReasonDialogNew(
    String meetingId,
    String currentUid,
    String location,
    String timeStr,
  ) async {
    String selectedReason = 'Scheduling Conflict';
    final TextEditingController noteController = TextEditingController();
    final reasons = [
      'Scheduling Conflict',
      'Location is too far',
      'Change of Plans',
      'Emergency',
      'Other'
    ];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: const Color(0xFFFAF7F5),
              title: const Text(
                'Cancel Attendance',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3E1F11),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please select a reason for cancellation:',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        color: Color(0xFF8C736B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...reasons.map((r) {
                      final isSelected = selectedReason == r;
                      return ListTile(
                        leading: Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: const Color(0xFF7A432D),
                          size: 20,
                        ),
                        title: Text(
                          r,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13.5,
                            color: Color(0xFF3E1F11),
                          ),
                        ),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                          setDialogState(() {
                            selectedReason = r;
                          });
                        },
                      );
                    }),
                    if (selectedReason == 'Other') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: noteController,
                        style: const TextStyle(fontSize: 13, fontFamily: 'PlusJakartaSans'),
                        decoration: InputDecoration(
                          hintText: 'Type your reason here...',
                          hintStyle: const TextStyle(color: Color(0xFF8C736B)),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF7A432D)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Go Back',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      color: Color(0xFF8C736B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      final reasonStr = selectedReason == 'Other' ? noteController.text.trim() : selectedReason;
                      final finalReason = reasonStr.isNotEmpty ? reasonStr : 'Scheduling Conflict';
                      
                      await MeetingService().updateParticipantStatus(
                        meetingId: meetingId,
                        userId: currentUid,
                        status: 'cancelled',
                        reason: finalReason,
                        note: selectedReason == 'Other' ? 'Custom reason' : '',
                      );

                      if (!context.mounted) return;
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Attendance cancelled.'),
                          backgroundColor: Color(0xFFC62828),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error cancelling meeting: $e'),
                          backgroundColor: const Color(0xFFC62828),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Cancel Meeting',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<UserProfile>> _fetchMeetingParticipants(List<String> uids) async {
    final futures = uids.map((uid) => UserService().getUserProfile(uid));
    final results = await Future.wait(futures);
    return results.whereType<UserProfile>().toList();
  }

  Widget _buildMeetingCard(String meetingId, Map<String, dynamic> data) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final requesterId = data['requesterId'] as String;
    final hosts = List<String>.from(data['hosts'] ?? []);
    final participants = List<String>.from(data['participants'] ?? []);
    final statusMap = Map<String, dynamic>.from(data['participantsStatus'] ?? {});
    
    final rawStatus = data['status'] as String? ?? 'pending';
    final statusStr = rawStatus.toUpperCase();
    final location = data['location'] as String? ?? 'Not specified';
    final scheduledTimestamp = data['scheduledAt'] as Timestamp?;
    final scheduledAt = scheduledTimestamp?.toDate();
    final reminderMinutes = data['reminderMinutes'] as int?;
    
    final proposedTimeTimestamp = data['proposedTime'] as Timestamp?;
    final proposedTime = proposedTimeTimestamp?.toDate();
    final proposedBy = data['proposedBy'] as String?;
    final proposalNote = data['proposalNote'] as String? ?? '';
    final isHost = hosts.contains(currentUid);
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isPast = scheduledAt != null && scheduledAt.isBefore(today);
    
    String timeStr = 'Not scheduled';
    if (scheduledAt != null) {
      timeStr = "${scheduledAt.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][scheduledAt.month - 1]} at ${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}";
    }

    final isExpanded = _expandedMeetingIds.contains(meetingId);

    Color statusColor;
    String statusLabel;
    switch (statusStr) {
      case 'APPROVED':
      case 'CONFIRMED':
        statusColor = const Color(0xFF2E7D32);
        statusLabel = 'Confirmed';
        break;
      case 'CANCELLED':
        statusColor = const Color(0xFFC62828);
        statusLabel = 'Cancelled';
        break;
      case 'REJECTED':
        statusColor = const Color(0xFFC62828);
        statusLabel = 'Rejected';
        break;
      case 'COMPLETED':
        statusColor = Colors.blueGrey;
        statusLabel = 'Completed';
        break;
      case 'RESCHEDULE_APPROVED':
      case 'RESCHEDULED':
        statusColor = const Color(0xFF007A87);
        statusLabel = 'Rescheduled';
        break;
      case 'RESCHEDULE_REQUESTED':
        statusColor = const Color(0xFFEF6C00);
        statusLabel = 'Reschedule Requested';
        break;
      case 'RESCHEDULE_REJECTED':
        statusColor = const Color(0xFFC62828);
        statusLabel = 'Reschedule Rejected';
        break;
      case 'EXPIRED':
        statusColor = Colors.grey;
        statusLabel = 'Expired';
        break;
      case 'NOSHOW':
        statusColor = Colors.purple;
        statusLabel = 'No Show';
        break;
      case 'PENDING':
      default:
        statusColor = const Color(0xFFEF6C00);
        statusLabel = 'Pending';
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E2DD)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 1),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapsed View / Card Header
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedMeetingIds.remove(meetingId);
                } else {
                  _expandedMeetingIds.add(meetingId);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.meeting_room_outlined, color: Color(0xFF7A432D), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            participants.length <= 2 ? '1-on-1 Meeting' : 'Group Meeting (${participants.length} people)',
                            style: const TextStyle(
                              fontFamily: 'PlayfairDisplay',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3E1F11),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: Color(0xFFFAF7F5)),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFF8C736B)),
                      const SizedBox(width: 6),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12.5,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Color(0xFF8C736B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12.5,
                            color: Color(0xFF3E1F11),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (reminderMinutes != null && reminderMinutes > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.notifications_active_outlined, size: 14, color: Color(0xFF8C736B)),
                        const SizedBox(width: 6),
                        Text(
                          reminderMinutes == 1440
                              ? "Reminder: 1 day before"
                              : (reminderMinutes == 60
                                  ? "Reminder: 1 hour before"
                                  : "Reminder: $reminderMinutes minutes before"),
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12.5,
                            color: Color(0xFF3E1F11),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: const Color(0xFF8C736B),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isExpanded ? 'Show less' : 'Show details & attendees',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8C736B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded View
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE8E2DD)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FutureBuilder<List<UserProfile>>(
                future: _fetchMeetingParticipants(participants),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7A432D)),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Text('Error loading participants: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 12));
                  }
                  final profiles = snapshot.data ?? [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Smart Context Box

                      // Active Proposals Section
                      if ((data['proposals'] as List?)?.isNotEmpty == true) ...[
                        Builder(builder: (context) {
                          final allProposals = List<Map<String, dynamic>>.from(data['proposals'] ?? []);
                          final activeProposals = allProposals.where((p) => p['status'] == 'active').toList();
                          if (activeProposals.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: activeProposals.map((proposal) {
                              final pTime = (proposal['proposedTime'] as Timestamp?)?.toDate();
                              final pBy = proposal['proposedBy'] as String?;
                              final pNote = proposal['note'] as String? ?? '';
                              final pId = proposal['proposalId'] as String? ?? '';
                              final pTimeStr = pTime != null
                                  ? '${pTime.day} ${const ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][pTime.month - 1]} at ${pTime.hour.toString().padLeft(2, '0')}:${pTime.minute.toString().padLeft(2, '0')}'
                                  : 'Unknown';

                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF7F5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF7A432D), width: 1),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.schedule, color: Color(0xFF7A432D), size: 16),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'Proposed Alternative Time',
                                          style: TextStyle(
                                            fontFamily: 'PlayfairDisplay',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Color(0xFF3E1F11),
                                          ),
                                        ),
                                        const Spacer(),
                                        if (pBy != null)
                                          FutureBuilder<DocumentSnapshot>(
                                            future: FirebaseFirestore.instance.collection('users').doc(pBy).get(),
                                            builder: (context, userSnap) {
                                              if (userSnap.connectionState == ConnectionState.waiting) {
                                                return const Text('By Loading...', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)));
                                              }
                                              final userData = userSnap.data?.data() as Map<String, dynamic>?;
                                              final proposerName = userData?['name'] ?? 'Someone';
                                              return Text('By $proposerName', style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)));
                                            },
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Proposed: $pTimeStr',
                                      style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E1F11)),
                                    ),
                                    if (pNote.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text('Note: "$pNote"', style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF5C473E))),
                                    ],
                                    // Accept / Decline / Propose Another Time buttons
                                    if (pBy != currentUid) ...[
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(color: Color(0xFFC62828)),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                padding: const EdgeInsets.symmetric(vertical: 4),
                                              ),
                                              onPressed: () async {
                                                try {
                                                  await MeetingService().declineProposal(meetingId: meetingId, proposalId: pId);
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Proposal declined.'), backgroundColor: Color(0xFFC62828)));
                                                  }
                                                  setState(() {});
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: const Color(0xFFC62828)));
                                                  }
                                                }
                                              },
                                              child: const Text('Decline', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC62828))),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF2E7D32),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                padding: const EdgeInsets.symmetric(vertical: 4),
                                              ),
                                              onPressed: () async {
                                                try {
                                                   if (pTime != null && currentUid != null) {
                                                     final myConflict = await MeetingService().hasMeetingConflict(currentUid, pTime);
                                                     if (myConflict) {
                                                       if (context.mounted) {
                                                         ScaffoldMessenger.of(context).showSnackBar(
                                                           const SnackBar(
                                                             content: Text('Cannot accept. You already have a confirmed meeting around this time.'),
                                                             backgroundColor: Color(0xFFC62828),
                                                           ),
                                                         );
                                                       }
                                                       return;
                                                     }

                                                     if (pBy != null) {
                                                       final otherConflict = await MeetingService().hasMeetingConflict(pBy, pTime);
                                                       if (otherConflict) {
                                                         if (context.mounted) {
                                                           ScaffoldMessenger.of(context).showSnackBar(
                                                             const SnackBar(
                                                               content: Text('Cannot accept. The other participant already has a confirmed meeting around this time.'),
                                                               backgroundColor: Color(0xFFC62828),
                                                             ),
                                                           );
                                                         }
                                                         return;
                                                       }
                                                     }
                                                   }
                                                   await MeetingService().acceptProposal(meetingId: meetingId, proposalId: pId);
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text(isHost ? 'Meeting rescheduled to proposed time!' : 'Proposal accepted!'),
                                                        backgroundColor: const Color(0xFF2E7D32),
                                                      ),
                                                    );
                                                  }
                                                  setState(() {});
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: const Color(0xFFC62828)));
                                                  }
                                                }
                                              },
                                              child: Text(
                                                isHost ? 'Accept & Reschedule' : 'Accept',
                                                style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        }),
                      ],
                      // Legacy single-proposal fallback (for old data without proposals array)
                      if ((data['proposals'] as List?)?.isEmpty != false && proposedTimeTimestamp != null && proposedBy != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF7A432D), width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.schedule, color: Color(0xFF7A432D), size: 16),
                                  const SizedBox(width: 6),
                                  const Text('Legacy Proposal', style: TextStyle(fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF3E1F11))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Proposed: ${proposedTime!.day} ${const ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][proposedTime.month - 1]} at ${proposedTime.hour.toString().padLeft(2, '0')}:${proposedTime.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E1F11)),
                              ),
                              if (proposalNote.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('Note: "$proposalNote"', style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF5C473E))),
                                ),
                            ],
                          ),
                        ),
                      ],
                      // Active Collaborative Reschedule Poll
                      if (data['currentPollId'] != null) ...[
                        PollWidget(
                          meetingId: meetingId,
                          pollId: data['currentPollId'] as String,
                          isHost: isHost,
                        ),
                        const SizedBox(height: 16),
                      ],

                      const SizedBox(height: 16),

                      // Attendee Details Header
                      const Text(
                        'ATTENDEE STATUSES',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Color(0xFF8C736B),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Attendee List
                      ...profiles.map((profile) {
                        final status = statusMap[profile.uid] as String? ?? 'pending';
                        final isOrg = profile.uid == requesterId;
                        final isHost = hosts.contains(profile.uid) && !isOrg;

                        Color partStatusColor;
                        String partStatusLabel;
                        switch (status) {
                          case 'accepted':
                            partStatusColor = const Color(0xFF2E7D32);
                            partStatusLabel = 'Accepted';
                            break;
                          case 'tentative':
                            partStatusColor = const Color(0xFFEF6C00);
                            partStatusLabel = 'Tentative';
                            break;
                          case 'cancelled':
                            partStatusColor = const Color(0xFFC62828);
                            partStatusLabel = 'Cancelled';
                            break;
                          case 'proposed_other_time':
                            partStatusColor = const Color(0xFF7A432D);
                            partStatusLabel = 'Proposed Time';
                            break;
                          case 'pending':
                          default:
                            partStatusColor = Colors.grey;
                            partStatusLabel = 'Pending';
                            break;
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFE5A475),
                                ),
                                child: ClipOval(
                                  child: buildProfileImage(
                                    profile.profileImageUrl ?? '',
                                    fit: BoxFit.cover,
                                    fallback: Center(
                                      child: Text(
                                        profile.name.substring(0, 1).toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          profile.name,
                                          style: const TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF3E1F11),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // Role Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: isOrg
                                                  ? const Color(0xFFEF6C00)
                                                  : (isHost ? const Color(0xFF7A432D) : Colors.grey),
                                              width: 0.8,
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isOrg ? 'Organizer' : (isHost ? 'Co-host' : 'Participant'),
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              color: isOrg
                                                  ? const Color(0xFFEF6C00)
                                                  : (isHost ? const Color(0xFF7A432D) : Colors.grey),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      profile.role != null && profile.role!.isNotEmpty && profile.company != null && profile.company!.isNotEmpty
                                          ? "${profile.role} · ${profile.company}"
                                          : (profile.headline ?? 'Professional'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 11,
                                        color: Color(0xFF8C736B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Attendee status badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: partStatusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  partStatusLabel,
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: partStatusColor,
                                  ),
                                ),
                              ),

                              // Organizer Action (Make / Remove Co-host)
                              if (currentUid == requesterId && profile.uid != requesterId && profiles.length > 2) ...[
                                const SizedBox(width: 6),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF8C736B)),
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: isHost ? 'remove_cohost' : 'make_cohost',
                                      child: Text(
                                        isHost ? 'Remove Co-host' : 'Make Co-host',
                                        style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12),
                                      ),
                                    ),
                                  ],
                                  onSelected: (val) async {
                                    try {
                                      final makeHost = val == 'make_cohost';
                                      await MeetingService().toggleCoHost(
                                        meetingId: meetingId,
                                        userId: profile.uid,
                                        makeCoHost: makeHost,
                                        currentUserId: currentUid ?? '',
                                      );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('${profile.name} is now ${makeHost ? 'a Co-host' : 'a Participant'}.'),
                                          backgroundColor: const Color(0xFF7A432D),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to update role: $e'),
                                          backgroundColor: const Color(0xFFC62828),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ]
                            ],
                          ),
                        );
                      }),

                      // Meeting Actions
                      if (!isPast && statusStr != 'completed' && statusStr != 'expired') ...[
                        const Divider(height: 24, color: Color(0xFFE8E2DD)),
                        if (statusStr == 'cancelled') ...[
                          if (hosts.contains(currentUid)) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7A432D),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  icon: const Icon(Icons.edit_calendar, size: 16, color: Colors.white),
                                  label: const Text(
                                    'Reschedule',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => CreatePollDialog(
                                        meetingId: meetingId,
                                        currentCity: data['meetingCity'] as String? ?? 'Vijayawada',
                                        onPollCreated: () {
                                          setState(() {});
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ] else ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Reschedule (Host only)
                              if (hosts.contains(currentUid)) ...[
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7A432D),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  icon: const Icon(Icons.edit_calendar, size: 16, color: Colors.white),
                                  label: const Text(
                                    'Reschedule',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => CreatePollDialog(
                                        meetingId: meetingId,
                                        currentCity: data['meetingCity'] as String? ?? 'Vijayawada',
                                        onPollCreated: () {
                                          setState(() {});
                                        },
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),
                              ],

                              // My Attendance dropdown/actions
                              if (participants.contains(currentUid)) ...[
                                Row(
                                  children: [
                                    const Text(
                                      'Your Response:',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF8C736B),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: const Color(0xFFE0D4CB)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: DropdownButton<String>(
                                          value: statusMap[currentUid] as String? ?? 'pending',
                                          dropdownColor: Colors.white,
                                          underline: const SizedBox(),
                                          isExpanded: true,
                                          style: const TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF3E1F11),
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'pending',
                                              child: Text('Pending', style: TextStyle(color: Colors.grey)),
                                            ),
                                            DropdownMenuItem(
                                              value: 'accepted',
                                              child: Text('Accept', style: TextStyle(color: Color(0xFF2E7D32))),
                                            ),
                                            DropdownMenuItem(
                                              value: 'tentative',
                                              child: Text('Tentative', style: TextStyle(color: Color(0xFFEF6C00))),
                                            ),
                                            DropdownMenuItem(
                                              value: 'cancelled',
                                              child: Text('Cancel', style: TextStyle(color: Color(0xFFC62828))),
                                            ),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) {
                                              _updateMyStatus(meetingId, val, location, timeStr);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                            ],
                          ),
                        ],
                      ],
                    ],
                  );
                },
              ),
            )
          ]
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF3E1F11)),
          onPressed: widget.onBack ?? () {
            _state.currentScreen = AppScreen.hub;
          },
        ),
        title: const Text(
          'Lock in Meeting',
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E1F11),
          ),
        ),
      ),
      body: Column(
        children: [
          // Segmented Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _activeTab == 0 ? const Color(0xFF7A432D) : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Request Meeting',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: _activeTab == 0 ? FontWeight.bold : FontWeight.w500,
                          fontSize: 14,
                          color: _activeTab == 0 ? const Color(0xFF3E1F11) : const Color(0xFF8C736B),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _activeTab == 1 ? const Color(0xFF7A432D) : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'My Meetings',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: _activeTab == 1 ? FontWeight.bold : FontWeight.w500,
                          fontSize: 14,
                          color: _activeTab == 1 ? const Color(0xFF3E1F11) : const Color(0xFF8C736B),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loadingConnections
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF7A432D)),
                  )
                : SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06, vertical: 16),
                      child: _activeTab == 0 ? _buildRequestTab() : _buildMeetingsTab(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestTab() {
    if (_connections.isEmpty && _userGroups.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 60),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 60, color: Color(0xFF8C736B)),
            const SizedBox(height: 16),
            const Text(
              'No active connections found.',
              style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E1F11),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connect or chat with users on the discover page to start scheduling meetings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                color: Color(0xFF8C736B),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A432D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                _state.currentScreen = AppScreen.hub;
              },
              child: const Text(
                'Go to Discover',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dropdown Selector for Group Invite (Optional)
        if (_userGroups.isNotEmpty) ...[
          const Text(
            'INVITE A GROUP (OPTIONAL)',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Color(0xFF8C736B),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<Map<String, dynamic>>(
            initialValue: _selectedGroup,
            dropdownColor: Colors.white,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF7A432D)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            hint: const Text(
              'Select a group to auto-invite all members',
              style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: Color(0xFF8C736B)),
            ),
            items: [
              const DropdownMenuItem<Map<String, dynamic>>(
                value: null,
                child: Text(
                  'None (Invite individuals)',
                  style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: Color(0xFF8C736B)),
                ),
              ),
              ..._userGroups.map((g) {
                return DropdownMenuItem<Map<String, dynamic>>(
                  value: g,
                  child: Text(
                    g['groupName'] as String? ?? 'Unnamed Group',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      color: Color(0xFF3E1F11),
                    ),
                  ),
                );
              })
            ],
            onChanged: (Map<String, dynamic>? val) async {
              setState(() {
                _selectedGroup = val;
                _selectedConnections.clear();
              });
              if (val != null) {
                final participantIds = List<String>.from(val['participants'] ?? []);
                final currentUid = FirebaseAuth.instance.currentUser?.uid;
                for (final pid in participantIds) {
                  if (pid == currentUid) continue;
                  final profile = await UserService().getUserProfile(pid);
                  if (profile != null) {
                    setState(() {
                      _selectedConnections.add(profile);
                    });
                  }
                }
              }
              _updateDetectedCity();
              _checkConflicts();
            },
          ),
          const SizedBox(height: 16),
        ],

        // Selected Attendees Chips
        if (_selectedConnections.isNotEmpty) ...[
          const Text(
            'SELECTED ATTENDEES',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Color(0xFF8C736B),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedConnections.map((conn) {
              return Chip(
                backgroundColor: const Color(0xFFFAF7F5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFFE8E2DD)),
                ),
                avatar: ClipOval(
                  child: buildProfileImage(
                    conn.profileImageUrl ?? '',
                    fit: BoxFit.cover,
                    width: 24,
                    height: 24,
                    fallback: Container(
                      color: const Color(0xFFE5A475),
                      alignment: Alignment.center,
                      child: Text(
                        conn.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                label: Text(
                  conn.name,
                  style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: Color(0xFF3E1F11)),
                ),
                deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFF8C736B)),
                onDeleted: () {
                  setState(() {
                    _selectedConnections.remove(conn);
                  });
                  _updateDetectedCity();
                  _checkConflicts();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Select Individuals Section
        const Text(
          'SELECT INDIVIDUALS',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Color(0xFF8C736B),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search connections...',
            prefixIcon: const Icon(Icons.search, color: Color(0xFF8C736B), size: 18),
            hintStyle: const TextStyle(color: Color(0xFF8C736B)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7A432D)),
            ),
          ),
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8E2DD)),
          ),
          child: _connections.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No connections available.',
                        style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: Color(0xFF8C736B))),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _connections.where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase())).length,
                  itemBuilder: (context, index) {
                    final conn = _connections.where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList()[index];
                    final isSelected = _selectedConnections.any((c) => c.uid == conn.uid);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              conn.name,
                              style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, color: Color(0xFF3E1F11)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Builder(
                            builder: (context) {
                              final currentUid = FirebaseAuth.instance.currentUser?.uid;
                              if (currentUid == null || _currentUserProfile == null) return const SizedBox.shrink();
                              final computedScore = calculateMatchScore(
                                currentUid: currentUid,
                                targetUid: conn.uid,
                                currentSkills: _currentUserProfile!.skills,
                                currentInterests: _currentUserProfile!.interests,
                                currentExpertise: _currentUserProfile!.expertise,
                                currentIntents: _currentUserProfile!.intents,
                                targetSkills: conn.skills,
                                targetInterests: conn.interests,
                                targetExpertise: conn.expertise,
                                targetIntents: conn.intents,
                              );
                              return Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5A475).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE5A475).withValues(alpha: 0.4),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Color(0xFF7A432D),
                                      size: 10,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '$computedScore% match',
                                      style: const TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF7A432D),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      subtitle: Text(
                        conn.role != null && conn.role!.isNotEmpty && conn.company != null && conn.company!.isNotEmpty
                            ? "${conn.role} · ${conn.company}"
                            : (conn.headline ?? 'Professional'),
                        style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: Color(0xFF8C736B)),
                      ),
                      secondary: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE5A475),
                        ),
                        child: ClipOval(
                          child: buildProfileImage(
                            conn.profileImageUrl ?? '',
                            fit: BoxFit.cover,
                            fallback: Center(
                              child: Text(
                                conn.name.substring(0, 1).toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),
                      activeColor: const Color(0xFF7A432D),
                      onChanged: (bool? checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedConnections.add(conn);
                          } else {
                            _selectedConnections.removeWhere((c) => c.uid == conn.uid);
                          }
                        });
                        _updateDetectedCity();
                        _checkConflicts();
                      },
                    );
                  },
                ),
        ),

        const SizedBox(height: 24),

        // Date Input
        const Text(
          'DATE',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Color(0xFF8C736B),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE8E2DD)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _meetingDate,
                  style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, color: Color(0xFF3E1F11)),
                ),
                const Icon(Icons.calendar_today, size: 18, color: Color(0xFF8C736B)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Time Input
        const Text(
          'TIME',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Color(0xFF8C736B),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _selectTime(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE8E2DD)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _meetingTime,
                  style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, color: Color(0xFF3E1F11)),
                ),
                const Icon(Icons.access_time, size: 18, color: Color(0xFF8C736B)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Meeting Purpose
        const Text(
          'MEETING PURPOSE',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Color(0xFF8C736B),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE8E2DD)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<MeetingPurpose>(
              value: _meetingPurpose,
              isExpanded: true,
              dropdownColor: Colors.white,
              style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, color: Color(0xFF3E1F11)),
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF8C736B)),
              items: MeetingPurpose.values.map((purpose) {
                return DropdownMenuItem(
                  value: purpose,
                  child: Text(purpose.displayName),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _meetingPurpose = val;
                  });
                }
              },
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Meeting Type (In-Person / Online)
        const Text(
          'MEETING TYPE',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Color(0xFF8C736B),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTypeButton(
                label: 'In-Person',
                icon: Icons.location_on_outlined,
                isSelected: _meetingType == 'in_person',
                onTap: () => setState(() => _meetingType = 'in_person'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTypeButton(
                label: 'Online Meeting',
                icon: Icons.videocam_outlined,
                isSelected: _meetingType == 'online',
                onTap: () => setState(() => _meetingType = 'online'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Location & Search Selector
        if (_meetingType == 'in_person') ...[
          const Text(
            'MEETING LOCATION',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Color(0xFF8C736B),
            ),
          ),
          const SizedBox(height: 10),
          LocationSearchSection(
            currentCity: _meetingCity,
            purpose: _meetingPurpose,
            selectedVenue: _selectedVenue,
            onVenueSelected: (venue) {
              setState(() {
                _selectedVenue = venue;
                _selectedLocation = venue.name;
              });
            },
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F5),
              border: Border.all(color: const Color(0xFFE8E2DD)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: const [
                Icon(Icons.videocam, color: Color(0xFF7A432D), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Virtual Video Call',
                        style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF3E1F11)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Meeting link will be shared in your chat conversation automatically.',
                        style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: Color(0xFF8C736B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        const Text(
          'REMINDER',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Color(0xFF8C736B),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE8E2DD)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedReminderMinutes,
              isExpanded: true,
              dropdownColor: Colors.white,
              style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, color: Color(0xFF3E1F11)),
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF8C736B)),
              items: const [
                DropdownMenuItem(value: 0, child: Text('None')),
                DropdownMenuItem(value: 5, child: Text('5 minutes before')),
                DropdownMenuItem(value: 10, child: Text('10 minutes before')),
                DropdownMenuItem(value: 15, child: Text('15 minutes before')),
                DropdownMenuItem(value: 30, child: Text('30 minutes before')),
                DropdownMenuItem(value: 60, child: Text('1 hour before')),
                DropdownMenuItem(value: 1440, child: Text('1 day before')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedReminderMinutes = val;
                  });
                }
              },
            ),
          ),
        ),

        if (_conflictWarning != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFD1D1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFC62828), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _conflictWarning!,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFC62828),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 30),

        // Confirm Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7A432D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _submittingMeeting ? null : _requestMeeting,
            child: _submittingMeeting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Lock in meeting',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 15,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildMeetingsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: MeetingService().streamUserMeetings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(color: Color(0xFF7A432D)),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 60),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.event_note, size: 60, color: Color(0xFF8C736B)),
                SizedBox(height: 16),
                Text(
                  'No meetings requested or scheduled yet.',
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E1F11),
                  ),
                ),
              ],
            ),
          );
        }

        final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final now = DateTime.now();

        final pendingList = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final confirmedList = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final historyList = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        for (final doc in docs) {
          final data = doc.data();
          final rawStatus = data['status'] as String? ?? 'pending';
          final statusStr = rawStatus.toUpperCase();
          final statusMap = Map<String, dynamic>.from(data['participantsStatus'] ?? {});
          final rawMyStatus = statusMap[currentUid] as String? ?? 'pending';
          final myStatus = rawMyStatus.toUpperCase();
          
          final scheduledTimestamp = data['scheduledAt'] as Timestamp?;
          final scheduledAt = scheduledTimestamp?.toDate();
          final isPast = scheduledAt != null && scheduledAt.isBefore(now);

          if (statusStr == 'CANCELLED' ||
              statusStr == 'COMPLETED' ||
              statusStr == 'EXPIRED' ||
              statusStr == 'NOSHOW' ||
              statusStr == 'REJECTED' ||
              statusStr == 'RESCHEDULE_REJECTED' ||
              isPast ||
              myStatus == 'CANCELLED' ||
              myStatus == 'REJECTED' ||
              myStatus == 'DECLINED') {
            historyList.add(doc);
          } else if (statusStr == 'PENDING' && myStatus == 'PENDING') {
            pendingList.add(doc);
          } else {
            confirmedList.add(doc);
          }
        }

        // Sort each list by scheduledAt
        int compareMeetings(QueryDocumentSnapshot<Map<String, dynamic>> a, QueryDocumentSnapshot<Map<String, dynamic>> b) {
          final aTime = (a.data()['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = (b.data()['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          return aTime.compareTo(bTime);
        }

        pendingList.sort(compareMeetings);
        confirmedList.sort(compareMeetings);
        // History sorted by most recent first
        historyList.sort((a, b) {
          final aTime = (a.data()['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = (b.data()['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pendingList.isNotEmpty) ...[
              _buildSectionHeader('Pending Invitations (${pendingList.length})', Icons.mail_outline),
              const SizedBox(height: 8),
              ...pendingList.map((doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildMeetingCard(doc.id, doc.data()),
                  )),
              const SizedBox(height: 20),
            ],
            if (confirmedList.isNotEmpty) ...[
              _buildSectionHeader('Confirmed Meetings (${confirmedList.length})', Icons.check_circle_outline),
              const SizedBox(height: 8),
              ...confirmedList.map((doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildMeetingCard(doc.id, doc.data()),
                  )),
              const SizedBox(height: 20),
            ],
            if (historyList.isNotEmpty) ...[
              _buildSectionHeader('Past & Cancelled (${historyList.length})', Icons.history),
              const SizedBox(height: 8),
              ...historyList.map((doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildMeetingCard(doc.id, doc.data()),
                  )),
            ],
            if (pendingList.isEmpty && confirmedList.isEmpty && historyList.isEmpty)
              const Center(
                child: Text('No meetings found.', style: TextStyle(fontFamily: 'PlusJakartaSans', color: Color(0xFF8C736B))),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF7A432D)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E1F11),
          ),
        ),
      ],
    );
  }
}
