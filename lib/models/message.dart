enum MessageKind { text, voice, card, poll, pin, image, file, link }
enum MessageSender { me, them }

class Message {
  final String id;
  final MessageKind kind;
  final MessageSender from;
  final String time;
  final List<String> reactions; // Keep for compatibility
  final Map<String, String> reactionsMap; // uid -> emoji
  final String? contactName;
  final String? senderId;
  final String? senderName;
  
  // Text kind
  final String? text;
  
  // Voice kind
  final int? seconds;
  final String? audioUrl;
  
  // Card kind
  final String? title;
  final String? subtitle;
  
  // Poll kind
  final String? question;
  final List<String>? options;
  int? picked; // selected option index
  
  // Pin kind
  final String? place;
  final String? meta;

  // Image kind
  final String? imageUrl;

  // File kind
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;

  // Link kind
  final String? linkUrl;
  final String? linkTitle;
  final String? linkDescription;

  // Reply structure
  final Map<String, dynamic>? replyTo; // { 'messageId': string, 'text': string, 'senderName': string }

  // Mentions
  final List<String> mentions; // list of mentioned user UIDs

  // Status check & Metadata
  final bool isRead;
  final DateTime? _createdAt;
  DateTime get createdAt => _createdAt ?? DateTime.now();

  Message({
    required this.id,
    required this.kind,
    required this.from,
    required this.time,
    this.reactions = const [],
    this.reactionsMap = const {},
    this.contactName,
    this.senderId,
    this.senderName,
    this.text,
    this.seconds,
    this.audioUrl,
    this.title,
    this.subtitle,
    this.question,
    this.options,
    this.picked,
    this.place,
    this.meta,
    this.imageUrl,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.linkUrl,
    this.linkTitle,
    this.linkDescription,
    this.replyTo,
    this.mentions = const [],
    this.isRead = false,
    this._createdAt,
  });
}
