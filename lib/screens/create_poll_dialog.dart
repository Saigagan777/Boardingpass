import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/venue.dart';
import '../models/meeting_poll.dart';
import '../models/poll_option.dart';
import '../services/poll_service.dart';
import '../services/meeting_service.dart';
import '../services/venue_repository.dart';

class CreatePollDialog extends StatefulWidget {
  final String meetingId;
  final String currentCity;
  final VoidCallback? onPollCreated;

  const CreatePollDialog({
    super.key,
    required this.meetingId,
    required this.currentCity,
    this.onPollCreated,
  });

  @override
  State<CreatePollDialog> createState() => _CreatePollDialogState();
}

class _CreatePollDialogState extends State<CreatePollDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Direct Reschedule fields
  DateTime? _directDate;
  TimeOfDay? _directTime;
  Venue? _directVenue;
  final TextEditingController _directVenueSearchController = TextEditingController();
  List<Venue> _directSuggestions = [];

  // Poll fields
  final List<PollSlot> _slots = [PollSlot()];
  bool _allowMultiple = true;
  int _deadlineHours = 24;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _directVenueSearchController.dispose();
    super.dispose();
  }

  // --- Direct Reschedule Actions ---
  Future<void> _selectDirectDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: DateTime(now.year + 1),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF7A432D),
            onPrimary: Colors.white,
            onSurface: Color(0xFF3E1F11),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _directDate = picked);
    }
  }

  Future<void> _selectDirectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF7A432D),
            onPrimary: Colors.white,
            onSurface: Color(0xFF3E1F11),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _directTime = picked);
    }
  }

  void _searchDirectVenues(String query) async {
    if (query.trim().length < 3) {
      setState(() => _directSuggestions = []);
      return;
    }
    final results = await VenueRepositoryImpl().searchVenues(query);
    setState(() => _directSuggestions = results);
  }

  Future<void> _submitDirectReschedule() async {
    if (_directDate == null || _directTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a date and time.'), backgroundColor: Color(0xFFC62828)),
      );
      return;
    }

    final newTime = DateTime(
      _directDate!.year,
      _directDate!.month,
      _directDate!.day,
      _directTime!.hour,
      _directTime!.minute,
    );

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await MeetingService().rescheduleMeeting(
        meetingId: widget.meetingId,
        newTime: newTime,
        userId: uid,
        newVenueSnapshot: _directVenue?.toMap(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meeting rescheduled successfully!'), backgroundColor: Color(0xFF2E7D32)),
        );
        widget.onPollCreated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: const Color(0xFFC62828)),
        );
      }
    }
  }

  // --- Preference Poll Actions ---
  void _addSlot() {
    if (_slots.length >= 4) return;
    setState(() => _slots.add(PollSlot()));
  }

  void _removeSlot(int index) {
    if (_slots.length <= 1) return;
    setState(() => _slots.removeAt(index));
  }

  Future<void> _submitPoll() async {
    // Validate slots
    for (int i = 0; i < _slots.length; i++) {
      if (_slots[i].date == null || _slots[i].time == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please complete Date and Time for Option ${i + 1}'), backgroundColor: const Color(0xFFC62828)),
        );
        return;
      }
    }

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final pollId = const Uuid().v4();
      final List<PollOption> options = [];

      for (final slot in _slots) {
        final dateStr = "${slot.date!.year}-${slot.date!.month.toString().padLeft(2, '0')}-${slot.date!.day.toString().padLeft(2, '0')}";
        final timeStr = "${slot.time!.hour.toString().padLeft(2, '0')}:${slot.time!.minute.toString().padLeft(2, '0')}";

        options.add(PollOption(
          optionId: const Uuid().v4(),
          venueSnapshot: slot.venue,
          date: dateStr,
          time: timeStr,
          voteCount: 0,
          voters: {},
        ));
      }

      final newPoll = MeetingPoll(
        id: pollId,
        type: 'venue_date_time',
        status: 'active',
        deadline: DateTime.now().add(Duration(hours: _deadlineHours)),
        createdBy: uid,
        createdAt: DateTime.now(),
        allowMultipleVotes: _allowMultiple,
        options: options,
      );

      await PollService().createPoll(meetingId: widget.meetingId, poll: newPoll);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preference poll raised successfully!'), backgroundColor: Color(0xFF2E7D32)),
        );
        widget.onPollCreated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: const Color(0xFFC62828)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFFFAF7F5),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
        child: Column(
          children: [
            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF3E1F11),
              unselectedLabelColor: const Color(0xFF8C736B),
              indicatorColor: const Color(0xFF7A432D),
              labelStyle: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.bold, fontSize: 13.5),
              tabs: const [
                Tab(text: 'Direct Reschedule', icon: Icon(Icons.edit_calendar, size: 20)),
                Tab(text: 'Preference Poll', icon: Icon(Icons.bar_chart, size: 20)),
              ],
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDirectTab(),
                  _buildPollTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI Builders ---
  Widget _buildDirectTab() {
    final formattedDate = _directDate == null
        ? 'Select Date'
        : "${_directDate!.day}/${_directDate!.month}/${_directDate!.year}";
    final formattedTime = _directTime == null
        ? 'Select Time'
        : _directTime!.format(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Date & Time', style: TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3E1F11))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectDirectDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE8E2DD)), borderRadius: BorderRadius.circular(12), color: Colors.white),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formattedDate, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13.5)),
                        const Icon(Icons.calendar_today, size: 16, color: Color(0xFF7A432D)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _selectDirectTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE8E2DD)), borderRadius: BorderRadius.circular(12), color: Colors.white),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formattedTime, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13.5)),
                        const Icon(Icons.access_time, size: 16, color: Color(0xFF7A432D)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          const Text('Venue (Optional)', style: TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3E1F11))),
          const SizedBox(height: 12),
          TextField(
            controller: _directVenueSearchController,
            onChanged: _searchDirectVenues,
            style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'Search Hotel or Restaurant...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF8C736B)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE8E2DD))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7A432D))),
            ),
          ),

          // Autocomplete list
          if (_directSuggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE8E2DD)), borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: Material(
                color: Colors.white,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _directSuggestions.length,
                  itemBuilder: (context, index) {
                    final v = _directSuggestions[index];
                    return ListTile(
                      dense: true,
                      title: Text(v.name, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12.5, fontWeight: FontWeight.bold)),
                      subtitle: Text(v.formattedAddress, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11)),
                      onTap: () {
                        setState(() {
                          _directVenue = v;
                          _directVenueSearchController.text = v.name;
                          _directSuggestions = [];
                        });
                      },
                    );
                  },
                ),
              ),
            ),

          if (_directVenue != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFAF7F5), border: Border.all(color: const Color(0xFFE5A475)), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_directVenue!.name, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(_directVenue!.formattedAddress, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: Color(0xFF8C736B))),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      setState(() {
                        _directVenue = null;
                        _directVenueSearchController.clear();
                      });
                    },
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 36),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A432D), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _submitDirectReschedule,
              child: const Text('Confirm Schedule', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _slots.length,
            itemBuilder: (context, index) {
              final slot = _slots[index];
              final dateLabel = slot.date == null
                  ? 'Select Date'
                  : "${slot.date!.day}/${slot.date!.month}/${slot.date!.year}";
              final timeLabel = slot.time == null
                  ? 'Select Time'
                  : slot.time!.format(context);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE8E2DD)), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Option ${index + 1}', style: const TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF3E1F11))),
                        if (_slots.length > 1)
                          GestureDetector(
                            onTap: () => _removeSlot(index),
                            child: const Icon(Icons.delete_outline, color: Color(0xFFC62828), size: 20),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final now = DateTime.now();
                              final today = DateTime(now.year, now.month, now.day);
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: today,
                                firstDate: today,
                                lastDate: DateTime(now.year + 1),
                              );
                              if (picked != null) {
                                setState(() => slot.date = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE8E2DD)), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(dateLabel, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12)),
                                  const Icon(Icons.calendar_today, size: 14, color: Color(0xFF8C736B)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setState(() => slot.time = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE8E2DD)), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(timeLabel, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12)),
                                  const Icon(Icons.access_time, size: 14, color: Color(0xFF8C736B)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Venue Picker
                    TextField(
                      controller: slot.searchController,
                      style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12),
                      onChanged: (query) async {
                        if (query.trim().length < 3) {
                          setState(() => slot.suggestions = []);
                          return;
                        }
                        final results = await VenueRepositoryImpl().searchVenues(query);
                        setState(() => slot.suggestions = results);
                      },
                      decoration: InputDecoration(
                        hintText: 'Add Venue (optional)...',
                        prefixIcon: const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF8C736B)),
                        filled: true,
                        fillColor: const Color(0xFFFAF7F5),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE8E2DD))),
                      ),
                    ),

                    if (slot.suggestions.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 120),
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE8E2DD)), borderRadius: BorderRadius.circular(8)),
                        clipBehavior: Clip.antiAlias,
                        child: Material(
                          color: Colors.white,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: slot.suggestions.length,
                            itemBuilder: (context, idx) {
                              final v = slot.suggestions[idx];
                              return ListTile(
                                dense: true,
                                title: Text(v.name, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11.5, fontWeight: FontWeight.bold)),
                                subtitle: Text(v.formattedAddress, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10)),
                                onTap: () {
                                  setState(() {
                                    slot.venue = v;
                                    slot.searchController.text = v.name;
                                    slot.suggestions = [];
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),

        // Controls
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Allow Multiple Votes', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12.5, fontWeight: FontWeight.w600)),
                  Switch(
                    value: _allowMultiple,
                    activeThumbColor: const Color(0xFF7A432D),
                    onChanged: (val) => setState(() => _allowMultiple = val),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Deadline (Hours)', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12.5, fontWeight: FontWeight.w600)),
                  DropdownButton<int>(
                    value: _deadlineHours,
                    items: const [
                      DropdownMenuItem(value: 12, child: Text('12 Hours')),
                      DropdownMenuItem(value: 24, child: Text('24 Hours')),
                      DropdownMenuItem(value: 48, child: Text('48 Hours')),
                      DropdownMenuItem(value: 72, child: Text('72 Hours')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _deadlineHours = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_slots.length < 4)
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF7A432D)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add, color: Color(0xFF7A432D), size: 16),
                        label: const Text('Add Option', style: TextStyle(fontFamily: 'PlusJakartaSans', color: Color(0xFF7A432D), fontSize: 13)),
                        onPressed: _addSlot,
                      ),
                    ),
                  if (_slots.length < 4) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A432D), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: _submitPoll,
                      child: const Text('Raise Poll', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PollSlot {
  DateTime? date;
  TimeOfDay? time;
  Venue? venue;
  final TextEditingController searchController = TextEditingController();
  List<Venue> suggestions = [];
}
