import 'package:flutter/material.dart';
import 'package:wchat/data/models/shift.dart';
import 'package:wchat/services/api/shift_api.dart';
import 'package:intl/intl.dart';
import 'package:wchat/ui/Home/manager_app_drawer.dart';  

class ManagerHomeScreen extends StatefulWidget {
  const ManagerHomeScreen({super.key});

  @override
  State<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> {
  Shift? _nextShift;
  bool _isLoading = true;

  final ShiftApi _shiftApi = ShiftApi();
  
  @override
  void initState() {
    super.initState();
    _fetchNextShift();
  }

  Future<void> _fetchNextShift() async {
    try {
      print('fetching next shift');
      final nextShift = await _shiftApi.getNextShift();
      setState(() {
        _nextShift = nextShift;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching next shift: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Dashboard'),
      ),
      drawer: const ManagerDrawer(),  // Changed to ManagerDrawer
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const CurrentTimeWidget(),
            _isLoading
                ? const CircularProgressIndicator()
                : NextShiftWidget(nextShift: _nextShift),
          ],
        ),
      ),
    );
  }
}

class CurrentTimeWidget extends StatelessWidget {
  const CurrentTimeWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Current Time'),
            const SizedBox(height: 8),
            Text(DateTime.now().toString()),
          ],
        ),
      ),
    );
  }
}

class NextShiftWidget extends StatelessWidget {
  final Shift? nextShift;

  const NextShiftWidget({Key? key, this.nextShift}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Next Shift'),
            const SizedBox(height: 8),
            if (nextShift != null)
              _buildShiftInfo(context)
            else
              const Text('No upcoming shifts'),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftInfo(BuildContext context) {
    final DateFormat dateFormatter = DateFormat('yyyy-MM-dd');
    final DateFormat timeFormatter = DateFormat('HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${timeFormatter.format(nextShift!.startTime)} - ${timeFormatter.format(nextShift!.endTime)}',
        ),
        const SizedBox(height: 4),
        Text(dateFormatter.format(nextShift!.date)),
        const SizedBox(height: 4),
        Text('Status: ${nextShift!.status}'),
        Text('Department: ${nextShift!.departmentName}'),
      ],
    );
  }
}