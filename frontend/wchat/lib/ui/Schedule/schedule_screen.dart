import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:wchat/ui/Home/app_drawer.dart';
import 'package:wchat/services/api/shift_api.dart';
import 'package:wchat/data/models/shift.dart';
import 'package:intl/intl.dart';

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
  int _availableShiftsCount = 0;
  bool _isLoadingAvailableShifts = true;

  @override
  void initState() {
    super.initState();
    _shiftApi = ShiftApi();
    _selectedDay = _focusedDay;
    _fetchShifts();
    _fetchAvailableShifts();
  }

  Future<void> _fetchAvailableShifts() async {
    try {
      final response = await _shiftApi.getAvailableShifts();
      setState(() {
        _availableShiftsCount = (response['shifts'] as List).length;
        _isLoadingAvailableShifts = false;
      });
    } catch (e) {
      print('Error fetching available shifts: $e');
      setState(() {
        _isLoadingAvailableShifts = false;
      });
    }
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
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
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
            calendarStyle: CalendarStyle(
              markerDecoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: _getEventsForDay(_selectedDay ?? _focusedDay)
                  .map((shift) => _buildShiftTile(shift))
                  .toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: Stack(
        children: [
          FloatingActionButton(
            onPressed: () {
              Navigator.pushNamed(context, '/shifts/available').then((_) {
                // Refresh available shifts count when returning from the available shifts screen
                _fetchAvailableShifts();
              });
            },
            child: const Icon(Icons.attach_money),
            backgroundColor: _availableShiftsCount > 0 
              ? Theme.of(context).colorScheme.primary 
              : Theme.of(context).colorScheme.secondary,
          ),
          if (_availableShiftsCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(6),
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                child: Text(
                  '$_availableShiftsCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (_isLoadingAvailableShifts)
            const Positioned(
              right: 0,
              top: 0,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShiftTile(Shift shift) {
    final timeFormatter = DateFormat('HH:mm');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(Icons.work, color: Theme.of(context).primaryColor),
        title: Text('${shift.departmentName} Shift'),
        subtitle: Text(
          '${timeFormatter.format(shift.startTime)} - ${timeFormatter.format(shift.endTime)}',
        ),
        trailing: Text(
          shift.status,
          style: TextStyle(
            color: _getStatusColor(shift.status),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}