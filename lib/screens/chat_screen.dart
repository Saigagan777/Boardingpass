import 'dart:async';
import 'package:flutter/material.dart';
import '../state_manager.dart';
import '../models/message.dart';

class ChatScreen extends StatefulWidget {
  final String? name;
  final VoidCallback? onMeet;
  final VoidCallback? onBack;
  const ChatScreen({super.key, this.name, this.onMeet, this.onBack});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final AppStateManager _state = AppStateManager();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Voice player animation state
  String? _playingVoiceId;
  double _voiceProgress = 0.0;
  Timer? _voiceTimer;
  int _voiceSecondsRemaining = 0;

  String? _selectedContactName;

  final List<Map<String, dynamic>> _contacts = [
    {
      'name': 'Ananya Rao',
      'role': 'Partner',
      'org': 'Lumen Ventures',
      'initials': 'AR',
      'avatarColor': const Color(0xFFE5A475),
      'lastMessage': 'When are you free for a quick chat?',
      'time': '9:40',
      'unread': true,
      'online': true,
      'location': 'BLR T2 lounge',
    },
    {
      'name': 'Vikram Shah',
      'role': 'VP Engineering',
      'org': 'Stripe APAC',
      'initials': 'VS',
      'avatarColor': const Color(0xFF68B2DF),
      'lastMessage': "Hey, let's swap notes on risk + ledger design.",
      'time': 'Yesterday',
      'unread': false,
      'online': true,
      'location': 'Gate 14',
    },
    {
      'name': 'Priya Iyer',
      'role': 'Head of SME',
      'org': 'HDFC Bank',
      'initials': 'PI',
      'avatarColor': const Color(0xFFE9659A),
      'lastMessage': 'Looking forward to our discussion.',
      'time': '2 days ago',
      'unread': false,
      'online': false,
      'location': 'Plaza Premium',
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedContactName = widget.name;
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.name != oldWidget.name) {
      setState(() {
        _selectedContactName = widget.name;
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _voiceTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final newMsg = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      kind: MessageKind.text,
      from: MessageSender.me,
      text: text,
      time: "${TimeOfDay.now().hour.toString().padLeft(2, '0')}:${TimeOfDay.now().minute.toString().padLeft(2, '0')}",
      contactName: _selectedContactName,
    );

    _state.addMessage(newMsg);
    _inputController.clear();
    _scrollToBottom();
  }

  void _toggleVoicePlayback(String msgId, int durationSeconds) {
    if (_playingVoiceId == msgId) {
      // Pause
      _voiceTimer?.cancel();
      setState(() {
        _playingVoiceId = null;
        _voiceProgress = 0.0;
      });
    } else {
      // Play
      _voiceTimer?.cancel();
      setState(() {
        _playingVoiceId = msgId;
        _voiceProgress = 0.0;
        _voiceSecondsRemaining = durationSeconds;
      });

      const tickMs = 100;
      final totalTicks = durationSeconds * 10;
      int currentTick = 0;

      _voiceTimer = Timer.periodic(const Duration(milliseconds: tickMs), (timer) {
        if (mounted) {
          setState(() {
            currentTick++;
            _voiceProgress = currentTick / totalTicks;
            if (currentTick % 10 == 0) {
              _voiceSecondsRemaining = durationSeconds - (currentTick ~/ 10);
            }
            if (currentTick >= totalTicks) {
              _voiceTimer?.cancel();
              _playingVoiceId = null;
              _voiceProgress = 0.0;
            }
          });
        } else {
          timer.cancel();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, child) {
        if (_selectedContactName == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFFAF7F5),
            appBar: AppBar(
              backgroundColor: const Color(0xFFFAF7F5),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF3E1F11)),
                onPressed: widget.onBack ?? () {
                  _state.currentScreen = AppScreen.hub;
                },
              ),
              title: const Text(
                'Conversations',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3E1F11),
                ),
              ),
            ),
            body: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _contacts.length,
              separatorBuilder: (context, index) => const Divider(
                color: Color(0xFFE8E2DD),
                height: 1,
                indent: 76,
              ),
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                
                // Get last message info
                final threadMsgs = _state.messages.where((m) =>
                  (m.contactName == contact['name']) ||
                  (m.contactName == null && contact['name'] == 'Ananya Rao')
                ).toList();
                
                String lastText = contact['lastMessage'];
                String lastTime = contact['time'];
                
                if (threadMsgs.isNotEmpty) {
                  final lastMsgObj = threadMsgs.last;
                  if (lastMsgObj.kind == MessageKind.text) {
                    lastText = lastMsgObj.text ?? lastText;
                  } else if (lastMsgObj.kind == MessageKind.voice) {
                    lastText = "🎤 Voice Note (${lastMsgObj.seconds}s)";
                  } else if (lastMsgObj.kind == MessageKind.pin) {
                    lastText = "📍 Location: ${lastMsgObj.place}";
                  }
                  lastTime = lastMsgObj.time;
                }

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedContactName = contact['name'];
                    });
                    _state.activeChatContact = contact['name'];
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Avatar
                        Stack(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: contact['avatarColor'],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                contact['initials'],
                                style: const TextStyle(
                                  fontFamily: 'PlayfairDisplay',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (contact['online'])
                              Positioned(
                                right: 1,
                                bottom: 1,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.green,
                                    border: Border.all(color: const Color(0xFFFAF7F5), width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),

                        // Text Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    contact['name'],
                                    style: TextStyle(
                                      fontFamily: 'PlayfairDisplay',
                                      fontSize: 15.5,
                                      fontWeight: contact['unread'] ? FontWeight.bold : FontWeight.w600,
                                      color: const Color(0xFF3E1F11),
                                    ),
                                  ),
                                  Text(
                                    lastTime,
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 10,
                                      color: contact['unread'] ? const Color(0xFF7A432D) : const Color(0xFF8C736B),
                                      fontWeight: contact['unread'] ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${contact['role']} · ${contact['org']}',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  color: Color(0xFF8C736B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                lastText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12.5,
                                  color: contact['unread'] ? const Color(0xFF3E1F11) : const Color(0xFF5C473E),
                                  fontWeight: contact['unread'] ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }

        // Detailed chat view for a selected contact
        final contactInfo = _contacts.firstWhere(
          (c) => c['name'] == _selectedContactName,
          orElse: () => _contacts[0],
        );

        final filteredMsgs = _state.messages.where((m) =>
          (m.contactName == _selectedContactName) ||
          (m.contactName == null && _selectedContactName == 'Ananya Rao')
        ).toList();

        return Scaffold(
          backgroundColor: const Color(0xFFFAF7F5),
          appBar: AppBar(
            backgroundColor: const Color(0xFFFAF7F5),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF3E1F11)),
              onPressed: () {
                setState(() {
                  _selectedContactName = null;
                });
                _state.activeChatContact = null;
              },
            ),
            title: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: contactInfo['avatarColor'],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    contactInfo['initials'],
                    style: const TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contactInfo['name'],
                        style: const TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                      Row(
                        children: [
                          if (contactInfo['online']) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            contactInfo['online']
                                ? 'Online · ${contactInfo['location']}'
                                : 'Offline',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 10,
                              color: Color(0xFF8C736B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.calendar_month, color: Color(0xFF7A432D)),
                onPressed: widget.onMeet ?? () {
                  _state.currentScreen = AppScreen.meeting;
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Messages area
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: filteredMsgs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final msg = filteredMsgs[index];
                    return _buildMessageBubble(msg);
                  },
                ),
              ),

              // Bottom Input Bar
              _buildInputBar(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(Message msg) {
    final isMe = msg.from == MessageSender.me;
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isMe ? const Color(0xFF7A432D) : Colors.white;
    final textColor = isMe ? Colors.white : const Color(0xFF3E1F11);
    final timeColor = isMe ? Colors.white70 : const Color(0xFF8C736B);

    return Column(
      crossAxisAlignment: align,
      children: [
        // Message body bubble
        Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: bubbleColor,
                  border: isMe ? null : Border.all(color: const Color(0xFFE8E2DD)),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                    bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    )
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: _buildBubbleContent(msg, textColor),
              ),
            ),
          ],
        ),

