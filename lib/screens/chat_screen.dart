import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../state_manager.dart';
import '../models/message.dart';
import '../models/user_profile.dart';
import '../services/chat_service.dart';
import '../services/moderation_service.dart';
import '../services/meeting_service.dart';
import '../utils/image_helper.dart';
import '../services/user_service.dart';
import '../utils/match_calculator.dart';
import 'candidate_profile_sheet.dart';
import '../models/venue.dart';
import '../services/venue_repository.dart';

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
  Duration _voicePosition = Duration.zero;
  Duration _voiceDuration = Duration.zero;

  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _playerPositionSubscription;
  StreamSubscription? _playerDurationSubscription;

  // Typing indicator state
  Timer? _typingDebounceTimer;
  bool _isCurrentlyTyping = false;
  String? _otherUid;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _chatDocStream;

  String? _chatId;
  bool _isBlocked = false;
  bool _isUnmatching = false;
  bool _isUploadingAttachment = false;
  String? _selectedContactName;

  // Audio services
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;
  String? _tempRecordPath;

  // Other user details for avatar
  String? _otherUserProfileImage;
  String? _otherUserInitials; // Group chat, search, replies, mentions state
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _selectedReplyMsg;
  bool _showMentionsList = false;
  List<UserProfile> _mentionsSuggestions = [];
  List<String> _selectedMentionUids = [];
  List<UserProfile> _groupMembers = [];

  Future<String?> _ensureChatId() async {
    if (_chatId != null) return _chatId;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || _otherUid == null) return null;
    try {
      final cid = await ChatService().getOrCreateChat(
        userId1: currentUid,
        userId2: _otherUid!,
      );
      if (mounted) {
        setState(() {
          _chatId = cid;
          _chatDocStream = FirebaseFirestore.instance
              .collection('chats')
              .doc(cid)
              .snapshots();
        });
      }
      return cid;
    } catch (e) {
      debugPrint('Error ensuring lazy chat ID: $e');
      return null;
    }
  }

  void _showUserProfileBottomSheet(String targetUid) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha((0.35 * 255).round()),
      builder: (context) {
        return CandidateProfileSheet.lazy(
          targetUid: targetUid,
          currentUid: currentUid,
        );
      },
    );
  }

  Future<void> _handleUnmatch() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final targetUid = _otherUid;
    final targetName = _selectedContactName ?? 'this user';
    if (currentUid == null || targetUid == null || _isUnmatching) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFAF7F5),
          title: Text(
            'Unmatch with $targetName?',
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E1F11),
            ),
          ),
          content: const Text(
            'This removes the connection and chat from both chat lists. You can only chat again after matching again.',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: Color(0xFF5C473E),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  color: Color(0xFF8C736B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Unmatch',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    setState(() {
      _isUnmatching = true;
    });

    try {
      await ChatService().unmatch(
        currentUid: currentUid,
        otherUid: targetUid,
        chatId: _chatId,
      );
      await _state.loadCandidates();

      if (!mounted) return;
      setState(() {
        _isUnmatching = false;
        _isBlocked = true;
        _showSearch = false;
        _selectedReplyMsg = null;
        _selectedMentionUids = [];
        _showMentionsList = false;
        _inputController.clear();
        _searchController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF7A432D),
          content: Text(
            'Unmatched with $targetName. Conversation is now read-only.',
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUnmatching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFC62828),
          content: Text(
            'Failed to unmatch: $e',
            style: const TextStyle(fontFamily: 'PlusJakartaSans'),
          ),
        ),
      );
    }
  }

  Future<void> _showReportDialog() async {
    final targetUid = _otherUid;
    if (targetUid == null) return;
    final reasonController = TextEditingController();
    var submitting = false;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report this user'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tell our safety team what happened. Your report is private.'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                minLines: 3,
                maxLines: 5,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Describe the abusive or unsafe behaviour',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: submitting ? null : () async {
                setDialogState(() => submitting = true);
                try {
                  await ModerationService.instance.reportUser(
                    reportedUserId: targetUid,
                    reason: reasonController.text,
                    chatId: _chatId,
                  );
                  if (context.mounted) Navigator.pop(dialogContext, true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                    );
                  }
                  setDialogState(() => submitting = false);
                }
              },
              icon: submitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.flag_outlined),
              label: const Text('Send report'),
            ),
          ],
        ),
      ),
    );
    reasonController.dispose();
    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Our safety team will review it.')),
      );
    }
  }

  void _initializeChat() async {
    final contactName = _selectedContactName;
    if (contactName == null) {
      setState(() {
        _chatId = null;
        _isBlocked = false;
      });
      return;
    }

    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) return;

      // Group Chat Bypass
      if (_chatId != null) {
        final chatDoc = await FirebaseFirestore.instance
            .collection('chats')
            .doc(_chatId)
            .get();
        if (chatDoc.exists && chatDoc.data()?['isGroup'] == true) {
          final data = chatDoc.data()!;
          final participantIds = List<String>.from(data['participants'] ?? []);

          final memberProfiles = <UserProfile>[];
          for (final id in participantIds) {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(id)
                .get();
            if (userDoc.exists) {
              memberProfiles.add(UserProfile.fromFirestore(userDoc));
            }
          }

          if (mounted) {
            setState(() {
              _isBlocked = false;
              _otherUserProfileImage = data['groupImageUrl'] as String?;
              _otherUserInitials = (data['groupName'] as String? ?? 'GP')
                  .trim()
                  .split(' ')
                  .map((e) => e[0])
                  .take(2)
                  .join()
                  .toUpperCase();
              _otherUid = null;
              _groupMembers = memberProfiles;
              _chatDocStream = FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatId)
                  .snapshots();
            });
          }
          _scrollToBottom();
          return;
        }
      }

      String otherUid = '';
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isEqualTo: contactName)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        otherUid = userQuery.docs.first.id;
        final userData = userQuery.docs.first.data();
        final profileImageUrl = userData['profileImageUrl'] as String?;
        final name = userData['name'] as String? ?? contactName;
        final initials = name.isNotEmpty
            ? name
                  .trim()
                  .split(' ')
                  .map((e) => e[0])
                  .take(2)
                  .join()
                  .toUpperCase()
            : 'P';
        if (mounted) {
          setState(() {
            _otherUserProfileImage = profileImageUrl;
            _otherUserInitials = initials;
            _otherUid = otherUid;
          });
        }
      } else {
        otherUid = 'dummy_${contactName.replaceAll(' ', '_').toLowerCase()}';
        final initials = contactName.isNotEmpty
            ? contactName
                  .trim()
                  .split(' ')
                  .map((e) => e[0])
                  .take(2)
                  .join()
                  .toUpperCase()
            : 'P';
        if (mounted) {
          setState(() {
            _otherUserInitials = initials;
            _otherUid = otherUid;
          });
        }
      }

      // Query if there is already a chat doc
      final chatQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('isGroup', isEqualTo: false)
          .where('participants', arrayContains: currentUid)
          .get();

      String? foundChatId;
      for (final doc in chatQuery.docs) {
        final participants = List<String>.from(
          doc.data()['participants'] ?? [],
        );
        if (participants.contains(otherUid)) {
          foundChatId = doc.id;
          break;
        }
      }

      // Check if users are connected
      final isConnected = await ChatService().hasConnection(
        currentUid,
        otherUid,
      );

      if (!isConnected) {
        if (foundChatId != null) {
          // Unmatched, but past conversation exists. Allow viewing, block messaging.
          if (mounted && _selectedContactName == contactName) {
            setState(() {
              _isBlocked = true;
              _chatId = foundChatId;
              _chatDocStream = FirebaseFirestore.instance
                  .collection('chats')
                  .doc(foundChatId)
                  .snapshots();
            });
            _scrollToBottom();
          }
        } else {
          // Never matched / no conversation
          if (mounted && _selectedContactName == contactName) {
            setState(() {
              _isBlocked = true;
              _chatId = null;
              _chatDocStream = null;
            });
          }
        }
        return;
      }

      if (mounted && _selectedContactName == contactName) {
        setState(() {
          _isBlocked = false;
          _chatId = foundChatId;
          if (foundChatId != null) {
            _chatDocStream = FirebaseFirestore.instance
                .collection('chats')
                .doc(foundChatId)
                .snapshots();
          } else {
            _chatDocStream = null;
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error initializing chat: $e');
    }
  }

  void _openGroupChat(String chatId, String name) {
    setState(() {
      _chatId = chatId;
      _selectedContactName = name;
    });
    _initializeChat();
  }

  @override
  void initState() {
    super.initState();
    _selectedContactName = widget.name;
    _initializeChat();
    _initAudioPlayerListener();
    _inputController.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.name != oldWidget.name) {
      setState(() {
        _selectedContactName = widget.name;
      });
      _initializeChat();
    }
  }

  @override
  void dispose() {
    _inputController.removeListener(_onTextChanged);
    _inputController.dispose();
    _scrollController.dispose();
    _recordTimer?.cancel();
    _typingDebounceTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _playerStateSubscription?.cancel();
    _playerPositionSubscription?.cancel();
    _playerDurationSubscription?.cancel();
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

  void _handleSendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final cid = await _ensureChatId();
    if (cid == null) return;

    _inputController.clear();
    _resetTypingState();

    final replyPayload = _selectedReplyMsg;
    final mentionsPayload = List<String>.from(_selectedMentionUids);

    setState(() {
      _selectedReplyMsg = null;
      _selectedMentionUids = [];
      _showMentionsList = false;
    });

    try {
      await ChatService().sendTextMessage(
        chatId: cid,
        text: text,
        replyTo: replyPayload,
        mentions: mentionsPayload,
      );
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  Future<void> _pickAndSendPhoto({
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
      );
      if (image == null) return;

      await _uploadAndSendAttachment(
        bytes: await image.readAsBytes(),
        fileName: image.name.isEmpty ? 'photo.jpg' : image.name,
        isPhoto: true,
      );
    } catch (e) {
      _showAttachmentError('Could not select that photo.');
      debugPrint('Photo selection failed: $e');
    }
  }

  Future<void> _pickAndSendDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx'],
        withData: true,
      );
      final file = result?.files.single;
      if (file == null || file.bytes == null) return;

      await _uploadAndSendAttachment(
        bytes: file.bytes!,
        fileName: file.name,
        isPhoto: false,
      );
    } catch (e) {
      _showAttachmentError('Could not select that document.');
      debugPrint('Document selection failed: $e');
    }
  }

  Future<void> _uploadAndSendAttachment({
    required List<int> bytes,
    required String fileName,
    required bool isPhoto,
  }) async {
    final cid = await _ensureChatId();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (cid == null || uid == null) {
      _showAttachmentError('Unable to open this conversation.');
      return;
    }

    if (mounted) setState(() => _isUploadingAttachment = true);
    try {
      final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'chat_attachments/$cid/$uid/${timestamp}_$safeName';
      final ref = FirebaseStorage.instance.ref().child(path);
      await ref.putData(
        Uint8List.fromList(bytes),
        SettableMetadata(contentType: _contentTypeFor(fileName, isPhoto)),
      );
      final downloadUrl = await ref.getDownloadURL();
      final replyTo = _selectedReplyMsg;
      final mentions = List<String>.from(_selectedMentionUids);

      if (isPhoto) {
        await ChatService().sendImageMessage(
          chatId: cid,
          imageUrl: downloadUrl,
          replyTo: replyTo,
          mentions: mentions,
        );
      } else {
        await ChatService().sendFileMessage(
          chatId: cid,
          fileUrl: downloadUrl,
          fileName: fileName,
          fileSize: bytes.length,
          replyTo: replyTo,
          mentions: mentions,
        );
      }

      if (!mounted) return;
      setState(() {
        _selectedReplyMsg = null;
        _selectedMentionUids = [];
        _showMentionsList = false;
      });
      _scrollToBottom();
    } catch (e) {
      _showAttachmentError('Upload failed. Please try again.');
      debugPrint('Attachment upload failed: $e');
    } finally {
      if (mounted) setState(() => _isUploadingAttachment = false);
    }
  }

  String _contentTypeFor(String fileName, bool isPhoto) {
    final extension = fileName.split('.').last.toLowerCase();
    if (isPhoto) {
      return switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        _ => 'image/jpeg',
      };
    }
    return switch (extension) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'txt' => 'text/plain',
      _ => 'application/octet-stream',
    };
  }

  void _showAttachmentError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: const Color(0xFFC62828), content: Text(message)),
    );
  }

  void _openImagePreview(Message message) {
    final imageUrl = message.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ChatImagePreview(
          imageUrl: imageUrl,
          heroTag: 'chat-image-${message.id}',
        ),
      ),
    );
  }

  void _initAudioPlayerListener() {
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((
      PlayerState state,
    ) {
      if (state == PlayerState.completed) {
        if (mounted) {
          setState(() {
            _playingVoiceId = null;
            _voiceProgress = 0.0;
            _voicePosition = Duration.zero;
          });
        }
      }
    });

    _playerPositionSubscription = _audioPlayer.onPositionChanged.listen((
      Duration p,
    ) {
      if (mounted && _playingVoiceId != null) {
        setState(() {
          _voicePosition = p;
          final durationMs = _voiceDuration.inMilliseconds;
          if (durationMs > 0) {
            _voiceProgress = p.inMilliseconds / durationMs;
          }
        });
      }
    });

    _playerDurationSubscription = _audioPlayer.onDurationChanged.listen((
      Duration d,
    ) {
      if (mounted && _playingVoiceId != null) {
        setState(() {
          _voiceDuration = d;
        });
      }
    });
  }

  void _onTextChanged() {
    final text = _inputController.text;
    final isTyping = text.isNotEmpty;

    if (isTyping != _isCurrentlyTyping) {
      _isCurrentlyTyping = isTyping;
      _updateTypingStatus(isTyping);
    }

    if (isTyping) {
      _typingDebounceTimer?.cancel();
      _typingDebounceTimer = Timer(const Duration(seconds: 3), () {
        if (_isCurrentlyTyping) {
          _isCurrentlyTyping = false;
          _updateTypingStatus(false);
        }
      });
    }

    // Mentions check
    final lastAt = text.lastIndexOf('@');
    if (lastAt != -1 && lastAt >= text.length - 15) {
      final query = text.substring(lastAt + 1).toLowerCase();
      _updateMentionsSuggestions(query);
    } else {
      if (_showMentionsList) {
        setState(() {
          _showMentionsList = false;
        });
      }
    }
  }

  void _updateTypingStatus(bool isTyping) {
    if (_chatId != null) {
      ChatService().updateTypingStatus(chatId: _chatId!, isTyping: isTyping);
    }
  }

  void _resetTypingState() {
    _typingDebounceTimer?.cancel();
    if (_isCurrentlyTyping) {
      _isCurrentlyTyping = false;
      _updateTypingStatus(false);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleVoicePlayback(Message msg, int durationSeconds) async {
    if (_playingVoiceId == msg.id) {
      await _audioPlayer.pause();
      if (mounted) {
        setState(() {
          _playingVoiceId = null;
          _voiceProgress = 0.0;
        });
      }
    } else {
      await _audioPlayer.stop();

      if (mounted) {
        setState(() {
          _playingVoiceId = msg.id;
          _voiceProgress = 0.0;
          _voiceDuration = Duration(seconds: durationSeconds);
          _voicePosition = Duration.zero;
        });
      }

      try {
        final audioUrl = msg.audioUrl;
        if (audioUrl != null && audioUrl.isNotEmpty) {
          if (audioUrl.startsWith('data:audio') ||
              !audioUrl.startsWith('http')) {
            String base64Data = audioUrl;
            if (audioUrl.contains(',')) {
              base64Data = audioUrl.split(',')[1];
            }
            final bytes = base64Decode(base64Data.trim());
            final tempDir = await getTemporaryDirectory();
            final tempFile = File('${tempDir.path}/temp_play_${msg.id}.m4a');
            await tempFile.writeAsBytes(bytes);
            await _audioPlayer.play(DeviceFileSource(tempFile.path));
          } else {
            await _audioPlayer.play(UrlSource(audioUrl));
          }
        }
      } catch (e) {
        debugPrint('Error playing audio: $e');
        if (mounted) {
          setState(() {
            _playingVoiceId = null;
          });
        }
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path =
            '${tempDir.path}/temp_record_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _tempRecordPath = path;

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        if (mounted) {
          setState(() {
            _isRecording = true;
            _recordDuration = 0;
          });
        }

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordDuration++;
            });
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Microphone permission is required to record voice memos.',
              ),
              backgroundColor: Color(0xFFC62828),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _cancelRecording() async {
    try {
      await _audioRecorder.stop();
      _recordTimer?.cancel();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordDuration = 0;
        });
      }
      if (_tempRecordPath != null) {
        final file = File(_tempRecordPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('Error cancelling recording: $e');
    }
  }

  Future<void> _sendRecordedVoice() async {
    try {
      final path = await _audioRecorder.stop();
      _recordTimer?.cancel();

      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }

      _resetTypingState();

      if (path != null) {
        final cid = await _ensureChatId();
        if (cid == null) return;

        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final base64Audio = base64Encode(bytes);
          final duration = _recordDuration > 0 ? _recordDuration : 1;

          await ChatService().sendVoiceMessage(
            chatId: cid,
            voiceDuration: duration,
            audioUrl: 'data:audio/m4a;base64,$base64Audio',
          );
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint('Error sending recording: $e');
    }
  }

  Future<Map<String, dynamic>?> _findPendingMeeting() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || _chatId == null) return null;

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .get();
      final participants = List<String>.from(
        chatDoc.data()?['participants'] ?? [],
      );
      final otherUid = participants.firstWhere(
        (p) => p != currentUid,
        orElse: () => '',
      );
      if (otherUid.isEmpty) return null;

      final meetingsQuery = await FirebaseFirestore.instance
          .collection('meetings')
          .where('participants', arrayContains: currentUid)
          .get();

      for (final doc in meetingsQuery.docs) {
        final data = doc.data();
        if (data['status'] == 'pending' &&
            data['participants'].contains(otherUid)) {
          final map = Map<String, dynamic>.from(data);
          map['meetingId'] = doc.id;
          return map;
        }
      }
    } catch (e) {
      debugPrint('Error finding pending meeting: $e');
    }
    return null;
  }

  Future<void> _handleMeetingActionFromChat(
    String meetingId,
    bool isAccept,
    String location,
    String timeStr,
  ) async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null || _chatId == null) return;

      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .get();
      final participants = List<String>.from(
        chatDoc.data()?['participants'] ?? [],
      );
      final otherUid = participants.firstWhere(
        (p) => p != currentUid,
        orElse: () => '',
      );
      if (otherUid.isEmpty) return;
      if (isAccept) {
        final meetingDoc = await FirebaseFirestore.instance
            .collection('meetings')
            .doc(meetingId)
            .get();
        final scheduledTimestamp =
            meetingDoc.data()?['scheduledAt'] as Timestamp?;
        if (scheduledTimestamp != null) {
          final scheduledAt = scheduledTimestamp.toDate();

          final myConflict = await MeetingService().hasMeetingConflict(
            currentUid,
            scheduledAt,
          );
          if (myConflict) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Cannot accept. You already have a confirmed meeting around this time.',
                ),
                backgroundColor: Color(0xFFC62828),
              ),
            );
            return;
          }

          final otherConflict = await MeetingService().hasMeetingConflict(
            otherUid,
            scheduledAt,
          );
          if (otherConflict) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Cannot accept. The other participant already has a confirmed meeting around this time.',
                ),
                backgroundColor: Color(0xFFC62828),
              ),
            );
            return;
          }
        }

        await MeetingService().updateParticipantStatus(
          meetingId: meetingId,
          userId: currentUid,
          status: 'accepted',
        );

        final responseMsg =
            "✅ Meeting Accepted: I'm down to meet at $location on $timeStr";
        await ChatService().sendTextMessage(
          chatId: _chatId!,
          text: responseMsg,
        );

        if (!mounted) return;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meeting accepted!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      } else {
        await _showCancellationReasonDialog(
          meetingId,
          currentUid,
          otherUid,
          location,
          timeStr,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update meeting: $e'),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    }
  }

  void _showProposeOtherTimeDialog(String meetingId, String location) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = TimeOfDay.now();
    final noteController = TextEditingController();
    int selectedReminderMinutes = 15;
    String? conflictWarning;
    bool isValidating = false;
    bool initialCheckDone = false;

    Future<void> checkConflicts(StateSetter setSheetState) async {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null || _otherUid == null) return;

      setSheetState(() {
        isValidating = true;
      });

      try {
        final proposedTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        );

        final myConflict = await MeetingService().hasMeetingConflict(
          currentUid,
          proposedTime,
        );
        if (myConflict) {
          setSheetState(() {
            conflictWarning =
                "You already have a confirmed meeting around this time.";
            isValidating = false;
          });
          return;
        }

        final otherConflict = await MeetingService().hasMeetingConflict(
          _otherUid!,
          proposedTime,
        );
        if (otherConflict) {
          setSheetState(() {
            final otherName = _selectedContactName ?? 'The other participant';
            conflictWarning =
                "$otherName already has a confirmed meeting around this time.";
            isValidating = false;
          });
          return;
        }

        setSheetState(() {
          conflictWarning = null;
          isValidating = false;
        });
      } catch (e) {
        debugPrint('Error validating conflicts: $e');
        setSheetState(() {
          isValidating = false;
        });
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (!initialCheckDone) {
              initialCheckDone = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                checkConflicts(setSheetState);
              });
            }

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
                  const Text(
                    'Propose Another Time',
                    style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E1F11),
                    ),
                  ),
                  const Divider(color: Color(0xFFE8E2DD)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE8E2DD)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Color(0xFF7A432D),
                          ),
                          label: Text(
                            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              color: Color(0xFF3E1F11),
                            ),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null) {
                              setSheetState(() => selectedDate = picked);
                              checkConflicts(setSheetState);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE8E2DD)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(
                            Icons.access_time,
                            size: 16,
                            color: Color(0xFF7A432D),
                          ),
                          label: Text(
                            selectedTime.format(context),
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              color: Color(0xFF3E1F11),
                            ),
                          ),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (picked != null) {
                              setSheetState(() => selectedTime = picked);
                              checkConflicts(setSheetState);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'REMINDER',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Color(0xFF8C736B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE8E2DD)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedReminderMinutes,
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          color: Color(0xFF3E1F11),
                        ),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFF8C736B),
                        ),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('None')),
                          DropdownMenuItem(
                            value: 5,
                            child: Text('5 minutes before'),
                          ),
                          DropdownMenuItem(
                            value: 10,
                            child: Text('10 minutes before'),
                          ),
                          DropdownMenuItem(
                            value: 15,
                            child: Text('15 minutes before'),
                          ),
                          DropdownMenuItem(
                            value: 30,
                            child: Text('30 minutes before'),
                          ),
                          DropdownMenuItem(
                            value: 60,
                            child: Text('1 hour before'),
                          ),
                          DropdownMenuItem(
                            value: 1440,
                            child: Text('1 day before'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setSheetState(() {
                              selectedReminderMinutes = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      hintText: 'Add a note (optional)',
                      hintStyle: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        color: Color(0xFF8C736B),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  if (conflictWarning != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFD1D1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFC62828),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              conflictWarning!,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFC62828),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7A432D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isValidating
                          ? null
                          : () async {
                              if (conflictWarning != null) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: const Color(0xFFFAF7F5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: const BorderSide(
                                        color: Color(0xFFE8E2DD),
                                        width: 1.5,
                                      ),
                                    ),
                                    title: const Text(
                                      'Schedule Conflict',
                                      style: TextStyle(
                                        fontFamily: 'PlayfairDisplay',
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF3E1F11),
                                      ),
                                    ),
                                    content: Text(
                                      conflictWarning!,
                                      style: const TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        color: Color(0xFF3E1F11),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text(
                                          'OK',
                                          style: TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF7A432D),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                return;
                              }

                              final proposedDateTime = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              );
                              final timeStr =
                                  '${selectedDate.day}/${selectedDate.month}/${selectedDate.year} at ${selectedTime.format(context)}';
                              try {
                                await MeetingService().proposeOtherTime(
                                  meetingId: meetingId,
                                  proposedTime: proposedDateTime,
                                  note: noteController.text.trim(),
                                  reminderMinutes: selectedReminderMinutes,
                                );
                                if (_chatId != null) {
                                  final msg =
                                      '🔄 Proposed New Time: $timeStr for meeting at $location [meetingId:$meetingId]';
                                  await ChatService().sendTextMessage(
                                    chatId: _chatId!,
                                    text: msg,
                                  );
                                }
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('New time proposed!'),
                                      backgroundColor: Color(0xFF7A432D),
                                    ),
                                  );
                                  setState(() {});
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to propose time: $e',
                                      ),
                                      backgroundColor: const Color(0xFFC62828),
                                    ),
                                  );
                                }
                              }
                            },
                      child: const Text(
                        'Send Proposal',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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

  void _showQuickMeetingRequestSheet() {
    if (_otherUid == null || _chatId == null) return;

    DateTime selectedDate = DateTime.now().add(const Duration(hours: 1));
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);
    String selectedLocation = '';
    final noteController = TextEditingController();
    int selectedReminderMinutes = 15;
    String? conflictWarning;
    bool isValidating = false;
    bool initialCheckDone = false;

    final searchController = TextEditingController(text: selectedLocation);
    List<Venue> suggestions = [];
    final venueRepository = VenueRepositoryImpl();

    Future<void> checkConflicts(StateSetter setSheetState) async {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null || _otherUid == null) return;

      setSheetState(() {
        isValidating = true;
      });

      try {
        final proposedTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        );

        final myConflict = await MeetingService().hasMeetingConflict(
          currentUid,
          proposedTime,
        );
        if (myConflict) {
          setSheetState(() {
            conflictWarning =
                "You already have a confirmed meeting around this time.";
            isValidating = false;
          });
          return;
        }

        final otherConflict = await MeetingService().hasMeetingConflict(
          _otherUid!,
          proposedTime,
        );
        if (otherConflict) {
          setSheetState(() {
            final otherName = _selectedContactName ?? 'The other participant';
            conflictWarning =
                "$otherName already has a confirmed meeting around this time.";
            isValidating = false;
          });
          return;
        }

        setSheetState(() {
          conflictWarning = null;
          isValidating = false;
        });
      } catch (e) {
        debugPrint('Error validating conflicts: $e');
        setSheetState(() {
          isValidating = false;
        });
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (!initialCheckDone) {
              initialCheckDone = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                checkConflicts(setSheetState);
              });
            }

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
                  const Text(
                    'Request Meeting',
                    style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E1F11),
                    ),
                  ),
                  const Divider(color: Color(0xFFE8E2DD)),
                  const SizedBox(height: 8),
                  const Text(
                    'LOCATION',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8C736B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: searchController,
                    style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search meetings venue (e.g. Novotel, Cafe)...',
                      hintStyle: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: Color(0xFF8C736B)),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF8C736B)),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                searchController.clear();
                                setSheetState(() {
                                  selectedLocation = '';
                                  suggestions = [];
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE8E2DD), width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF7A432D), width: 1.5),
                      ),
                    ),
                    onChanged: (query) async {
                      if (query.trim().length < 3) {
                        setSheetState(() => suggestions = []);
                        return;
                      }
                      final results = await venueRepository.searchVenues(query);
                      setSheetState(() {
                        suggestions = results;
                      });
                    },
                  ),

                  // Autocomplete suggestions dropdown
                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 160),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE8E2DD)),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Material(
                        color: Colors.white,
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: suggestions.length,
                          itemBuilder: (context, index) {
                            final v = suggestions[index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.location_on, size: 18, color: Color(0xFF7A432D)),
                              title: Text(v.name, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.bold)),
                              subtitle: Text(v.formattedAddress, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                              onTap: () {
                                setSheetState(() {
                                  selectedLocation = v.name;
                                  searchController.text = v.name;
                                  suggestions = [];
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE8E2DD)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Color(0xFF7A432D),
                          ),
                          label: Text(
                            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              color: Color(0xFF3E1F11),
                            ),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null) {
                              setSheetState(() => selectedDate = picked);
                              checkConflicts(setSheetState);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE8E2DD)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(
                            Icons.access_time,
                            size: 16,
                            color: Color(0xFF7A432D),
                          ),
                          label: Text(
                            selectedTime.format(context),
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              color: Color(0xFF3E1F11),
                            ),
                          ),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (picked != null) {
                              setSheetState(() => selectedTime = picked);
                              checkConflicts(setSheetState);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'REMINDER',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Color(0xFF8C736B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE8E2DD)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedReminderMinutes,
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          color: Color(0xFF3E1F11),
                        ),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFF8C736B),
                        ),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('None')),
                          DropdownMenuItem(
                            value: 5,
                            child: Text('5 minutes before'),
                          ),
                          DropdownMenuItem(
                            value: 10,
                            child: Text('10 minutes before'),
                          ),
                          DropdownMenuItem(
                            value: 15,
                            child: Text('15 minutes before'),
                          ),
                          DropdownMenuItem(
                            value: 30,
                            child: Text('30 minutes before'),
                          ),
                          DropdownMenuItem(
                            value: 60,
                            child: Text('1 hour before'),
                          ),
                          DropdownMenuItem(
                            value: 1440,
                            child: Text('1 day before'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setSheetState(() {
                              selectedReminderMinutes = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      hintText: 'Add a note (optional)',
                      hintStyle: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        color: Color(0xFF8C736B),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  if (conflictWarning != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFD1D1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFC62828),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              conflictWarning!,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFC62828),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7A432D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isValidating
                          ? null
                          : () async {
                              if (conflictWarning != null) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: const Color(0xFFFAF7F5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: const BorderSide(
                                        color: Color(0xFFE8E2DD),
                                        width: 1.5,
                                      ),
                                    ),
                                    title: const Text(
                                      'Schedule Conflict',
                                      style: TextStyle(
                                        fontFamily: 'PlayfairDisplay',
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF3E1F11),
                                      ),
                                    ),
                                    content: Text(
                                      conflictWarning!,
                                      style: const TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        color: Color(0xFF3E1F11),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text(
                                          'OK',
                                          style: TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF7A432D),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                return;
                              }

                              try {
                                final scheduledAt = DateTime(
                                  selectedDate.year,
                                  selectedDate.month,
                                  selectedDate.day,
                                  selectedTime.hour,
                                  selectedTime.minute,
                                );

                                final timeStr =
                                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year} at ${selectedTime.format(context)}';
                                final meetingId = await MeetingService()
                                    .createMeeting(
                                      attendeeIds: [_otherUid!],
                                      scheduledAt: scheduledAt,
                                      location: selectedLocation,
                                      note: noteController.text.trim(),
                                      chatId: _chatId,
                                      reminderMinutes: selectedReminderMinutes,
                                    );

                                final msg =
                                    "📅 Meeting Request: Let's meet at $selectedLocation on $timeStr [meetingId:$meetingId]";
                                await ChatService().sendTextMessage(
                                  chatId: _chatId!,
                                  text: msg,
                                );

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Meeting request sent!'),
                                      backgroundColor: Color(0xFF2E7D32),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to send meeting request: $e',
                                      ),
                                      backgroundColor: const Color(0xFFC62828),
                                    ),
                                  );
                                }
                              }
                            },
                      child: const Text(
                        'Send Meeting Request',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    String text;
    if (_isSameDay(date, now)) {
      text = 'Today';
    } else if (_isSameDay(date, yesterday)) {
      text = 'Yesterday';
    } else {
      text =
          "${date.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1]} ${date.year}";
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE8E2DD)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8C736B),
          ),
        ),
      ),
    );
  }

  Future<void> _openDirections(String location, Map<String, dynamic>? venueSnapshot) async {
    double? lat;
    double? lng;
    if (venueSnapshot != null) {
      lat = double.tryParse(venueSnapshot['latitude'].toString());
      lng = double.tryParse(venueSnapshot['longitude'].toString());
    }

    String url;
    if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
      url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    } else {
      url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}';
    }

    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Could not launch map URL: $url - Error: $e');
    }
  }

  Widget _buildInlineMeetingRequestCard(Message msg, String text) {
    final isMe = msg.from == MessageSender.me;

    String venue = 'Lounge';
    String timeDetails = 'Scheduled Time';

    // Parse meetingId if embedded
    final meetingIdRegex = RegExp(r'\[meetingId:([^\]]+)\]');
    final match = meetingIdRegex.firstMatch(text);
    final String? embeddedMeetingId = match?.group(1);

    // Clean text by stripping out [meetingId:...] for clean display
    String cleanText = text;
    final bracketIndex = text.indexOf(" [meetingId:");
    if (bracketIndex != -1) {
      cleanText = text.substring(0, bracketIndex);
    }

    final requestPrefix = "📅 Meeting Request: Let's meet at ";
    final proposalPrefix = "🔄 Proposed New Time: ";

    if (cleanText.startsWith(requestPrefix)) {
      final atIndex = cleanText.indexOf("Let's meet at ");
      final onIndex = cleanText.indexOf(" on ");
      if (atIndex != -1 && onIndex != -1) {
        venue = cleanText.substring(atIndex + 14, onIndex);
        timeDetails = cleanText.substring(onIndex + 4);
      }
    } else if (cleanText.startsWith(proposalPrefix)) {
      final forMeetingAtIndex = cleanText.indexOf(" for meeting at ");
      if (forMeetingAtIndex != -1) {
        timeDetails = cleanText.substring(
          proposalPrefix.length,
          forMeetingAtIndex,
        );
        venue = cleanText.substring(forMeetingAtIndex + 16);
      }
    }

    return Container(
      width: 230,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF7A432D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isMe ? null : Border.all(color: const Color(0xFFE8E2DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event,
                color: isMe ? Colors.white : const Color(0xFF7A432D),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                cleanText.startsWith(proposalPrefix)
                    ? 'Reschedule Proposal'
                    : 'Meeting Proposal',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isMe ? Colors.white : const Color(0xFF3E1F11),
                ),
              ),
            ],
          ),
          const Divider(height: 16, color: Colors.white24),
          Text(
            'VENUE',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isMe ? Colors.white60 : const Color(0xFF8C736B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            venue,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isMe ? Colors.white : const Color(0xFF3E1F11),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'TIME',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isMe ? Colors.white60 : const Color(0xFF8C736B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            timeDetails,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isMe ? Colors.white : const Color(0xFF3E1F11),
            ),
          ),
          if (embeddedMeetingId != null)
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('meetings')
                  .doc(embeddedMeetingId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  final isVirtual = venue.toLowerCase().contains('virtual') ||
                      venue.toLowerCase().contains('online') ||
                      venue == 'Not specified';
                  if (isVirtual) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isMe ? Colors.white : const Color(0xFF7A432D),
                          side: BorderSide(color: isMe ? Colors.white60 : const Color(0xFF7A432D)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        ),
                        icon: Icon(Icons.map_outlined, size: 14, color: isMe ? Colors.white : const Color(0xFF7A432D)),
                        label: const Text(
                          'Directions',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () => _openDirections(venue, null),
                      ),
                    ),
                  );
                }

                final mData = snapshot.data!.data()!;
                final mLoc = mData['location'] as String? ?? venue;
                final isVirtual = mLoc.toLowerCase().contains('virtual') ||
                    mLoc.toLowerCase().contains('online') ||
                    mLoc == 'Not specified';
                if (isVirtual) return const SizedBox.shrink();

                final venueSnapshot = mData['selectedVenueSnapshot'] as Map<String, dynamic>?;

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isMe ? Colors.white : const Color(0xFF7A432D),
                        side: BorderSide(color: isMe ? Colors.white60 : const Color(0xFF7A432D)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      ),
                      icon: Icon(Icons.map_outlined, size: 14, color: isMe ? Colors.white : const Color(0xFF7A432D)),
                      label: const Text(
                        'Directions',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => _openDirections(mLoc, venueSnapshot),
                    ),
                  ),
                );
              },
            )
          else ...[
            Builder(builder: (context) {
              final isVirtual = venue.toLowerCase().contains('virtual') ||
                  venue.toLowerCase().contains('online') ||
                  venue == 'Not specified';
              if (isVirtual) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isMe ? Colors.white : const Color(0xFF7A432D),
                      side: BorderSide(color: isMe ? Colors.white60 : const Color(0xFF7A432D)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    ),
                    icon: Icon(Icons.map_outlined, size: 14, color: isMe ? Colors.white : const Color(0xFF7A432D)),
                    label: const Text(
                      'Directions',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _openDirections(venue, null),
                  ),
                ),
              );
            }),
          ],
          if (!isMe) ...[
            const SizedBox(height: 12),
            embeddedMeetingId != null
                ? StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('meetings')
                        .doc(embeddedMeetingId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 32,
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF7A432D),
                              ),
                            ),
                          ),
                        );
                      }
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return const SizedBox.shrink();
                      }
                      final data = snapshot.data!.data()!;
                      final meetingId = snapshot.data!.id;
                      final location = data['location'] as String? ?? venue;
                      final statusStr = data['status'] as String? ?? 'pending';

                      final currentUid = FirebaseAuth.instance.currentUser?.uid;
                      if (currentUid == null) return const SizedBox.shrink();
                      final statusMap = Map<String, dynamic>.from(
                        data['participantsStatus'] ?? {},
                      );
                      final myStatus =
                          statusMap[currentUid] as String? ?? 'pending';
                      final reminderMinutes = data['reminderMinutes'] as int?;
                      final participants = List<String>.from(
                        data['participants'] ?? [],
                      );
                      final otherUid = participants.firstWhere(
                        (p) => p != currentUid,
                        orElse: () => '',
                      );

                      final isRescheduleRequested =
                          statusStr == 'RESCHEDULE_REQUESTED';
                      final isReschedulePendingForMe =
                          statusStr == 'RESCHEDULE_APPROVED' &&
                          myStatus == 'pending';

                      if (!isRescheduleRequested &&
                          !isReschedulePendingForMe &&
                          (statusStr != 'pending' || myStatus != 'pending')) {
                        String messageText = '';
                        Color textColor;
                        if (statusStr == 'RESCHEDULE_APPROVED' ||
                            statusStr == 'rescheduled') {
                          messageText = '✓ Rescheduled';
                          textColor = const Color(0xFF2E7D32);
                        } else if (statusStr == 'RESCHEDULE_REJECTED') {
                          messageText = '✗ Reschedule Declined';
                          textColor = const Color(0xFFC62828);
                        } else if (myStatus == 'accepted') {
                          messageText = '✓ Approved';
                          textColor = const Color(0xFF2E7D32);
                        } else if (myStatus == 'cancelled') {
                          messageText = '✗ Cancelled';
                          textColor = const Color(0xFFC62828);
                        } else if (myStatus == 'proposed_other_time') {
                          messageText = '🔄 Other Time Proposed';
                          textColor = const Color(0xFF7A432D);
                        } else {
                          messageText = 'Responded';
                          textColor = Colors.grey;
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            messageText,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        );
                      }

                      if (isRescheduleRequested) {
                        final proposals = List<Map<String, dynamic>>.from(
                          data['proposals'] ?? [],
                        );
                        final activeProposal = proposals.firstWhere(
                          (p) => p['status'] == 'active',
                          orElse: () => {},
                        );
                        final String? proposalId =
                            activeProposal['proposalId'] as String?;
                        final String? proposedBy =
                            activeProposal['proposedBy'] as String?;

                        if (proposedBy == currentUid) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Waiting for response',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFEF6C00),
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: [
                            if (reminderMinutes != null &&
                                reminderMinutes > 0) ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.notifications_active_outlined,
                                    size: 14,
                                    color: const Color(0xFF8C736B),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    reminderMinutes == 1440
                                        ? "Reminder: 1 day before"
                                        : (reminderMinutes == 60
                                              ? "Reminder: 1 hour before"
                                              : "Reminder: $reminderMinutes minutes before"),
                                    style: const TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF3E1F11),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Color(0xFFC62828),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                    ),
                                    onPressed: () async {
                                      if (proposalId != null) {
                                        try {
                                          await MeetingService()
                                              .declineProposal(
                                                meetingId: meetingId,
                                                proposalId: proposalId,
                                              );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Proposal declined.',
                                                ),
                                                backgroundColor: Color(
                                                  0xFFC62828,
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text('Failed: $e'),
                                                backgroundColor: const Color(
                                                  0xFFC62828,
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                                    child: const Text(
                                      'Decline',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFC62828),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2E7D32),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                    ),
                                    onPressed: () async {
                                      if (proposalId != null) {
                                        try {
                                          final proposedTimestamp =
                                              activeProposal['proposedTime']
                                                  as Timestamp?;
                                          if (proposedTimestamp != null) {
                                            final proposedTime =
                                                proposedTimestamp.toDate();
                                            final myConflict =
                                                await MeetingService()
                                                    .hasMeetingConflict(
                                                      currentUid,
                                                      proposedTime,
                                                    );
                                            if (myConflict) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Cannot accept. You already have a confirmed meeting around this time.',
                                                    ),
                                                    backgroundColor: Color(
                                                      0xFFC62828,
                                                    ),
                                                  ),
                                                );
                                              }
                                              return;
                                            }

                                            if (otherUid.isNotEmpty) {
                                              final otherConflict =
                                                  await MeetingService()
                                                      .hasMeetingConflict(
                                                        otherUid,
                                                        proposedTime,
                                                      );
                                              if (otherConflict) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Cannot accept. The other participant already has a confirmed meeting around this time.',
                                                      ),
                                                      backgroundColor: Color(
                                                        0xFFC62828,
                                                      ),
                                                    ),
                                                  );
                                                }
                                                return;
                                              }
                                            }
                                          }

                                          await MeetingService().acceptProposal(
                                            meetingId: meetingId,
                                            proposalId: proposalId,
                                          );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Meeting rescheduled successfully!',
                                                ),
                                                backgroundColor: Color(
                                                  0xFF2E7D32,
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text('Failed: $e'),
                                                backgroundColor: const Color(
                                                  0xFFC62828,
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                                    child: const Text(
                                      'Approve',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFF7A432D),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.schedule,
                                  size: 14,
                                  color: Color(0xFF7A432D),
                                ),
                                label: const Text(
                                  'Propose Other Time',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7A432D),
                                  ),
                                ),
                                onPressed: () => _showProposeOtherTimeDialog(
                                  meetingId,
                                  location,
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFFC62828),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                  ),
                                  onPressed: () => _handleMeetingActionFromChat(
                                    meetingId,
                                    false,
                                    location,
                                    timeDetails,
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFC62828),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E7D32),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                  ),
                                  onPressed: () => _handleMeetingActionFromChat(
                                    meetingId,
                                    true,
                                    location,
                                    timeDetails,
                                  ),
                                  child: const Text(
                                    'Approve',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF7A432D),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                              ),
                              icon: const Icon(
                                Icons.schedule,
                                size: 14,
                                color: Color(0xFF7A432D),
                              ),
                              label: const Text(
                                'Propose Other Time',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7A432D),
                                ),
                              ),
                              onPressed: () => _showProposeOtherTimeDialog(
                                meetingId,
                                location,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  )
                : FutureBuilder<Map<String, dynamic>?>(
                    future: _findPendingMeeting(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 32,
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF7A432D),
                              ),
                            ),
                          ),
                        );
                      }
                      final meeting = snapshot.data;
                      if (meeting == null) {
                        return const SizedBox.shrink();
                      }
                      final meetingId = meeting['meetingId'] as String;
                      final location = meeting['location'] as String? ?? venue;

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFFC62828),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                  ),
                                  onPressed: () => _handleMeetingActionFromChat(
                                    meetingId,
                                    false,
                                    location,
                                    timeDetails,
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFC62828),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E7D32),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                  ),
                                  onPressed: () => _handleMeetingActionFromChat(
                                    meetingId,
                                    true,
                                    location,
                                    timeDetails,
                                  ),
                                  child: const Text(
                                    'Approve',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF7A432D),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                              ),
                              icon: const Icon(
                                Icons.schedule,
                                size: 14,
                                color: Color(0xFF7A432D),
                              ),
                              label: const Text(
                                'Propose Other Time',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7A432D),
                                ),
                              ),
                              onPressed: () => _showProposeOtherTimeDialog(
                                meetingId,
                                location,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedContactName == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAF7F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFAF7F5),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF3E1F11)),
            onPressed:
                widget.onBack ??
                () {
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
          actions: [
            IconButton(
              icon: const Icon(
                Icons.group_add_outlined,
                color: Color(0xFF7A432D),
              ),
              onPressed: () => _showCreateGroupModal(context),
              tooltip: 'New Group Chat',
            ),
          ],
        ),
        body: Column(
          children: [
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ChatService().streamUserGroupInvitations(),
              builder: (context, inviteSnapshot) {
                if (!inviteSnapshot.hasData ||
                    inviteSnapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }
                final invites = inviteSnapshot.data!.docs;
                return Container(
                  width: double.infinity,
                  color: const Color(0xFFFAF2EE),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PENDING GROUP INVITATIONS',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Color(0xFF7A432D),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: invites.length,
                        separatorBuilder: (context, idx) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final doc = invites[idx];
                          final data = doc.data();
                          final groupName = data['groupName'] ?? 'Group Chat';
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE8E2DD),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        groupName,
                                        style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF3E1F11),
                                        ),
                                      ),
                                      const Text(
                                        'Invited you to join.',
                                        style: TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 12,
                                          color: Color(0xFF8C736B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => ChatService()
                                      .acceptGroupInvitation(doc.id),
                                  child: const Text(
                                    'Accept',
                                    style: TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => ChatService()
                                      .declineGroupInvitation(doc.id),
                                  child: const Text(
                                    'Decline',
                                    style: TextStyle(color: Color(0xFFC62828)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            Expanded(
              child: StreamBuilder<UserProfile?>(
                stream: UserService().streamCurrentUserProfile(),
                builder: (context, currentUserSnapshot) {
                  final currentUser = currentUserSnapshot.data;
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: ChatService().streamUserChats(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF7A432D),
                            ),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      final chatDocs =
                          List<
                            QueryDocumentSnapshot<Map<String, dynamic>>
                          >.from(snapshot.data?.docs ?? []);
                      chatDocs.sort((a, b) {
                        final aTime = a.data()['updatedAt'] as Timestamp?;
                        final bTime = b.data()['updatedAt'] as Timestamp?;
                        if (aTime == null && bTime == null) return 0;
                        if (aTime == null) return -1;
                        if (bTime == null) return 1;
                        return bTime.compareTo(aTime);
                      });
                      if (chatDocs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: Color(0xFF8C736B),
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No active conversations yet.',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3E1F11),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Go to the Discover tab to connect with people nearby.',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  color: Color(0xFF8C736B),
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7A432D),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  _state.currentScreen = AppScreen.discover;
                                },
                                child: const Text(
                                  'Discover Connections',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: chatDocs.length,
                        separatorBuilder: (context, index) => const Divider(
                          color: Color(0xFFE8E2DD),
                          height: 1,
                          indent: 76,
                        ),
                        itemBuilder: (context, index) {
                          final chatDoc = chatDocs[index];
                          final chatData = chatDoc.data();
                          final currentUid =
                              FirebaseAuth.instance.currentUser?.uid;
                          final isGroup = chatData['isGroup'] == true;

                          if (isGroup) {
                            final String groupName =
                                chatData['groupName'] ?? 'Group Chat';
                            final String groupImageUrl =
                                chatData['groupImageUrl'] ?? '';
                            final List<String> participants = List<String>.from(
                              chatData['participants'] ?? [],
                            );
                            final int participantCount = participants.length;

                            final lastMsgInfo =
                                chatData['lastMessage']
                                    as Map<String, dynamic>?;
                            final String lastText =
                                lastMsgInfo?['text'] ??
                                'Say hello to start the conversation!';
                            final String senderName =
                                lastMsgInfo?['senderName'] ?? '';
                            final String displayText = senderName.isNotEmpty
                                ? '$senderName: $lastText'
                                : lastText;

                            String lastTime = 'now';
                            final ts = lastMsgInfo?['timestamp'] as Timestamp?;
                            if (ts != null) {
                              final dt = ts.toDate();
                              lastTime =
                                  '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                            }

                            final unreadMap =
                                chatData['unreadCount']
                                    as Map<String, dynamic>?;
                            final int unreadCount = unreadMap?[currentUid] ?? 0;
                            final bool isUnread = unreadCount > 0;

                            final String initials = groupName.isNotEmpty
                                ? groupName
                                      .trim()
                                      .split(' ')
                                      .map((e) => e[0])
                                      .take(2)
                                      .join()
                                      .toUpperCase()
                                : 'GP';

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedContactName = groupName;
                                  _chatId = chatDoc.id;
                                  _chatDocStream = FirebaseFirestore.instance
                                      .collection('chats')
                                      .doc(chatDoc.id)
                                      .snapshots();
                                });
                                _state.activeChatContact = groupName;
                                _scrollToBottom();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF7A432D),
                                      ),
                                      child: ClipOval(
                                        child: buildProfileImage(
                                          groupImageUrl,
                                          fit: BoxFit.cover,
                                          fallback: Center(
                                            child: Text(
                                              initials,
                                              style: const TextStyle(
                                                fontFamily: 'PlayfairDisplay',
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                groupName,
                                                style: TextStyle(
                                                  fontFamily: 'PlayfairDisplay',
                                                  fontSize: 15.5,
                                                  fontWeight: isUnread
                                                      ? FontWeight.bold
                                                      : FontWeight.w600,
                                                  color: const Color(
                                                    0xFF3E1F11,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                lastTime,
                                                style: TextStyle(
                                                  fontFamily: 'PlusJakartaSans',
                                                  fontSize: 10,
                                                  color: isUnread
                                                      ? const Color(0xFF7A432D)
                                                      : const Color(0xFF8C736B),
                                                  fontWeight: isUnread
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '$participantCount members',
                                            style: const TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              fontSize: 11,
                                              color: Color(0xFF8C736B),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            displayText,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              fontSize: 12.5,
                                              color: isUnread
                                                  ? const Color(0xFF3E1F11)
                                                  : const Color(0xFF5C473E),
                                              fontWeight: isUnread
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
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

                          final participants = List<String>.from(
                            chatData['participants'] ?? [],
                          );
                          final otherUid = participants.firstWhere(
                            (uid) => uid != currentUid,
                            orElse: () => '',
                          );

                          return StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(otherUid)
                                .snapshots(),
                            builder: (context, userSnapshot) {
                              if (!userSnapshot.hasData) {
                                return const SizedBox(height: 72);
                              }
                              final userData =
                                  userSnapshot.data?.data()
                                      as Map<String, dynamic>?;
                              final String name =
                                  userData?['name'] ?? 'Professional';
                              final String role =
                                  userData?['role'] ?? 'Founder';
                              final String org =
                                  userData?['company'] ?? 'Startup';
                              final String profileImageUrl =
                                  userData?['profileImageUrl'] ?? '';

                              final targetSkills = List<String>.from(
                                userData?['skills'] ?? [],
                              );
                              final targetInterests = List<String>.from(
                                userData?['interests'] ?? [],
                              );
                              final targetExpertise = List<String>.from(
                                userData?['expertise'] ?? [],
                              );
                              final targetIntents = List<String>.from(
                                userData?['intents'] ?? [],
                              );

                              final int? matchScore = currentUser != null
                                  ? calculateMatchScore(
                                      currentUid: currentUser.uid,
                                      targetUid: otherUid,
                                      currentSkills: currentUser.skills,
                                      currentInterests: currentUser.interests,
                                      currentExpertise: currentUser.expertise,
                                      currentIntents: currentUser.intents,
                                      targetSkills: targetSkills,
                                      targetInterests: targetInterests,
                                      targetExpertise: targetExpertise,
                                      targetIntents: targetIntents,
                                    )
                                  : (userData?['matchScore'] as int?);
                              final String initials = name.isNotEmpty
                                  ? name
                                        .trim()
                                        .split(' ')
                                        .map((e) => e[0])
                                        .take(2)
                                        .join()
                                        .toUpperCase()
                                  : 'P';

                              final DateTime? lastSeen =
                                  (userData?['lastSeen'] as Timestamp?)
                                      ?.toDate();
                              final bool isOnline =
                                  lastSeen != null &&
                                  DateTime.now()
                                          .difference(lastSeen)
                                          .inMinutes <
                                      5;

                              final lastMsgInfo =
                                  chatData['lastMessage']
                                      as Map<String, dynamic>?;
                              final String lastText =
                                  lastMsgInfo?['text'] ??
                                  'Say hello to start the conversation!';

                              String lastTime = 'now';
                              final ts =
                                  lastMsgInfo?['timestamp'] as Timestamp?;
                              if (ts != null) {
                                final dt = ts.toDate();
                                lastTime =
                                    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                              }

                              final unreadMap =
                                  chatData['unreadCount']
                                      as Map<String, dynamic>?;
                              final int unreadCount =
                                  unreadMap?[currentUid] ?? 0;
                              final bool isUnread = unreadCount > 0;

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedContactName = name;
                                  });
                                  _state.activeChatContact = name;
                                  _initializeChat();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Stack(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Color(0xFFE5A475),
                                            ),
                                            child: ClipOval(
                                              child: buildProfileImage(
                                                profileImageUrl,
                                                fit: BoxFit.cover,
                                                fallback: Center(
                                                  child: Text(
                                                    initials,
                                                    style: const TextStyle(
                                                      fontFamily:
                                                          'PlayfairDisplay',
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 1,
                                            right: 1,
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: isOnline
                                                    ? const Color(0xFF2E7D32)
                                                    : const Color(0xFF9E9E9E),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          name,
                                                          style: TextStyle(
                                                            fontFamily:
                                                                'PlayfairDisplay',
                                                            fontSize: 15.5,
                                                            fontWeight: isUnread
                                                                ? FontWeight
                                                                      .bold
                                                                : FontWeight
                                                                      .w600,
                                                            color: const Color(
                                                              0xFF3E1F11,
                                                            ),
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      if (matchScore != null &&
                                                          matchScore > 0) ...[
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 2,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color:
                                                                const Color(
                                                                  0xFFE5A475,
                                                                ).withValues(
                                                                  alpha: 0.15,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  10,
                                                                ),
                                                            border: Border.all(
                                                              color:
                                                                  const Color(
                                                                    0xFFE5A475,
                                                                  ).withValues(
                                                                    alpha: 0.4,
                                                                  ),
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              const Icon(
                                                                Icons.star,
                                                                color: Color(
                                                                  0xFF7A432D,
                                                                ),
                                                                size: 8,
                                                              ),
                                                              const SizedBox(
                                                                width: 2,
                                                              ),
                                                              Text(
                                                                '$matchScore% match',
                                                                style: const TextStyle(
                                                                  fontFamily:
                                                                      'PlusJakartaSans',
                                                                  fontSize: 8,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Color(
                                                                    0xFF7A432D,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  lastTime,
                                                  style: TextStyle(
                                                    fontFamily:
                                                        'PlusJakartaSans',
                                                    fontSize: 10,
                                                    color: isUnread
                                                        ? const Color(
                                                            0xFF7A432D,
                                                          )
                                                        : const Color(
                                                            0xFF8C736B,
                                                          ),
                                                    fontWeight: isUnread
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '$role ┬╖ $org',
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
                                                color: isUnread
                                                    ? const Color(0xFF3E1F11)
                                                    : const Color(0xFF5C473E),
                                                fontWeight: isUnread
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
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
    }
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
              _chatId = null;
              _showSearch = false;
              _searchController.clear();
            });
            _state.activeChatContact = null;
          },
        ),
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  color: Color(0xFF3E1F11),
                ),
                decoration: const InputDecoration(
                  hintText: 'Search messages...',
                  hintStyle: TextStyle(color: Color(0xFF8C736B)),
                  border: InputBorder.none,
                ),
                onChanged: (_) {
                  setState(() {});
                },
              )
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _chatId != null
                    ? FirebaseFirestore.instance
                          .collection('chats')
                          .doc(_chatId)
                          .snapshots()
                    : const Stream.empty(),
                builder: (context, chatSnap) {
                  final chatData = chatSnap.data?.data();
                  final isGroup = chatData?['isGroup'] == true;

                  if (isGroup) {
                    final groupName =
                        chatData?['groupName'] ??
                        _selectedContactName ??
                        'Group';
                    final groupImageUrl = chatData?['groupImageUrl'] ?? '';
                    final participants = List<String>.from(
                      chatData?['participants'] ?? [],
                    );
                    final count = participants.length;
                    final initials = groupName.isNotEmpty
                        ? groupName
                              .trim()
                              .split(' ')
                              .map((e) => e[0])
                              .take(2)
                              .join()
                              .toUpperCase()
                        : 'GP';

                    return GestureDetector(
                      onTap: () => _showGroupSettingsSheet(context),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF7A432D),
                            ),
                            child: ClipOval(
                              child: buildProfileImage(
                                groupImageUrl,
                                fit: BoxFit.cover,
                                fallback: Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      fontFamily: 'PlayfairDisplay',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  groupName,
                                  style: const TextStyle(
                                    fontFamily: 'PlayfairDisplay',
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3E1F11),
                                  ),
                                ),
                                Text(
                                  "$count members",
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 10,
                                    color: Color(0xFF8C736B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('name', isEqualTo: _selectedContactName)
                        .limit(1)
                        .snapshots(),
                    builder: (context, userSnapshot) {
                      final Map<String, dynamic> userData =
                          (userSnapshot.data?.docs.isNotEmpty == true)
                          ? userSnapshot.data!.docs.first.data()
                                as Map<String, dynamic>
                          : {
                              'name': _selectedContactName ?? 'Professional',
                              'role': 'Founder',
                              'company': 'Startup',
                            };

                      final String name = userData['name'] ?? 'Professional';
                      final String role = userData['role'] ?? 'Founder';
                      final String org = userData['company'] ?? 'Startup';
                      final String profileImageUrl =
                          userData['profileImageUrl'] ?? '';
                      final String initials = name.isNotEmpty
                          ? name
                                .trim()
                                .split(' ')
                                .map((e) => e[0])
                                .take(2)
                                .join()
                                .toUpperCase()
                          : 'P';

                      final DateTime? lastSeen =
                          (userData['lastSeen'] as Timestamp?)?.toDate();
                      final bool isOnline =
                          lastSeen != null &&
                          DateTime.now().difference(lastSeen).inMinutes < 5;

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (_otherUid != null) {
                            _showUserProfileBottomSheet(_otherUid!);
                          }
                        },
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFE5A475),
                                  ),
                                  child: ClipOval(
                                    child: buildProfileImage(
                                      profileImageUrl,
                                      fit: BoxFit.cover,
                                      fallback: Center(
                                        child: Text(
                                          initials,
                                          style: const TextStyle(
                                            fontFamily: 'PlayfairDisplay',
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: isOnline
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFF9E9E9E),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontFamily: 'PlayfairDisplay',
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF3E1F11),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          "$role · $org",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 10,
                                            color: Color(0xFF8C736B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
        actions: [
          if (_otherUid != null)
            PopupMenuButton<String>(
              enabled: !_isUnmatching,
              icon: _isUnmatching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF7A432D),
                      ),
                    )
                  : const Icon(
                      Icons.more_vert_rounded,
                      color: Color(0xFF7A432D),
                    ),
              onSelected: (value) {
                if (value == 'unmatch') {
                  _handleUnmatch();
                } else if (value == 'report') {
                  _showReportDialog();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'unmatch',
                  child: Row(
                    children: const [
                      Icon(
                        Icons.link_off_rounded,
                        size: 18,
                        color: Color(0xFFC62828),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Unmatch',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFC62828),
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, size: 18, color: Color(0xFFC62828)),
                      SizedBox(width: 10),
                      Text('Report user', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.bold, color: Color(0xFFC62828))),
                    ],
                  ),
                ),
              ],
            ),
          if (_chatId != null)
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatId)
                  .snapshots(),
              builder: (context, chatSnap) {
                final chatData = chatSnap.data?.data();
                final isGroup = chatData?['isGroup'] == true;
                if (isGroup) {
                  return IconButton(
                    icon: const Icon(
                      Icons.person_add_alt_1,
                      color: Color(0xFF7A432D),
                    ),
                    onPressed: () =>
                        _showAddMemberDialogFromAppBar(context, chatData!),
                    tooltip: 'Add Member',
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          IconButton(
            icon: Icon(
              _showSearch ? Icons.close : Icons.search,
              color: const Color(0xFF7A432D),
            ),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                }
              });
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _chatId != null
            ? ChatService().streamMessages(_chatId!)
            : const Stream.empty(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _chatId == null) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7A432D)),
              ),
            );
          }
          final messageDocs = snapshot.data?.docs ?? [];
          final currentUid = FirebaseAuth.instance.currentUser?.uid;

          final List<Message> filteredMsgs = messageDocs
              .where((doc) {
                final hiddenFor = List<String>.from(
                  doc.data()['hiddenFor'] ?? [],
                );
                return currentUid == null || !hiddenFor.contains(currentUid);
              })
              .map((doc) {
                final data = doc.data();
                final senderId = data['senderId'] ?? '';
                final from = (senderId == currentUid)
                    ? MessageSender.me
                    : MessageSender.them;

                final ts = data['createdAt'] as Timestamp?;
                final dt = ts?.toDate() ?? DateTime.now();
                final time =
                    "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

                final typeStr = data['type'] ?? 'text';
                final kind = MessageKind.values.firstWhere(
                  (k) => k.name == typeStr,
                  orElse: () => MessageKind.text,
                );

                return Message(
                  id: doc.id,
                  kind: kind,
                  from: from,
                  time: time,
                  reactions: List<String>.from(data['reactions'] ?? []),
                  reactionsMap: Map<String, String>.from(
                    data['reactionsMap'] ?? {},
                  ),
                  senderId: senderId,
                  senderName: data['senderName'],
                  text: data['text'],
                  seconds: data['voiceDuration'],
                  audioUrl: data['audioUrl'],
                  place: data['place'],
                  meta: data['meta'],
                  question: data['question'],
                  options: data['options'] != null
                      ? List<String>.from(data['options'])
                      : null,
                  picked: data['picked'],
                  imageUrl: data['imageUrl'],
                  fileUrl: data['fileUrl'],
                  fileName: data['fileName'],
                  fileSize: data['fileSize'],
                  linkUrl: data['linkUrl'],
                  linkTitle: data['linkTitle'],
                  linkDescription: data['linkDescription'],
                  replyTo: data['replyTo'] != null
                      ? Map<String, dynamic>.from(data['replyTo'])
                      : null,
                  mentions: data['mentions'] != null
                      ? List<String>.from(data['mentions'])
                      : const [],
                  isRead:
                      (data['readBy'] as List?) != null &&
                      (data['readBy'] as List).length > 1,
                  createdAt: dt,
                );
              })
              .toList();

          // Mark messages as read reactively
          if (_chatId != null) {
            ChatService().markMessagesAsRead(_chatId!);
          }

          final query = _searchController.text.trim().toLowerCase();
          final listToShow = query.isEmpty
              ? filteredMsgs
              : filteredMsgs
                    .where((m) => (m.text ?? '').toLowerCase().contains(query))
                    .toList();

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _chatDocStream,
            builder: (context, chatSnapshot) {
              final chatData = chatSnapshot.data?.data();
              final participants = List<String>.from(
                chatData?['participants'] ?? [],
              );
              final isChatUnavailable =
                  chatSnapshot.hasData &&
                  (chatSnapshot.data?.exists == false ||
                      (chatData != null &&
                          currentUid != null &&
                          !participants.contains(currentUid)));
              if (isChatUnavailable) {
                return Column(
                  children: [
                    const Expanded(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'This conversation is no longer available.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3E1F11),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildConnectionRequiredBar(
                      'Match again before messaging this user.',
                    ),
                  ],
                );
              }
              final pinnedList = List<Map<String, dynamic>>.from(
                (chatData?['pinnedMessages'] as List?)?.map(
                      (e) => Map<String, dynamic>.from(e),
                    ) ??
                    [],
              );
              final typingStatus =
                  chatData?['typingStatus'] as Map<String, dynamic>?;

              // Resolve group typing status
              bool isAnyOtherTyping = false;
              if (typingStatus != null) {
                final typingUids = typingStatus.entries
                    .where((e) => e.key != currentUid && e.value == true)
                    .map((e) => e.key)
                    .toList();
                if (typingUids.isNotEmpty) {
                  isAnyOtherTyping = true;
                }
              }

              return Column(
                children: [
                  if (pinnedList.isNotEmpty) _buildPinnedHeader(pinnedList),

                  // Messages area
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      itemCount: listToShow.length + (isAnyOtherTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == listToShow.length) {
                          return _TypingIndicator(
                            profileImageUrl: null,
                            initials: '...',
                          );
                        }
                        final msg = listToShow[index];
                        final showDateHeader =
                            index == 0 ||
                            !_isSameDay(
                              listToShow[index - 1].createdAt,
                              msg.createdAt,
                            );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDateHeader) _buildDateHeader(msg.createdAt),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildMessageBubble(msg),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // Mentions selection overlay if active
                  if (_showMentionsList && _mentionsSuggestions.isNotEmpty)
                    _buildMentionsSuggestionOverlay(),

                  // Bottom Input Bar
                  _buildInputBar(
                    isBlocked: _isBlocked ||
                        chatData?['isUnmatched'] == true,
                  ),
                ],
              );
            },
          );
        },
      ),
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
        // Group participant name above bubble
        if (_otherUid == null && !isMe) ...[
          Padding(
            padding: const EdgeInsets.only(left: 36, bottom: 4),
            child: Text(
              msg.senderName ?? 'Member',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8C736B),
              ),
            ),
          ),
        ],

        // Message body bubble
        Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              if (_otherUid != null)
                GestureDetector(
                  onTap: () => _showUserProfileBottomSheet(_otherUid!),
                  child:
                      _otherUserProfileImage != null &&
                          _otherUserProfileImage!.isNotEmpty
                      ? CircleAvatar(
                          radius: 14,
                          backgroundImage: NetworkImage(
                            _otherUserProfileImage!,
                          ),
                        )
                      : CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFFE5A475),
                          child: Text(
                            _otherUserInitials ?? 'P',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                )
              else
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(msg.senderId)
                      .get(),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data() as Map<String, dynamic>?;
                    final img = data?['profileImageUrl'] ?? '';
                    final name = data?['name'] ?? msg.senderName ?? 'P';
                    final initials = name.isNotEmpty
                        ? name
                              .trim()
                              .split(' ')
                              .map((e) => e[0])
                              .take(2)
                              .join()
                              .toUpperCase()
                        : 'P';
                    return GestureDetector(
                      onTap: msg.senderId != null
                          ? () => _showUserProfileBottomSheet(msg.senderId!)
                          : null,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundImage: img.isNotEmpty
                            ? NetworkImage(img)
                            : null,
                        backgroundColor: const Color(0xFFE5A475),
                        child: img.isEmpty
                            ? Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: GestureDetector(
                onLongPress: () => _showMessageOptions(context, msg),
                child: Container(
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    border: isMe
                        ? null
                        : Border.all(color: const Color(0xFFE8E2DD)),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMe
                          ? const Radius.circular(16)
                          : Radius.zero,
                      bottomRight: isMe
                          ? Radius.zero
                          : const Radius.circular(16),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Reply indicator preview
                      if (msg.replyTo != null)
                        _buildReplyPreviewHeader(msg.replyTo!, textColor),

                      // Bubble content
                      _buildBubbleContent(msg, textColor),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // Reactions and timestamp row
        const SizedBox(height: 4),
        Padding(
          padding: EdgeInsets.only(left: isMe ? 0 : 36, right: isMe ? 8 : 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (msg.reactionsMap.isNotEmpty) ...[
                _buildReactionsDisplay(msg),
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
              if (isMe) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.done_all,
                  size: 12,
                  color: msg.isRead ? Colors.blue : Colors.white60,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBubbleContent(Message msg, Color textColor) {
    switch (msg.kind) {
      case MessageKind.text:
        final text = msg.text ?? '';
        if (text.startsWith('📅 Meeting Request:') ||
            text.startsWith('🔄 Proposed New Time:')) {
          return _buildInlineMeetingRequestCard(msg, text);
        }
        return Text(
          text,
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

        return SizedBox(
          width: 190,
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: textColor,
                  size: 28,
                ),
                onPressed: () => _toggleVoicePlayback(msg, duration),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Seekable waveform visualizer
                    Builder(
                      builder: (widgetContext) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) {
                            if (isPlaying) {
                              final box =
                                  widgetContext.findRenderObject()
                                      as RenderBox?;
                              if (box != null) {
                                final width = box.size.width;
                                final localX = details.localPosition.dx;
                                final pct = (localX / width).clamp(0.0, 1.0);
                                final seekTarget = Duration(
                                  milliseconds: (duration * 1000 * pct).toInt(),
                                );
                                _audioPlayer.seek(seekTarget);
                              }
                            }
                          },
                          onHorizontalDragUpdate: (details) {
                            if (isPlaying) {
                              final box =
                                  widgetContext.findRenderObject()
                                      as RenderBox?;
                              if (box != null) {
                                final width = box.size.width;
                                final localX = details.localPosition.dx;
                                final pct = (localX / width).clamp(0.0, 1.0);
                                final seekTarget = Duration(
                                  milliseconds: (duration * 1000 * pct).toInt(),
                                );
                                _audioPlayer.seek(seekTarget);
                              }
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(24, (i) {
                              // Create simulated peaks
                              final double h = (i % 5 == 0)
                                  ? 16
                                  : (i % 3 == 0)
                                  ? 12
                                  : (i % 2 == 0 ? 8 : 4);
                              final isActive =
                                  isPlaying && (i / 24.0) <= _voiceProgress;
                              return Container(
                                width: 2.2,
                                height: h,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? (msg.from == MessageSender.me
                                            ? const Color(0xFFE5A475)
                                            : const Color(0xFF7A432D))
                                      : textColor.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              );
                            }),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPlaying
                          ? '${_formatDuration(_voicePosition)} / ${_formatDuration(_voiceDuration)}'
                          : 'Voice Memo • 0:${duration.toString().padLeft(2, "0")}',
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
                  final percentage = optIndex == 0
                      ? 60
                      : (optIndex == 1 ? 25 : 15);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      onTap: () {
                        if (!hasVoted && _chatId != null) {
                          ChatService().answerPoll(
                            chatId: _chatId!,
                            messageId: msg.id,
                            optionIndex: optIndex,
                          );
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
                                        ? (msg.from == MessageSender.me
                                              ? Colors.white12
                                              : const Color(
                                                  0xFF7A432D,
                                                ).withValues(alpha: 0.15))
                                        : (msg.from == MessageSender.me
                                              ? Colors.white.withValues(
                                                  alpha: 0.05,
                                                )
                                              : const Color(
                                                  0xFFE8E2DD,
                                                ).withValues(alpha: 0.5)),
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
                                    ? (msg.from == MessageSender.me
                                          ? Colors.white38
                                          : const Color(
                                              0xFF7A432D,
                                            ).withValues(alpha: 0.6))
                                    : const Color(0xFFE8E2DD),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  options[optIndex],
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11.5,
                                    color: textColor,
                                    fontWeight: isPicked
                                        ? FontWeight.bold
                                        : FontWeight.normal,
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
      case MessageKind.image:
        return Semantics(
          button: true,
          label: 'Open image in full screen',
          child: GestureDetector(
            onTap: () => _openImagePreview(msg),
            child: Hero(
              tag: 'chat-image-${msg.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  msg.imageUrl ?? '',
                  width: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 200,
                    height: 120,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),
        );

      case MessageKind.file:
        return Semantics(
          button: true,
          label: 'Open ${msg.fileName ?? 'document'}',
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: msg.fileUrl == null || msg.fileUrl!.isEmpty
                ? null
                : () => launchUrl(
                    Uri.parse(msg.fileUrl!),
                    mode: LaunchMode.externalApplication,
                  ),
            child: Container(
              width: 200,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.insert_drive_file, color: textColor, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.fileName ?? 'Document.pdf',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          msg.fileSize != null
                              ? '${(msg.fileSize! / 1024 / 1024).toStringAsFixed(1)} MB'
                              : 'Unknown size',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 10,
                            color: textColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.download, color: textColor, size: 20),
                ],
              ),
            ),
          ),
        );

      case MessageKind.link:
        return Container(
          width: 210,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg.linkTitle ?? 'Web Link',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      msg.linkDescription ?? 'Tap to open web link',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10.5,
                        color: textColor.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      msg.linkUrl ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 9.5,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox();
    }
  }

  Widget _buildConnectionRequiredBar(String message) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFDF1E6),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      alignment: Alignment.center,
      child: SafeArea(
        top: false,
        child: Text(
          message,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF7A432D),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildInputBar({required bool isBlocked}) {
    if (isBlocked) {
      return _buildConnectionRequiredBar(
        'Match again before messaging this user.',
      );
    }
    if (_isRecording) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE8E2DD), width: 1.2)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              const _BlinkingRecordingDot(),
              const SizedBox(width: 8),
              Text(
                'Recording: 0:${_recordDuration.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC62828),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _cancelRecording,
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: Color(0xFF8C736B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A432D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                onPressed: _sendRecordedVoice,
                child: const Text(
                  'Send',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selectedReplyMsg != null)
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFAF7F5),
              border: Border(
                top: BorderSide(color: Color(0xFFE8E2DD), width: 1.2),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.reply, size: 16, color: Color(0xFF7A432D)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Replying to ${_selectedReplyMsg!['senderName']}',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7A432D),
                        ),
                      ),
                      Text(
                        _selectedReplyMsg!['text'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: Color(0xFF8C736B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 16,
                    color: Color(0xFF8C736B),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedReplyMsg = null;
                    });
                  },
                ),
              ],
            ),
          ),
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFE8E2DD), width: 1.2),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // Attachment drawer
                IconButton(
                  tooltip: _isUploadingAttachment
                      ? 'Uploading attachment'
                      : 'Add photo or document',
                  icon: Icon(
                    _isUploadingAttachment
                        ? Icons.upload_file_outlined
                        : Icons.add_circle_outline,
                    color: Color(0xFF8C736B),
                  ),
                  onPressed: _isUploadingAttachment
                      ? null
                      : _showAttachmentDrawer,
                ),

                // Voice memo button
                IconButton(
                  icon: const Icon(
                    Icons.mic_none_outlined,
                    color: Color(0xFF8C736B),
                  ),
                  onPressed: _startRecording,
                ),

                // Meeting request button
                IconButton(
                  icon: const Icon(
                    Icons.calendar_month_outlined,
                    color: Color(0xFF7A432D),
                  ),
                  onPressed: _otherUid != null
                      ? () => _showQuickMeetingRequestSheet()
                      : null,
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
                        hintStyle: TextStyle(
                          color: Color(0xFF8C736B),
                          fontSize: 13,
                        ),
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
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Color(0xFF7A432D),
                  ),
                  onPressed: _handleSendMessage,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Advanced Features Helpers
  // ---------------------------------------------------------------------------

  Future<void> _showCancellationReasonDialog(
    String meetingId,
    String currentUid,
    String otherUid,
    String location,
    String timeStr,
  ) async {
    String selectedReason = 'Scheduling Conflict';
    final TextEditingController noteController = TextEditingController();
    final reasons = [
      'Scheduling Conflict',
      'Location is too far',
      'Change of Plans',
      'Emergency',
      'Other',
    ];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: const Color(0xFFFAF7F5),
              title: const Text(
                'Cancel Meeting Request',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3E1F11),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please select a reason for cancellation:',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        color: Color(0xFF8C736B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...reasons.map(
                      (r) => RadioListTile<String>(
                        title: Text(
                          r,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13.5,
                            color: Color(0xFF3E1F11),
                          ),
                        ),
                        value: r,
                        groupValue: selectedReason,
                        activeColor: const Color(0xFF7A432D),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedReason = val;
                            });
                          }
                        },
                      ),
                    ),
                    if (selectedReason == 'Other') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: noteController,
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'PlusJakartaSans',
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type your reason here...',
                          hintStyle: const TextStyle(color: Color(0xFF8C736B)),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFE8E2DD),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF7A432D),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Go Back',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      color: Color(0xFF8C736B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      final reasonStr = selectedReason == 'Other'
                          ? noteController.text.trim()
                          : selectedReason;
                      final finalReason = reasonStr.isNotEmpty
                          ? reasonStr
                          : 'Scheduling Conflict';

                      await MeetingService().updateParticipantStatus(
                        meetingId: meetingId,
                        userId: currentUid,
                        status: 'cancelled',
                        reason: finalReason,
                        note: selectedReason == 'Other' ? 'Custom reason' : '',
                      );

                      final responseMsg =
                          "❌ Meeting Cancelled: I won't be able to meet at $location on $timeStr. Reason: $finalReason";
                      await ChatService().sendTextMessage(
                        chatId: _chatId!,
                        text: responseMsg,
                      );

                      if (!mounted) return;
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Meeting cancelled.'),
                          backgroundColor: Color(0xFFC62828),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error cancelling meeting: $e'),
                          backgroundColor: const Color(0xFFC62828),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Cancel Meeting',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAttachmentDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAF7F5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Share Attachment',
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E1F11),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDrawerItem(
                      icon: Icons.photo_library_outlined,
                      label: 'Photo',
                      color: const Color(0xFF7A432D),
                      onTap: () async {
                        Navigator.pop(context);
                        await _pickAndSendPhoto();
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.insert_drive_file,
                      label: 'Document',
                      color: const Color(0xFFE5A475),
                      onTap: () async {
                        Navigator.pop(context);
                        await _pickAndSendDocument();
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.link,
                      label: 'Web Link',
                      color: const Color(0xFF8C736B),
                      onTap: () {
                        Navigator.pop(context);
                        _showSendLinkDialog();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              color: Color(0xFF3E1F11),
            ),
          ),
        ],
      ),
    );
  }

  // Retained for a future expanded attachment menu.
  // ignore: unused_element
  Widget _buildAttachmentMenuItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 25),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  void _showStickerPicker() {
    const stickers = ['👍', '😂', '🎉', '❤️', '🔥', '👏', '✨', '🙌'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF171619),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Choose a sticker',
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: stickers.map((sticker) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final cid = await _ensureChatId();
                        if (cid == null) return;
                        await ChatService().sendTextMessage(
                          chatId: cid,
                          text: sticker,
                        );
                        _scrollToBottom();
                      },
                      child: Container(
                        width: 62,
                        height: 62,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(sticker, style: const TextStyle(fontSize: 30)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ignore: unused_element
  Future<void> _showQuickPollDialog() async {
    final questionController = TextEditingController();
    final firstOptionController = TextEditingController();
    final secondOptionController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFAF7F5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Create a poll',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E1F11),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPollInput(questionController, 'Ask a question'),
              const SizedBox(height: 10),
              _buildPollInput(firstOptionController, 'First option'),
              const SizedBox(height: 10),
              _buildPollInput(secondOptionController, 'Second option'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final question = questionController.text.trim();
                final options = [
                  firstOptionController.text.trim(),
                  secondOptionController.text.trim(),
                ].where((option) => option.isNotEmpty).toList();
                if (question.isEmpty || options.length < 2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Add a question and two options.'),
                      backgroundColor: Color(0xFFC62828),
                    ),
                  );
                  return;
                }

                final cid = await _ensureChatId();
                if (cid == null) return;
                try {
                  await ChatService().sendPollMessage(
                    chatId: cid,
                    question: question,
                    options: options,
                    replyTo: _selectedReplyMsg,
                    mentions: List<String>.from(_selectedMentionUids),
                  );
                  if (!dialogContext.mounted) return;
                  setState(() {
                    _selectedReplyMsg = null;
                    _selectedMentionUids = [];
                    _showMentionsList = false;
                  });
                  Navigator.pop(dialogContext);
                  _scrollToBottom();
                } catch (e) {
                  _showAttachmentError('Could not create this poll.');
                  debugPrint('Poll creation failed: $e');
                }
              },
              child: const Text('Send poll'),
            ),
          ],
        );
      },
    );

    questionController.dispose();
    firstOptionController.dispose();
    secondOptionController.dispose();
  }

  // ignore: unused_element
  Widget _buildPollInput(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
        ),
      ),
    );
  }

  void _showSendLinkDialog() {
    final urlController = TextEditingController(text: 'https://');
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: const Color(0xFFFAF7F5),
          title: const Text(
            'Share Web Link',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL (required)',
                  ),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                  ),
                ),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                  ),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A432D),
              ),
              onPressed: () async {
                final url = urlController.text.trim();
                if (url.isEmpty || url == 'https://') return;
                Navigator.pop(context);
                if (_chatId == null) return;
                await ChatService().sendLinkMessage(
                  chatId: _chatId!,
                  url: url,
                  title: titleController.text.trim().isNotEmpty
                      ? titleController.text.trim()
                      : 'Useful Link',
                  description: descController.text.trim().isNotEmpty
                      ? descController.text.trim()
                      : 'Shared via BoardingPass Chat',
                );
              },
              child: const Text(
                'Send Link',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCreateGroupModal(BuildContext context) async {
    final nameController = TextEditingController();
    final imageController = TextEditingController(
      text:
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&auto=format&fit=crop&q=80',
    );

    // Fetch all users to invite
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .get();
    final List<UserProfile> availableUsers = usersSnapshot.docs
        .map((doc) => UserProfile.fromFirestore(doc))
        .where((user) => user.uid != FirebaseAuth.instance.currentUser?.uid)
        .toList();

    final List<String> selectedUids = [];

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF7F5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 24),
                      const Text(
                        'Create Group Chat',
                        style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Group Name',
                          hintText: 'e.g. Lounge Networking London',
                        ),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: imageController,
                        decoration: const InputDecoration(
                          labelText: 'Group Image URL',
                        ),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Invite Members',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (availableUsers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'No other users found in the system.',
                              style: TextStyle(
                                color: Color(0xFF8C736B),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: availableUsers.length,
                          itemBuilder: (context, index) {
                            final user = availableUsers[index];
                            final isSelected = selectedUids.contains(user.uid);
                            return CheckboxListTile(
                              title: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundImage:
                                        user.profileImageUrl != null &&
                                            user.profileImageUrl!.isNotEmpty
                                        ? NetworkImage(user.profileImageUrl!)
                                        : null,
                                    backgroundColor: const Color(0xFFE5A475),
                                    child:
                                        user.profileImageUrl == null ||
                                            user.profileImageUrl!.isEmpty
                                        ? Text(
                                            user.name.isNotEmpty
                                                ? user.name
                                                      .trim()
                                                      .split(' ')
                                                      .map((e) => e[0])
                                                      .take(2)
                                                      .join()
                                                      .toUpperCase()
                                                : 'U',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.name,
                                          style: const TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF3E1F11),
                                          ),
                                        ),
                                        if (user.headline != null)
                                          Text(
                                            user.headline!,
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
                                ],
                              ),
                              value: isSelected,
                              activeColor: const Color(0xFF7A432D),
                              onChanged: (checked) {
                                setModalState(() {
                                  if (checked == true) {
                                    selectedUids.add(user.uid);
                                  } else {
                                    selectedUids.remove(user.uid);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7A432D),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a group name.'),
                              ),
                            );
                            return;
                          }
                          try {
                            final newChatId = await ChatService()
                                .createGroupChat(
                                  groupName: name,
                                  imageUrl: imageController.text.trim(),
                                  participants: selectedUids,
                                );
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            _openGroupChat(newChatId, name);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to create group: $e'),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Create Group',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showAddMemberDialogFromAppBar(
    BuildContext context,
    Map<String, dynamic> chatData,
  ) async {
    final List<String> participants = List<String>.from(
      chatData['participants'] ?? [],
    );
    final docSnapshot = await FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId!)
        .get();
    final List<String> pending = List<String>.from(
      docSnapshot.data()?['pendingInvitations'] ?? [],
    );
    final allUsers = await FirebaseFirestore.instance.collection('users').get();
    final addable = allUsers.docs
        .map((doc) => UserProfile.fromFirestore(doc))
        .where(
          (user) =>
              !participants.contains(user.uid) && !pending.contains(user.uid),
        )
        .toList();
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFAF7F5),
          title: const Text(
            'Invite Member',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              color: Color(0xFF3E1F11),
            ),
          ),
          content: addable.isEmpty
              ? const Text(
                  'No inviteable members found.',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: Color(0xFF8C736B),
                  ),
                )
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: addable.length,
                    itemBuilder: (context, i) {
                      final u = addable[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              u.profileImageUrl != null &&
                                  u.profileImageUrl!.isNotEmpty
                              ? NetworkImage(u.profileImageUrl!)
                              : null,
                          backgroundColor: const Color(0xFFE5A475),
                          child:
                              u.profileImageUrl == null ||
                                  u.profileImageUrl!.isEmpty
                              ? Text(
                                  u.name.isNotEmpty
                                      ? u.name[0].toUpperCase()
                                      : 'U',
                                )
                              : null,
                        ),
                        title: Text(
                          u.name,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          u.role ?? 'Professional',
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                          ),
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          await ChatService().inviteUserToGroupChat(
                            _chatId!,
                            u.uid,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Invitation sent to ${u.name}!'),
                              backgroundColor: const Color(0xFF7A432D),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
        );
      },
    );
  }

  void _showGroupSettingsSheet(BuildContext context) async {
    if (_chatId == null) return;

    final chatDoc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .get();
    if (!chatDoc.exists) return;

    final chatData = chatDoc.data()!;
    final String groupName = chatData['groupName'] ?? 'Group';
    final String groupImageUrl = chatData['groupImageUrl'] ?? '';
    final List<String> participants = List<String>.from(
      chatData['participants'] ?? [],
    );
    final List<String> admins = List<String>.from(chatData['admins'] ?? []);
    final List<String> mutedBy = List<String>.from(chatData['mutedBy'] ?? []);

    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool isAdmin = admins.contains(currentUid);
    final bool isMuted = mutedBy.contains(currentUid);

    final nameController = TextEditingController(text: groupName);
    final imageController = TextEditingController(text: groupImageUrl);

    // Fetch details for all current members
    final List<UserProfile> currentMembers = [];
    for (final id in participants) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(id)
          .get();
      if (userDoc.exists) {
        currentMembers.add(UserProfile.fromFirestore(userDoc));
      }
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF7F5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              groupName,
                              style: const TextStyle(
                                fontFamily: 'PlayfairDisplay',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3E1F11),
                              ),
                            ),
                          ),
                          Text(
                            '${participants.length} Members',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              color: Color(0xFF8C736B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SwitchListTile(
                        title: const Text(
                          'Mute Notifications',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: const Text(
                          'Suppress layout pop-ups for this group',
                        ),
                        value: isMuted,
                        activeThumbColor: const Color(0xFF7A432D),
                        onChanged: (val) async {
                          await ChatService().muteGroup(
                            chatId: _chatId!,
                            mute: val,
                          );
                          Navigator.pop(context);
                        },
                      ),
                      const Divider(color: Color(0xFFE8E2DD)),
                      if (isAdmin) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Edit Group details',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3E1F11),
                          ),
                        ),
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: 'Name'),
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                          ),
                        ),
                        TextField(
                          controller: imageController,
                          decoration: const InputDecoration(
                            labelText: 'Image URL',
                          ),
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7A432D),
                          ),
                          onPressed: () async {
                            await ChatService().updateGroupSettings(
                              chatId: _chatId!,
                              name: nameController.text.trim(),
                              imageUrl: imageController.text.trim(),
                            );
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Save Details',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const Divider(color: Color(0xFFE8E2DD)),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Members List',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3E1F11),
                            ),
                          ),
                          if (true)
                            IconButton(
                              icon: const Icon(
                                Icons.person_add_alt_1,
                                color: Color(0xFF7A432D),
                              ),
                              onPressed: () async {
                                // Add members flow
                                final allUsers = await FirebaseFirestore
                                    .instance
                                    .collection('users')
                                    .get();
                                final docSnapshot = await FirebaseFirestore
                                    .instance
                                    .collection('chats')
                                    .doc(_chatId!)
                                    .get();
                                final List<String> pending = List<String>.from(
                                  docSnapshot.data()?['pendingInvitations'] ??
                                      [],
                                );
                                final addable = allUsers.docs
                                    .map(
                                      (doc) => UserProfile.fromFirestore(doc),
                                    )
                                    .where(
                                      (user) =>
                                          !participants.contains(user.uid) &&
                                          !pending.contains(user.uid),
                                    )
                                    .toList();
                                if (!context.mounted) return;
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('Invite Member'),
                                      content: SizedBox(
                                        width: double.maxFinite,
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: addable.length,
                                          itemBuilder: (context, i) {
                                            final u = addable[i];
                                            return ListTile(
                                              title: Text(u.name),
                                              onTap: () async {
                                                Navigator.pop(context);
                                                await ChatService()
                                                    .inviteUserToGroupChat(
                                                      _chatId!,
                                                      u.uid,
                                                    );
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Invitation sent to ${u.name}!',
                                                    ),
                                                    backgroundColor:
                                                        const Color(0xFF7A432D),
                                                  ),
                                                );
                                                // Refresh sheet
                                                if (!mounted) return;
                                                Navigator.pop(context);
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: currentMembers.length,
                        itemBuilder: (context, index) {
                          final member = currentMembers[index];
                          final isMemberAdmin = admins.contains(member.uid);
                          final isMe = member.uid == currentUid;

                          return ListTile(
                            onTap: () =>
                                _showUserProfileBottomSheet(member.uid),
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundImage:
                                  member.profileImageUrl != null &&
                                      member.profileImageUrl!.isNotEmpty
                                  ? NetworkImage(member.profileImageUrl!)
                                  : null,
                              backgroundColor: const Color(0xFFE5A475),
                              child:
                                  member.profileImageUrl == null ||
                                      member.profileImageUrl!.isEmpty
                                  ? Text(
                                      member.name.isNotEmpty
                                          ? member.name
                                                .trim()
                                                .split(' ')
                                                .map((e) => e[0])
                                                .take(2)
                                                .join()
                                                .toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              member.name + (isMe ? ' (You)' : ''),
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              isMemberAdmin ? 'Group Admin' : 'Member',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF8C736B),
                              ),
                            ),
                            trailing: (isAdmin && !isMe)
                                ? PopupMenuButton<String>(
                                    onSelected: (action) async {
                                      if (action == 'remove') {
                                        final newList = List<String>.from(
                                          participants,
                                        )..remove(member.uid);
                                        final newAdmins = List<String>.from(
                                          admins,
                                        )..remove(member.uid);
                                        await ChatService().updateGroupSettings(
                                          chatId: _chatId!,
                                          participants: newList,
                                          admins: newAdmins,
                                        );
                                      } else if (action == 'make_admin') {
                                        final newAdmins = [
                                          ...admins,
                                          member.uid,
                                        ];
                                        await ChatService().updateGroupSettings(
                                          chatId: _chatId!,
                                          admins: newAdmins,
                                        );
                                      } else if (action == 'remove_admin') {
                                        final newAdmins = List<String>.from(
                                          admins,
                                        )..remove(member.uid);
                                        await ChatService().updateGroupSettings(
                                          chatId: _chatId!,
                                          admins: newAdmins,
                                        );
                                      }
                                      if (!mounted) return;
                                      Navigator.pop(context);
                                    },
                                    itemBuilder: (context) => [
                                      if (!isMemberAdmin)
                                        const PopupMenuItem(
                                          value: 'make_admin',
                                          child: Text('Promote Admin'),
                                        ),
                                      if (isMemberAdmin)
                                        const PopupMenuItem(
                                          value: 'remove_admin',
                                          child: Text('Revoke Admin'),
                                        ),
                                      const PopupMenuItem(
                                        value: 'remove',
                                        child: Text(
                                          'Remove from Group',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  )
                                : null,
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[800],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          // Leave Group flow
                          final newList = List<String>.from(participants)
                            ..remove(currentUid);
                          final newAdmins = List<String>.from(admins)
                            ..remove(currentUid);

                          if (newList.isEmpty) {
                            // Delete chat if no participants left
                            await FirebaseFirestore.instance
                                .collection('chats')
                                .doc(_chatId!)
                                .delete();
                          } else {
                            // If leaving user was the only admin, assign admin role to another participant
                            final nextAdmins = newAdmins.isEmpty
                                ? [newList.first]
                                : newAdmins;
                            await ChatService().updateGroupSettings(
                              chatId: _chatId!,
                              participants: newList,
                              admins: nextAdmins,
                            );
                          }

                          if (!context.mounted) return;
                          Navigator.pop(context); // close sheet
                          widget.onBack?.call(); // go back to hub/conversations
                        },
                        child: const Text(
                          'Leave Group',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPinnedHeader(List<Map<String, dynamic>> pinnedList) {
    final lastPin = pinnedList.last;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F5),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE8E2DD), width: 1.2),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(
            Icons.push_pin_rounded,
            size: 16,
            color: Color(0xFF7A432D),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PINNED MESSAGE (by ${lastPin['senderName']})',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7A432D),
                  ),
                ),
                Text(
                  lastPin['text'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    color: Color(0xFF3E1F11),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Color(0xFF8C736B)),
            onPressed: () async {
              if (_chatId != null) {
                await ChatService().unpinMessage(
                  chatId: _chatId!,
                  messageId: lastPin['id'],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMentionsSuggestionOverlay() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 160),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E2DD)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _mentionsSuggestions.length,
        itemBuilder: (context, index) {
          final user = _mentionsSuggestions[index];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 12,
              backgroundImage:
                  user.profileImageUrl != null &&
                      user.profileImageUrl!.isNotEmpty
                  ? NetworkImage(user.profileImageUrl!)
                  : null,
              backgroundColor: const Color(0xFFE5A475),
              child:
                  user.profileImageUrl == null || user.profileImageUrl!.isEmpty
                  ? Text(
                      user.name.isNotEmpty
                          ? user.name
                                .trim()
                                .split(' ')
                                .map((e) => e[0])
                                .take(2)
                                .join()
                                .toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            title: Text(
              user.name,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E1F11),
              ),
            ),
            onTap: () {
              final text = _inputController.text;
              final lastAt = text.lastIndexOf('@');
              if (lastAt != -1) {
                final newText = '${text.substring(0, lastAt)}@${user.name} ';
                _inputController.text = newText;
                _inputController.selection = TextSelection.fromPosition(
                  TextPosition(offset: newText.length),
                );
                if (!_selectedMentionUids.contains(user.uid)) {
                  _selectedMentionUids.add(user.uid);
                }
              }
              setState(() {
                _showMentionsList = false;
                _mentionsSuggestions = [];
              });
            },
          );
        },
      ),
    );
  }

  Future<void> _deleteMessageForMe(Message msg) async {
    final chatId = _chatId;
    if (chatId == null) return;

    try {
      await ChatService().deleteMessageForMe(chatId: chatId, messageId: msg.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFC62828),
          content: Text(
            'Failed to delete message: $e',
            style: const TextStyle(fontFamily: 'PlusJakartaSans'),
          ),
        ),
      );
    }
  }

  Future<void> _deleteMessageForEveryone(Message msg) async {
    final chatId = _chatId;
    if (chatId == null) return;

    try {
      await ChatService().deleteMessageForEveryone(
        chatId: chatId,
        messageId: msg.id,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFC62828),
          content: Text(
            'Failed to delete message for everyone: $e',
            style: const TextStyle(fontFamily: 'PlusJakartaSans'),
          ),
        ),
      );
    }
  }

  void _showMessageOptions(BuildContext context, Message msg) {
    final isMyMessage = msg.from == MessageSender.me;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAF7F5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji Reaction Bar Row
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                    final isReacted =
                        msg.reactionsMap[FirebaseAuth
                            .instance
                            .currentUser
                            ?.uid] ==
                        emoji;
                    return GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        if (_chatId != null) {
                          await ChatService().toggleReaction(
                            chatId: _chatId!,
                            messageId: msg.id,
                            emoji: emoji,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isReacted
                              ? const Color(0xFFE5A475).withValues(alpha: 0.2)
                              : Colors.transparent,
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE8E2DD)),
              ListTile(
                leading: const Icon(Icons.reply, color: Color(0xFF7A432D)),
                title: const Text(
                  'Reply',
                  style: TextStyle(fontFamily: 'PlusJakartaSans'),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedReplyMsg = {
                      'messageId': msg.id,
                      'text': msg.text ?? '[Attachment]',
                      'senderName': msg.senderName ?? 'Member',
                    };
                  });
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.push_pin_outlined,
                  color: Color(0xFF7A432D),
                ),
                title: const Text(
                  'Pin Message',
                  style: TextStyle(fontFamily: 'PlusJakartaSans'),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  if (_chatId != null) {
                    await ChatService().pinMessage(
                      chatId: _chatId!,
                      messageId: msg.id,
                      text: msg.text ?? '[Attachment]',
                      senderName: msg.senderName ?? 'Member',
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFC62828),
                ),
                title: const Text(
                  'Delete for Me',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: Color(0xFFC62828),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessageForMe(msg);
                },
              ),
              if (isMyMessage)
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    color: Color(0xFFC62828),
                  ),
                  title: const Text(
                    'Delete for Everyone',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      color: Color(0xFFC62828),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessageForEveryone(msg);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReplyPreviewHeader(
    Map<String, dynamic> replyData,
    Color textColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: const Border(
          left: BorderSide(color: Color(0xFFE5A475), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replyData['senderName'] ?? 'Member',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            replyData['text'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              color: textColor.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionsDisplay(Message msg) {
    final counts = <String, int>{};
    for (final reaction in msg.reactionsMap.values) {
      counts[reaction] = (counts[reaction] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E2DD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: counts.entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Text(
              '${e.key} ${e.value}',
              style: const TextStyle(
                fontSize: 9,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _updateMentionsSuggestions(String query) {
    if (_groupMembers.isEmpty) {
      setState(() {
        _showMentionsList = false;
        _mentionsSuggestions = [];
      });
      return;
    }
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final suggestions = _groupMembers.where((user) {
      if (user.uid == currentUid) return false;
      return user.name.toLowerCase().contains(query);
    }).toList();

    setState(() {
      _mentionsSuggestions = suggestions;
      _showMentionsList = suggestions.isNotEmpty;
    });
  }
}

class _ChatImagePreview extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const _ChatImagePreview({required this.imageUrl, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Hero(
                tag: heroTag,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const SizedBox(
                        height: 48,
                        width: 48,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined, color: Colors.white70, size: 44),
                        SizedBox(height: 10),
                        Text(
                          'This image is unavailable.',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Close image preview',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
            const Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Pinch to zoom',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    color: Colors.white70,
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

class _BlinkingRecordingDot extends StatefulWidget {
  const _BlinkingRecordingDot();

  @override
  State<_BlinkingRecordingDot> createState() => _BlinkingRecordingDotState();
}

class _BlinkingRecordingDotState extends State<_BlinkingRecordingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Color(0xFFC62828),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  final String? profileImageUrl;
  final String initials;
  const _TypingIndicator({this.profileImageUrl, required this.initials});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE5A475),
            ),
            child: ClipOval(
              child: buildProfileImage(
                widget.profileImageUrl ?? '',
                fit: BoxFit.cover,
                fallback: Center(
                  child: Text(
                    widget.initials,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE8E2DD)),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.zero,
                bottomRight: Radius.circular(16),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final delay = index * 0.2;
                    double value = math.sin(
                      (_controller.value * 2 * math.pi) - delay,
                    );
                    value = (value + 1) / 2;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFF7A432D,
                        ).withValues(alpha: 0.3 + 0.7 * value),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
