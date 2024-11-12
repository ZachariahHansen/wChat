import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:wchat/data/models/department.dart';
import 'package:wchat/services/api/department_api.dart';
import 'package:wchat/ui/Home/manager_app_drawer.dart';
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

  @override
  void initState() {
    super.initState();
    _loadDepartments();
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
        backgroundColor: Colors.red,
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
              title: const Text('Add Busy Time Slot'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Start Time'),
                    trailing: Text(slotStartTime?.format(context) ?? 'Select Time'),
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
                    title: const Text('End Time'),
                    trailing: Text(slotEndTime?.format(context) ?? 'Select Time'),
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
                      const Text('Required Employees:'),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              if (employees > 1) {
                                setState(() => employees--);
                              }
                            },
                          ),
                          Text('$employees'),
                          IconButton(
                            icon: const Icon(Icons.add),
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
                  child: const Text('Cancel'),
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
                  child: const Text('Add'),
                ),
              ],
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
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
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Shift Hours',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ListTile(
                                  title: const Text('Start Time'),
                                  trailing: Text(_startTime.format(context)),
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
                                  title: const Text('End Time'),
                                  trailing: Text(_endTime.format(context)),
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
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Busy Time Slots',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add),
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
                              return ListTile(
                                title: Text(
                                  '${slot.startTime.format(context)} - ${slot.endTime.format(context)}',
                                ),
                                subtitle: Text('${slot.requiredEmployees} employees needed'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    setState(() {
                                      _busyTimeSlots.removeAt(index);
                                    });
                                  },
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
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<Department>(
                            decoration: const InputDecoration(
                              labelText: 'Department',
                              prefixIcon: Icon(Icons.business),
                            ),
                            value: _selectedDepartment,
                            items: _departments.map((Department department) {
                              return DropdownMenuItem<Department>(
                                value: department,
                                child: Text(department.name),
                              );
                            }).toList(),
                            onChanged: (Department? newValue) {
                              setState(() {
                                _selectedDepartment = newValue;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Auto-assign Shifts'),
                            value: _autoAssign,
                            onChanged: (bool value) {
                              setState(() {
                                _autoAssign = value;
                              });
                            },
                          ),
                          SwitchListTile(
                            title: const Text('Allow Overtime'),
                            value: _allowOvertime,
                            onChanged: (bool value) {
                              setState(() {
                                _allowOvertime = value;
                              });
                            },
                          ),
                          if (_allowOvertime) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('Maximum Hours: '),
                                Expanded(
                                  child: Slider(
                                    value: _maxHours,
                                    min: 8,
                                    max: 12,
                                    divisions: 8,
                                    label: _maxHours.toString(),
                                    onChanged: (double value) {
                                      setState(() {
                                        _maxHours = value;
                                      });
                                    },
                                  ),
                                ),
                                Text('${_maxHours.toStringAsFixed(1)} hours'),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_selectedStartDate == null || _selectedEndDate == null) {
                          _showErrorSnackBar('Please select date range');
                          return;
                        }
                        if (_selectedDepartment == null) {
                          _showErrorSnackBar('Please select department');
                          return;
                        }
                        // TODO: Implement shift generation logic
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Text('Generate Shifts'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
