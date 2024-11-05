import 'package:flutter/material.dart';

// lib/data/models/shift.dart
class Shift {
  final int id;
  final DateTime startTime;
  final DateTime endTime;
  final int scheduledById;
  final int departmentId;
  final int? userId;
  final String status;
  final String departmentName;

  Shift({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.scheduledById,
    required this.departmentId,
    this.userId,
    required this.status,
    this.departmentName = '',
  });

  // Factory constructor to create a Shift from JSON
  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'] as int,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      scheduledById: json['scheduled_by_id'] as int,
      departmentId: json['department_id'] as int,
      userId: json['user_id'] as int?,
      status: json['status'] as String,
      departmentName: json['department_name'] as String,
    );
  }

  // Convert Shift to JSON
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

  // Create a copy of Shift with optional parameter updates
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

  // Helper method to check if shift is available for exchange
  bool get isAvailableForExchange => status == 'available_for_exchange';

  // Helper method to check if shift is active/scheduled
  bool get isScheduled => status == 'scheduled';

  // Helper method to check if shift is completed
  bool get isCompleted => status == 'completed';

  // Helper method to check if shift is cancelled
  bool get isCancelled => status == 'cancelled';

  // Helper method to get shift duration in hours
  double get durationInHours {
    return endTime.difference(startTime).inMinutes / 60.0;
  }

  // Helper method to check if shift is currently ongoing
  bool get isOngoing {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  // Static getter for valid status values
  static List<String> get validStatuses => [
    'scheduled',
    'completed',
    'cancelled',
    'available_for_exchange'
  ];

  @override
  String toString() {
    return 'Shift{id: $id, startTime: $startTime, endTime: $endTime, '
           'scheduledById: $scheduledById, departmentId: $departmentId, '
           'userId: $userId, status: $status}';
  }

  DateTime get date => DateTime(startTime.year, startTime.month, startTime.day);

  TimeOfDay get startTimeOfDay => TimeOfDay.fromDateTime(startTime);
  TimeOfDay get endTimeOfDay => TimeOfDay.fromDateTime(endTime);
}
