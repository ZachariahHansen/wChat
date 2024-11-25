import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:wchat/ui/Home/app_drawer.dart';
import 'package:wchat/services/api/shift_api.dart';
import 'package:wchat/services/api/user_api.dart';
import 'package:wchat/data/models/shift.dart';
import 'package:wchat/data/models/user.dart';
import 'package:intl/intl.dart';
import 'package:wchat/data/app_theme.dart';
import 'package:wchat/services/storage/jwt_decoder.dart';

class ScheduleScreen extends StatefulWidget {
  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late ShiftApi _shiftApi;
  late UserApi _userApi;
  Map<DateTime, List<Shift>> _events = {};
  int _availableShiftsCount = 0;
  bool _isLoadingAvailableShifts = true;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _shiftApi = ShiftApi();
    _userApi = UserApi();
    _selectedDay = _focusedDay;
    _loadUserAndShifts();
  }

  Future<void> _loadUserAndShifts() async {
    try {
      final userId = await JwtDecoder.getUserId();
      if (userId == null) {
        throw Exception('User ID not found in JWT payload');
      }
      final user = await _userApi.getUserProfile(userId);
      setState(() {
        _currentUser = user;
      });
      await _fetchShifts();
      await _fetchAvailableShifts();
    } catch (e) {
      print('Error loading user and shifts: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load user data: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
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
        SnackBar(
          content: Text('Failed to load shifts: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Map<DateTime, List<Shift>> _groupShiftsByDay(List<Shift> shifts) {
    Map<DateTime, List<Shift>> groupedShifts = {};
    for (var shift in shifts) {
      final day = DateTime(
          shift.startTime.year, shift.startTime.month, shift.startTime.day);
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
        title: const Text('Schedule'),
        elevation: 0,
      ),
      drawer: const AppDrawer(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withOpacity(0.1),
              AppColors.background,
            ],
          ),
        ),
        child: Column(
          children: [
            _buildCalendarCard(),
            const SizedBox(height: 16),
            _buildShiftsList(),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildCalendarCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
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
            selectedDecoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            markerDecoration: BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
            ),
            weekendTextStyle: TextStyle(color: AppColors.textSecondary),
            outsideTextStyle:
                TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
          ),
          headerStyle: HeaderStyle(
            titleTextStyle: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            formatButtonDecoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            formatButtonTextStyle: TextStyle(color: AppColors.textLight),
          ),
        ),
      ),
    );
  }

  Widget _buildShiftsList() {
    final shifts = _getEventsForDay(_selectedDay ?? _focusedDay);

    return Expanded(
      child: shifts.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: shifts.length,
              itemBuilder: (context, index) => _buildShiftTile(shifts[index]),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No shifts scheduled for this day',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftTile(Shift shift) {
    final timeFormatter = DateFormat('HH:mm');
    final currencyFormatter = NumberFormat.currency(symbol: '\$');

    // Calculate expected earnings
    double expectedEarnings = 0;
    if (_currentUser != null) {
      final hours = shift.endTime.difference(shift.startTime).inMinutes / 60;
      expectedEarnings = hours * _currentUser!.hourlyRate;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.primaryLight.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.work,
            color: AppColors.primary,
          ),
        ),
        title: Text(
          '${shift.departmentName} Shift',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${timeFormatter.format(shift.startTime)} - ${timeFormatter.format(shift.endTime)}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_currentUser != null)
              Row(
                children: [
                  Icon(
                    Icons.attach_money,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Expected earnings: ${currencyFormatter.format(expectedEarnings)}',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getStatusColor(shift.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            shift.status,
            style: TextStyle(
              color: _getStatusColor(shift.status),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Stack(
      children: [
        FloatingActionButton.extended(
          onPressed: () {
            Navigator.pushNamed(context, '/shifts/available').then((_) {
              _fetchAvailableShifts();
            });
          },
          icon: const Icon(Icons.attach_money),
          label: const Text('Available Shifts'),
          backgroundColor: _availableShiftsCount > 0
              ? AppColors.secondary
              : AppColors.secondaryLight,
        ),
        if (_availableShiftsCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.background, width: 2),
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Text(
                '$_availableShiftsCount',
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
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
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return AppColors.primary;
      case 'completed':
        return AppColors.secondary;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}
