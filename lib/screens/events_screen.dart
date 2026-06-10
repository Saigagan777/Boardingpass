import 'package:flutter/material.dart';
import '../state_manager.dart';
import '../models/event.dart';

class EventsScreen extends StatefulWidget {
  final VoidCallback? onNext;
  const EventsScreen({super.key, this.onNext});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final AppStateManager _state = AppStateManager();
  int _activeSubTab = 0; // 0 for Upcoming, 1 for My Events
  final Set<String> _bookmarkedEvents = {};

  void _handleCreateEvent() {
    showDialog(
      context: context,
      builder: (context) {
        final titleController = TextEditingController();
        final locController = TextEditingController();
        final dateController = TextEditingController();
        final timeController = TextEditingController();

        return AlertDialog(
          backgroundColor: const Color(0xFFFAF7F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE8E2DD), width: 1.5),
          ),
          title: const Text(
            'Create Your Own Event',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 20,
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
                  'EVENT TITLE',
                  style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: 'Enter title',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'LOCATION / VENUE',
                  style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: locController,
                  decoration: InputDecoration(
                    hintText: 'Enter venue (e.g. Lounge Gate 12)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DATE',
                            style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: dateController,
                            decoration: InputDecoration(
                              hintText: '24 May',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TIME',
                            style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C736B)),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: timeController,
                            decoration: InputDecoration(
                              hintText: '6:30 PM',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8C736B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A432D)),
              onPressed: () {
                if (titleController.text.trim().isNotEmpty) {
                  final newEvent = Event(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    illustrationPath: 'assets/images/boarding_pass_illustration_6.png',
                    month: dateController.text.toUpperCase().contains(' ') 
                        ? dateController.text.trim().split(' ').last 
                        : 'JUN',
                    day: dateController.text.trim().split(' ').first,
                    title: titleController.text.trim(),
                    location: locController.text.isEmpty ? 'Lounge' : locController.text.trim(),
                    time: "${timeController.text.isEmpty ? '7:00 PM' : timeController.text.trim()} • Today",
                    attendees: '1 attending',
                    isJoined: true,
                  );
                  _state.createEvent(newEvent);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Event created successfully!'),
                      backgroundColor: Color(0xFF7A432D),
                    ),
                  );
                }
              },
              child: const Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return ListenableBuilder(
      listenable: _state,
      builder: (context, child) {
        final upcomingEvents = _state.events;
        final myEvents = _state.events.where((e) => e.isJoined).toList();
        final currentList = _activeSubTab == 0 ? upcomingEvents : myEvents;

        return Scaffold(
          backgroundColor: const Color(0xFFFAF7F5),
          appBar: AppBar(
            backgroundColor: const Color(0xFFFAF7F5),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF3E1F11)),
              onPressed: widget.onNext ?? () {
                _state.currentScreen = AppScreen.hub;
              },
            ),
            title: const Text(
              'Events',
              style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E1F11),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: Color(0xFF3E1F11)),
                onPressed: _handleCreateEvent,
              ),
            ],
          ),
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Explore events and networking opportunities.',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    color: Color(0xFF8C736B),
                  ),
                ),
                const SizedBox(height: 16),

                // Segmented tab controls
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E2DD).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _buildSubTabButton(0, 'Upcoming'),
                      _buildSubTabButton(1, 'My Events'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Events List Feed
                Expanded(
                  child: currentList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.event_busy_outlined, color: Color(0xFF8C736B), size: 40),
                              SizedBox(height: 8),
                              Text(
                                'No events found.',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 14,
                                  color: Color(0xFF8C736B),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: currentList.length + 1, // +1 for the bottom "Create event" card
                          separatorBuilder: (context, index) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            if (index == currentList.length) {
                              return _buildCreateEventCTA();
                            }
                            final event = currentList[index];
                            return _buildEventItem(event);
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubTabButton(int index, String title) {
    final isActive = _activeSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeSubTab = index;
          });
        },
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    )
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? const Color(0xFF3E1F11) : const Color(0xFF8C736B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventItem(Event event) {
    final isBookmarked = _bookmarkedEvents.contains(event.id);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E2DD)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Illustration image
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 68,
                  height: 68,
                  color: const Color(0xFFFAF7F5),
                  child: Image.asset(
                    event.illustrationPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Date container
              Container(
                width: 44,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F5),
                  border: Border.all(color: const Color(0xFFE8E2DD)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      event.month,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7A432D),
                      ),
                    ),
                    Text(
                      event.day,
                      style: const TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7A432D),
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Title and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E1F11),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF8C736B)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              color: Color(0xFF8C736B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF8C736B)),
                        const SizedBox(width: 4),
                        Text(
                          event.time,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            color: Color(0xFF8C736B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bookmark icon
              IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  size: 20,
                  color: const Color(0xFF7A432D),
                ),
                onPressed: () {
                  setState(() {
                    if (isBookmarked) {
                      _bookmarkedEvents.remove(event.id);
                    } else {
                      _bookmarkedEvents.add(event.id);
                    }
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Bottom card action row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_outline, size: 12, color: Color(0xFF8C736B)),
                  const SizedBox(width: 4),
                  Text(
                    event.attendees,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      color: Color(0xFF8C736B),
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: event.isJoined
                      ? const Color(0xFFE8E2DD)
                      : const Color(0xFF7A432D),
                  foregroundColor: event.isJoined
                      ? const Color(0xFF3E1F11)
                      : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(100, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () {
                  _state.toggleJoinEvent(event.id);
                },
                child: Row(
                  children: [
                    if (event.isJoined) ...[
                      const Icon(Icons.check, size: 14),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      event.isJoined ? 'Joined' : 'Join Event',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreateEventCTA() {
    return GestureDetector(
      onTap: _handleCreateEvent,
      child: Container(
        height: 84,
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF7A432D).withValues(alpha: 0.4),
            width: 1.5,
            style: BorderStyle.solid, // Note: Flutter border doesn't support dashed natively without packages, solid/colored works beautifully.
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.calendar_today_outlined, color: Color(0xFF7A432D), size: 20),
            SizedBox(width: 10),
            Text(
              'Create Your Own Event',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF7A432D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
