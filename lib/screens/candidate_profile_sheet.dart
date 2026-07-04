import 'package:flutter/material.dart';
import '../models/candidate.dart';
import '../utils/image_helper.dart';
import '../utils/candidate_helper.dart';

class CandidateProfileSheet extends StatefulWidget {
  final Candidate? candidate;
  final String? targetUid;
  final String? currentUid;

  const CandidateProfileSheet({
    super.key,
    required this.candidate,
  })  : targetUid = null,
        currentUid = null;

  const CandidateProfileSheet.lazy({
    super.key,
    required this.targetUid,
    required this.currentUid,
  })  : candidate = null;

  @override
  State<CandidateProfileSheet> createState() => _CandidateProfileSheetState();
}

class _CandidateProfileSheetState extends State<CandidateProfileSheet> {
  Future<Candidate>? _lazyCandidateFuture;

  @override
  void initState() {
    super.initState();
    if (widget.candidate == null && widget.targetUid != null && widget.currentUid != null) {
      _lazyCandidateFuture = CandidateHelper.fetchCandidate(widget.targetUid!, widget.currentUid!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.candidate != null) {
      return _buildProfileContent(widget.candidate!);
    }

    return FutureBuilder<Candidate>(
      future: _lazyCandidateFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Color(0xFFFAF7F5),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF7A432D),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading profile details...',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      color: Color(0xFF8C736B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.4,
            decoration: const BoxDecoration(
              color: Color(0xFFFAF7F5),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load profile',
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E1F11),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else if (snapshot.hasData) {
          return _buildProfileContent(snapshot.data!);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildProfileContent(Candidate c) {
    final interestsList = <Widget>[];
    for (final interest in c.interests) {
      String priority = 'Medium';
      if (c.interestsWithPriority.isNotEmpty) {
        final match = c.interestsWithPriority.firstWhere(
          (e) => e['name'].toString().toLowerCase().trim() == interest.toLowerCase().trim(),
          orElse: () => <String, dynamic>{},
        );
        if (match.isNotEmpty) {
          priority = match['priority']?.toString() ?? 'Medium';
        }
      }
      interestsList.add(_buildInterestChipWithPriority(interest, priority));
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.96,
      snap: true,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFAF7F5),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: Column(
            children: [
              // Scroll Handle Indicator
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0D4CB),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Large profile photo
                    Center(
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7A432D).withAlpha((0.15 * 255).round()),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: buildProfileImage(
                            c.profileImageUrl ?? '',
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                            fallback: Container(
                              color: const Color(0xFF7A432D),
                              child: Center(
                                child: Text(
                                  c.initials,
                                  style: const TextStyle(
                                    fontFamily: 'PlayfairDisplay',
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name
                    Center(
                      child: Text(
                        c.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Badges Row
                    if (c.badges.isNotEmpty) ...[
                      Center(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: c.badges.map((badge) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32).withAlpha((0.08 * 255).round()),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF2E7D32).withAlpha((0.2 * 255).round()),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.stars, size: 13, color: Color(0xFF2E7D32)),
                                  const SizedBox(width: 4),
                                  Text(
                                    badge,
                                    style: const TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Occupation and Match overlay row
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0052FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              c.org.isNotEmpty ? c.org : 'Independent',
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            c.role,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8C736B),
                            ),
                          ),
                          if (c.experience.isNotEmpty) ...[
                            const Text('•', style: TextStyle(color: Color(0xFFE0D4CB))),
                            Text(
                              '${c.experience} yrs exp',
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8C736B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section Dividers / Grid of Quick Stats
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickStatCard(
                            Icons.place_outlined,
                            'Location',
                            c.loc.isNotEmpty ? c.loc.split(',').first.trim() : 'Remote',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickStatCard(
                            Icons.translate,
                            'Languages',
                            'English, Hindi',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickStatCard(
                            Icons.verified_user_outlined,
                            'Mentoring',
                            '${c.completedMentoringSessions} sessions',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickStatCard(
                            Icons.thumb_up_alt_outlined,
                            'Endorsements',
                            '${c.expertiseWithLevel.fold<int>(0, (total, item) => total + (item['endorsements'] as int? ?? 0))} endorsements',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Bio / About Card
                    if (c.bio.isNotEmpty) ...[
                      _buildDetailSectionHeader('About'),
                      const SizedBox(height: 8),
                      _buildDetailCard(
                        child: Text(
                          c.bio,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13.5,
                            color: Color(0xFF3E1F11),
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Match justification (Explainable matching)
                    if (c.matchReasons.isNotEmpty) ...[
                      _buildDetailSectionHeader('Why You Matched'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF90CAF9)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1565C0),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${c.match}% Match Rating',
                                    style: const TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...c.matchReasons.map((reason) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ', style: TextStyle(color: Color(0xFF1565C0), fontSize: 14, fontWeight: FontWeight.bold)),
                                    Expanded(
                                      child: Text(
                                        reason,
                                        style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 13.5,
                                          color: Color(0xFF0D47A1),
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Expertise (What I can share)
                    if (c.skills.isNotEmpty || c.tags.isNotEmpty) ...[
                      _buildDetailSectionHeader('Expertise (What I can share)'),
                      const SizedBox(height: 8),
                      _buildDetailCard(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (c.skills.isNotEmpty ? c.skills : c.tags)
                              .map((exp) {
                                String level = 'Intermediate';
                                if (c.expertiseWithLevel.isNotEmpty) {
                                  final match = c.expertiseWithLevel.firstWhere(
                                    (e) => e['name'].toString().toLowerCase().trim() == exp.toLowerCase().trim(),
                                    orElse: () => <String, dynamic>{},
                                  );
                                  if (match.isNotEmpty) {
                                    level = match['level']?.toString() ?? 'Intermediate';
                                  }
                                }
                                return _buildExpertiseChipWithLevel(exp, level);
                              })
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Interests (What I want to learn)
                    if (interestsList.isNotEmpty) ...[
                      _buildDetailSectionHeader('Interests (What I want to learn)'),
                      const SizedBox(height: 8),
                      _buildDetailCard(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: interestsList,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Suggested starters
                    if (c.conversationStarters.isNotEmpty) ...[
                      _buildDetailSectionHeader('Suggested Icebreakers'),
                      const SizedBox(height: 8),
                      ...c.conversationStarters.map((starter) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF1EC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF7A432D).withAlpha((0.15 * 255).round()),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xFF7A432D)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  starter,
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 13,
                                    color: Color(0xFF5C473E),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInterestChipWithPriority(String interest, String priority) {
    final style = _getInterestStyle(interest);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            style.icon,
            size: 13,
            color: style.foregroundColor,
          ),
          const SizedBox(width: 4),
          Text(
            interest,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: style.foregroundColor,
            ),
          ),
        ],
      ),
    );
  }

  _InterestStyle _getInterestStyle(String interest) {
    final key = interest.toLowerCase().trim();
    if (key.contains('stock market') || key.contains('stock') || key.contains('trading')) {
      return const _InterestStyle(Icons.show_chart, Color(0xFFE8F5E9), Color(0xFF2E7D32));
    } else if (key.contains('artificial intelligence') || key.contains('ai') || key.contains('ml') || key.contains('machine learning')) {
      return const _InterestStyle(Icons.psychology, Color(0xFFE0F7FA), Color(0xFF00838F));
    } else if (key.contains('startup') || key.contains('founder') || key.contains('entrepreneur')) {
      return const _InterestStyle(Icons.rocket_launch, Color(0xFFFFF3E0), Color(0xFFD84315));
    } else if (key.contains('invest')) {
      return const _InterestStyle(Icons.monetization_on_outlined, Color(0xFFE8F5E9), Color(0xFF2E7D32));
    } else if (key.contains('public speaking') || key.contains('speak') || key.contains('talk')) {
      return const _InterestStyle(Icons.record_voice_over, Color(0xFFF8E8F8), Color(0xFF8E24AA));
    } else if (key.contains('fit') || key.contains('gym') || key.contains('coach') || key.contains('health') || key.contains('workout')) {
      return const _InterestStyle(Icons.fitness_center_rounded, Color(0xFFE3F2FD), Color(0xFF1565C0));
    } else if (key.contains('personal finance') || key.contains('finance') || key.contains('money') || key.contains('wallet')) {
      return const _InterestStyle(Icons.account_balance_wallet_outlined, Color(0xFFFFF9E6), Color(0xFFB7791F));
    } else if (key.contains('design') || key.contains('ui') || key.contains('ux') || key.contains('art')) {
      return const _InterestStyle(Icons.palette_outlined, Color(0xFFFFF3E0), Color(0xFFEF6C00));
    } else if (key.contains('content') || key.contains('create') || key.contains('photo') || key.contains('video') || key.contains('camera')) {
      return const _InterestStyle(Icons.video_call, Color(0xFFFFEBF0), Color(0xFFD81B60));
    }
    // Terracotta theme fallback matching app primary brand style
    return const _InterestStyle(
      Icons.label_outline_rounded,
      Color(0xFFFAF1EC),
      Color(0xFF7A432D),
    );
  }

  Widget _buildExpertiseChipWithLevel(String exp, String level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF1EC), // light terracotta
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF7A432D).withAlpha((0.2 * 255).round()),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_outlined,
            size: 13,
            color: Color(0xFF7A432D),
          ),
          const SizedBox(width: 4),
          Text(
            exp,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7A432D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        color: Color(0xFF8C736B),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDetailCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E2DD)),
      ),
      child: child,
    );
  }

  Widget _buildQuickStatCard(IconData icon, String label, String val) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E2DD)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF7A432D)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8C736B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  val,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E1F11),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InterestStyle {
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  const _InterestStyle(this.icon, this.backgroundColor, this.foregroundColor);
}
