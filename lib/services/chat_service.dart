import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';

/// Singleton service for real-time Firestore chat.
///
/// Firestore structure:
/// ```
/// chats/{chatId}
///   participants: [uid1, uid2]
///   lastMessage: {text, senderId, timestamp}
///   unreadCount: {uid1: 0, uid2: 3}
///   typingStatus: {uid1: false, uid2: false}
///   updatedAt: Timestamp
///
///   messages/{messageId}
///     senderId, type, text, createdAt, readBy[]
///     voiceDuration (voice), place/meta (pin), question/options/picked (poll)
/// ```
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Reference to the top-level `chats` collection.
  CollectionReference<Map<String, dynamic>> get _chatsRef =>
      _firestore.collection('chats');

  /// The currently signed-in user's UID, or `null`.
  String? get _currentUid => _auth.currentUser?.uid;

  // ---------------------------------------------------------------------------
  // Chat CRUD
  // ---------------------------------------------------------------------------

  /// Creates a new 1-to-1 chat document between [userId1] and [userId2].
  Future<String> createChat({
    required String userId1,
    required String userId2,
  }) async {
    try {
      final chatDoc = await _chatsRef.add({
        'isGroup': false,
        'participants': [userId1, userId2],
        'lastMessage': null,
        'unreadCount': {userId1: 0, userId2: 0},
        'typingStatus': {userId1: false, userId2: false},
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return chatDoc.id;
    } catch (e) {
      throw Exception('Failed to create chat: $e');
    }
  }

  Future<String> createGroupChat({
    required String groupName,
    required String imageUrl,
    required List<String> participants,
  }) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('User not signed in');

    try {
      final allParticipants = [uid];
      final invitedParticipants = List<String>.from(participants)..remove(uid);
      final unreadMap = <String, int>{uid: 0};
      final typingMap = <String, bool>{uid: false};

      final chatDoc = await _chatsRef.add({
        'isGroup': true,
        'groupName': groupName,
        'groupImageUrl': imageUrl,
        'createdBy': uid,
        'admins': [uid],
        'participants': allParticipants,
        'pendingInvitations': invitedParticipants,
        'mutedBy': [],
        'pinnedMessages': [],
        'lastMessage': {
          'text': 'Group created by ${imageUrl.isEmpty ? "Organizer" : "Admin"}',
          'senderId': uid,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'unreadCount': unreadMap,
        'typingStatus': typingMap,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Write activity message
      await _chatsRef.doc(chatDoc.id).collection('messages').add({
        'senderId': 'system',
        'senderName': 'System',
        'type': MessageKind.text.name,
        'text': '📢 Group "$groupName" was created.',
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [uid],
      });

      return chatDoc.id;
    } catch (e) {
      throw Exception('Failed to create group chat: $e');
    }
  }

  /// Updates group metadata, admins, or participants.
  Future<void> updateGroupSettings({
    required String chatId,
    String? name,
    String? imageUrl,
    List<String>? participants,
    List<String>? admins,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (name != null) updates['groupName'] = name;
      if (imageUrl != null) updates['groupImageUrl'] = imageUrl;
      if (participants != null) {
        updates['participants'] = participants;
        // Clean unread / typing status maps to align with current participants
        final doc = await _chatsRef.doc(chatId).get();
        final data = doc.data() ?? {};
        final unread = Map<String, dynamic>.from(data['unreadCount'] ?? {});
        final typing = Map<String, dynamic>.from(data['typingStatus'] ?? {});
        final newUnread = <String, int>{};
        final newTyping = <String, bool>{};
        for (final p in participants) {
          newUnread[p] = unread[p] ?? 0;
          newTyping[p] = typing[p] ?? false;
        }
        updates['unreadCount'] = newUnread;
        updates['typingStatus'] = newTyping;
      }
      if (admins != null) updates['admins'] = admins;

      await _chatsRef.doc(chatId).update(updates);
    } catch (e) {
      throw Exception('Failed to update group settings: $e');
    }
  }

  /// Mutes or unmutes notifications for a specific group/chat.
  Future<void> muteGroup({
    required String chatId,
    required bool mute,
  }) async {
    final uid = _currentUid;
    if (uid == null) return;
    try {
      await _chatsRef.doc(chatId).update({
        'mutedBy': mute
            ? FieldValue.arrayUnion([uid])
            : FieldValue.arrayRemove([uid])
      });
    } catch (e) {
      throw Exception('Failed to update group mute status: $e');
    }
  }

  /// Pins a message to the chat header.
  Future<void> pinMessage({
    required String chatId,
    required String messageId,
    required String text,
    required String senderName,
  }) async {
    try {
      await _chatsRef.doc(chatId).update({
        'pinnedMessages': FieldValue.arrayUnion([
          {
            'id': messageId,
            'text': text,
            'senderName': senderName,
            'timestamp': Timestamp.now(),
          }
        ])
      });
    } catch (e) {
      throw Exception('Failed to pin message: $e');
    }
  }

  /// Unpins a message.
  Future<void> unpinMessage({
    required String chatId,
    required String messageId,
  }) async {
    try {
      final doc = await _chatsRef.doc(chatId).get();
      final pinned = List<Map<String, dynamic>>.from(
        (doc.data()?['pinnedMessages'] as List?)?.map((e) => Map<String, dynamic>.from(e)) ?? []
      );
      pinned.removeWhere((item) => item['id'] == messageId);
      await _chatsRef.doc(chatId).update({'pinnedMessages': pinned});
    } catch (e) {
      throw Exception('Failed to unpin message: $e');
    }
  }

  /// Toggles emoji reaction on a message.
  Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String emoji,
  }) async {
    final uid = _currentUid;
    if (uid == null) return;
    try {
      final msgRef = _chatsRef.doc(chatId).collection('messages').doc(messageId);
      final doc = await msgRef.get();
      final currentReactions = Map<String, dynamic>.from(doc.data()?['reactionsMap'] ?? {});
      
      if (currentReactions[uid] == emoji) {
        // Remove reaction
        currentReactions.remove(uid);
      } else {
        // Set/Change reaction
        currentReactions[uid] = emoji;
      }
      
      await msgRef.update({'reactionsMap': currentReactions});
    } catch (e) {
      throw Exception('Failed to toggle reaction: $e');
    }
  }

  Future<bool> hasConnection(String userId1, String userId2) async {
    try {
      final userA = userId1.compareTo(userId2) < 0 ? userId1 : userId2;
      final userB = userId1.compareTo(userId2) < 0 ? userId2 : userId1;
      final doc = await FirebaseFirestore.instance
          .collection('connections')
          .doc('${userA}_$userB')
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Returns the existing chat ID between two users, or creates a new one.
  Future<String> getOrCreateChat({
    required String userId1,
    required String userId2,
  }) async {
    try {
      final query = await _chatsRef
          .where('isGroup', isEqualTo: false)
          .where('participants', arrayContains: userId1)
          .get();

      for (final doc in query.docs) {
        final participants = List<String>.from(doc['participants'] ?? []);
        if (participants.contains(userId2)) {
          return doc.id;
        }
      }

      final isConnected = await hasConnection(userId1, userId2);
      if (!isConnected) {
        throw Exception('You can only chat with accepted connections.');
      }

      return createChat(userId1: userId1, userId2: userId2);
    } catch (e) {
      throw Exception('Failed to get or create chat: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Chat list stream
  // ---------------------------------------------------------------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> streamUserChats() {
    final uid = _currentUid;
    if (uid == null) return const Stream.empty();

    return _chatsRef
        .where('participants', arrayContains: uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamUserGroupInvitations() {
    final uid = _currentUid;
    if (uid == null) return const Stream.empty();
    return _chatsRef
        .where('isGroup', isEqualTo: true)
        .where('pendingInvitations', arrayContains: uid)
        .snapshots();
  }

  Future<void> acceptGroupInvitation(String chatId) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('User not signed in');

    try {
      final docRef = _chatsRef.doc(chatId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final data = doc.data() ?? {};
      final participants = List<String>.from(data['participants'] ?? []);
      final pendingInvitations = List<String>.from(data['pendingInvitations'] ?? []);

      if (pendingInvitations.contains(uid)) {
        pendingInvitations.remove(uid);
        if (!participants.contains(uid)) {
          participants.add(uid);
        }

        final unreadMap = Map<String, dynamic>.from(data['unreadCount'] ?? {});
        unreadMap[uid] = 0;
        final typingMap = Map<String, dynamic>.from(data['typingStatus'] ?? {});
        typingMap[uid] = false;

        await docRef.update({
          'participants': participants,
          'pendingInvitations': pendingInvitations,
          'unreadCount': unreadMap,
          'typingStatus': typingMap,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Get user's name
        final userDoc = await _firestore.collection('users').doc(uid).get();
        final userName = userDoc.data()?['name'] ?? 'Someone';

        // Write activity message
        await docRef.collection('messages').add({
          'senderId': 'system',
          'senderName': 'System',
          'type': MessageKind.text.name,
          'text': '📢 $userName has accepted the invitation and joined the group.',
          'createdAt': FieldValue.serverTimestamp(),
          'readBy': [uid],
        });
      }
    } catch (e) {
      throw Exception('Failed to accept group invitation: $e');
    }
  }

  Future<void> declineGroupInvitation(String chatId) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('User not signed in');

    try {
      final docRef = _chatsRef.doc(chatId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final data = doc.data() ?? {};
      final pendingInvitations = List<String>.from(data['pendingInvitations'] ?? []);

      if (pendingInvitations.contains(uid)) {
        pendingInvitations.remove(uid);
        await docRef.update({
          'pendingInvitations': pendingInvitations,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Get user's name
        final userDoc = await _firestore.collection('users').doc(uid).get();
        final userName = userDoc.data()?['name'] ?? 'Someone';

        // Write activity message
        await docRef.collection('messages').add({
          'senderId': 'system',
          'senderName': 'System',
          'type': MessageKind.text.name,
          'text': '📢 $userName declined the invitation.',
          'createdAt': FieldValue.serverTimestamp(),
          'readBy': [uid],
        });
      }
    } catch (e) {
      throw Exception('Failed to decline group invitation: $e');
    }
  }

  Future<void> inviteUserToGroupChat(String chatId, String userId) async {
    try {
      final docRef = _chatsRef.doc(chatId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final data = doc.data() ?? {};
      final pendingInvitations = List<String>.from(data['pendingInvitations'] ?? []);
      final participants = List<String>.from(data['participants'] ?? []);

      if (!participants.contains(userId) && !pendingInvitations.contains(userId)) {
        pendingInvitations.add(userId);
        await docRef.update({
          'pendingInvitations': pendingInvitations,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw Exception('Failed to invite user: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMessages(String chatId) {
    return _chatsRef
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// Sends a **text** message.
  Future<void> sendTextMessage({
    required String chatId,
    required String text,
    Map<String, dynamic>? replyTo,
    List<String> mentions = const [],
  }) async {
    await _sendMessage(
      chatId: chatId,
      type: MessageKind.text,
      data: {
        'text': text,
        'replyTo':? replyTo,
        'mentions': mentions,
      },
    );
  }

  /// Sends a **system** message.
  Future<void> sendSystemMessage({
    required String chatId,
    required String text,
  }) async {
    final now = FieldValue.serverTimestamp();
    await _chatsRef.doc(chatId).collection('messages').add({
      'senderId': 'system',
      'senderName': 'System',
      'type': MessageKind.text.name,
      'text': text,
      'createdAt': now,
      'readBy': ['system'],
    });

    // Update parent chat
    final chatDoc = await _chatsRef.doc(chatId).get();
    if (chatDoc.exists) {
      final chatData = chatDoc.data()!;
      final participants = List<String>.from(chatData['participants'] ?? []);
      final unreadCount = Map<String, dynamic>.from(chatData['unreadCount'] ?? {});

      for (final p in participants) {
        unreadCount[p] = (unreadCount[p] ?? 0) + 1;
      }

      await _chatsRef.doc(chatId).update({
        'lastMessage': {
          'text': text,
          'senderId': 'system',
          'timestamp': now,
        },
        'unreadCount': unreadCount,
        'updatedAt': now,
      });
    }
  }

  /// Sends a **voice** message.
  Future<void> sendVoiceMessage({
    required String chatId,
    required int voiceDuration,
    String? audioUrl,
    Map<String, dynamic>? replyTo,
    List<String> mentions = const [],
  }) async {
    await _sendMessage(
      chatId: chatId,
      type: MessageKind.voice,
      data: {
        'voiceDuration': voiceDuration,
        'audioUrl': audioUrl,
        'replyTo':? replyTo,
        'mentions': mentions,
      },
    );
  }

  /// Sends a **pin** message.
  Future<void> sendPinMessage({
    required String chatId,
    required String place,
    String? meta,
    Map<String, dynamic>? replyTo,
    List<String> mentions = const [],
  }) async {
    await _sendMessage(
      chatId: chatId,
      type: MessageKind.pin,
      data: {
        'place': place,
        'meta': meta,
        'replyTo':? replyTo,
        'mentions': mentions,
      },
    );
  }

  /// Sends a **poll** message.
  Future<void> sendPollMessage({
    required String chatId,
    required String question,
    required List<String> options,
    Map<String, dynamic>? replyTo,
    List<String> mentions = const [],
  }) async {
    await _sendMessage(
      chatId: chatId,
      type: MessageKind.poll,
      data: {
        'question': question,
        'options': options,
        'picked': null,
        'replyTo':? replyTo,
        'mentions': mentions,
      },
    );
  }

  /// Sends an **image** message.
  Future<void> sendImageMessage({
    required String chatId,
    required String imageUrl,
    Map<String, dynamic>? replyTo,
    List<String> mentions = const [],
  }) async {
    await _sendMessage(
      chatId: chatId,
      type: MessageKind.image,
      data: {
        'imageUrl': imageUrl,
        'replyTo':? replyTo,
        'mentions': mentions,
      },
    );
  }

  /// Sends a **file** message.
  Future<void> sendFileMessage({
    required String chatId,
    required String fileUrl,
    required String fileName,
    required int fileSize,
    Map<String, dynamic>? replyTo,
    List<String> mentions = const [],
  }) async {
    await _sendMessage(
      chatId: chatId,
      type: MessageKind.file,
      data: {
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'replyTo':? replyTo,
        'mentions': mentions,
      },
    );
  }

  /// Sends a **link** message.
  Future<void> sendLinkMessage({
    required String chatId,
    required String url,
    String? title,
    String? description,
    Map<String, dynamic>? replyTo,
    List<String> mentions = const [],
  }) async {
    await _sendMessage(
      chatId: chatId,
      type: MessageKind.link,
      data: {
        'linkUrl': url,
        'linkTitle':? title,
        'linkDescription':? description,
        'replyTo':? replyTo,
        'mentions': mentions,
      },
    );
  }

  /// Internal helper that writes a message sub-document and updates the parent chat.
  Future<void> _sendMessage({
    required String chatId,
    required MessageKind type,
    required Map<String, dynamic> data,
  }) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('User not signed in');

    try {
      final messageRef = _chatsRef.doc(chatId).collection('messages').doc();
      final now = FieldValue.serverTimestamp();
      final senderName = _auth.currentUser?.displayName ?? 'User';

      final messageData = {
        'senderId': uid,
        'senderName': senderName,
        'type': type.name,
        'createdAt': now,
        'readBy': [uid],
        'reactionsMap': {},
        ...data,
      };

      // Determine the preview text for `lastMessage`
      String previewText;
      switch (type) {
        case MessageKind.text:
          previewText = data['text'] ?? '';
          break;
        case MessageKind.voice:
          previewText = '🎤 Voice message';
          break;
        case MessageKind.pin:
          previewText = '📍 ${data['place'] ?? 'Location'}';
          break;
        case MessageKind.poll:
          previewText = '📊 ${data['question'] ?? 'Poll'}';
          break;
        case MessageKind.card:
          previewText = '📇 Card';
          break;
        case MessageKind.image:
          previewText = '📷 Image shared';
          break;
        case MessageKind.file:
          previewText = '📄 File: ${data['fileName'] ?? 'Document'}';
          break;
        case MessageKind.link:
          previewText = '🔗 Link shared';
          break;
      }

      // Fetch participants to update unread counts
      final chatDoc = await _chatsRef.doc(chatId).get();
      final chatMap = chatDoc.data() ?? {};
      final participants = List<String>.from(chatMap['participants'] ?? []);

      // Build unread count updates – increment for all other users
      final unreadUpdates = <String, dynamic>{};
      final currentUnreadMap = Map<String, dynamic>.from(chatMap['unreadCount'] ?? {});
      for (final p in participants) {
        if (p == uid) {
          unreadUpdates[p] = 0;
        } else {
          final currentUnread = currentUnreadMap[p] ?? 0;
          unreadUpdates[p] = currentUnread + 1;
        }
      }

      // Batch write: message + chat metadata
      final batch = _firestore.batch();
      batch.set(messageRef, messageData);
      batch.update(_chatsRef.doc(chatId), {
        'lastMessage': {
          'text': previewText,
          'senderId': uid,
          'senderName': senderName,
          'timestamp': now,
        },
        'unreadCount': unreadUpdates,
        'updatedAt': now,
      });

      await batch.commit();

      // Trigger push notification triggers / database alerts
      final isGroup = chatMap['isGroup'] == true;
      final groupName = chatMap['groupName'] ?? 'Group';
      final muted = List<String>.from(chatMap['mutedBy'] ?? []);
      final mentionsList = List<String>.from(data['mentions'] ?? []);

      for (final p in participants) {
        if (p == uid) continue;
        final isMuted = muted.contains(p);
        final isMentioned = mentionsList.contains(p);
        
        // Skip notify if group is muted, UNLESS the user is explicitly @mentioned!
        if (isMuted && !isMentioned) continue;

        final alertTitle = isGroup ? groupName : senderName;
        final alertBody = isMentioned 
            ? '@$senderName mentioned you: $previewText'
            : '$senderName: $previewText';

        // Write directly to root notifications collection for the recipient
        await _firestore.collection('notifications').add({
          'userId': p,
          'title': alertTitle,
          'body': alertBody,
          'type': 'group_activity',
          'isRead': false,
          'metadata': {
            'chatId': chatId,
            'senderId': uid,
          },
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Read receipts
  // ---------------------------------------------------------------------------

  /// Marks all messages in [chatId] not yet read by the current user as read,
  /// and resets the current user's unread count to zero.
  Future<void> markMessagesAsRead(String chatId) async {
    final uid = _currentUid;
    if (uid == null) return;

    try {
      // Fetch unread messages
      final unreadQuery = await _chatsRef
          .doc(chatId)
          .collection('messages')
          .where('readBy', whereNotIn: [
            [uid]
          ])
          .get();

      if (unreadQuery.docs.isEmpty) return;

      final batch = _firestore.batch();

      for (final doc in unreadQuery.docs) {
        final readBy = List<String>.from(doc.data()['readBy'] ?? []);
        if (!readBy.contains(uid)) {
          batch.update(doc.reference, {
            'readBy': FieldValue.arrayUnion([uid]),
          });
        }
      }

      // Reset unread count for this user
      batch.update(_chatsRef.doc(chatId), {
        'unreadCount.$uid': 0,
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to mark messages as read: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Typing indicator
  // ---------------------------------------------------------------------------

  /// Updates the typing status for the current user in [chatId].
  Future<void> updateTypingStatus({
    required String chatId,
    required bool isTyping,
  }) async {
    final uid = _currentUid;
    if (uid == null) return;

    try {
      await _chatsRef.doc(chatId).update({
        'typingStatus.$uid': isTyping,
      });
    } catch (e) {
      // Non-critical – swallow in production to avoid UX disruption.
      throw Exception('Failed to update typing status: $e');
    }
  }

  /// Updates a poll message's `picked` field in Firestore.
  Future<void> answerPoll({
    required String chatId,
    required String messageId,
    required int optionIndex,
  }) async {
    try {
      await _chatsRef
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'picked': optionIndex});
    } catch (e) {
      throw Exception('Failed to answer poll: $e');
    }
  }
}
