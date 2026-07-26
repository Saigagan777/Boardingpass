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
  bool _acceptedTerms = false;
  bool _termsError = false;
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

  void _showTermsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Color(0xFFFAF7F5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Modal Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE8E2DD))),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Event Terms & Conditions',
                        style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF3E1F11)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              // Modal Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: const [
                    Text(
                      'Event Rules & Agreement',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E1F11),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '1. Code of Conduct:\nAttendees must treat all participants, speakers, and staff with dignity and respect. Any harassment or inappropriate behavior will result in immediate expulsion without refund.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '2. Ticket & Pass Policy:\nEvent passes are assigned to the registered individual and are non-transferable unless authorized by the event host prior to check-in.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '3. Media & Photography Notice:\nPhotography and video recording may take place during the event for promotional purposes. Attendance constitutes consent to appear in such media.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '4. Organizer Rights:\nOrganizers reserve the right to modify event agendas, venue details, or cancel the event due to unforeseen circumstances.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '5. Privacy Protection:\nYour registration details are securely stored and shared exclusively with the host for event coordination purposes.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                  ],
                ),
              ),
              // Accept Action Button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A432D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      setState(() {
                        _acceptedTerms = true;
                        _termsError = false;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      'I Understand & Accept Terms',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (widget.event.isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration is closed for expired events.'),
          backgroundColor: Color(0xFF616161),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      setState(() => _termsError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms & Conditions to complete registration.'),
          backgroundColor: Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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
                const SizedBox(height: 16),
                // Mandatory Terms & Conditions Checkbox
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _termsError ? const Color(0xFFFFEBEE) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _termsError ? const Color(0xFFC62828) : const Color(0xFFE8E2DD),
                      width: _termsError ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _acceptedTerms,
                        activeColor: const Color(0xFF7A432D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _acceptedTerms = val ?? false;
                            if (_acceptedTerms) _termsError = false;
                          });
                        },
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _acceptedTerms = !_acceptedTerms;
                              if (_acceptedTerms) _termsError = false;
                            });
                          },
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'I agree to the ',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  color: Color(0xFF3E1F11),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _showTermsModal(context),
                                child: const Text(
                                  'Event Terms & Conditions',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7A432D),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              const Text(
                                ' *',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  color: Color(0xFFC62828),
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
                if (_termsError) ...[
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text(
                      'You must accept the Terms & Conditions to complete registration.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        color: Color(0xFFC62828),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
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
