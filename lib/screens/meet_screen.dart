import 'package:flutter/material.dart';
import '../state_manager.dart';
import '../models/event.dart';

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

  String _meetingDate = '';
  String _meetingTime = '';
  String _selectedLocation = 'Plaza Premium Lounge';

  final List<String> _quickLocations = [
    'Plaza Premium Lounge',
    'Gate 12 Lounge',
    'Starbucks Reserve (Gate 14)',
    'Transit Hotel Lobby',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _meetingDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    _meetingTime = "${(now.hour + 1).toString().padLeft(2, '0')}:00";
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
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
    }
  }

  void _confirmMeeting(String contactName) {
    // 1. Create event
    final dateParts = _meetingDate.split('-');
    String month = 'JUN';
    String day = '15';
    if (dateParts.length == 3) {
      final m = int.tryParse(dateParts[1]);
      day = dateParts[2];
      const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
      if (m != null && m >= 1 && m <= 12) {
        month = months[m - 1];
      }
    }

    final newEvent = Event(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      illustrationPath: 'assets/images/boarding_pass_illustration_3.png',
      month: month,
      day: day,
      title: 'Coffee with $contactName',
      location: _selectedLocation,
      time: 'Today • $_meetingTime',
      attendees: '2 attending',
      isJoined: true, // Auto-join scheduled meetings
    );

    _state.createEvent(newEvent);

    // 2. Feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Meeting confirmed with $contactName!'),
        backgroundColor: const Color(0xFF7A432D),
      ),
    );

    // 3. Navigate back
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      _state.currentScreen = AppScreen.hub;
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactName = widget.name ?? 'Ananya Rao';
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF3E1F11)),
          onPressed: widget.onBack ?? () {
            _state.currentScreen = AppScreen.chat;
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
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contact Summary Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE8E2DD)),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    )
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE5A475),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        contactName.split(' ').map((n) => n[0]).join(),
                        style: const TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contactName,
                            style: const TextStyle(
                              fontFamily: 'PlayfairDisplay',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3E1F11),
                            ),
                          ),
                          const Text(
                            'Partner at Lumen Ventures',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              color: Color(0xFF8C736B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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

              // Location Input
              const Text(
                'LOCATION',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Color(0xFF8C736B),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickLocations.map((loc) {
                  final isSelected = _selectedLocation == loc;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedLocation = loc;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF7A432D) : Colors.white,
                        border: Border.all(
                          color: isSelected ? const Color(0xFF7A432D) : const Color(0xFFE8E2DD),
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        loc,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF3E1F11),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 40),

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
                  onPressed: () => _confirmMeeting(contactName),
                  child: const Text(
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
          ),
        ),
      ),
    );
  }
}
