import 'package:flutter/material.dart';
import 'package:wchat/data/app_theme.dart';
import 'package:wchat/services/api/availability_api.dart';
import 'package:flutter/services.dart';
import 'package:wchat/services/storage/jwt_decoder.dart';
import 'package:wchat/ui/Home/app_drawer.dart';

class AvailabilityForm extends StatefulWidget {
  const AvailabilityForm({Key? key}) : super(key: key);

  @override
  State<AvailabilityForm> createState() => _AvailabilityFormState();
}

class _AvailabilityFormState extends State<AvailabilityForm> {
  final AvailabilityApi _availabilityApi = AvailabilityApi();
  bool _isLoading = true;
  List<Map<String, dynamic>> _availability = [];
  int? _userId;

  final List<String> _daysOfWeek = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  ];

  @override
  void initState() {
    super.initState();
    _initializeUserId();
  }

  Future<void> _initializeUserId() async {
    final userId = await JwtDecoder.getUserId();
    if (userId == null) {
      // Handle the case where userId is not available
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error: Unable to get user information'),
          backgroundColor: AppColors.error,
        ),
      );
      Navigator.of(context).pop(); // Return to previous screen
      return;
    }
    setState(() {
      _userId = userId;
    });
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    if (_userId == null) return;
    
    try {
      final availability = await _availabilityApi.getAvailability(_userId!);
      setState(() {
        _availability = availability ?? AvailabilityApi.createDefaultWeekAvailability();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading availability: $e');
      setState(() {
        _availability = AvailabilityApi.createDefaultWeekAvailability();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAvailability() async {
    if (_userId == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final success = await _availabilityApi.upsertAvailability(
        _userId!,
        _availability,
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Availability saved successfully'),
            backgroundColor: AppColors.secondary,
          ),
        );
      } else {
        throw Exception('Failed to save availability');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save availability'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateAvailability(int day, String field, dynamic value) {
    setState(() {
      final dayIndex = _availability.indexWhere((item) => item['day'] == day);
      if (dayIndex != -1) {
        _availability[dayIndex][field] = value;
      }
    });
  }

  Future<TimeOfDay?> _showTimePicker(BuildContext context, TimeOfDay initialTime) async {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              secondary: AppColors.secondary,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  TimeOfDay _parseTimeString(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Your Availability'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveAvailability,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Schedule',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  ..._availability.map((day) {
                    final dayIndex = day['day'] as int;
                    final isAvailable = day['is_available'] as bool;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _daysOfWeek[dayIndex],
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Switch(
                                  value: isAvailable,
                                  onChanged: (value) {
                                    _updateAvailability(dayIndex, 'is_available', value);
                                  },
                                  activeColor: AppColors.secondary,
                                ),
                              ],
                            ),
                            if (isAvailable) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () async {
                                        final time = await _showTimePicker(
                                          context,
                                          _parseTimeString(day['start_time']),
                                        );
                                        if (time != null) {
                                          _updateAvailability(
                                            dayIndex,
                                            'start_time',
                                            _formatTimeOfDay(time),
                                          );
                                        }
                                      },
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.access_time),
                                          const SizedBox(width: 8),
                                          Text('Start: ${day['start_time']}'),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () async {
                                        final time = await _showTimePicker(
                                          context,
                                          _parseTimeString(day['end_time']),
                                        );
                                        if (time != null) {
                                          _updateAvailability(
                                            dayIndex,
                                            'end_time',
                                            _formatTimeOfDay(time),
                                          );
                                        }
                                      },
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.access_time),
                                          const SizedBox(width: 8),
                                          Text('End: ${day['end_time']}'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
    );
  }
}
