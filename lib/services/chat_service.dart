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

  /// Creates a new chat document between [userId1] and [userId2].
  ///
  /// Returns the new chat document's ID.
  Future<String> createChat({
    required String userId1,
    required String userId2,
  }) async {
    try {
      final chatDoc = await _chatsRef.add({
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

  /// Returns the existing chat ID between two users, or creates a new one
  /// if none exists.
  Future<String> getOrCreateChat({
    required String userId1,
    required String userId2,
  }) async {
    try {
      // Look for a chat that contains both participants
      final query = await _chatsRef
          .where('participants', arrayContains: userId1)
          .get();

      for (final doc in query.docs) {
        final participants = List<String>.from(doc['participants'] ?? []);
        if (participants.contains(userId2)) {
          return doc.id;
        }
      }

      // No existing chat – create one
      return createChat(userId1: userId1, userId2: userId2);
    } catch (e) {
      throw Exception('Failed to get or create chat: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Chat list stream
  // ---------------------------------------------------------------------------

  /// Streams the current user's chat list, ordered by most-recently updated.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamUserChats() {
    final uid = _currentUid;
    if (uid == null) return const Stream.empty();

    return _chatsRef
        .where('participants', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  /// Streams all messages in [chatId], ordered oldest-first.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMessages(String chatId) {
    return _chatsRef
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// Sends a **text** message to the given [chatId].
  Future<void> sendTextMessage({
    required String chatId,
    required String text,
  }) async {
    await _sendMessage(
      chatId: chatId,
      type: MessageKind.text,
      data: {'text': text},
    );
  }

  /// Sends a **voice** message to the given [chatId].
  Future<void> sendVoiceMessage({
    required String chatId,
    required int voiceDuration,
    String? audioUrl,
  }) async {
    await _sendMessage(
      chatId: chatId,
      type: MessageKind.voice,
      data: {
        'voiceDuration': voiceDuration,
        'audioUrl': ?audioUrl,
      },
    );
  }

  /// Sends a **pin** (location share) message to the given [chatId].
  Future<void> sendPinMessage({
    required String chatId,
    required String place,
    String? meta,
  }) async {
    await _sendMessage(
      chatId: chatId,
      type: MessageKind.pin,
      data: {
        'place': place,
        'meta': ?meta,
      },
    );
  }

  /// Sends a **poll** message to the given [chatId].
  Future<void> sendPollMessage({
    required String chatId,
    required String question,
    required List<String> options,
  }) async {
    await _sendMessage(
      chatId: chatId,
      type: MessageKind.poll,
      data: {
        'question': question,
        'options': options,
        'picked': null,
      },
    );
  }

  /// Internal helper that writes a message sub-document and updates the
  /// parent chat's `lastMessage`, `unreadCount`, and `updatedAt`.
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

      final messageData = {
        'senderId': uid,
        'type': type.name,
        'createdAt': now,
        'readBy': [uid],
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
      }

      // Fetch participants to update unread counts
      final chatDoc = await _chatsRef.doc(chatId).get();
      final participants =
          List<String>.from(chatDoc.data()?['participants'] ?? []);
      final otherUid = participants.firstWhere(
        (p) => p != uid,
        orElse: () => '',
      );

      // Build unread count updates – increment for the other user
      final unreadUpdates = <String, dynamic>{};
      if (otherUid.isNotEmpty) {
        final currentUnread =
            (chatDoc.data()?['unreadCount'] as Map<String, dynamic>?)?[otherUid];
        unreadUpdates[otherUid] = (currentUnread ?? 0) + 1;
      }
      unreadUpdates[uid] = 0;

      // Batch write: message + chat metadata
      final batch = _firestore.batch();
      batch.set(messageRef, messageData);
      batch.update(_chatsRef.doc(chatId), {
        'lastMessage': {
          'text': previewText,
          'senderId': uid,
          'timestamp': now,
        },
        'unreadCount': unreadUpdates,
        'updatedAt': now,
      });

      await batch.commit();
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
}
