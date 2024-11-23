import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:wchat/data/models/department.dart';
import 'package:wchat/services/api/department_api.dart';
import 'package:wchat/services/api/openai_api.dart';
import 'package:wchat/ui/Home/manager_app_drawer.dart';
import 'package:wchat/data/app_theme.dart';
import 'package:intl/intl.dart';

class BusyTimeSlot {
  TimeOfDay startTime;
  TimeOfDay endTime;
  int requiredEmployees;

  BusyTimeSlot({
    required this.startTime,
    required this.endTime,
    required this.requiredEmployees,
  });
}

class GenerateShiftsScreen extends StatefulWidget {
  const GenerateShiftsScreen({super.key});

  @override
  State<GenerateShiftsScreen> createState() => _GenerateShiftsScreenState();
}

class _GenerateShiftsScreenState extends State<GenerateShiftsScreen> {
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  final DepartmentApi _departmentApi = DepartmentApi();
  final AISchedulingService _aiService = AISchedulingService();
  
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  Department? _selectedDepartment;
  List<Department> _departments = [];
  bool _autoAssign = false;
  bool _allowOvertime = false;
  double _maxHours = 8.0;
  List<BusyTimeSlot> _busyTimeSlots = [];
  bool _isLoading = true;
  bool _isGenerating = false;
  Map<String, dynamic>? _generatedSchedule;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  String _formatRequirements() {
    final StringBuffer requirements = StringBuffer();
    
    requirements.writeln('Regular shift hours: ${_startTime.format(context)} to ${_endTime.format(context)}');
    
    if (_busyTimeSlots.isNotEmpty) {
      requirements.writeln('\nBusy time slots requiring additional staff:');
      for (var slot in _busyTimeSlots) {
        requirements.writeln('- ${slot.startTime.format(context)} to ${slot.endTime.format(context)} needs ${slot.requiredEmployees} staff');
      }
    }
    
    requirements.writeln('\nAdditional requirements:');
    requirements.writeln('- Maximum hours per shift: ${_maxHours.toStringAsFixed(1)} hours');
    if (_allowOvertime) {
      requirements.writeln('- Overtime is allowed');
    } else {
      requirements.writeln('- No overtime allowed');
    }
    if (_autoAssign) {
      requirements.writeln('- Auto-assign shifts to available staff');
    }
    
    return requirements.toString();
  }

  Future<void> _generateShifts() async {
    if (_selectedStartDate == null || _selectedEndDate == null) {
      _showErrorSnackBar('Please select date range');
      return;
    }
    if (_selectedDepartment == null) {
      _showErrorSnackBar('Please select department');
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedSchedule = null;
    });

    try {
      final requirements = _formatRequirements();
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedStartDate!);
      
      final schedule = await _aiService.generateSchedule(
        requirements: requirements,
        departmentId: _selectedDepartment!.id,
        date: formattedDate,
      );

      setState(() {
        _generatedSchedule = schedule;
        _isGenerating = false;
      });

