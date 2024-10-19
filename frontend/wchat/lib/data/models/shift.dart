import 'package:flutter/material.dart';

class Shift {
  final int id;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final String departmentName;

  Shift({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.departmentName,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'],
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      status: json['status'],
      departmentName: json['department_name'],
    );
  }


  DateTime get date => DateTime(startTime.year, startTime.month, startTime.day);

  TimeOfDay get startTimeOfDay => TimeOfDay.fromDateTime(startTime);
  TimeOfDay get endTimeOfDay => TimeOfDay.fromDateTime(endTime);
}