        // Reactions and timestamp
        const SizedBox(height: 4),
        Padding(
          padding: EdgeInsets.only(left: isMe ? 0 : 8, right: isMe ? 8 : 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (msg.reactions.isNotEmpty) ...[
                Wrap(
                  spacing: 4,
                  children: msg.reactions.map((react) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE8E2DD)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        react,
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                msg.time,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 9,
                  color: timeColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBubbleContent(Message msg, Color textColor) {
    switch (msg.kind) {
      case MessageKind.text:
        return Text(
          msg.text ?? '',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13.5,
            color: textColor,
            height: 1.35,
          ),
        );

      case MessageKind.voice:
        final duration = msg.seconds ?? 10;
        final isPlaying = _playingVoiceId == msg.id;
        final dispSeconds = isPlaying ? _voiceSecondsRemaining : duration;

        return SizedBox(
          width: 180,
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: textColor,
                  size: 28,
                ),
                onPressed: () => _toggleVoicePlayback(msg.id, duration),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Waveform lines visualizer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(16, (i) {
                        // Create simulated peaks
                        final double h = (i % 3 == 0) ? 14 : (i % 2 == 0 ? 8 : 4);
                        final isActive = isPlaying && (i / 16.0) <= _voiceProgress;
                        return Container(
                          width: 2.2,
                          height: h,
                          color: isActive 
                              ? (msg.from == MessageSender.me ? const Color(0xFFE5A475) : const Color(0xFF7A432D)) 
                              : textColor.withValues(alpha: 0.4),
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Voice Memo • 0:${dispSeconds.toString().padLeft(2, "0")}',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10,
                        color: textColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case MessageKind.pin:
        return SizedBox(
          width: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, color: textColor, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Pinned Location',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                msg.place ?? '',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Text(
                msg.meta ?? '',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 10,
                  color: textColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        );

      case MessageKind.poll:
        final options = msg.options ?? [];
        final pickedIdx = msg.picked;
        final hasVoted = pickedIdx != null;

        return SizedBox(
          width: 210,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg.question ?? '',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Column(
                children: List.generate(options.length, (optIndex) {
                  final isPicked = pickedIdx == optIndex;
                  final percentage = optIndex == 0 ? 60 : (optIndex == 1 ? 25 : 15);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      onTap: () {
                        if (!hasVoted) {
                          _state.answerPoll(msg.id, optIndex);
                        }
                      },
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          // Percentage bar background tracking
                          if (hasVoted)
                            Positioned.fill(
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: percentage / 100,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isPicked
                                        ? (msg.from == MessageSender.me ? Colors.white12 : const Color(0xFF7A432D).withValues(alpha: 0.15))
                                        : (msg.from == MessageSender.me ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE8E2DD).withValues(alpha: 0.5)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          // Content Row
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isPicked 
                                    ? (msg.from == MessageSender.me ? Colors.white38 : const Color(0xFF7A432D).withValues(alpha: 0.6))
                                    : const Color(0xFFE8E2DD),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  options[optIndex],
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11.5,
                                    color: textColor,
                                    fontWeight: isPicked ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                if (hasVoted)
                                  Text(
                                    '$percentage%',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );

      default:
        return const SizedBox();
    }
  }

  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE8E2DD), width: 1.2),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Voice memo button
            IconButton(
              icon: const Icon(Icons.mic_none_outlined, color: Color(0xFF8C736B)),
              onPressed: () {
                // Mock add voice memo
                final voiceMsg = Message(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  kind: MessageKind.voice,
                  from: MessageSender.me,
                  seconds: 8,
                  time: "${TimeOfDay.now().hour.toString().padLeft(2, '0')}:${TimeOfDay.now().minute.toString().padLeft(2, '0')}",
                );
                _state.addMessage(voiceMsg);
                _scrollToBottom();
              },
            ),

            // Emoji button
            IconButton(
              icon: const Icon(Icons.sentiment_satisfied_alt_outlined, color: Color(0xFF8C736B)),
              onPressed: () {},
            ),

            // Input field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE8E2DD)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _inputController,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    color: Color(0xFF3E1F11),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: Color(0xFF8C736B), fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onSubmitted: (_) => _handleSendMessage(),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Send button
            IconButton(
              icon: const Icon(Icons.send_rounded, color: Color(0xFF7A432D)),
              onPressed: _handleSendMessage,
            ),
          ],
        ),
      ),
    );
  }
}
