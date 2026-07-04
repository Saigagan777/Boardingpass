import 'package:flutter/material.dart';
import '../models/candidate.dart';
import '../utils/candidate_helper.dart';
import '../utils/image_helper.dart';

class CandidateProfileSheet extends StatefulWidget {
  final Candidate? candidate;
  final String? targetUid;
  final String? currentUid;

  const CandidateProfileSheet({super.key, required this.candidate})
    : targetUid = null,
      currentUid = null;

  const CandidateProfileSheet.lazy({
    super.key,
    required this.targetUid,
    required this.currentUid,
  }) : candidate = null;

  @override
  State<CandidateProfileSheet> createState() => _CandidateProfileSheetState();
}

class _CandidateProfileSheetState extends State<CandidateProfileSheet> {
  Future<Candidate>? _lazyCandidateFuture;

  @override
  void initState() {
    super.initState();
    if (widget.candidate == null &&
        widget.targetUid != null &&
        widget.currentUid != null) {
      _lazyCandidateFuture = CandidateHelper.fetchCandidate(
        widget.targetUid!,
        widget.currentUid!,
      );
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
          return _buildLoadingState(context);
        }
        if (snapshot.hasError) {
          return _buildErrorState(context, snapshot.error.toString());
        }
        if (snapshot.hasData) {
          return _buildProfileContent(snapshot.data!);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLoadingState(BuildContext context) {
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
            CircularProgressIndicator(color: Color(0xFF7A432D)),
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
  }

  Widget _buildErrorState(BuildContext context, String message) {
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 48,
              ),
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
                message,
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
  }

  List<String> _profileExpertise(Candidate c) {
    final seen = <String>{};
    final values = <String>[];
    for (final item in [...c.skills, ...c.tags]) {
      final trimmed = item.trim();
      final key = trimmed.toLowerCase();
      if (trimmed.isNotEmpty && seen.add(key)) {
        values.add(trimmed);
      }
    }
    return values;
  }

  Widget _buildProfileContent(Candidate c) {
    final expertise = _profileExpertise(c);
    final interests = c.interests
        .map((interest) => interest.trim())
        .where((interest) => interest.isNotEmpty)
        .toList();
    final careerEntries = _timelineEntries(c.careerTimeline, const [
      'role',
      'company',
      'employmentType',
      'location',
      'startDate',
      'endDate',
      'duration',
      'description',
    ]);
    final educationEntries = _timelineEntries(c.educationTimeline, const [
      'degree',
      'school',
      'startDate',
      'endDate',
      'duration',
      'description',
    ]);
    final experienceSummary = c.experience.trim();

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
                    Center(
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF7A432D,
                              ).withAlpha((0.15 * 255).round()),
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
                    const SizedBox(height: 12),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (c.role.trim().isNotEmpty)
                            _buildProfilePill(
                              Icons.work_outline_rounded,
                              c.role.trim(),
                            ),
                          if (c.org.trim().isNotEmpty)
                            _buildProfilePill(
                              Icons.business_outlined,
                              c.org.trim(),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (c.bio.trim().isNotEmpty) ...[
                      _buildDetailSectionHeader('Short Bio'),
                      const SizedBox(height: 8),
                      _buildDetailCard(
                        child: Text(
                          c.bio.trim(),
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
                    if (careerEntries.isNotEmpty ||
                        experienceSummary.isNotEmpty) ...[
                      _buildDetailSectionHeader('Work Experience'),
                      const SizedBox(height: 8),
                      _buildDetailCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (experienceSummary.isNotEmpty)
                              _buildTimelineEntry(
                                icon: Icons.timeline_rounded,
                                title: 'Experience',
                                meta: [experienceSummary],
                              ),
                            if (experienceSummary.isNotEmpty &&
                                careerEntries.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(
                                  height: 1,
                                  color: Color(0xFFE8E2DD),
                                ),
                              ),
                            for (var i = 0; i < careerEntries.length; i++) ...[
                              _buildCareerTimelineEntry(careerEntries[i]),
                              if (i != careerEntries.length - 1)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(
                                    height: 1,
                                    color: Color(0xFFE8E2DD),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (educationEntries.isNotEmpty) ...[
                      _buildDetailSectionHeader('Education'),
                      const SizedBox(height: 8),
                      _buildDetailCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (
                              var i = 0;
                              i < educationEntries.length;
                              i++
                            ) ...[
                              _buildEducationTimelineEntry(educationEntries[i]),
                              if (i != educationEntries.length - 1)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(
                                    height: 1,
                                    color: Color(0xFFE8E2DD),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (expertise.isNotEmpty) ...[
                      _buildDetailSectionHeader('Expertise'),
                      const SizedBox(height: 8),
                      _buildDetailCard(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: expertise
                              .map(_buildExpertiseChipWithLevel)
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (interests.isNotEmpty) ...[
                      _buildDetailSectionHeader('Interests'),
                      const SizedBox(height: 8),
                      _buildDetailCard(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: interests
                              .map(_buildInterestChipWithPriority)
                              .toList(),
                        ),
                      ),
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

  List<Map<String, dynamic>> _timelineEntries(
    List<Map<String, dynamic>> entries,
    List<String> keys,
  ) {
    return entries
        .where(
          (entry) => keys.any((key) => _timelineValue(entry, key).isNotEmpty),
        )
        .toList();
  }

  String _timelineValue(Map<String, dynamic> entry, String key) {
    return (entry[key] ?? '').toString().trim();
  }

  String _joinTimelineTitle(
    String primary,
    String secondary, {
    required String fallback,
  }) {
    if (primary.isNotEmpty && secondary.isNotEmpty) {
      return '$primary at $secondary';
    }
    if (primary.isNotEmpty) return primary;
    if (secondary.isNotEmpty) return secondary;
    return fallback;
  }

  String _timelineDateRange(Map<String, dynamic> entry) {
    final duration = _timelineValue(entry, 'duration');
    if (duration.isNotEmpty && duration.toLowerCase() != 'to') {
      return duration;
    }

    final startDate = _timelineValue(entry, 'startDate');
    final endDate = _timelineValue(entry, 'endDate');
    if (startDate.isNotEmpty && endDate.isNotEmpty) {
      return '$startDate to $endDate';
    }
    if (startDate.isNotEmpty) return '$startDate to Present';
    if (endDate.isNotEmpty) return endDate;
    return '';
  }

  Widget _buildCareerTimelineEntry(Map<String, dynamic> entry) {
    final role = _timelineValue(entry, 'role');
    final company = _timelineValue(entry, 'company');
    final employmentType = _timelineValue(entry, 'employmentType');
    final location = _timelineValue(entry, 'location');
    final description = _timelineValue(entry, 'description');

    return _buildTimelineEntry(
      icon: Icons.work_outline_rounded,
      title: _joinTimelineTitle(role, company, fallback: 'Work experience'),
      meta: [_timelineDateRange(entry), employmentType, location],
      description: description,
    );
  }

  Widget _buildEducationTimelineEntry(Map<String, dynamic> entry) {
    final degree = _timelineValue(entry, 'degree');
    final school = _timelineValue(entry, 'school');
    final description = _timelineValue(entry, 'description');

    return _buildTimelineEntry(
      icon: Icons.school_outlined,
      title: _joinTimelineTitle(degree, school, fallback: 'Education'),
      meta: [_timelineDateRange(entry)],
      description: description,
    );
  }

  Widget _buildTimelineEntry({
    required IconData icon,
    required String title,
    List<String> meta = const [],
    String description = '',
  }) {
    final cleanMeta = meta
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFFAF1EC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF7A432D)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3E1F11),
                  height: 1.25,
                ),
              ),
              if (cleanMeta.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  cleanMeta.join(' | '),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8C736B),
                    height: 1.35,
                  ),
                ),
              ],
              if (description.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  description.trim(),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    color: Color(0xFF5C473E),
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE8E2DD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF7A432D)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5C473E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestChipWithPriority(String interest) {
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
          Icon(style.icon, size: 13, color: style.foregroundColor),
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
    if (key.contains('stock market') ||
        key.contains('stock') ||
        key.contains('trading')) {
      return const _InterestStyle(
        Icons.show_chart,
        Color(0xFFE8F5E9),
        Color(0xFF2E7D32),
      );
    } else if (key.contains('artificial intelligence') ||
        key.contains('ai') ||
        key.contains('ml') ||
        key.contains('machine learning')) {
      return const _InterestStyle(
        Icons.psychology,
        Color(0xFFE0F7FA),
        Color(0xFF00838F),
      );
    } else if (key.contains('startup') ||
        key.contains('founder') ||
        key.contains('entrepreneur')) {
      return const _InterestStyle(
        Icons.rocket_launch,
        Color(0xFFFFF3E0),
        Color(0xFFD84315),
      );
    } else if (key.contains('invest')) {
      return const _InterestStyle(
        Icons.monetization_on_outlined,
        Color(0xFFE8F5E9),
        Color(0xFF2E7D32),
      );
    } else if (key.contains('public speaking') ||
        key.contains('speak') ||
        key.contains('talk')) {
      return const _InterestStyle(
        Icons.record_voice_over,
        Color(0xFFF8E8F8),
        Color(0xFF8E24AA),
      );
    } else if (key.contains('fit') ||
        key.contains('gym') ||
        key.contains('coach') ||
        key.contains('health') ||
        key.contains('workout')) {
      return const _InterestStyle(
        Icons.fitness_center_rounded,
        Color(0xFFE3F2FD),
        Color(0xFF1565C0),
      );
    } else if (key.contains('personal finance') ||
        key.contains('finance') ||
        key.contains('money') ||
        key.contains('wallet')) {
      return const _InterestStyle(
        Icons.account_balance_wallet_outlined,
        Color(0xFFFFF9E6),
        Color(0xFFB7791F),
      );
    } else if (key.contains('design') ||
        key.contains('ui') ||
        key.contains('ux') ||
        key.contains('art')) {
      return const _InterestStyle(
        Icons.palette_outlined,
        Color(0xFFFFF3E0),
        Color(0xFFEF6C00),
      );
    } else if (key.contains('content') ||
        key.contains('create') ||
        key.contains('photo') ||
        key.contains('video') ||
        key.contains('camera')) {
      return const _InterestStyle(
        Icons.video_call,
        Color(0xFFFFEBF0),
        Color(0xFFD81B60),
      );
    }
    return const _InterestStyle(
      Icons.label_outline_rounded,
      Color(0xFFFAF1EC),
      Color(0xFF7A432D),
    );
  }

  Widget _buildExpertiseChipWithLevel(String exp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF1EC),
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
}

class _InterestStyle {
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  const _InterestStyle(this.icon, this.backgroundColor, this.foregroundColor);
}
