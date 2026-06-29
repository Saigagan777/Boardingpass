import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../state_manager.dart';
import '../models/candidate.dart';
import '../utils/card_renderer.dart';
import '../utils/image_helper.dart';
import '../utils/app_logo.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  final AppStateManager _state = AppStateManager();

  // Filter states
  final TextEditingController _searchQuery = TextEditingController();
  String _selectedRole = 'All';
  String _selectedIntent = 'All';
  double _minMatchScore = 0.0;
  List<String> _selectedInterests = [];
  List<String> _selectedExpertise = [];
  String? _selectedLocation;

  // Swiping state variables
  double _dragDx = 0.0;
  double _dragDy = 0.0;
  bool _isAnimating = false;

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
    _state.loadCandidates();
    _searchQuery.addListener(() {
      if (mounted) {
        setState(() {
          _cardIndex = 0;
        });
      }
    });
  }

  @override
  void dispose() {
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
        final matchesCompany = c.org.toLowerCase().contains(query);
        final matchesRole = c.role.toLowerCase().contains(query);
        final matchesSkills = c.tags.any(
          (tag) => tag.toLowerCase().contains(query),
        );
        final matchesIntent = c.intent.toLowerCase().contains(query);
        if (!matchesName &&
            !matchesCompany &&
            !matchesRole &&
            !matchesSkills &&
            !matchesIntent) {
          return false;
        }
      }

      // 2. Role filter
      if (_selectedRole != 'All') {
        if (_selectedRole == 'Founders / CEOs') {
          final roleLower = c.role.toLowerCase();
          if (!roleLower.contains('founder') &&
              !roleLower.contains('ceo') &&
              !roleLower.contains('co-founder')) {
            return false;
          }
        } else if (_selectedRole == 'Investors / VCs') {
          final roleLower = c.role.toLowerCase();
          if (!roleLower.contains('investor') &&
              !roleLower.contains('vc') &&
              !roleLower.contains('partner') &&
              !roleLower.contains('capital')) {
            return false;
          }
        } else if (_selectedRole == 'Tech / Engineering') {
          final roleLower = c.role.toLowerCase();
          if (!roleLower.contains('engineer') &&
              !roleLower.contains('developer') &&
              !roleLower.contains('cto') &&
              !roleLower.contains('tech') &&
              !roleLower.contains('product')) {
            return false;
          }
        } else if (_selectedRole == 'Sales / Marketing') {
          final roleLower = c.role.toLowerCase();
          if (!roleLower.contains('sales') &&
              !roleLower.contains('marketing') &&
              !roleLower.contains('growth') &&
              !roleLower.contains('bd')) {
            return false;
          }
        } else {
          if (!c.role.toLowerCase().contains(_selectedRole.toLowerCase())) {
            return false;
          }
        }
      }

      // 3. Intent filter
      if (_selectedIntent != 'All') {
        if (!c.intent.toLowerCase().contains(_selectedIntent.toLowerCase())) {
          return false;
        }
      }

      // 4. Minimum Match Score filter
      if (c.match < _minMatchScore) {
        return false;
      }

      // 5. Interest filter
      if (_selectedInterests.isNotEmpty) {
        if (!c.interests.any((i) => _selectedInterests.contains(i))) {
          return false;
        }
      }

      // 6. Expertise filter
      if (_selectedExpertise.isNotEmpty) {
        if (!c.skills.any((s) => _selectedExpertise.contains(s)) &&
            !c.tags.any((t) => _selectedExpertise.contains(t))) {
          return false;
        }
      }

      // 7. Location filter
      if (_selectedLocation != null) {
        if (c.loc != _selectedLocation && c.homeBase != _selectedLocation) {
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

  void _showConnectionRequestPopup(
    Candidate candidate, {
    bool alreadyPending = false,
  }) {
    final message = alreadyPending
        ? 'Connection request already sent to ${candidate.name}.'
        : 'Connection request sent to ${candidate.name}.';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFF3E1F11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE5A475), width: 0.8),
          ),
          content: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5A475).withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_read_rounded,
                  color: Color(0xFFE5A475),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$message They can accept it from their notifications.',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
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

  Future<void> _swipeLeft(List<Candidate> filteredList) async {
    if (_isAnimating || filteredList.isEmpty) return;
    final currentCandidate = filteredList[_cardIndex % filteredList.length];
    final targetUid = currentCandidate.uid;

    setState(() {
      _isAnimating = true;
      _dragDx = -400.0;
    });

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    if (targetUid != null && targetUid.isNotEmpty) {
      // Optimistic local update
      _state.removeCandidate(targetUid);
      // Background Firestore write
      _state.swipeCandidate(targetUid: targetUid, action: 'dislike');
    }

    setState(() {
      _dragDx = 0.0;
      _dragDy = 0.0;
      _isAnimating = false;
    });
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
      _dragDx = 400.0;
    });

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    // Optimistic local update: move to back
    _state.moveCandidateToBack(targetUid);
    // Background Firestore write
    _state.swipeCandidate(targetUid: targetUid, action: 'favorite');

    setState(() {
      _dragDx = 0.0;
      _dragDy = 0.0;
      _isAnimating = false;
    });

    if (!mounted) return;

    // Show favorited notification feedback (other user is not notified)
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFF7A432D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE5A475), width: 0.8),
          ),
          content: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Added to Favorites',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'You can view ${currentCandidate.name} later in Favorites.',
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
      _dragDy = -600.0;
    });

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    // Optimistic local update
    _state.removeCandidate(targetUid);

    setState(() {
      _dragDx = 0.0;
      _dragDy = 0.0;
      _isAnimating = false;
    });

    final result = await _state.sendOrAcceptConnection(targetUid: targetUid);
    if (result != ConnectionRequestResult.failed) {
      await _state.swipeCandidate(targetUid: targetUid, action: 'like');
    }

    if (!mounted) return;

    switch (result) {
      case ConnectionRequestResult.sent:
        _showConnectionRequestPopup(currentCandidate);
        break;
      case ConnectionRequestResult.alreadyPending:
        _showConnectionRequestPopup(currentCandidate, alreadyPending: true);
        break;
      case ConnectionRequestResult.accepted:
        _triggerMatch(currentCandidate.name);
        break;
      case ConnectionRequestResult.failed:
        _showConnectionRequestError(currentCandidate);
        break;
    }
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onClear,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E2DD),
        borderRadius: BorderRadius.circular(16),
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
              color: Color(0xFF3E1F11),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClear,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: Color(0xFF3E1F11),
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
                            _selectedRole = 'All';
                            _selectedIntent = 'All';
                            _minMatchScore = 0.0;
                            _selectedInterests = [];
                            _selectedExpertise = [];
                            _selectedLocation = null;
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
                          // Role Selection
                          const Text(
                            'Role / Profession',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF3E1F11),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                [
                                  'All',
                                  'Founders / CEOs',
                                  'Investors / VCs',
                                  'Tech / Engineering',
                                  'Sales / Marketing',
                                ].map((role) {
                                  final isSelected = _selectedRole == role;
                                  return ChoiceChip(
                                    label: Text(role),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setModalState(() {
                                        _selectedRole = role;
                                      });
                                      setState(() {});
                                    },
                                    selectedColor: const Color(0xFF7A432D),
                                    disabledColor: Colors.transparent,
                                    backgroundColor: Colors.transparent,
                                    checkmarkColor: Colors.white,
                                    labelStyle: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF5C473E),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                        color: isSelected
                                            ? Colors.transparent
                                            : const Color(0xFFE8E2DD),
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: 20),

                          // Intent Selection
                          const Text(
                            'Intent / Objective',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF3E1F11),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                [
                                  'All',
                                  'Raising Seed',
                                  'Hiring Team',
                                  'Open to Coffee',
                                  'B2B Partnerships',
                                ].map((intent) {
                                  final isSelected = _selectedIntent == intent;
                                  return ChoiceChip(
                                    label: Text(intent),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setModalState(() {
                                        _selectedIntent = intent;
                                      });
                                      setState(() {});
                                    },
                                    selectedColor: const Color(0xFF7A432D),
                                    disabledColor: Colors.transparent,
                                    backgroundColor: Colors.transparent,
                                    checkmarkColor: Colors.white,
                                    labelStyle: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF5C473E),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                        color: isSelected
                                            ? Colors.transparent
                                            : const Color(0xFFE8E2DD),
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: 20),

                          // Interests Multi-Select
                          const Text(
                            'Interests',
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
                              final allInterests =
                                  _state.candidates
                                      .expand((c) => c.interests)
                                      .toSet()
                                      .toList()
                                    ..sort();
                              if (allInterests.isEmpty) {
                                return const Text(
                                  'No interest data available',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    color: Color(0xFF8C736B),
                                  ),
                                );
                              }
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: allInterests.map((interest) {
                                  final isSelected = _selectedInterests
                                      .contains(interest);
                                  return FilterChip(
                                    label: Text(interest),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setModalState(() {
                                        if (selected) {
                                          _selectedInterests.add(interest);
                                        } else {
                                          _selectedInterests.remove(interest);
                                        }
                                      });
                                      setState(() {});
                                    },
                                    selectedColor: const Color(0xFF7A432D),
                                    checkmarkColor: Colors.white,
                                    backgroundColor: Colors.transparent,
                                    labelStyle: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF5C473E),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                        color: isSelected
                                            ? Colors.transparent
                                            : const Color(0xFFE8E2DD),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 20),

                          // Expertise Multi-Select
                          const Text(
                            'Expertise / Skills',
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
                              final allExpertise =
                                  _state.candidates
                                      .expand((c) => [...c.tags, ...c.skills])
                                      .toSet()
                                      .toList()
                                    ..sort();
                              if (allExpertise.isEmpty) {
                                return const Text(
                                  'No expertise data available',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    color: Color(0xFF8C736B),
                                  ),
                                );
                              }
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: allExpertise.map((skill) {
                                  final isSelected = _selectedExpertise
                                      .contains(skill);
                                  return FilterChip(
                                    label: Text(skill),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setModalState(() {
                                        if (selected) {
                                          _selectedExpertise.add(skill);
                                        } else {
                                          _selectedExpertise.remove(skill);
                                        }
                                      });
                                      setState(() {});
                                    },
                                    selectedColor: const Color(0xFF7A432D),
                                    checkmarkColor: Colors.white,
                                    backgroundColor: Colors.transparent,
                                    labelStyle: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF5C473E),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                        color: isSelected
                                            ? Colors.transparent
                                            : const Color(0xFFE8E2DD),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 20),

                          // Location Filter
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
                              final allLocations =
                                  _state.candidates
                                      .map((c) => c.loc)
                                      .where((l) => l.isNotEmpty)
                                      .toSet()
                                      .toList()
                                    ..sort();
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ChoiceChip(
                                    label: const Text('All'),
                                    selected: _selectedLocation == null,
                                    onSelected: (selected) {
                                      setModalState(() {
                                        _selectedLocation = null;
                                      });
                                      setState(() {});
                                    },
                                    selectedColor: const Color(0xFF7A432D),
                                    checkmarkColor: Colors.white,
                                    backgroundColor: Colors.transparent,
                                    labelStyle: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 12,
                                      fontWeight: _selectedLocation == null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: _selectedLocation == null
                                          ? Colors.white
                                          : const Color(0xFF5C473E),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                        color: _selectedLocation == null
                                            ? Colors.transparent
                                            : const Color(0xFFE8E2DD),
                                      ),
                                    ),
                                  ),
                                  ...allLocations.map((loc) {
                                    final isSelected = _selectedLocation == loc;
                                    return ChoiceChip(
                                      label: Text(loc),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setModalState(() {
                                          _selectedLocation = selected
                                              ? loc
                                              : null;
                                        });
                                        setState(() {});
                                      },
                                      selectedColor: const Color(0xFF7A432D),
                                      checkmarkColor: Colors.white,
                                      backgroundColor: Colors.transparent,
                                      labelStyle: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF5C473E),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        side: BorderSide(
                                          color: isSelected
                                              ? Colors.transparent
                                              : const Color(0xFFE8E2DD),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 20),

                          // Match Score Slider
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Minimum Match Score',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF3E1F11),
                                ),
                              ),
                              Text(
                                '${_minMatchScore.round()}%',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF7A432D),
                                ),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFF7A432D),
                              inactiveTrackColor: const Color(0xFFE8E2DD),
                              thumbColor: const Color(0xFF7A432D),
                              overlayColor: const Color(
                                0xFF7A432D,
                              ).withValues(alpha: 0.12),
                              valueIndicatorColor: const Color(0xFF7A432D),
                            ),
                            child: Slider(
                              value: _minMatchScore,
                              min: 0,
                              max: 100,
                              divisions: 10,
                              onChanged: (val) {
                                setModalState(() {
                                  _minMatchScore = val;
                                });
                                setState(() {});
                              },
                            ),
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
                  _selectedRole = 'All';
                  _selectedIntent = 'All';
                  _minMatchScore = 0.0;
                  _selectedInterests = [];
                  _selectedExpertise = [];
                  _selectedLocation = null;
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
                if (_selectedRole != 'All' ||
                    _selectedIntent != 'All' ||
                    _minMatchScore > 0 ||
                    _selectedInterests.isNotEmpty ||
                    _selectedExpertise.isNotEmpty ||
                    _selectedLocation != null)
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
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE8E2DD),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _searchQuery,
                      decoration: InputDecoration(
                        hintText: 'Search by name, company, skills...',
                        hintStyle: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          color: Color(0xFF8C736B),
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF8C736B),
                          size: 18,
                        ),
                        suffixIcon: _searchQuery.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  _searchQuery.clear();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
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
                if (_selectedRole != 'All' ||
                    _selectedIntent != 'All' ||
                    _minMatchScore > 0 ||
                    _selectedInterests.isNotEmpty ||
                    _selectedExpertise.isNotEmpty ||
                    _selectedLocation != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      height: 32,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          if (_selectedRole != 'All')
                            _buildFilterChip(
                              label: 'Role: $_selectedRole',
                              onClear: () {
                                setState(() {
                                  _selectedRole = 'All';
                                });
                              },
                            ),
                          if (_selectedIntent != 'All')
                            _buildFilterChip(
                              label: 'Intent: $_selectedIntent',
                              onClear: () {
                                setState(() {
                                  _selectedIntent = 'All';
                                });
                              },
                            ),
                          if (_minMatchScore > 0)
                            _buildFilterChip(
                              label: 'Match: >=${_minMatchScore.round()}%',
                              onClear: () {
                                setState(() {
                                  _minMatchScore = 0.0;
                                });
                              },
                            ),
                          if (_selectedInterests.isNotEmpty)
                            _buildFilterChip(
                              label: 'Interests: ${_selectedInterests.length}',
                              onClear: () {
                                setState(() {
                                  _selectedInterests = [];
                                });
                              },
                            ),
                          if (_selectedExpertise.isNotEmpty)
                            _buildFilterChip(
                              label: 'Expertise: ${_selectedExpertise.length}',
                              onClear: () {
                                setState(() {
                                  _selectedExpertise = [];
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
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedRole = 'All';
                                _selectedIntent = 'All';
                                _minMatchScore = 0.0;
                                _selectedInterests = [];
                                _selectedExpertise = [];
                                _selectedLocation = null;
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

                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Third Card (Bottom)
                                    if (third != null)
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        top: 20,
                                        bottom: 0,
                                        child: Transform.scale(
                                          scale: 0.92,
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
                                        top: 10,
                                        bottom: 10,
                                        child: Transform.scale(
                                          scale: 0.96,
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
                                        onDoubleTap: () => _swipeUp(filtered),
                                        onLongPress: () => _swipeRight(filtered),
                                        onPanUpdate: (details) {
                                          if (_isAnimating) return;
                                          setState(() {
                                            _dragDx += details.delta.dx;
                                            _dragDy += details.delta.dy;
                                          });
                                        },
                                        onPanEnd: (details) {
                                          if (_isAnimating) return;
                                          if (_dragDx > 120) {
                                            _swipeRight(filtered);
                                          } else if (_dragDx < -120) {
                                            _swipeLeft(filtered);
                                          } else if (_dragDy < -100) {
                                            _swipeUp(filtered);
                                          } else {
                                            // Reset card position
                                            setState(() {
                                              _dragDx = 0;
                                              _dragDy = 0;
                                            });
                                          }
                                        },
                                        child: Transform.translate(
                                          offset: Offset(_dragDx, _dragDy),
                                          child: Transform.rotate(
                                            angle: _dragDx / 400 * 0.15,
                                            child: _buildCard(
                                              first,
                                              isTop: true,
                                            ),
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

                // Button controls (only visible if filtered list is not empty)
                if (filteredCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24, top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Dislike Button
                        _buildRoundButton(
                          icon: Icons.close,
                          iconColor: const Color(0xFF8C736B),
                          backgroundColor: Colors.white,
                          borderColor: const Color(0xFFE8E2DD),
                          size: 56,
                          onPressed: () => _swipeLeft(filtered),
                        ),
                        const SizedBox(width: 24),

                        // Handshake/Connect Button
                        Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF7A432D), Color(0xFFB06F4D)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: _buildRoundButton(
                            icon: Icons.handshake,
                            iconColor: Colors.white,
                            backgroundColor: Colors.transparent,
                            borderColor: Colors.transparent,
                            size: 68,
                            onPressed: () => _swipeUp(filtered),
                          ),
                        ),
                        const SizedBox(width: 24),

                        // Star Button (Favorite)
                        _buildRoundButton(
                          icon: Icons.star_rounded,
                          iconColor: const Color(0xFFB06F4D),
                          backgroundColor: Colors.white,
                          borderColor: const Color(0xFFE8E2DD),
                          size: 56,
                          onPressed: () => _swipeRight(filtered),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

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
        ],
      ),
    );
  }

  Widget _buildCard(Candidate c, {required bool isTop}) {
    final cleanLoc = c.loc.isNotEmpty ? c.loc.split(',').first.trim() : '';
    final interestsList = <Widget>[];
    final displayedInterests = c.interests.take(7).toList();
    for (final interest in displayedInterests) {
      interestsList.add(_buildInterestChip(interest));
    }
    if (c.interests.length > 7) {
      interestsList.add(_buildMoreChip());
    }

    return Card(
      color: Colors.white,
      elevation: isTop ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: Color(0xFFE8E2DD), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Large Image Block at the top
          SizedBox(
            height: 250,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  child: buildProfileImage(
                    c.profileImageUrl ?? '',
                    fit: BoxFit.cover,
                    fallback: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [c.primaryColor, const Color(0xFF3E1F11)],
                        ),
                      ),
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
                // Overlay Match score badge
                Positioned(
                  left: 16,
                  top: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "${c.match}% match",
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Overlay Location badge (pin icon + location name)
                if (cleanLoc.isNotEmpty)
                  Positioned(
                    right: 16,
                    top: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 100),
                            child: Text(
                              cleanLoc,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                    ),
                  ),
                // Showcase Deck Button overlay
                if (isTop && c.customCards.isNotEmpty)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: GestureDetector(
                      onTap: () => _showCustomCardsDeck(context, c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.style_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Deck',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 2. Content Details area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Headline (Name) - Wraps to 2 lines instead of cutting off
                    Text(
                      c.name,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A1629),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Subhead (Role & Company) - Wrap prevents truncation
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        // Company pill
                        if (c.org.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0052FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              c.org,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        if (c.org.isNotEmpty && c.role.isNotEmpty)
                          const Text(
                            '·',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE8E2DD),
                            ),
                          ),
                        // Job Title
                        Text(
                          c.role,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8C736B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Body (Bio)
                    Text(
                      c.bio,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13.5,
                        color: Color(0xFF3E1F11),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Interests title
                    if (interestsList.isNotEmpty) ...[
                      const Text(
                        'Interests',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Interests list
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: interestsList,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper styles mapping class for interests
  _InterestStyle _getInterestStyle(String interest) {
    final key = interest.toLowerCase().trim();
    if (key.contains('music')) {
      return const _InterestStyle(Icons.music_note_rounded, Color(0xFFF0EEFF), Color(0xFF5636CC));
    } else if (key.contains('photo') || key.contains('camera')) {
      return const _InterestStyle(Icons.camera_alt_outlined, Color(0xFFE5F6ED), Color(0xFF2E7D32));
    } else if (key.contains('travel') || key.contains('flight') || key.contains('explore') || key.contains('tour')) {
      return const _InterestStyle(Icons.flight_takeoff_rounded, Color(0xFFFFF9E6), Color(0xFFB7791F));
    } else if (key.contains('fit') || key.contains('gym') || key.contains('workout') || key.contains('sport') || key.contains('health') || key.contains('run')) {
      return const _InterestStyle(Icons.fitness_center_rounded, Color(0xFFE3F2FD), Color(0xFF1565C0));
    } else if (key.contains('game') || key.contains('gaming') || key.contains('play')) {
      return const _InterestStyle(Icons.sports_esports_outlined, Color(0xFFFFEBF0), Color(0xFFD81B60));
    } else if (key.contains('read') || key.contains('book') || key.contains('write')) {
      return const _InterestStyle(Icons.menu_book_rounded, Color(0xFFFFF0EB), Color(0xFFD84315));
    } else if (key.contains('coffee') || key.contains('cafe') || key.contains('tea') || key.contains('drink')) {
      return const _InterestStyle(Icons.local_cafe_outlined, Color(0xFFF8E8F8), Color(0xFF8E24AA));
    } else if (key.contains('art') || key.contains('paint') || key.contains('design')) {
      return const _InterestStyle(Icons.palette_outlined, Color(0xFFFFF3E0), Color(0xFFEF6C00));
    } else if (key.contains('tech') || key.contains('code') || key.contains('computer') || key.contains('cto') || key.contains('hiring') || key.contains('develop')) {
      return const _InterestStyle(Icons.code_rounded, Color(0xFFE0F7FA), Color(0xFF00838F));
    } else if (key.contains('food') || key.contains('cooking') || key.contains('eat') || key.contains('bake')) {
      return const _InterestStyle(Icons.restaurant_rounded, Color(0xFFF1F8E9), Color(0xFF558B2F));
    } else if (key.contains('movie') || key.contains('film') || key.contains('cinema') || key.contains('watch')) {
      return const _InterestStyle(Icons.movie_outlined, Color(0xFFEDE7F6), Color(0xFF673AB7));
    } else if (key.contains('partner') || key.contains('b2b') || key.contains('sales') || key.contains('marketing') || key.contains('business') || key.contains('growth')) {
      return const _InterestStyle(Icons.handshake_outlined, Color(0xFFFFF3E0), Color(0xFFD84315));
    } else if (key.contains('invest') || key.contains('vc') || key.contains('fund') || key.contains('finance') || key.contains('money')) {
      return const _InterestStyle(Icons.monetization_on_outlined, Color(0xFFE8F5E9), Color(0xFF2E7D32));
    }
    // Terracotta theme fallback matching app primary brand style
    return const _InterestStyle(
      Icons.label_outline_rounded,
      Color(0xFFFAF1EC),
      Color(0xFF7A432D),
    );
  }

  Widget _buildInterestChip(String interest) {
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
          Icon(
            Icons.more_horiz_rounded,
            size: 13,
            color: Color(0xFF37474F),
          ),
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
    required VoidCallback onPressed,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: backgroundColor != Colors.transparent
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor),
        iconSize: size * 0.45,
        onPressed: onPressed,
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
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF8C736B)),
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
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF7A432D)));
                    }
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.star_outline_rounded, size: 48, color: Color(0xFF8C736B)),
                            SizedBox(height: 12),
                            Text(
                              'No favorited profiles yet',
                              style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, color: Color(0xFF8C736B), fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Swipe up or tap star on a profile card to add.',
                              style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: Color(0xFF8C736B)),
                            ),
                          ],
                        ),
                      );
                    }

                    final favoriteDocs = snapshot.data!.docs;
                    return ListView.builder(
                      itemCount: favoriteDocs.length,
                      itemBuilder: (context, index) {
                        final fav = favoriteDocs[index].data() as Map<String, dynamic>;
                        final targetUid = fav['toUid'] as String? ?? '';
                        if (targetUid.isEmpty) return const SizedBox.shrink();

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(targetUid).get(),
                          builder: (context, userSnap) {
                            if (!userSnap.hasData || !userSnap.data!.exists) {
                              return const SizedBox.shrink();
                            }
                            final userData = userSnap.data!.data() as Map<String, dynamic>;
                            final name = userData['name'] ?? 'Someone';
                            final role = userData['role'] ?? 'Professional';
                            final company = userData['company'] ?? '';
                            final imageUrl = userData['profileImageUrl'] ?? '';
                            final initials = (name as String).substring(0, 1).toUpperCase();

                            // Construct a Candidate object for the detail view
                            final c = Candidate(
                              uid: targetUid,
                              name: name,
                              role: role,
                              org: company,
                              loc: userData['currentLocationName'] ?? userData['homeBase'] ?? '',
                              match: 95, // Default high match for favorites
                              intent: List<String>.from(userData['intents'] ?? []).join(', '),
                              tags: List<String>.from(userData['expertise'] ?? []),
                              interests: List<String>.from(userData['interests'] ?? []),
                              skills: List<String>.from(userData['skills'] ?? []),
                              homeBase: userData['homeBase'] ?? '',
                              bio: userData['bio'] ?? '',
                              initials: initials,
                              profileImageUrl: imageUrl,
                              primaryColor: const Color(0xFFE5A475),
                            );

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: const Color(0xFFFAF0E6),
                                  backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                                  child: imageUrl.isEmpty
                                      ? Text(initials, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7A432D)))
                                      : null,
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF3E1F11)),
                                ),
                                subtitle: Text(
                                  '$role${company.isNotEmpty ? ' at $company' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: Color(0xFF8C736B)),
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7A432D),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context); // Close favorites sheet
                                    _showFavoriteProfileDetailsSheet(context, c);
                                  },
                                  child: const Text(
                                    'View Profile',
                                    style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
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
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF8C736B)),
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
}

class _InterestStyle {
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  const _InterestStyle(this.icon, this.backgroundColor, this.foregroundColor);
}

