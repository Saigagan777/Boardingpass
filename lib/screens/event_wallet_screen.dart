import 'package:flutter/material.dart';

import '../models/event_registration.dart';
import '../services/event_registration_service.dart';
import 'event_pass_screen.dart';

/// In-app wallet of saved event passes.
class EventWalletScreen extends StatelessWidget {
  const EventWalletScreen({super.key});

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
          'My Pass Wallet',
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E1F11),
          ),
        ),
      ),
      body: StreamBuilder<List<EventRegistration>>(
        stream: EventRegistrationService().streamMyWalletPasses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF7A432D)),
            );
          }

          final passes = snapshot.data ?? [];
          if (passes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 56,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No passes saved yet',
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E1F11),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Register for an event, open your pass, and tap the wallet icon to save it here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        color: Color(0xFF8C736B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: passes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final reg = passes[index];
              final invalid = reg.isQrInvalid;
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventPassScreen(registration: reg),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE8E2DD)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: invalid
                                ? const Color(0xFFF5F5F5)
                                : const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            invalid
                                ? Icons.confirmation_number_outlined
                                : Icons.confirmation_number,
                            color: invalid
                                ? const Color(0xFF9E9E9E)
                                : const Color(0xFF7A432D),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reg.eventTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: invalid
                                      ? const Color(0xFF9E9E9E)
                                      : const Color(0xFF3E1F11),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${reg.eventDay} ${reg.eventMonth} · ${reg.ticketId}',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  color: Color(0xFF8C736B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: invalid
                                ? const Color(0xFFFFEBEE)
                                : const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            reg.statusLabel,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: invalid
                                  ? const Color(0xFFC62828)
                                  : const Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
