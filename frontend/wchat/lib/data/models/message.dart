class Message {
  final int id;
  final String content;
  final DateTime timeStamp;
  bool isRead;
  final int sentByUserId;
  final int receivedByUserId;

  Message({
    required this.id,
    required this.content,
    required this.timeStamp,
    this.isRead = false,
    required this.sentByUserId,
    required this.receivedByUserId,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      content: json['content'],
      timeStamp: DateTime.parse(json['time_stamp']),
      isRead: json['is_read'],
      sentByUserId: json['sent_by_user_id'],
      receivedByUserId: json['received_by_user_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'time_stamp': timeStamp.toIso8601String(),
      'is_read': isRead,
      'sent_by_user_id': sentByUserId,
      'received_by_user_id': receivedByUserId,
    };
  }
}