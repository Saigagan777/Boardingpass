import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/event.dart';
import '../models/event_registration.dart';
import '../services/event_registration_service.dart';
import '../state_manager.dart';
import '../widgets/country_phone_input.dart';
import 'event_pass_screen.dart';

/// Collects basic attendee details, then issues a ticket pass with QR.
class EventRegistrationFormScreen extends StatefulWidget {
  final Event event;

  const EventRegistrationFormScreen({super.key, required this.event});

  @override
  State<EventRegistrationFormScreen> createState() =>
      _EventRegistrationFormScreenState();
}

class _EventRegistrationFormScreenState
    extends State<EventRegistrationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _submitting = false;
  CountryCode _selectedCountry = defaultCountries.first;

  @override
  void initState() {
    super.initState();
    final profile = AppStateManager().currentUserProfile;
    final user = FirebaseAuth.instance.currentUser;
    _nameCtrl.text = profile?.name ?? user?.displayName ?? '';
    _emailCtrl.text = profile?.email ?? user?.email ?? '';
    _companyCtrl.text = profile?.company ?? '';
    _roleCtrl.text = profile?.role ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _companyCtrl.dispose();
    _roleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 13,
        color: Color(0xFF8C736B),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        borderSide: const BorderSide(color: Color(0xFF7A432D), width: 1.5),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final EventRegistration reg =
          await EventRegistrationService().registerForEvent(
        event: widget.event,
        fullName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: '${_selectedCountry.dialCode} ${_phoneCtrl.text.trim()}',
        company: _companyCtrl.text.trim(),
        role: _roleCtrl.text,
        notes: _notesCtrl.text,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EventPassScreen(registration: reg),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $e'),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF3E1F11)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Event Registration',
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E1F11),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8E2DD)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${event.day} ${event.month}  ·  ${event.time}',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: Color(0xFF8C736B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        event.location,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: Color(0xFF8C736B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Your details',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E1F11),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'These details appear on your pass and are shared with the event host.',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    color: Color(0xFF8C736B),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _fieldDecoration('Full name *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _fieldDecoration('Email *'),
                  validator: (v) {
                    final val = v?.trim() ?? '';
                    if (val.isEmpty) return 'Email is required';
                    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(val)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CountryPhoneInput(
                  controller: _phoneCtrl,
                  label: 'Phone',
                  isRequired: true,
                  initialCountry: _selectedCountry,
                  onCountryChanged: (c) => setState(() => _selectedCountry = c),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _companyCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _fieldDecoration('Company (optional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _roleCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _fieldDecoration('Role / Title (optional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: _fieldDecoration(
                    'Notes for host (optional)',
                    hint: 'Dietary needs, accessibility, etc.',
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A432D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Complete registration',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 15,
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
