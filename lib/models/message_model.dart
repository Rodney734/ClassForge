class MessageModel {
  final int? id;
  final String messageId;
  final String senderId;
  final String senderName;
  final String? senderProfilePicture;
  final String message;
  final String type;
  final String? fileName;
  final String? fileUrl;
  final String? filePath;
  final DateTime timestamp;
  final bool isMe;
  final bool isDelivered;
  final bool isRead;
  final int level;

  MessageModel({
    this.id,
    required this.messageId,
    required this.senderId,
    required this.senderName,
    this.senderProfilePicture,
    required this.message,
    this.type = 'text',
    this.fileName,
    this.fileUrl,
    this.filePath,
    required this.timestamp,
    required this.isMe,
    this.isDelivered = false,
    this.isRead = false,
    required this.level,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'],
      messageId: map['messageId'],
      senderId: map['senderId'],
      senderName: map['senderName'],
      senderProfilePicture: map['senderProfilePicture'],
      message: map['message'],
      type: map['type'] ?? 'text',
      fileName: map['fileName'],
      fileUrl: map['fileUrl'],
      filePath: map['filePath'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      isMe: map['isMe'] == 1,
      isDelivered: map['isDelivered'] == 1,
      isRead: map['isRead'] == 1,
      level: map['level'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'senderName': senderName,
      'senderProfilePicture': senderProfilePicture,
      'message': message,
      'type': type,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'filePath': filePath,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isMe': isMe ? 1 : 0,
      'isDelivered': isDelivered ? 1 : 0,
      'isRead': isRead ? 1 : 0,
      'level': level,
    };
  }
}
