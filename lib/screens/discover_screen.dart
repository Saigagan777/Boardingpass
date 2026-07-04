import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state_manager.dart';
import '../models/candidate.dart';
import '../utils/card_renderer.dart';
import '../utils/image_helper.dart';
import '../utils/app_logo.dart';
import '../utils/match_calculator.dart';
import 'candidate_profile_sheet.dart';
enum _SwipeAction { reject, like, favorite }


class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  final AppStateManager _state = AppStateManager();
  static const double _horizontalSwipeThreshold = 120.0;
  static const double _upSwipeThreshold = 100.0;
  static const Duration _swipeExitDuration = Duration(milliseconds: 230);

  // Filter states
  final TextEditingController _searchQuery = TextEditingController();
  String? _selectedIndustry;
  String? _selectedInterest;
  String? _selectedLocation;
  String? _selectedFilterExpertise;
  final TextEditingController _industryController = TextEditingController();
  final List<String> _customIndustries = [];

  final List<String> _industryOptions = [
    'Technology',
    'Finance',
    'Healthcare',
    'Education',
    'Consulting',
    'Real Estate',
    'Automotive',
    'Entertainment',
    'Other',
  ];

  final List<String> _interestOptions = [
    'Stock Market',
    'Artificial Intelligence',
    'Startups',
    'Investing',
    'Public Speaking',
    'Fitness',
    'Personal Finance',
    'Entrepreneurship',
    'Design',
    'Content Creation',
  ];

  final List<String> _expertiseOptions = [
    'React',
    'Flutter',
    'Spring Boot',
    'AI/ML',
    'Data Science',
    'Stock Market',
    'Investing',
    'Leadership',
    'Product Strategy',
    'UI/UX',
    'Marketing',
    'Sales',
    'Public Speaking',
  ];

  // Swiping state variables
  double _dragDx = 0.0;
  double _dragDy = 0.0;
  bool _isAnimating = false;
  bool _isProfileExpanded = false;
  _SwipeAction? _thresholdHapticAction;
  _SwipeAction? _completionAction;
  int _completionEffectToken = 0;

  // Match overlay state
  String? _matchedName;
  bool _showMatchOverlay = false;
  double _connectScale = 1.0;
  Timer? _connectTimer;

  // Local card index to manage swipe animations independently of global index
  int _cardIndex = 0;

  @override
  void initState() {
    super.initState();
    _cardIndex = _state.activeCandidateIndex;
    // Listen for state-manager notifications so we rebuild when
    // loadCandidates() finishes and populates _state.candidates.
    _state.addListener(_onStateChanged);
    _state.loadCandidates();
    _searchQuery.addListener(() {
      if (mounted) {
        setState(() {
          _cardIndex = 0;
        });
      }
    });
  }

  /// Called whenever AppStateManager.notifyListeners() fires (e.g. after
  /// loadCandidates completes). Triggers a rebuild so filteredCandidates
  /// reflects the newly loaded data — identical to what Reset Filters does.
  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    _connectTimer?.cancel();
    _searchQuery.dispose();
    super.dispose();
  }

  List<Candidate> get filteredCandidates {
    final query = _searchQuery.text.trim().toLowerCase();
    return _state.candidates.where((c) {
      // 1. Search Query filter
      if (query.isNotEmpty) {
        final matchesName = c.name.toLowerCase().contains(query);
        final matchesHeadline = c.headline.toLowerCase().contains(query);
        final matchesCompany = c.org.toLowerCase().contains(query);
        final matchesRole = c.role.toLowerCase().contains(query);
        final matchesSkills = c.tags.any(
          (tag) => tag.toLowerCase().contains(query),
        );
        final matchesIntent = c.intent.toLowerCase().contains(query);
        if (!matchesName &&
            !matchesHeadline &&
            !matchesCompany &&
            !matchesRole &&
            !matchesSkills &&
            !matchesIntent) {
          return false;
        }
      }

      // 2. Industry filter
      if (_selectedIndustry != null) {
        if (c.industry != _selectedIndustry) {
          return false;
        }
      }

      // 3. Interest filter
      if (_selectedInterest != null) {
        bool hasMatchingExpertise =
            c.skills.any(
              (s) => doesExpertiseSatisfyInterest(s, _selectedInterest!),
            ) ||
            c.tags.any(
              (t) => doesExpertiseSatisfyInterest(t, _selectedInterest!),
            );
        bool hasSharedInterest = c.interests.any(
          (i) =>
              i.toLowerCase().trim() == _selectedInterest!.toLowerCase().trim(),
        );
        if (!hasMatchingExpertise && !hasSharedInterest) {
          return false;
        }
      }

      // 4. Location filter
      if (_selectedLocation != null) {
        if (!c.loc.toLowerCase().contains(_selectedLocation!.toLowerCase())) {
          return false;
        }
      }

      // 5. Expertise filter
      if (_selectedFilterExpertise != null) {
        bool hasExpertise =
            c.skills.any(
              (s) =>
                  s.toLowerCase().trim() ==
                  _selectedFilterExpertise!.toLowerCase().trim(),
            ) ||
            c.tags.any(
              (t) =>
                  t.toLowerCase().trim() ==
                  _selectedFilterExpertise!.toLowerCase().trim(),
            );
        if (!hasExpertise) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _showCustomCardsDeck(BuildContext context, Candidate c) {
    if (c.customCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${c.name} has not customized their cards yet.'),
          backgroundColor: const Color(0xFF7A432D),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        int currentPage = 0;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: 360,
              decoration: const BoxDecoration(
                color: Color(0xFF3E1F11),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                children: [
                  // Pull Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${c.name}'s Showcase Deck",
                            style: const TextStyle(
                              fontFamily: 'PlayfairDisplay',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE5A475),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Swipe left/right to view cards",
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // PageView Carousel
                  Expanded(
                    child: PageView.builder(
                      itemCount: c.customCards.length,
                      onPageChanged: (int page) {
                        setModalState(() {
                          currentPage = page;
                        });
                      },
                      itemBuilder: (context, idx) {
                        final card = c.customCards[idx];
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: PremiumCustomCard(
                              card: card,
                              width: 320,
                              height: 200,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(c.customCards.length, (idx) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: currentPage == idx ? 12 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: currentPage == idx
                              ? const Color(0xFFE5A475)
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _triggerMatch(String name) {
    setState(() {
      _matchedName = name;
      _showMatchOverlay = true;
      _connectScale = 1.0;
    });

    // Pulse handshake animation
    _connectTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (mounted) {
        setState(() {
          _connectScale = _connectScale == 1.0 ? 1.25 : 1.0;
        });
      }
    });

    // Dismiss overlay and keep the user on Discovery.
    Future.delayed(const Duration(milliseconds: 1600), () {
      _connectTimer?.cancel();
      if (mounted) {
        setState(() {
          _showMatchOverlay = false;
          _matchedName = null;
        });
      }
    });
  }

  void _showConnectionRequestError(Candidate candidate) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          backgroundColor: const Color(0xFF7A2D2D),
          content: Text(
            'Could not send a connection request to ${candidate.name}. Please try again.',
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
  }

  Future<void> _acceptIncomingRequest(String fromUid) async {
    final result = await _state.sendOrAcceptConnection(targetUid: fromUid);
    if (!mounted) return;

    final accepted = result == ConnectionRequestResult.accepted;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: accepted
              ? const Color(0xFF2E7D32)
              : const Color(0xFF7A2D2D),
          content: Text(
            accepted
                ? 'Connection accepted. You can now chat.'
                : 'Could not accept this request. Please try again.',
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
  }

  Future<void> _rejectIncomingRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('connection_requests')
          .doc(requestId)
          .update({
            'status': 'rejected',
            'updatedAt': FieldValue.serverTimestamp(),
            'respondedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF7A432D),
            content: Text(
              'Connection request rejected.',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF7A2D2D),
            content: Text(
              'Could not reject request: $e',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
    }
  }

  Widget _buildIncomingRequestCard(
    QueryDocumentSnapshot<Map<String, dynamic>> requestDoc,
  ) {
    final request = requestDoc.data();
    final fromUid = request['fromUid'] as String? ?? '';
    if (fromUid.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(fromUid).get(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data();
        final name = (userData?['name'] as String?)?.trim().isNotEmpty == true
            ? userData!['name'] as String
            : 'Someone';
        final headline =
            (userData?['headline'] ??
                    userData?['role'] ??
                    userData?['company'] ??
                    'Wants to connect')
                .toString();
        final imageUrl = (userData?['profileImageUrl'] ?? '').toString();
        final initials = name
            .trim()
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join();

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8E2DD)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFE8E2DD),
                backgroundImage: imageUrl.isNotEmpty
                    ? NetworkImage(imageUrl)
                    : null,
                child: imageUrl.isEmpty
                    ? Text(
                        initials.isNotEmpty ? initials : '?',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF7A432D),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3E1F11),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      headline,
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
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Reject',
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF7EAEA),
                  foregroundColor: const Color(0xFFC62828),
                ),
                onPressed: () => _rejectIncomingRequest(requestDoc.id),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Accept',
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFEAF4EC),
                  foregroundColor: const Color(0xFF2E7D32),
                ),
                onPressed: () => _acceptIncomingRequest(fromUid),
                icon: const Icon(Icons.check_rounded, size: 18),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIncomingRequestsPanel() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('connection_requests')
          .where('toUid', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        final requests = snapshot.data?.docs ?? [];
        if (requests.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.mark_email_unread_outlined,
                    color: Color(0xFF7A432D),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${requests.length} connection request${requests.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF3E1F11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...requests.take(3).map(_buildIncomingRequestCard),
            ],
          ),
        );
      },
    );
  }

  double _clampedProgress(double value) {
    return value.clamp(0.0, 1.0).toDouble();
  }

  double _progressForAction(_SwipeAction action) {
    switch (action) {
      case _SwipeAction.reject:
        return _clampedProgress(-_dragDx / (_horizontalSwipeThreshold * 1.35));
      case _SwipeAction.like:
        return _clampedProgress(_dragDx / (_horizontalSwipeThreshold * 1.35));
      case _SwipeAction.favorite:
        return _clampedProgress(-_dragDy / (_upSwipeThreshold * 1.45));
    }
  }

  _SwipeAction? _activeOverlayAction() {
    final rejectProgress = _progressForAction(_SwipeAction.reject);
    final likeProgress = _progressForAction(_SwipeAction.like);
    final favoriteProgress = _progressForAction(_SwipeAction.favorite);
    final horizontalProgress = rejectProgress > likeProgress
        ? rejectProgress
        : likeProgress;

    if (horizontalProgress < 0.04 && favoriteProgress < 0.04) {
      return null;
    }

    if (likeProgress > 0.04 && likeProgress >= favoriteProgress * 0.72) {
      return _SwipeAction.like;
    }

    if (rejectProgress > 0.04 && rejectProgress >= favoriteProgress * 0.72) {
      return _SwipeAction.reject;
    }

    if (favoriteProgress > 0.04) {
      return _SwipeAction.favorite;
    }

    return _dragDx >= 0 ? _SwipeAction.like : _SwipeAction.reject;
  }

  _SwipeAction? _releaseAction() {
    if (_dragDx > _horizontalSwipeThreshold) return _SwipeAction.like;
    if (_dragDx < -_horizontalSwipeThreshold) return _SwipeAction.reject;
    if (_dragDy < -_upSwipeThreshold) return _SwipeAction.favorite;
    return null;
  }

  double get _cardRotationAngle {
    return (_dragDx / 400 * 0.18).clamp(-0.22, 0.22).toDouble();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_isAnimating) return;
    setState(() {
      _dragDx += details.delta.dx;
      _dragDy += details.delta.dy;
    });
    _triggerThresholdHaptic(_releaseAction());
  }

  void _handlePanEnd(List<Candidate> filteredList) {
    if (_isAnimating) return;
    final action = _releaseAction();
    switch (action) {
      case _SwipeAction.reject:
        _swipeLeft(filteredList);
        break;
      case _SwipeAction.like:
        _swipeRight(filteredList);
        break;
      case _SwipeAction.favorite:
        _swipeUp(filteredList);
        break;
      case null:
        setState(() {
          _dragDx = 0;
          _dragDy = 0;
          _thresholdHapticAction = null;
        });
        break;
    }
  }

  void _triggerThresholdHaptic(_SwipeAction? action) {
    if (action == null) {
      _thresholdHapticAction = null;
      return;
    }
    if (_thresholdHapticAction == action) return;
    _thresholdHapticAction = action;
    if (action == _SwipeAction.favorite) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void _triggerConfirmedHaptic(_SwipeAction action) {
    if (action == _SwipeAction.favorite) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void _showSwipeCompletionEffect(_SwipeAction action) {
    final token = ++_completionEffectToken;
    setState(() {
      _completionAction = action;
    });
    Future.delayed(const Duration(milliseconds: 420), () {
      if (!mounted || token != _completionEffectToken) return;
      setState(() {
        _completionAction = null;
      });
    });
  }

  Color _swipeActionColor(_SwipeAction action) {
    switch (action) {
      case _SwipeAction.reject:
        return const Color(0xFFC62828);
      case _SwipeAction.like:
        return const Color(0xFF2E7D32);
      case _SwipeAction.favorite:
        return const Color(0xFFE5A475);
    }
  }

  Color _swipeActionBackground(_SwipeAction action) {
    switch (action) {
      case _SwipeAction.reject:
        return const Color(0xFF3B1414);
      case _SwipeAction.like:
        return const Color(0xFF103B28);
      case _SwipeAction.favorite:
        return const Color(0xFF3E1F11);
    }
  }

  IconData _swipeActionIcon(_SwipeAction action) {
    switch (action) {
      case _SwipeAction.reject:
        return Icons.close_rounded;
      case _SwipeAction.like:
        return Icons.favorite_rounded;
      case _SwipeAction.favorite:
        return Icons.star_rounded;
    }
  }

  String _swipeConfirmationTitle(_SwipeAction action) {
    switch (action) {
      case _SwipeAction.reject:
        return 'Rejected';
      case _SwipeAction.like:
        return 'Liked';
      case _SwipeAction.favorite:
        return 'Added to Favorites';
    }
  }

  void _showSwipeConfirmation(
    _SwipeAction action,
    Candidate candidate, {
    ConnectionRequestResult? connectionResult,
  }) {
    final accent = _swipeActionColor(action);
    final background = _swipeActionBackground(action);
    final name = candidate.name.trim().isEmpty
        ? 'this profile'
        : candidate.name.trim();
    String detail;

    switch (action) {
      case _SwipeAction.reject:
        detail = '$name moved out of your discovery stack.';
        break;
      case _SwipeAction.like:
        switch (connectionResult) {
          case ConnectionRequestResult.accepted:
            detail = 'You and $name are now connected.';
            break;
          case ConnectionRequestResult.alreadyPending:
            detail = 'Your connection request to $name is already pending.';
            break;
          case ConnectionRequestResult.sent:
          case null:
            detail = 'Connection request sent to $name.';
            break;
          case ConnectionRequestResult.failed:
            detail = 'Could not like $name. Please try again.';
            break;
        }
        break;
      case _SwipeAction.favorite:
        detail = 'You can view $name later in Favorites.';
        break;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          duration: const Duration(milliseconds: 1500),
          backgroundColor: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: accent.withValues(alpha: 0.8), width: 0.9),
          ),
          content: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(_swipeActionIcon(action), color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _swipeConfirmationTitle(action),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        color: Color(0xFFFAF1EC),
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

  Widget _buildSwipeActionOverlay() {
    final action = _activeOverlayAction();
    if (action == null) return const SizedBox.shrink();

    final progress = _progressForAction(action);
    final accent = _swipeActionColor(action);
    final isFavorite = action == _SwipeAction.favorite;
    final alignment = switch (action) {
      _SwipeAction.reject => Alignment.topLeft,
      _SwipeAction.like => Alignment.topRight,
      _SwipeAction.favorite => Alignment.topCenter,
    };
    final rotation = switch (action) {
      _SwipeAction.reject => -0.14 * progress,
      _SwipeAction.like => 0.14 * progress,
      _SwipeAction.favorite => 0.0,
    };
    final scale = isFavorite
        ? 0.88 + (progress * 0.28)
        : action == _SwipeAction.like
        ? 0.9 + (progress * 0.32)
        : 0.92 + (progress * 0.22);
    final iconSize = isFavorite ? 62 + (progress * 38) : 58 + (progress * 34);

    return Positioned.fill(
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 34, 22, 0),
          child: Align(
            alignment: alignment,
            child: Transform.translate(
              offset: Offset(
                0,
                isFavorite ? -28 * progress : 8 * (1 - progress),
              ),
              child: Transform.rotate(
                angle: rotation,
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: (0.12 + progress * 0.88).clamp(0.0, 1.0),
                    child: Icon(
                      _swipeActionIcon(action),
                      size: iconSize,
                      color: accent,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(
                            alpha: 0.28 + (progress * 0.14),
                          ),
                          blurRadius: 10 + (progress * 8),
                        ),
                        Shadow(
                          color: accent.withValues(
                            alpha: isFavorite
                                ? 0.52 * progress
                                : 0.34 * progress,
                          ),
                          blurRadius: isFavorite
                              ? 28 * progress
                              : 18 * progress,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeCompletionEffects() {
    final action = _completionAction;
    final accent = action == null
        ? Colors.transparent
        : _swipeActionColor(action);

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            AnimatedOpacity(
              opacity: action == null
                  ? 0
                  : action == _SwipeAction.reject
                  ? 0.08
                  : 0.055,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              child: Container(color: accent),
            ),
            if (action != null)
              Center(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('${action.name}-$_completionEffectToken'),
                  tween: Tween<double>(begin: 0.65, end: 1.18),
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: (1.6 - value).clamp(0.0, 1.0),
                      child: Transform.scale(scale: value, child: child),
                    );
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        _swipeActionIcon(action),
                        color: accent,
                        size: action == _SwipeAction.favorite ? 88 : 78,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 16,
                          ),
                          Shadow(
                            color: accent.withValues(
                              alpha: action == _SwipeAction.favorite
                                  ? 0.58
                                  : 0.42,
                            ),
                            blurRadius: action == _SwipeAction.favorite
                                ? 34
                                : 24,
                          ),
                        ],
                      ),
                      if (action == _SwipeAction.favorite) ...[
                        const Positioned(
                          top: -10,
                          right: -8,
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: Color(0xFFE5A475),
                            size: 18,
                          ),
                        ),
                        const Positioned(
                          left: -12,
                          bottom: 2,
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: Color(0xFFFFD37A),
                            size: 14,
                          ),
                        ),
                        const Positioned(
                          top: 18,
                          left: -24,
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: Color(0xFFE5A475),
                            size: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _swipeLeft(List<Candidate> filteredList) async {
    if (_isAnimating || filteredList.isEmpty) return;
    final currentCandidate = filteredList[_cardIndex % filteredList.length];
    final targetUid = currentCandidate.uid;

    setState(() {
      _isAnimating = true;
      _dragDx = -520.0;
      _dragDy = 0.0;
    });
    _triggerConfirmedHaptic(_SwipeAction.reject);
    _showSwipeCompletionEffect(_SwipeAction.reject);

    await Future.delayed(_swipeExitDuration);
    if (!mounted) return;

    if (targetUid != null && targetUid.isNotEmpty) {
      // Optimistic local update
      _state.moveCandidateToBack(targetUid);
      // Background Firestore write
      _state.swipeCandidate(targetUid: targetUid, action: 'dislike');
    }

    setState(() {
      _dragDx = 0.0;
      _dragDy = 0.0;
      _isAnimating = false;
      _thresholdHapticAction = null;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  Future<void> _swipeRight(List<Candidate> filteredList) async {
    if (_isAnimating || filteredList.isEmpty) return;
    final currentCandidate = filteredList[_cardIndex % filteredList.length];
    final targetUid = currentCandidate.uid;

    if (targetUid == null || targetUid.isEmpty) {
      _showConnectionRequestError(currentCandidate);
      return;
    }

    setState(() {
      _isAnimating = true;
      _dragDx = 520.0;
      _dragDy = 0.0;
    });
    _triggerConfirmedHaptic(_SwipeAction.like);
    _showSwipeCompletionEffect(_SwipeAction.like);

    await Future.delayed(_swipeExitDuration);
    if (!mounted) return;

    // Optimistic local update
    _state.removeCandidate(targetUid);

    setState(() {
      _dragDx = 0.0;
      _dragDy = 0.0;
      _isAnimating = false;
      _thresholdHapticAction = null;
    });

    final result = await _state.sendOrAcceptConnection(targetUid: targetUid);
    if (result != ConnectionRequestResult.failed) {
      await _state.swipeCandidate(targetUid: targetUid, action: 'like');
    }

    if (!mounted) return;

    switch (result) {
      case ConnectionRequestResult.sent:
      case ConnectionRequestResult.alreadyPending:
        _showSwipeConfirmation(
          _SwipeAction.like,
          currentCandidate,
          connectionResult: result,
        );
        break;
      case ConnectionRequestResult.accepted:
        _showSwipeConfirmation(
          _SwipeAction.like,
          currentCandidate,
          connectionResult: result,
        );
        _triggerMatch(currentCandidate.name);
        break;
      case ConnectionRequestResult.failed:
        _showConnectionRequestError(currentCandidate);
        break;
    }
  }

  Future<void> _swipeUp(List<Candidate> filteredList) async {
    if (_isAnimating || filteredList.isEmpty) return;
    final currentCandidate = filteredList[_cardIndex % filteredList.length];
    final targetUid = currentCandidate.uid;

    if (targetUid == null || targetUid.isEmpty) {
      _showConnectionRequestError(currentCandidate);
      return;
    }

    setState(() {
      _isAnimating = true;
      _dragDx = 0.0;
      _dragDy = -640.0;
    });
    _triggerConfirmedHaptic(_SwipeAction.favorite);
    _showSwipeCompletionEffect(_SwipeAction.favorite);

    await Future.delayed(_swipeExitDuration);
    if (!mounted) return;

    // Optimistic local update: keep favorites discoverable later in the session
    _state.moveCandidateToBack(targetUid);
    _state.swipeCandidate(targetUid: targetUid, action: 'favorite');

    setState(() {
      _dragDx = 0.0;
      _dragDy = 0.0;
      _isAnimating = false;
      _thresholdHapticAction = null;
    });

    _showSwipeConfirmation(_SwipeAction.favorite, currentCandidate);
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onClear,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF7A432D).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF7A432D).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7A432D),
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: onClear,
            child: const Icon(
              Icons.close_rounded,
              size: 13,
              color: Color(0xFF7A432D),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFAF7F5),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 30,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pull Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E2DD),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Professionals',
                        style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedIndustry = null;
                            _selectedInterest = null;
                            _selectedLocation = null;
                            _selectedFilterExpertise = null;
                          });
                          setState(() {});
                        },
                        child: const Text(
                          'Reset All',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB06F4D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFE8E2DD)),
                  const SizedBox(height: 16),

                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Industry Dropdown
                          const Text(
                            'Industry',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF3E1F11),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final candidateIndustries = _state.candidates
                                  .where((c) => c.industry.isNotEmpty)
                                  .map((c) => c.industry)
                                  .toSet();
                              final allIndustries = <String>{
                                ..._industryOptions,
                                ...candidateIndustries.where(
                                  (i) => !_industryOptions.contains(i),
                                ),
                                ..._customIndustries,
                              }.toList()..sort();
                              return Column(
                                children: [
                                  InputDecorator(
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 4,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE8E2DD),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE8E2DD),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF7A432D),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String?>(
                                        value: _selectedIndustry,
                                        hint: const Text(
                                          'Select industry',
                                          style: TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 14,
                                            color: Color(0xFF8C736B),
                                          ),
                                        ),
                                        isExpanded: true,
                                        isDense: true,
                                        dropdownColor: Colors.white,
                                        icon: const Icon(
                                          Icons.arrow_drop_down,
                                          color: Color(0xFF7A432D),
                                        ),
                                        style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 14,
                                          color: Color(0xFF3E1F11),
                                        ),
                                        items: allIndustries.map((val) {
                                          return DropdownMenuItem<String?>(
                                            value: val,
                                            child: Text(val),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          setModalState(() {
                                            _selectedIndustry = val;
                                            if (val == 'Other') {
                                              _industryController.clear();
                                            }
                                          });
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                  ),
                                  if (_selectedIndustry == 'Other')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: TextField(
                                        controller: _industryController,
                                        decoration: InputDecoration(
                                          hintText: 'Enter custom industry...',
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFE8E2DD),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFE8E2DD),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF7A432D),
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                        style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 14,
                                          color: Color(0xFF3E1F11),
                                        ),
                                        onSubmitted: (text) {
                                          final trimmed = text.trim();
                                          if (trimmed.isNotEmpty) {
                                            setModalState(() {
                                              _customIndustries.add(trimmed);
                                              _selectedIndustry = trimmed;
                                              _industryController.clear();
                                            });
                                            setState(() {});
                                          }
                                        },
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 20),

                          // Expertise Dropdown
                          const Text(
                            'Expertise',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF3E1F11),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final candidateSkills = _state.candidates
                                  .expand(
                                    (c) =>
                                        c.skills.isNotEmpty ? c.skills : c.tags,
                                  )
                                  .toSet();
                              final allExpertise = <String>{
                                ..._expertiseOptions,
                                ...candidateSkills.where(
                                  (s) => !_expertiseOptions.contains(s),
                                ),
                              }.toList()..sort();
                              return InputDecorator(
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE8E2DD),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE8E2DD),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF7A432D),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String?>(
                                    value: _selectedFilterExpertise,
                                    hint: const Text(
                                      'Select expertise',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 14,
                                        color: Color(0xFF8C736B),
                                      ),
                                    ),
                                    isExpanded: true,
                                    isDense: true,
                                    dropdownColor: Colors.white,
                                    icon: const Icon(
                                      Icons.arrow_drop_down,
                                      color: Color(0xFF7A432D),
                                    ),
                                    style: const TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 14,
                                      color: Color(0xFF3E1F11),
                                    ),
                                    items: allExpertise.map((val) {
                                      return DropdownMenuItem<String?>(
                                        value: val,
                                        child: Text(val),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setModalState(() {
                                        _selectedFilterExpertise = val;
                                      });
                                      setState(() {});
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),

                          // Interest Dropdown
                          const Text(
                            'Interest',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF3E1F11),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final candidateInterests = _state.candidates
                                  .where((c) => c.interests.isNotEmpty)
                                  .expand((c) => c.interests)
                                  .toSet();
                              final allInterests = <String>{
                                ..._interestOptions,
                                ...candidateInterests.where(
                                  (i) => !_interestOptions.contains(i),
                                ),
                              }.toList()..sort();
                              return InputDecorator(
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE8E2DD),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE8E2DD),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF7A432D),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String?>(
                                    value: _selectedInterest,
                                    hint: const Text(
                                      'Select interest',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 14,
                                        color: Color(0xFF8C736B),
                                      ),
                                    ),
                                    isExpanded: true,
                                    isDense: true,
                                    dropdownColor: Colors.white,
                                    icon: const Icon(
                                      Icons.arrow_drop_down,
                                      color: Color(0xFF7A432D),
                                    ),
                                    style: const TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 14,
                                      color: Color(0xFF3E1F11),
                                    ),
                                    items: allInterests.map((val) {
                                      return DropdownMenuItem<String?>(
                                        value: val,
                                        child: Text(val),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setModalState(() {
                                        _selectedInterest = val;
                                      });
                                      setState(() {});
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),

                          // Location Dropdown
                          const Text(
                            'Location',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF3E1F11),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final candidateLocations =
                                  _state.candidates
                                      .where((c) => c.loc.isNotEmpty)
                                      .map((c) => c.loc)
                                      .toSet()
                                      .toList()
                                    ..sort();
                              return InputDecorator(
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE8E2DD),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE8E2DD),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF7A432D),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String?>(
                                    value: _selectedLocation,
                                    hint: const Text(
                                      'Select location',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 14,
                                        color: Color(0xFF8C736B),
                                      ),
                                    ),
                                    isExpanded: true,
                                    isDense: true,
                                    dropdownColor: Colors.white,
                                    icon: const Icon(
                                      Icons.arrow_drop_down,
                                      color: Color(0xFF7A432D),
                                    ),
                                    style: const TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 14,
                                      color: Color(0xFF3E1F11),
                                    ),
                                    items: candidateLocations.map((val) {
                                      return DropdownMenuItem<String?>(
                                        value: val,
                                        child: Text(val),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setModalState(() {
                                        _selectedLocation = val;
                                      });
                                      setState(() {});
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7A432D),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFE8E2DD).withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 48,
                color: Color(0xFF8C736B),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Matching Professionals',
              style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E1F11),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try expanding your search query or loosening the filters to discover more people.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                color: Color(0xFF8C736B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _searchQuery.clear();
                  _selectedIndustry = null;
                  _selectedInterest = null;
                  _selectedLocation = null;
                  _selectedFilterExpertise = null;
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(
                'Reset All Filters',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A432D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    final filtered = filteredCandidates;
    final filteredCount = filtered.length;
    final highlightedSwipeAction = _activeOverlayAction();

    double buttonProgressFor(_SwipeAction action) {
      return highlightedSwipeAction == action ? _progressForAction(action) : 0;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5EFE9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5EFE9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF3E1F11)),
          onPressed: () {
            _state.currentScreen = AppScreen.hub;
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppLogo(size: 20, showText: false),
            const SizedBox(height: 2),
            Text(
              '$filteredCount professionals nearby',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                color: Color(0xFF8C736B),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_rounded, color: Color(0xFF7A432D)),
            tooltip: 'My Favorites',
            onPressed: () => _showFavoritesBottomSheet(context),
          ),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.tune_rounded, color: Color(0xFF3E1F11)),
                if (_selectedIndustry != null ||
                    _selectedInterest != null ||
                    _selectedLocation != null ||
                    _selectedFilterExpertise != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFB06F4D),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => _showFilterBottomSheet(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main Swiper area
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05,
              vertical: 10,
            ),
            child: Column(
              children: [
                // Search Input Field
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE0D4CB),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF7A432D,
                          ).withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchQuery,
                      decoration: InputDecoration(
                        hintText: 'Search by name, company, skills...',
                        hintStyle: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          color: Color(0xFFAA9488),
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF8C736B),
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  size: 16,
                                  color: Color(0xFF8C736B),
                                ),
                                onPressed: () {
                                  _searchQuery.clear();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        color: Color(0xFF3E1F11),
                      ),
                    ),
                  ),
                ),

                _buildIncomingRequestsPanel(),

                // Active Filter Chips
                if (_selectedIndustry != null ||
                    _selectedInterest != null ||
                    _selectedLocation != null ||
                    _selectedFilterExpertise != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      height: 32,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          if (_selectedIndustry != null)
                            _buildFilterChip(
                              label: 'Industry: $_selectedIndustry',
                              onClear: () {
                                setState(() {
                                  _selectedIndustry = null;
                                });
                              },
                            ),
                          if (_selectedInterest != null)
                            _buildFilterChip(
                              label: 'Interest: $_selectedInterest',
                              onClear: () {
                                setState(() {
                                  _selectedInterest = null;
                                });
                              },
                            ),
                          if (_selectedLocation != null)
                            _buildFilterChip(
                              label: 'Location: $_selectedLocation',
                              onClear: () {
                                setState(() {
                                  _selectedLocation = null;
                                });
                              },
                            ),
                          if (_selectedFilterExpertise != null)
                            _buildFilterChip(
                              label: 'Expertise: $_selectedFilterExpertise',
                              onClear: () {
                                setState(() {
                                  _selectedFilterExpertise = null;
                                });
                              },
                            ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedIndustry = null;
                                _selectedInterest = null;
                                _selectedLocation = null;
                                _selectedFilterExpertise = null;
                              });
                            },
                            child: const Text(
                              'Clear All',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB06F4D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                Expanded(
                  child: filteredCount == 0
                      ? _buildEmptyState()
                      : Center(
                          child: AnimatedScale(
                            scale: _isProfileExpanded ? 0.97 : 1.0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: SizedBox(
                              width: double.infinity,
                              height: screenHeight * 0.62,
                              child: Builder(
                                builder: (context) {
                                  final int index = _cardIndex % filteredCount;
                                  final first = filtered[index];
                                  final second = filteredCount > 1
                                      ? filtered[(index + 1) % filteredCount]
                                      : null;
                                  final third = filteredCount > 2
                                      ? filtered[(index + 2) % filteredCount]
                                      : null;
                                  final activeAction = _activeOverlayAction();
                                  final stackProgress = activeAction == null
                                      ? 0.0
                                      : _progressForAction(activeAction);

                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // Third Card (Bottom)
                                      if (third != null)
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          top: 20 - (10 * stackProgress),
                                          bottom: 10 * stackProgress,
                                          child: Transform.scale(
                                            scale:
                                                0.92 + (0.04 * stackProgress),
                                            child: _buildCard(
                                              third,
                                              isTop: false,
                                            ),
                                          ),
                                        ),

                                      // Second Card (Middle)
                                      if (second != null)
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          top: 10 - (10 * stackProgress),
                                          bottom: 10 + (10 * stackProgress),
                                          child: Transform.scale(
                                            scale:
                                                0.96 + (0.04 * stackProgress),
                                            child: _buildCard(
                                              second,
                                              isTop: false,
                                            ),
                                          ),
                                        ),

                                      // First Card (Top - Draggable)
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        top: 0,
                                        bottom: 20,
                                        child: GestureDetector(
                                          onTap: () =>
                                              _showDetailedProfileBottomSheet(
                                                first,
                                              ),
                                          onPanUpdate: _handlePanUpdate,
                                          onPanEnd: (_) =>
                                              _handlePanEnd(filtered),
                                          child: AnimatedContainer(
                                            duration: _isAnimating
                                                ? _swipeExitDuration
                                                : Duration.zero,
                                            curve: Curves.easeOutCubic,
                                            transformAlignment:
                                                Alignment.center,
                                            transform: Matrix4.identity()
                                              ..translateByDouble(
                                                _dragDx,
                                                _dragDy,
                                                0,
                                                1,
                                              )
                                              ..rotateZ(_cardRotationAngle),
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                _buildCard(first, isTop: true),
                                                _buildSwipeActionOverlay(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                ),

                // Button controls (only visible if filtered list is not empty)
                if (filteredCount > 0)
                  Container(
                    padding: const EdgeInsets.only(bottom: 20, top: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFF5EFE9).withValues(alpha: 0),
                          const Color(0xFFF5EFE9),
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Dislike Button
                        _buildRoundButton(
                          icon: Icons.close_rounded,
                          iconColor: const Color(0xFFC62828),
                          backgroundColor: Colors.white,
                          borderColor: const Color(0xFFF1C8C8),
                          size: 58,
                          tooltip: 'Reject',
                          highlightProgress: buttonProgressFor(
                            _SwipeAction.reject,
                          ),
                          onPressed: () => _swipeLeft(filtered),
                        ),
                        const SizedBox(width: 20),

                        // Favorite Button
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFB06F4D), Color(0xFFE5A475)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFE5A475,
                                ).withValues(alpha: 0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: _buildRoundButton(
                            icon: Icons.star_rounded,
                            iconColor: Colors.white,
                            backgroundColor: Colors.transparent,
                            borderColor: Colors.transparent,
                            size: 70,
                            tooltip: 'Favorite',
                            highlightColor: const Color(0xFFE5A475),
                            highlightProgress: buttonProgressFor(
                              _SwipeAction.favorite,
                            ),
                            onPressed: () => _swipeUp(filtered),
                          ),
                        ),
                        const SizedBox(width: 20),

                        // Like Button
                        _buildRoundButton(
                          icon: Icons.favorite_rounded,
                          iconColor: const Color(0xFF2E7D32),
                          backgroundColor: Colors.white,
                          borderColor: const Color(0xFFCFE8D4),
                          size: 58,
                          tooltip: 'Like',
                          highlightProgress: buttonProgressFor(
                            _SwipeAction.like,
                          ),
                          onPressed: () => _swipeRight(filtered),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          _buildSwipeCompletionEffects(),

          // Connection Overlay
          if (_showMatchOverlay && _matchedName != null)
            AnimatedOpacity(
              opacity: _showMatchOverlay ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                color: const Color(0xFF3E1F11).withValues(alpha: 0.95),
                width: double.infinity,
                height: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'It\'s a Connection!',
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFE5A475),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You and $_matchedName both want to talk.',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 36),
                    AnimatedScale(
                      scale: _connectScale,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5A475).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.handshake,
                          color: Color(0xFFE5A475),
                          size: 44,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_isProfileExpanded)
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: Container(color: Colors.black.withValues(alpha: 0.3)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(Candidate c, {required bool isTop}) {
    final cleanLoc = c.loc.isNotEmpty ? c.loc.split(',').first.trim() : '';
    final interestsList = <Widget>[];
    final displayedInterests = c.interests.take(7).toList();
    for (final interest in displayedInterests) {
      String priority = 'Medium';
      if (c.interestsWithPriority.isNotEmpty) {
        final match = c.interestsWithPriority.firstWhere(
          (e) =>
              e['name'].toString().toLowerCase().trim() ==
              interest.toLowerCase().trim(),
          orElse: () => <String, dynamic>{},
        );
        if (match.isNotEmpty) {
          priority = match['priority']?.toString() ?? 'Medium';
        }
      }
      interestsList.add(_buildInterestChipWithPriority(interest, priority));
    }
    if (c.interests.length > 7) {
      interestsList.add(_buildMoreChip());
    }

    final roleLine = [
      if (c.role.trim().isNotEmpty) c.role.trim(),
      if (c.org.trim().isNotEmpty) c.org.trim(),
    ].join(c.role.trim().isNotEmpty && c.org.trim().isNotEmpty ? ' at ' : '');
    final headline = c.headline.trim().isNotEmpty
        ? c.headline.trim()
        : roleLine;
    final bio = c.bio.trim();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFFFFBF8)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF3E1F11,
            ).withValues(alpha: isTop ? 0.16 : 0.08),
            blurRadius: isTop ? 32 : 18,
            offset: Offset(0, isTop ? 18 : 10),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.82),
            blurRadius: 14,
            offset: const Offset(-4, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 218,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  buildProfileImage(
                    c.profileImageUrl ?? '',
                    fit: BoxFit.cover,
                    fallback: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            c.primaryColor,
                            const Color(0xFFB06F4D),
                            const Color(0xFF3E1F11),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          c.initials,
                          style: const TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.10),
                          Colors.black.withValues(alpha: 0.04),
                          Colors.black.withValues(alpha: 0.42),
                        ],
                        stops: const [0, 0.48, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    top: 16,
                    child: _buildImagePill(
                      icon: Icons.star_rounded,
                      label: '${c.match}% match',
                      iconColor: const Color(0xFFFFD37A),
                    ),
                  ),
                  if (cleanLoc.isNotEmpty)
                    Positioned(
                      right: 16,
                      top: 16,
                      child: _buildImagePill(
                        icon: Icons.location_on_rounded,
                        label: cleanLoc,
                        maxWidth: 132,
                      ),
                    ),
                  if (isTop && c.customCards.isNotEmpty)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: GestureDetector(
                        onTap: () => _showCustomCardsDeck(context, c),
                        child: _buildImagePill(
                          icon: Icons.style_rounded,
                          label: 'Deck',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A1629),
                        height: 1.06,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (headline.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        headline,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5C473E),
                          height: 1.28,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (roleLine.isNotEmpty && roleLine != headline) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.work_outline_rounded,
                            size: 14,
                            color: Color(0xFFB06F4D),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              roleLine,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8C736B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 3,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5A475),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              bio,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6E5A51),
                                height: 1.34,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Spacer(),
                    if (c.skills.isNotEmpty || c.tags.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (c.skills.isNotEmpty ? c.skills : c.tags)
                            .take(2)
                            .map((exp) {
                              String level = 'Intermediate';
                              if (c.expertiseWithLevel.isNotEmpty) {
                                final match = c.expertiseWithLevel.firstWhere(
                                  (e) =>
                                      e['name']
                                          .toString()
                                          .toLowerCase()
                                          .trim() ==
                                      exp.toLowerCase().trim(),
                                  orElse: () => <String, dynamic>{},
                                );
                                if (match.isNotEmpty) {
                                  level =
                                      match['level']?.toString() ??
                                      'Intermediate';
                                }
                              }
                              return _buildExpertiseChipWithLevel(exp, level);
                            })
                            .toList(),
                      ),
                    ] else if (interestsList.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: interestsList.take(2).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePill({
    required IconData icon,
    required String label,
    Color iconColor = Colors.white,
    double maxWidth = 148,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 14),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper styles mapping class for interests
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
          color: const Color(0xFF7A432D).withValues(alpha: 0.2),
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

  Widget _buildMoreChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.more_horiz_rounded, size: 13, color: Color(0xFF37474F)),
          SizedBox(width: 4),
          Text(
            'More',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF37474F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required Color borderColor,
    required double size,
    String? tooltip,
    Color? highlightColor,
    double highlightProgress = 0,
    required VoidCallback onPressed,
  }) {
    final progress = highlightProgress.clamp(0.0, 1.0).toDouble();
    final accent = highlightColor ?? iconColor;
    final highlightFill = accent.withValues(
      alpha: backgroundColor == Colors.transparent ? 0.18 : 0.14,
    );
    final fillColor = Color.lerp(backgroundColor, highlightFill, progress)!;
    final effectiveBorderColor = Color.lerp(borderColor, accent, progress)!;
    final effectiveIconColor = Color.lerp(iconColor, accent, progress)!;

    return Transform.scale(
      scale: 1 + (0.12 * progress),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fillColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: effectiveBorderColor,
            width: 1.5 + (2.2 * progress),
          ),
          boxShadow: [
            if (backgroundColor != Colors.transparent)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            if (progress > 0)
              BoxShadow(
                color: accent.withValues(alpha: 0.18 + (0.28 * progress)),
                blurRadius: 10 + (18 * progress),
                spreadRadius: 1 + (3 * progress),
              ),
          ],
        ),
        child: IconButton(
          icon: Icon(icon, color: effectiveIconColor),
          iconSize: size * (0.45 + (0.08 * progress)),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      ),
    );
  }

  void _showFavoritesBottomSheet(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Color(0xFFFAF7F5),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pull handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E2DD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Favorites ⭐',
                    style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E1F11),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF8C736B),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Color(0xFFE8E2DD), height: 24),
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('swipes')
                      .where('fromUid', isEqualTo: currentUid)
                      .where('action', isEqualTo: 'favorite')
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF7A432D),
                        ),
                      );
                    }
                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.star_outline_rounded,
                              size: 48,
                              color: Color(0xFF8C736B),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No favorited profiles yet',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 14,
                                color: Color(0xFF8C736B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Swipe up or tap star on a profile card to add.',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11,
                                color: Color(0xFF8C736B),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final favoriteDocs = snapshot.data!.docs;
                    return ListView.builder(
                      itemCount: favoriteDocs.length,
                      itemBuilder: (context, index) {
                        final fav =
                            favoriteDocs[index].data() as Map<String, dynamic>;
                        final targetUid = fav['toUid'] as String? ?? '';
                        if (targetUid.isEmpty) return const SizedBox.shrink();

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(targetUid)
                              .get(),
                          builder: (context, userSnap) {
                            if (!userSnap.hasData || !userSnap.data!.exists) {
                              return const SizedBox.shrink();
                            }
                            final userData =
                                userSnap.data!.data() as Map<String, dynamic>;
                            final name = userData['name'] ?? 'Someone';
                            final role = userData['role'] ?? 'Professional';
                            final company = userData['company'] ?? '';
                            final imageUrl = userData['profileImageUrl'] ?? '';
                            final initials = (name as String)
                                .substring(0, 1)
                                .toUpperCase();

                            // Construct a Candidate object for the detail view
                            final c = Candidate(
                              uid: targetUid,
                              name: name,
                              headline: userData['headline'] ?? '',
                              role: role,
                              org: company,
                              loc:
                                  userData['currentLocationName'] ??
                                  userData['homeBase'] ??
                                  '',
                              match: 95, // Default high match for favorites
                              intent: List<String>.from(
                                userData['intents'] ?? [],
                              ).join(', '),
                              tags: List<String>.from(
                                userData['expertise'] ?? [],
                              ),
                              interests: List<String>.from(
                                userData['interests'] ?? [],
                              ),
                              skills: List<String>.from(
                                userData['skills'] ?? [],
                              ),
                              homeBase: userData['homeBase'] ?? '',
                              bio: userData['bio'] ?? '',
                              initials: initials,
                              profileImageUrl: imageUrl,
                              primaryColor: const Color(0xFFE5A475),
                            );

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: const Color(0xFFFAF0E6),
                                  backgroundImage: imageUrl.isNotEmpty
                                      ? NetworkImage(imageUrl)
                                      : null,
                                  child: imageUrl.isEmpty
                                      ? Text(
                                          initials,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF7A432D),
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF3E1F11),
                                  ),
                                ),
                                subtitle: Text(
                                  '$role${company.isNotEmpty ? ' at $company' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11,
                                    color: Color(0xFF8C736B),
                                  ),
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7A432D),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(
                                      context,
                                    ); // Close favorites sheet
                                    _showFavoriteProfileDetailsSheet(
                                      context,
                                      c,
                                    );
                                  },
                                  child: const Text(
                                    'View Profile',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFavoriteProfileDetailsSheet(BuildContext context, Candidate c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFFFAF7F5),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              // Pull Handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E2DD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Favorite Profile Details',
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E1F11),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF8C736B),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Color(0xFFE8E2DD), height: 16),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.62,
                        child: _buildCard(c, isTop: true),
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

  void _showDetailedProfileBottomSheet(Candidate c) async {
    setState(() {
      _isProfileExpanded = true;
    });

    final interestsList = <Widget>[];
    for (final interest in c.interests) {
      String priority = 'Medium';
      if (c.interestsWithPriority.isNotEmpty) {
        final match = c.interestsWithPriority.firstWhere(
          (e) =>
              e['name'].toString().toLowerCase().trim() ==
              interest.toLowerCase().trim(),
          orElse: () => <String, dynamic>{},
        );
        if (match.isNotEmpty) {
          priority = match['priority']?.toString() ?? 'Medium';
        }
      }
      interestsList.add(_buildInterestChipWithPriority(interest, priority));
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha((0.35 * 255).round()),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.96,
          snap: true,
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
                                  color: const Color(
                                    0xFF7A432D,
                                  ).withValues(alpha: 0.15),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF2E7D32,
                                    ).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF2E7D32,
                                      ).withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.stars,
                                        size: 13,
                                        color: Color(0xFF2E7D32),
                                      ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
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
                                const Text(
                                  '•',
                                  style: TextStyle(color: Color(0xFFE0D4CB)),
                                ),
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
                                c.loc.isNotEmpty
                                    ? c.loc.split(',').first.trim()
                                    : 'Remote',
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
                              border: Border.all(
                                color: const Color(0xFF90CAF9),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '• ',
                                          style: TextStyle(
                                            color: Color(0xFF1565C0),
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
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
                          _buildDetailSectionHeader(
                            'Expertise (What I can share)',
                          ),
                          const SizedBox(height: 8),
                          _buildDetailCard(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  (c.skills.isNotEmpty ? c.skills : c.tags).map(
                                    (exp) {
                                      String level = 'Intermediate';
                                      if (c.expertiseWithLevel.isNotEmpty) {
                                        final match = c.expertiseWithLevel
                                            .firstWhere(
                                              (e) =>
                                                  e['name']
                                                      .toString()
                                                      .toLowerCase()
                                                      .trim() ==
                                                  exp.toLowerCase().trim(),
                                              orElse: () => <String, dynamic>{},
                                            );
                                        if (match.isNotEmpty) {
                                          level =
                                              match['level']?.toString() ??
                                              'Intermediate';
                                        }
                                      }
                                      return _buildExpertiseChipWithLevel(
                                        exp,
                                        level,
                                      );
                                    },
                                  ).toList(),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Interests (What I want to learn)
                        if (interestsList.isNotEmpty) ...[
                          _buildDetailSectionHeader(
                            'Interests (What I want to learn)',
                          ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF1EC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(
                                    0xFF7A432D,
                                  ).withValues(alpha: 0.15),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.chat_bubble_outline,
                                    size: 16,
                                    color: Color(0xFF7A432D),
                                  ),
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
      },
    );

    setState(() {
      _isProfileExpanded = false;
    });
  }
}

class _InterestStyle {
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  const _InterestStyle(this.icon, this.backgroundColor, this.foregroundColor);
}
