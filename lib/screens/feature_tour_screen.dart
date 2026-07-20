import 'package:flutter/material.dart';

/// A one-time visual walkthrough shown after a newly registered user completes
/// their profile. It demonstrates the core discovery and chat interactions.
class FeatureTourScreen extends StatefulWidget {
  final Future<void> Function() onComplete;

  const FeatureTourScreen({super.key, required this.onComplete});

  @override
  State<FeatureTourScreen> createState() => _FeatureTourScreenState();
}

class _FeatureTourScreenState extends State<FeatureTourScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _cueController;
  int _pageIndex = 0;
  bool _isCompleting = false;

  static const _stories = [
    _TourStory(
      eyebrow: 'DISCOVER',
      title: 'Meet people\nworth knowing.',
      description:
          'Browse tailored professional cards and find people with goals that complement yours.',
    ),
    _TourStory(
      eyebrow: 'CONNECT',
      title: 'Swipe to make\na connection.',
      description:
          'Swipe right when you would like to connect. Pass with a left swipe and keep exploring.',
    ),
    _TourStory(
      eyebrow: 'CHAT',
      title: 'Start the\nconversation.',
      description:
          'After you connect, tap the chat icon to introduce yourself, share ideas, and plan a meet-up.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _cueController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cueController.dispose();
    super.dispose();
  }

  Future<void> _advance() async {
    if (_pageIndex < _stories.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    try {
      await widget.onComplete();
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.height < 680;

    return Material(
      color: const Color(0xFFFAF7F5),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 18, 8),
              child: Row(
                children: [
                  Text(
                    'NEXMEET GUIDE',
                    style: TextStyle(
                      color: const Color(0xFF7A432D).withValues(alpha: 0.8),
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isCompleting ? null : _finish,
                    child: const Text('Skip tour'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: List.generate(
                  _stories.length,
                  (index) => Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      height: 4,
                      margin: EdgeInsets.only(
                        right: index == _stories.length - 1 ? 0 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: index <= _pageIndex
                            ? const Color(0xFF7A432D)
                            : const Color(0xFFE8E2DD),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _stories.length,
                onPageChanged: (index) => setState(() => _pageIndex = index),
                itemBuilder: (context, index) {
                  return _TourPage(
                    story: _stories[index],
                    pageIndex: index,
                    cue: _cueController,
                    compact: isCompact,
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, isCompact ? 16 : 28),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isCompleting ? null : _advance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7A432D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isCompleting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          _pageIndex == _stories.length - 1
                              ? 'Start exploring'
                              : 'Continue',
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TourPage extends StatelessWidget {
  final _TourStory story;
  final int pageIndex;
  final Animation<double> cue;
  final bool compact;

  const _TourPage({
    required this.story,
    required this.pageIndex,
    required this.cue,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, compact ? 18 : 34, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: '${story.eyebrow} walkthrough illustration',
            child: SizedBox(
              height: compact ? 280 : 350,
              width: double.infinity,
              child: AnimatedBuilder(
                animation: cue,
                builder: (context, _) => switch (pageIndex) {
                  0 => _DiscoverPreview(phase: cue.value),
                  1 => _SwipePreview(phase: cue.value),
                  _ => _ChatPreview(phase: cue.value),
                },
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            story.eyebrow,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: Color(0xFFE5A475),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            story.title,
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              color: const Color(0xFF3E1F11),
              fontSize: compact ? 29 : 34,
              fontWeight: FontWeight.w700,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            story.description,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: Color(0xFF6B554B),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverPreview extends StatelessWidget {
  final double phase;

  const _DiscoverPreview({required this.phase});

  @override
  Widget build(BuildContext context) {
    final handX = -18 + phase * 34;
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 12,
          left: 24,
          child: Transform.rotate(
            angle: -0.11,
            child: const _GhostCard(label: 'Product · Design'),
          ),
        ),
        Positioned(
          top: 18,
          right: 18,
          child: Transform.rotate(
            angle: 0.1,
            child: const _GhostCard(label: 'Technology · AI'),
          ),
        ),
        const _ProfileCard(),
        Positioned(
          bottom: 10,
          child: Column(
            children: [
              const Text(
                'A profile picked for you',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Color(0xFF7A432D),
                ),
              ),
              Transform.translate(
                offset: Offset(handX, 8),
                child: const Icon(
                  Icons.touch_app_rounded,
                  size: 38,
                  color: Color(0xFF7A432D),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SwipePreview extends StatelessWidget {
  final double phase;

  const _SwipePreview({required this.phase});

  @override
  Widget build(BuildContext context) {
    final x = -20 + phase * 62;
    final opacity = 0.55 + phase * 0.45;
    return Stack(
      alignment: Alignment.center,
      children: [
        const Positioned(top: 16, child: _ProfileCard()),
        Positioned(
          top: 46,
          right: 30,
          child: Opacity(
            opacity: opacity,
            child: const _ActionBadge(icon: Icons.favorite_rounded, label: 'CONNECT'),
          ),
        ),
        Positioned(
          bottom: 64,
          child: Row(
            children: const [
              _ActionCircle(icon: Icons.close_rounded, color: Color(0xFF8C736B)),
              SizedBox(width: 38),
              _ActionCircle(icon: Icons.favorite_rounded, color: Color(0xFFB74A4A)),
            ],
          ),
        ),
        Positioned(
          bottom: 2,
          child: Transform.translate(
            offset: Offset(x, 0),
            child: const Icon(
              Icons.touch_app_rounded,
              size: 39,
              color: Color(0xFF7A432D),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatPreview extends StatelessWidget {
  final double phase;

  const _ChatPreview({required this.phase});

  @override
  Widget build(BuildContext context) {
    final reveal = Curves.easeOut.transform((phase * 1.8).clamp(0.0, 1.0));
    return Center(
      child: Container(
        width: 280,
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE8E2DD)),
          boxShadow: const [
            BoxShadow(color: Color(0x1F3E1F11), blurRadius: 24, offset: Offset(0, 12)),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 12, 12),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFE5A475),
                    child: Text('SK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Sarah Khan', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w800, color: Color(0xFF3E1F11))),
                  ),
                  const Icon(Icons.more_horiz, color: Color(0xFF8C736B)),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE8E2DD)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Opacity(
                      opacity: reveal,
                      child: const _ChatBubble(text: 'Hi! Great to connect with you.', incoming: true),
                    ),
                    const SizedBox(height: 9),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Opacity(
                        opacity: (reveal - 0.2).clamp(0.0, 1.0).toDouble(),
                        child: const _ChatBubble(text: 'Likewise — shall we meet at the event?', incoming: false),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      height: 39,
                      padding: const EdgeInsets.only(left: 12, right: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE8E2DD)),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text('Type a message...', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, color: Color(0xFF8C736B))),
                          ),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const CircleAvatar(
                                radius: 14,
                                backgroundColor: Color(0xFF7A432D),
                                child: Icon(Icons.chat_bubble_rounded, size: 15, color: Colors.white),
                              ),
                              Positioned(
                                right: -18 + phase * 12,
                                bottom: -17 + phase * 5,
                                child: const Icon(Icons.touch_app_rounded, size: 32, color: Color(0xFF7A432D)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x243E1F11), blurRadius: 20, offset: Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 34,
            backgroundColor: Color(0xFFE5A475),
            child: Icon(Icons.person_rounded, size: 44, color: Colors.white),
          ),
          const Spacer(),
          const Text('Sarah Khan', style: TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF3E1F11))),
          const SizedBox(height: 3),
          const Text('Product strategist · Mumbai', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, color: Color(0xFF8C736B))),
          const SizedBox(height: 10),
          Wrap(
            spacing: 5,
            children: const [
              _Tag(label: 'Startups'),
              _Tag(label: 'Design'),
            ],
          ),
        ],
      ),
    );
  }
}

class _GhostCard extends StatelessWidget {
  final String label;

  const _GhostCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      height: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2E6DF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Text(label, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF8C736B))),
      ),
    );
  }
}

class _ActionBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActionBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB74A4A).withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFB74A4A)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontFamily: 'PlusJakartaSans', color: Color(0xFFB74A4A), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
        ],
      ),
    );
  }
}

class _ActionCircle extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _ActionCircle({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Color(0x173E1F11), blurRadius: 12)],
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;

  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF0EA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFF7A432D))),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool incoming;

  const _ChatBubble({required this.text, required this.incoming});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 185),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: incoming ? const Color(0xFFF2E6DF) : const Color(0xFF7A432D),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          color: incoming ? const Color(0xFF3E1F11) : Colors.white,
          fontSize: 10,
          height: 1.35,
        ),
      ),
    );
  }
}

class _TourStory {
  final String eyebrow;
  final String title;
  final String description;

  const _TourStory({
    required this.eyebrow,
    required this.title,
    required this.description,
  });
}
