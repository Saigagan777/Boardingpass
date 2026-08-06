import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportSheet extends StatefulWidget {
  const HelpSupportSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const HelpSupportSheet(),
    );
  }

  @override
  State<HelpSupportSheet> createState() => _HelpSupportSheetState();
}

class _HelpSupportSheetState extends State<HelpSupportSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  bool _isSubmitting = false;

  final String _contactEmail = 'admin@nexmeet.world';
  final String _contactPhone = '8500551177';

  final List<Map<String, String>> _faqs = [
    {
      'question': 'How does NexMeet matching work?',
      'answer':
          'NexMeet connects you with nearby professionals based on shared industries, interests, business connect goals, and real-time location proximity.',
    },
    {
      'question': 'How do I verify my email address?',
      'answer':
          'During signup or in your profile settings, tap "Verify Email" to receive a 6-digit OTP via email. Enter the code to instantly get your verified badge.',
    },
    {
      'question': 'What is "Business Forums"?',
      'answer':
          'Business Forums shows the professional networks and communities you are part of (e.g. BNI, Rotary, Startup Grind). You can filter candidate profiles in Discovery by these forums.',
    },
    {
      'question': 'How do I host or join an Event?',
      'answer':
          'Go to the Events tab to discover upcoming networking sessions. Tap on any event to register, view your digital pass, or scan QR passes.',
    },
    {
      'question': 'How can I update my profile or travel location?',
      'answer':
          'Navigate to your Profile tab and tap "Edit Profile". Here you can update your home base, current location, bio, occupation, and networking interests.',
    },
    {
      'question': 'Is my contact information secure and private?',
      'answer':
          'Yes! Your email and phone number are kept secure and are never shared publicly without your explicit consent.',
    },
  ];

  @override
  void dispose() {
    _questionController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _launchEmail() async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: _contactEmail,
      queryParameters: {
        'subject': 'NexMeet App Inquiry / Support Request',
      },
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _copyToClipboard(_contactEmail, 'Email copied to clipboard');
      }
    } catch (_) {
      _copyToClipboard(_contactEmail, 'Email copied to clipboard');
    }
  }

  Future<void> _launchPhone() async {
    final Uri uri = Uri(
      scheme: 'tel',
      path: _contactPhone,
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _copyToClipboard(_contactPhone, 'Phone number copied to clipboard');
      }
    } catch (_) {
      _copyToClipboard(_contactPhone, 'Phone number copied to clipboard');
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'PlusJakartaSans')),
        backgroundColor: const Color(0xFF7A432D),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submitQuestion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('help_requests').add({
        'userId': currentUser?.uid ?? 'anonymous',
        'userEmail': currentUser?.email ?? 'anonymous',
        'subject': _subjectController.text.trim(),
        'question': _questionController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (mounted) {
        _subjectController.clear();
        _questionController.clear();
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your message has been sent to admin@nexmeet.world! We will get back to you soon.',
              style: TextStyle(fontFamily: 'PlusJakartaSans'),
            ),
            backgroundColor: Color(0xFF2E7D32),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to send message. Please email $_contactEmail directly.',
              style: const TextStyle(fontFamily: 'PlusJakartaSans'),
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.help_outline_rounded, color: Color(0xFF7A432D), size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Help & Support',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E1F11),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF8C736B)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8E2DD)),

          // Scrollable Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Contact Info Cards Header
                const Text(
                  'Get in Touch',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E1F11),
                  ),
                ),
                const SizedBox(height: 12),

                // Email & Phone Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildContactCard(
                        icon: Icons.email_outlined,
                        title: 'Email Us',
                        value: _contactEmail,
                        onTap: _launchEmail,
                        onCopy: () => _copyToClipboard(_contactEmail, 'Email copied to clipboard'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildContactCard(
                        icon: Icons.phone_outlined,
                        title: 'Call Support',
                        value: '+91 $_contactPhone',
                        onTap: _launchPhone,
                        onCopy: () => _copyToClipboard(_contactPhone, 'Phone number copied to clipboard'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // FAQ Section
                const Text(
                  'Frequently Asked Questions (FAQ)',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E1F11),
                  ),
                ),
                const SizedBox(height: 12),

                ..._faqs.map((faq) => _buildFaqTile(faq['question']!, faq['answer']!)),

                const SizedBox(height: 28),

                // Ask a Question Form Section
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8E2DD)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.question_answer_outlined, color: Color(0xFF7A432D), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Ask a Question / Report an Issue',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3E1F11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Have a custom inquiry or feedback? Send us a message directly.',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            color: Color(0xFF8C736B),
                          ),
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _subjectController,
                          decoration: InputDecoration(
                            labelText: 'Subject',
                            hintText: 'e.g. Account setup or Event question',
                            labelStyle: const TextStyle(fontFamily: 'PlusJakartaSans', color: Color(0xFF8C736B), fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFFFAF7F5),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter a subject';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _questionController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Your Question / Feedback',
                            hintText: 'Type your message here...',
                            labelStyle: const TextStyle(fontFamily: 'PlusJakartaSans', color: Color(0xFF8C736B), fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFFFAF7F5),
                            contentPadding: const EdgeInsets.all(14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter your question';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitQuestion,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7A432D),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.send_rounded, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Submit Question',
                                        style: TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
    required VoidCallback onCopy,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF7A432D).withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7A432D).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF7A432D), size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                color: Color(0xFF8C736B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E1F11),
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: onCopy,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_rounded, size: 12, color: Color(0xFF7A432D)),
                  SizedBox(width: 4),
                  Text(
                    'Copy',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      color: Color(0xFF7A432D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqTile(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E2DD)),
      ),
      child: ExpansionTile(
        shape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        iconColor: const Color(0xFF7A432D),
        collapsedIconColor: const Color(0xFF8C736B),
        title: Text(
          question,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF3E1F11),
          ),
        ),
        children: [
          Text(
            answer,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              color: Color(0xFF5D4037),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
