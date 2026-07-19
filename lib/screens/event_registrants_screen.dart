import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/event.dart';
import '../models/event_registration.dart';
import '../services/event_registration_service.dart';
import 'candidate_profile_sheet.dart';
import 'event_qr_scanner_screen.dart';

/// Host view: list of people who registered, with detail sheet.
class EventRegistrantsScreen extends StatelessWidget {
  final Event event;

  const EventRegistrantsScreen({super.key, required this.event});

  void _showRegistrantDetails(
    BuildContext context,
    EventRegistration reg,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFAF7F5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFF7A432D),
                    child: Text(
                      reg.fullName.isNotEmpty
                          ? reg.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reg.fullName,
                          style: const TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3E1F11),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          reg.statusLabel,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: reg.isCheckedIn
                                ? const Color(0xFF2E7D32)
                                : reg.isQrInvalid
                                    ? const Color(0xFFC62828)
                                    : const Color(0xFF7A432D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE8E2DD)),
              _DetailRow(icon: Icons.email_outlined, label: 'Email', value: reg.email),
              _DetailRow(icon: Icons.phone_outlined, label: 'Phone', value: reg.phone),
              if (reg.company != null && reg.company!.isNotEmpty)
                _DetailRow(
                  icon: Icons.business_outlined,
                  label: 'Company',
                  value: reg.company!,
                ),
              if (reg.role != null && reg.role!.isNotEmpty)
                _DetailRow(
                  icon: Icons.work_outline,
                  label: 'Role',
                  value: reg.role!,
                ),
              if (reg.notes != null && reg.notes!.isNotEmpty)
                _DetailRow(
                  icon: Icons.notes_outlined,
                  label: 'Notes',
                  value: reg.notes!,
                ),
              _DetailRow(
                icon: Icons.confirmation_number_outlined,
                label: 'Ticket ID',
                value: reg.ticketId,
              ),
              _DetailRow(
                icon: Icons.schedule,
                label: 'Registered',
                value:
                    '${reg.registeredAt.day}/${reg.registeredAt.month}/${reg.registeredAt.year} ${reg.registeredAt.hour.toString().padLeft(2, '0')}:${reg.registeredAt.minute.toString().padLeft(2, '0')}',
              ),
              if (reg.checkedInAt != null)
                _DetailRow(
                  icon: Icons.verified_outlined,
                  label: 'Checked in',
                  value:
                      '${reg.checkedInAt!.day}/${reg.checkedInAt!.month}/${reg.checkedInAt!.year} ${reg.checkedInAt!.hour.toString().padLeft(2, '0')}:${reg.checkedInAt!.minute.toString().padLeft(2, '0')}',
                ),
              if (reg.userId.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF7A432D)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final currentUid = FirebaseAuth.instance.currentUser?.uid;
                      if (currentUid != null && context.mounted) {
                        final sheetContext = context;
                        showModalBottomSheet(
                          context: sheetContext,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => CandidateProfileSheet.lazy(
                            targetUid: reg.userId,
                            currentUid: currentUid,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.person_outline, color: Color(0xFF7A432D), size: 18),
                    label: const Text(
                      'View Full Professional Profile',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7A432D),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF3E1F11)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Registrants',
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E1F11),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Scan QR',
            icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF3E1F11)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventQrScannerScreen(event: event),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF7A432D),
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text(
          'Scan QR',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventQrScannerScreen(event: event),
            ),
          );
        },
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3E1F11),
                  ),
                ),
                Text(
                  '${event.day} ${event.month} · ${event.location}',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    color: Color(0xFF8C736B),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<EventRegistration>>(
              stream:
                  EventRegistrationService().streamEventRegistrations(event.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF7A432D)),
                  );
                }

                final list = snapshot.data ?? [];
                if (list.isEmpty) {
                  return const Center(
                    child: Text(
                      'No one has registered yet.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        color: Color(0xFF8C736B),
                      ),
                    ),
                  );
                }

                final checkedIn =
                    list.where((r) => r.isCheckedIn).length;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          _StatChip(
                            label: 'Total',
                            value: '${list.length}',
                            color: const Color(0xFF7A432D),
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            label: 'Checked in',
                            value: '$checkedIn',
                            color: const Color(0xFF2E7D32),
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            label: 'Pending',
                            value: '${list.length - checkedIn}',
                            color: const Color(0xFFE65100),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final reg = list[index];
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _showRegistrantDetails(context, reg),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFE8E2DD),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: const Color(0xFFE8E2DD),
                                      child: Text(
                                        reg.fullName.isNotEmpty
                                            ? reg.fullName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Color(0xFF3E1F11),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            reg.fullName,
                                            style: const TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF3E1F11),
                                            ),
                                          ),
                                          Text(
                                            [
                                              if (reg.company != null &&
                                                  reg.company!.isNotEmpty)
                                                reg.company!,
                                              if (reg.role != null &&
                                                  reg.role!.isNotEmpty)
                                                reg.role!,
                                            ].join(' · ').isEmpty
                                                ? reg.email
                                                : [
                                                    if (reg.company != null &&
                                                        reg.company!.isNotEmpty)
                                                      reg.company!,
                                                    if (reg.role != null &&
                                                        reg.role!.isNotEmpty)
                                                      reg.role!,
                                                  ].join(' · '),
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
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Icon(
                                          reg.isCheckedIn
                                              ? Icons.verified
                                              : Icons.chevron_right,
                                          color: reg.isCheckedIn
                                              ? const Color(0xFF2E7D32)
                                              : const Color(0xFFB0A8A2),
                                          size: 20,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          reg.statusLabel,
                                          style: TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: reg.isCheckedIn
                                                ? const Color(0xFF2E7D32)
                                                : const Color(0xFF8C736B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF7A432D)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: Color(0xFF8C736B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    color: Color(0xFF3E1F11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 10,
                color: color.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
