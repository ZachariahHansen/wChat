import 'package:flutter/material.dart';
import 'package:wchat/data/app_theme.dart';
import 'package:wchat/services/api/availability_api.dart';
import 'package:flutter/services.dart';
import 'package:wchat/services/storage/jwt_decoder.dart';
import 'package:wchat/ui/Home/app_drawer.dart';
import 'package:wchat/ui/Availability/time_off_widget.dart';

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
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final result = await showDialog(
                context: context,
                builder: (context) => const TimeOffRequestDialog(),
              );
              if (result == true) {
                _loadAvailability();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveAvailability,
          ),
        ],
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
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadAvailability,
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.textSecondary.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              color: AppColors.primary,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Weekly Schedule',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._availability.map((day) {
                        final dayIndex = day['day'] as int;
                        final isAvailable = day['is_available'] as bool;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: AppColors.primaryLight.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isAvailable
                                                ? AppColors.secondary.withOpacity(0.1)
                                                : AppColors.error.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isAvailable
                                                ? Icons.check_circle_outline
                                                : Icons.do_not_disturb_on_outlined,
                                            color: isAvailable
                                                ? AppColors.secondary
                                                : AppColors.error,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          _daysOfWeek[dayIndex],
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
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
                                        child: _buildTimeButton(
                                          context,
                                          'Start',
                                          day['start_time'],
                                          () async {
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
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildTimeButton(
                                          context,
                                          'End',
                                          day['end_time'],
                                          () async {
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
              ),
      ),
    );
  }

  Widget _buildTimeButton(
    BuildContext context,
    String label,
    String time,
    VoidCallback onPressed,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primaryLight.withOpacity(0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.access_time,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '$label: $time',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}