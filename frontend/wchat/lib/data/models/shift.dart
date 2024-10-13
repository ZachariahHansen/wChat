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

  // Getter for date (assuming you want the date of the start time)
  DateTime get date => DateTime(startTime.year, startTime.month, startTime.day);

  // Getters for TimeOfDay
  TimeOfDay get startTimeOfDay => TimeOfDay.fromDateTime(startTime);
  TimeOfDay get endTimeOfDay => TimeOfDay.fromDateTime(endTime);
}

/**
 * Notes for if I want to use the intl package for formatting dates and times:
 * 
 * import 'package:intl/intl.dart';

// ...

final dateFormatter = DateFormat('yyyy-MM-dd');
final timeFormatter = DateFormat('HH:mm');

String formattedDate = dateFormatter.format(shift.startTime);
String formattedStartTime = timeFormatter.format(shift.startTime);
String formattedEndTime = timeFormatter.format(shift.endTime);


dependencies:
  intl: ^0.17.0
 */