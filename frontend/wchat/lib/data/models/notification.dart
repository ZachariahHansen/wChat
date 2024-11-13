class Notification {
  final int id;
  final String content;
  final DateTime timeStamp;
  final bool isRead;

  Notification({
    required this.id,
    required this.content,
    required this.timeStamp,
    required this.isRead,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'],
      content: json['content'],
      timeStamp: DateTime.parse(json['time_stamp']),
      isRead: json['is_read'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'time_stamp': timeStamp.toIso8601String(),
      'is_read': isRead,
    };
  }
}