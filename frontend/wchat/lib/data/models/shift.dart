import 'package:flutter/material.dart';

class Shift {
  final int id;
  final DateTime startTime;
  final DateTime endTime;
  final int? scheduledById;  // Made optional
  final int? departmentId;   // Made optional
  final int? userId;
  final String status;
  final String departmentName;

  Shift({
    required this.id,
    required this.startTime,
    required this.endTime,
    this.scheduledById,    // Made optional
    this.departmentId,     // Made optional
    this.userId,
    required this.status,
    required this.departmentName,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    // Handle both response formats
    return Shift(
      id: json['id'] as int,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      scheduledById: json['scheduled_by_id'] as int?,  // Made nullable
      departmentId: json['department_id'] as int?,     // Made nullable
      userId: json['user_id'] as int?,
      status: json['status'] as String,
      departmentName: json['department_name'] as String? ?? '',  // Provide default value
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'scheduled_by_id': scheduledById,
      'department_id': departmentId,
      'user_id': userId,
      'status': status,
      'department_name': departmentName,
    };
  }

  Shift copyWith({
    int? id,
    DateTime? startTime,
    DateTime? endTime,
    int? scheduledById,
    int? departmentId,
    int? userId,
    String? status,
    String? departmentName,
  }) {
    return Shift(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      scheduledById: scheduledById ?? this.scheduledById,
      departmentId: departmentId ?? this.departmentId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      departmentName: departmentName ?? this.departmentName,
    );
  }

  // Keep all your existing helper methods
  bool get isAvailableForExchange => status == 'available_for_exchange';
  bool get isScheduled => status == 'scheduled';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  double get durationInHours {
    return endTime.difference(startTime).inMinutes / 60.0;
  }

  bool get isOngoing {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  static List<String> get validStatuses => [
    'scheduled',
    'completed',
    'cancelled',
    'available_for_exchange'
  ];

  DateTime get date => DateTime(startTime.year, startTime.month, startTime.day);

  TimeOfDay get startTimeOfDay => TimeOfDay.fromDateTime(startTime);
  TimeOfDay get endTimeOfDay => TimeOfDay.fromDateTime(endTime);

  @override
  String toString() {
    return 'Shift{id: $id, startTime: $startTime, endTime: $endTime, '
           'scheduledById: $scheduledById, departmentId: $departmentId, '
           'userId: $userId, status: $status, departmentName: $departmentName}';
  }
}