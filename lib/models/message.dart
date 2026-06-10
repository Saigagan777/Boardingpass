enum MessageKind { text, voice, card, poll, pin }
enum MessageSender { me, them }

class Message {
  final String id;
  final MessageKind kind;
  final MessageSender from;
  final String time;
  final List<String> reactions;
  final String? contactName;
  
  // Text kind
  final String? text;
  
  // Voice kind
  final int? seconds;
  
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

  Message({
    required this.id,
    required this.kind,
    required this.from,
    required this.time,
    this.reactions = const [],
    this.contactName,
    this.text,
    this.seconds,
    this.title,
    this.subtitle,
    this.question,
    this.options,
    this.picked,
    this.place,
    this.meta,
  });
}
