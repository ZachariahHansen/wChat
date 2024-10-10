import 'package:flutter/material.dart';
import 'package:wchat/ui/Home/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    // TODO: Implement build method
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            NextShiftWidget(nextShift: Shift(date: DateTime.now(), startTime: TimeOfDay(hour: 9, minute: 0), endTime: TimeOfDay(hour: 17, minute: 0))),
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
            const Text(
              'Next Shift'
            ),
            const SizedBox(height: 8),
            if (nextShift != null)
              _buildShiftInfo(context)
            else
              const Text(
                'No upcoming shifts',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${nextShift!.startTime.format(context)} - ${nextShift!.endTime.format(context)}'
        ),
        const SizedBox(height: 4),
        Text(
          nextShift!.date.toString()
        ),
      ],
    );
  }
}

// I will add this to a separate file later
class Shift {
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  Shift({required this.date, required this.startTime, required this.endTime});
}