      _showScheduleDialog(schedule);
    } catch (e) {
      setState(() => _isGenerating = false);
      _showErrorSnackBar('Failed to generate shifts: $e');
    }
  }

  void _showScheduleDialog(Map<String, dynamic> schedule) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            'Generated Schedule',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var shift in schedule['shifts']) ...[
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: AppColors.primaryLight.withOpacity(0.2),
                      ),
                    ),
                    child: ListTile(
                      title: Text(
                        '${shift['start_time']} - ${shift['end_time']}',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        'Role: ${shift['role']}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: Text(
                        'Staff ID: ${shift['assigned_staff'].join(', ')}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement save functionality
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Shifts saved successfully'),
                    backgroundColor: AppColors.secondary,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Save Shifts'),
            ),
          ],
          actionsPadding: const EdgeInsets.all(16),
        );
      },
    );
  }

  Future<void> _loadDepartments() async {
    try {
      final departments = await _departmentApi.getAllDepartments();
      setState(() {
        _departments = departments;
        _isLoading = false;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load departments: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _addBusyTimeSlot() async {
    TimeOfDay? slotStartTime;
    TimeOfDay? slotEndTime;
    int employees = 2;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                'Add Busy Time Slot',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(
                      'Start Time',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    trailing: Text(
                      slotStartTime?.format(context) ?? 'Select Time',
                      style: TextStyle(color: AppColors.primary),
                    ),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
                      );
                      if (time != null) {
                        setState(() => slotStartTime = time);
                      }
                    },
                  ),
                  ListTile(
                    title: Text(
                      'End Time',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    trailing: Text(
                      slotEndTime?.format(context) ?? 'Select Time',
                      style: TextStyle(color: AppColors.primary),
                    ),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _endTime,
                      );
                      if (time != null) {
                        setState(() => slotEndTime = time);
                      }
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Required Employees:',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.remove,
                              color: AppColors.primary,
                            ),
                            onPressed: () {
                              if (employees > 1) {
                                setState(() => employees--);
                              }
                            },
                          ),
                          Text(
                            '$employees',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.add,
                              color: AppColors.primary,
                            ),
                            onPressed: () {
                              setState(() => employees++);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (slotStartTime != null && slotEndTime != null) {
                      setState(() {
                        _busyTimeSlots.add(BusyTimeSlot(
                          startTime: slotStartTime!,
                          endTime: slotEndTime!,
                          requiredEmployees: employees,
                        ));
                      });
                      Navigator.of(context).pop();
                    } else {
                      _showErrorSnackBar('Please select both start and end times');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Add'),
                ),
              ],
              actionsPadding: const EdgeInsets.all(16),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Shifts'),
        elevation: 0,
        actions: [
          Tooltip(
            message: 'This information will be processed by OpenAI to generate optimal shifts. No sensitive employee information will be shared.',
            child: IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () {},
            ),
          ),
        ],
      ),
      drawer: const ManagerDrawer(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.secondary.withOpacity(0.1),
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: AppColors.primaryLight.withOpacity(0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TableCalendar(
                        firstDay: DateTime.now(),
                        lastDay: DateTime.now().add(const Duration(days: 365)),
                        focusedDay: _focusedDay,
                        calendarFormat: _calendarFormat,
                        selectedDayPredicate: (day) {
                          return _selectedStartDate != null && 
                                 _selectedEndDate != null &&
                                 day.isAfter(_selectedStartDate!.subtract(const Duration(days: 1))) && 
                                 day.isBefore(_selectedEndDate!.add(const Duration(days: 1)));
                        },
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            if (_selectedStartDate == null || _selectedEndDate != null) {
                              _selectedStartDate = selectedDay;
                              _selectedEndDate = null;
                            } else {
                              if (selectedDay.isBefore(_selectedStartDate!)) {
                                _selectedEndDate = _selectedStartDate;
                                _selectedStartDate = selectedDay;
                              } else {
                                _selectedEndDate = selectedDay;
                              }
                            }
                            _focusedDay = focusedDay;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: AppColors.primaryLight.withOpacity(0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shift Hours',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ListTile(
                                  title: Text(
                                    'Start Time',
                                    style: TextStyle(color: AppColors.textPrimary),
                                  ),
                                  trailing: Text(
                                    _startTime.format(context),
                                    style: TextStyle(color: AppColors.primary),
                                  ),
                                  onTap: () async {
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: _startTime,
                                    );
                                    if (time != null) {
                                      setState(() => _startTime = time);
                                    }
                                  },
                                ),
                              ),
                              Expanded(
                                child: ListTile(
                                  title: Text(
                                    'End Time',
                                    style: TextStyle(color: AppColors.textPrimary),
                                  ),
                                  trailing: Text(
                                    _endTime.format(context),
                                    style: TextStyle(color: AppColors.primary),
                                  ),
                                  onTap: () async {
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: _endTime,
                                    );
                                    if (time != null) {
                                      setState(() => _endTime = time);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: AppColors.primaryLight.withOpacity(0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Busy Time Slots',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.add,
                                  color: AppColors.primary,
                                ),
                                onPressed: _addBusyTimeSlot,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _busyTimeSlots.length,
                            itemBuilder: (context, index) {
                              final slot = _busyTimeSlots[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.primaryLight.withOpacity(0.2),
                                  ),
                                ),
                                child: ListTile(
                                  title: Text(
                                    '${slot.startTime.format(context)} - ${slot.endTime.format(context)}',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${slot.requiredEmployees} employees needed',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      color: AppColors.error,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _busyTimeSlots.removeAt(index);
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: AppColors.primaryLight.withOpacity(0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.primaryLight.withOpacity(0.2),
                              ),
                            ),
                            child: DropdownButtonFormField<Department>(
                              decoration: InputDecoration(
                                labelText: 'Department',
                                labelStyle: TextStyle(color: AppColors.textSecondary),
                                prefixIcon: Icon(
                                  Icons.business,
                                  color: AppColors.primary,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              value: _selectedDepartment,
                              items: _departments.map((Department department) {
                                return DropdownMenuItem<Department>(
                                  value: department,
                                  child: Text(
                                    department.name,
                                    style: TextStyle(color: AppColors.textPrimary),
                                  ),
                                );
                              }).toList(),
                              onChanged: (Department? newValue) {
                                setState(() {
                                  _selectedDepartment = newValue;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.primaryLight.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                SwitchListTile(
                                  title: Text(
                                    'Auto-assign Shifts',
                                    style: TextStyle(color: AppColors.textPrimary),
                                  ),
                                  value: _autoAssign,
                                  activeColor: AppColors.primary,
                                  onChanged: (bool value) {
                                    setState(() {
                                      _autoAssign = value;
                                    });
                                  },
                                ),
                                const Divider(height: 1),
                                SwitchListTile(
                                  title: Text(
                                    'Allow Overtime',
                                    style: TextStyle(color: AppColors.textPrimary),
                                  ),
                                  value: _allowOvertime,
                                  activeColor: AppColors.primary,
                                  onChanged: (bool value) {
                                    setState(() {
                                      _allowOvertime = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          if (_allowOvertime) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.primaryLight.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Maximum Hours',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Slider(
                                          value: _maxHours,
                                          min: 8,
                                          max: 12,
                                          divisions: 8,
                                          activeColor: AppColors.primary,
                                          inactiveColor: AppColors.primaryLight.withOpacity(0.3),
                                          label: _maxHours.toString(),
                                          onChanged: (double value) {
                                            setState(() {
                                              _maxHours = value;
                                            });
                                          },
                                        ),
                                      ),
                                      Text(
                                        '${_maxHours.toStringAsFixed(1)} hours',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isGenerating ? null : _generateShifts,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isGenerating
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.textLight),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Generating...',
                                  style: TextStyle(
                                    color: AppColors.textLight,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Generate Shifts',
                              style: TextStyle(
                                color: AppColors.textLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
