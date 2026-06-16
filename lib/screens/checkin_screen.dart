import 'package:flutter/material.dart';
import '../state_manager.dart';
import '../models/checkin.dart';

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  final AppStateManager _state = AppStateManager();
  
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _linkController = TextEditingController();
  
  String _checkinDate = '';
  String _checkinTime = '';
  String _checkoutDate = '';
  String _checkoutTime = '';

  @override
  void initState() {
    super.initState();
    // Default dates/times
    final now = DateTime.now();
    _checkinDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    _checkinTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final tomorrow = now.add(const Duration(days: 1));
    _checkoutDate = "${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}";
    _checkoutTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _handleAddCheckin() {
    if (_nameController.text.trim().isEmpty) return;
    
    final newCheckin = Checkin(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: _state.selectedCheckinType,
      name: _nameController.text.trim(),
      location: _locationController.text.trim().isEmpty ? 'General' : _locationController.text.trim(),
      link: _state.selectedCheckinType == CheckinType.event && _linkController.text.isNotEmpty 
          ? _linkController.text.trim() 
          : null,
      checkinDate: _checkinDate,
      checkinTime: _checkinTime,
      checkoutDate: _checkoutDate,
      checkoutTime: _checkoutTime,
    );

    _state.addCheckin(newCheckin);
    
    // Clear form
    _nameController.clear();
    _locationController.clear();
    _linkController.clear();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Successfully checked in!'),
        backgroundColor: Color(0xFF7A432D),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isCheckin) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
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
        final formatted = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
        if (isCheckin) {
          _checkinDate = formatted;
        } else {
          _checkoutDate = formatted;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isCheckin) async {
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
        final formatted = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
        if (isCheckin) {
          _checkinTime = formatted;
        } else {
          _checkoutTime = formatted;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final selectedTab = _state.selectedCheckinType;

        String nameLabel = '';
        String locLabel = '';
        IconData nameIcon = Icons.help;
        IconData locIcon = Icons.map;
        bool showLink = false;

        switch (selectedTab) {
          case CheckinType.event:
            nameLabel = 'Event name';
            locLabel = 'Venue';
            nameIcon = Icons.celebration_outlined;
            locIcon = Icons.room_outlined;
            showLink = true;
            break;
          case CheckinType.airport:
            nameLabel = 'Airport / Terminal';
            locLabel = 'Gate / Lounge';
            nameIcon = Icons.flight_takeoff;
            locIcon = Icons.meeting_room_outlined;
            showLink = false;
            break;
          case CheckinType.hotel:
            nameLabel = 'Hotel name';
            locLabel = 'City / Area';
            nameIcon = Icons.hotel_outlined;
            locIcon = Icons.location_city_outlined;
            showLink = false;
            break;
        }

        return Scaffold(
          backgroundColor: const Color(0xFFFAF7F5),
          appBar: AppBar(
            backgroundColor: const Color(0xFFFAF7F5),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF3E1F11)),
              onPressed: () {
                _state.currentScreen = AppScreen.hub;
              },
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Check in',
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E1F11),
                  ),
                ),
                Text(
                  'Share where you are',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    color: Color(0xFF8C736B),
                  ),
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: 10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tab Buttons
                  Row(
                    children: [
                      _buildTabButton(CheckinType.event, 'Event', Icons.calendar_today_outlined),
                      const SizedBox(width: 8),
                      _buildTabButton(CheckinType.airport, 'Airport', Icons.flight_outlined),
                      const SizedBox(width: 8),
                      _buildTabButton(CheckinType.hotel, 'Hotel,', Icons.business_outlined),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Form Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE8E2DD), width: 1.5),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name Input
                          Text(
                            nameLabel.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: Color(0xFF8C736B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 14,
                              color: Color(0xFF3E1F11),
                            ),
                            decoration: InputDecoration(
                              prefixIcon: Icon(nameIcon, color: const Color(0xFF8C736B), size: 18),
                              hintText: 'Enter ${nameLabel.toLowerCase()}',
                              hintStyle: const TextStyle(color: Color(0xFF8C736B), fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFFFAF7F5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF7A432D)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Location Input
                          Text(
                            locLabel.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: Color(0xFF8C736B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _locationController,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 14,
                              color: Color(0xFF3E1F11),
                            ),
                            decoration: InputDecoration(
                              prefixIcon: Icon(locIcon, color: const Color(0xFF8C736B), size: 18),
                              hintText: 'Enter ${locLabel.toLowerCase()}',
                              hintStyle: const TextStyle(color: Color(0xFF8C736B), fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFFFAF7F5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF7A432D)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            ),
                          ),

                          if (showLink) ...[
                            const SizedBox(height: 16),
                            // Link Input
                            const Text(
                              'EVENT LINK',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: Color(0xFF8C736B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _linkController,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 14,
                                color: Color(0xFF3E1F11),
                              ),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.link_rounded, color: Color(0xFF8C736B), size: 18),
                                hintText: 'https://...',
                                hintStyle: const TextStyle(color: Color(0xFF8C736B), fontSize: 13),
                                filled: true,
                                fillColor: const Color(0xFFFAF7F5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF7A432D)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Check-in Date and Time Selection
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'CHECK IN DATE',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF8C736B),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => _selectDate(context, true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFAF7F5),
                                          border: Border.all(color: const Color(0xFFE8E2DD)),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _checkinDate,
                                              style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13),
                                            ),
                                            const Icon(Icons.calendar_today, size: 16, color: Color(0xFF8C736B)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'TIME',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF8C736B),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => _selectTime(context, true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFAF7F5),
                                          border: Border.all(color: const Color(0xFFE8E2DD)),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _checkinTime,
                                              style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13),
                                            ),
                                            const Icon(Icons.access_time, size: 16, color: Color(0xFF8C736B)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Check-out Date and Time Selection
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'CHECK OUT DATE',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF8C736B),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => _selectDate(context, false),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFAF7F5),
                                          border: Border.all(color: const Color(0xFFE8E2DD)),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _checkoutDate,
                                              style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13),
                                            ),
                                            const Icon(Icons.calendar_today, size: 16, color: Color(0xFF8C736B)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'TIME',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF8C736B),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => _selectTime(context, false),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFAF7F5),
                                          border: Border.all(color: const Color(0xFFE8E2DD)),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _checkoutTime,
                                              style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13),
                                            ),
                                            const Icon(Icons.access_time, size: 16, color: Color(0xFF8C736B)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Add Check-in Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7A432D),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              onPressed: _handleAddCheckin,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Add checkin',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 14,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Your checkins List
                  if (_state.checkins.isNotEmpty) ...[
                    const Text(
                      'YOUR CHECKINS',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Color(0xFF8C736B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _state.checkins.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _state.checkins[index];
                        IconData itemIcon = Icons.celebration_outlined;
                        if (item.type == CheckinType.airport) {
                          itemIcon = Icons.flight_takeoff;
                        } else if (item.type == CheckinType.hotel) {
                          itemIcon = Icons.hotel_outlined;
                        }

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE8E2DD)),
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF7F5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(itemIcon, color: const Color(0xFF7A432D), size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontFamily: 'PlayfairDisplay',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF3E1F11),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF8C736B)),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            item.location,
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
                                    if (item.link != null && item.link!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.link, size: 12, color: Color(0xFF7A432D)),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              item.link!,
                                              style: const TextStyle(
                                                fontFamily: 'PlusJakartaSans',
                                                fontSize: 11,
                                                color: Color(0xFF7A432D),
                                                decoration: TextDecoration.underline,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 10, color: Color(0xFF8C736B)),
                                        const SizedBox(width: 4),
                                        Text(
                                          "${item.checkinDate} ${item.checkinTime}",
                                          style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, color: Color(0xFF8C736B)),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text('→', style: TextStyle(fontSize: 10, color: Color(0xFF8C736B))),
                                        const SizedBox(width: 6),
                                        Text(
                                          "${item.checkoutDate} ${item.checkoutTime}",
                                          style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, color: Color(0xFF8C736B)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Bottom discover CTA
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
                      onPressed: () {
                        _state.currentScreen = AppScreen.discover;
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'Discover connections nearby',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
  }

  Widget _buildTabButton(CheckinType type, String label, IconData icon) {
    final isSelected = _state.selectedCheckinType == type;

    return Expanded(
      child: InkWell(
        onTap: () {
          _state.selectedCheckinType = type;
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF7A432D) : Colors.white,
            border: Border.all(
              color: isSelected ? const Color(0xFF7A432D) : const Color(0xFFE8E2DD),
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF7A432D).withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : const Color(0xFF8C736B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF8C736B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
