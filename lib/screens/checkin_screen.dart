import 'package:flutter/material.dart';
import '../state_manager.dart';

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  final AppStateManager _state = AppStateManager();

  @override
  Widget build(BuildContext context) {
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFEDD8C4), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF1E6),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5A475), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFF7A432D),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7A432D).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'COMING SOON',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Color(0xFF7A432D),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Check-In Feature',
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E1F11),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'We are currently building an enhanced real-time location check-in experience for events, airports, and hotels. Stay tuned!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFF8C736B),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A432D),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      _state.currentScreen = AppScreen.hub;
                    },
                    child: const Text(
                      'Back to Hub',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/*
================================================================================
EXISTING CHECK-IN IMPLEMENTATION (COMMENTED OUT)
================================================================================

import '../models/checkin.dart';

class _OldCheckinScreenState {
  final AppStateManager _state = AppStateManager();
  
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _linkController = TextEditingController();
  
  String _checkinDate = '';
  String _checkinTime = '';
  String _checkoutDate = '';
  String _checkoutTime = '';

  void initState() {
    final now = DateTime.now();
    _checkinDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    _checkinTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final tomorrow = now.add(const Duration(days: 1));
    _checkoutDate = "${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}";
    _checkoutTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _linkController.dispose();
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
    
    _nameController.clear();
    _locationController.clear();
    _linkController.clear();
  }
}
================================================================================
*/
