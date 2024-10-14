import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:wchat/ui/Home/app_drawer.dart';
import 'package:wchat/services/api/shift_api.dart';
import 'package:wchat/data/models/shift.dart';

class ScheduleScreen extends StatefulWidget {
  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late ShiftApi _shiftApi;
  Map<DateTime, List<Shift>> _events = {};

  @override
  void initState() {
    super.initState();
    _shiftApi = ShiftApi();
    _fetchShifts();
  }

  Future<void> _fetchShifts() async {
    try {
      final shifts = await _shiftApi.getUserAvailableShifts();
      setState(() {
        _events = _groupShiftsByDay(shifts);
      });
    } catch (e) {
      print('Error fetching shifts: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load shifts: $e')),
      );
    }
  }

  Map<DateTime, List<Shift>> _groupShiftsByDay(List<Shift> shifts) {
    Map<DateTime, List<Shift>> groupedShifts = {};
    for (var shift in shifts) {
      final day = DateTime(shift.startTime.year, shift.startTime.month, shift.startTime.day);
      if (groupedShifts[day] == null) groupedShifts[day] = [];
      groupedShifts[day]!.add(shift);
    }
    return groupedShifts;
  }

  List<Shift> _getEventsForDay(DateTime day) {
    return _events[day] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Schedule'),
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            eventLoader: _getEventsForDay,
          ),
          Expanded(
            child: ListView(
              children: _getEventsForDay(_selectedDay ?? _focusedDay)
                  .map((shift) => ListTile(
                        title: Text('${shift.departmentName} Shift'),
                        subtitle: Text('${shift.startTime.toLocal()} - ${shift.endTime.toLocal()}'),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
