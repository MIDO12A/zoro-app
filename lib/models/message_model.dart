class MessageModel {
  final String msgId;
  final String roomId;
  final String senderUid;
  final String senderName;
  final String senderPhotoUrl;
  final String text;
  final String type;
  final int timestamp;
  final String? imageUrl;
  final String? activeBubble;

  MessageModel({
    this.msgId = '',
    this.roomId = '',
    this.senderUid = '',
    this.senderName = '',
    this.senderPhotoUrl = '',
    this.text = '',
    this.type = 'text',
    this.timestamp = 0,
    this.imageUrl,
    this.activeBubble,
  });

  factory MessageModel.fromMap(Map map) {
    return MessageModel(
      msgId: map['msg_id']?.toString() ?? '',
      roomId: map['room_id']?.toString() ?? '',
      senderUid: map['sender_uid']?.toString() ?? '',
      senderName: map['sender_name']?.toString() ?? '',
      senderPhotoUrl: map['sender_photo_url']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      type: map['type']?.toString() ?? 'text',
      timestamp: map['created_at'] is int
          ? (map['created_at'] as int)
          : DateTime.tryParse(map['created_at']?.toString() ?? '')
                  ?.millisecondsSinceEpoch ?? 0,
      imageUrl: map['image_url']?.toString(),
      activeBubble: map['active_bubble']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'msg_id': msgId,
        'room_id': roomId,
        'sender_uid': senderUid,
        'sender_name': senderName,
        'sender_photo_url': senderPhotoUrl,
        'text': text,
        'type': type,
        'created_at': timestamp > 0
            ? DateTime.fromMillisecondsSinceEpoch(timestamp).toIso8601String()
            : null,
        'image_url': imageUrl,
        'active_bubble': activeBubble,
      };
}
