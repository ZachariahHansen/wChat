import 'package:flutter/material.dart';
import 'package:wchat/data/models/shift.dart';
import 'package:wchat/data/models/user.dart';
import 'package:wchat/data/models/department.dart';
import 'package:wchat/ui/Home/manager_app_drawer.dart';
import 'package:wchat/services/api/shift_api.dart';
import 'package:wchat/services/api/user_api.dart';
import 'package:wchat/services/api/department_api.dart';
import 'package:intl/intl.dart';
import 'package:wchat/services/storage/jwt_decoder.dart';

class ShiftsScreen extends StatefulWidget {
  const ShiftsScreen({super.key});

  @override
  State<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends State<ShiftsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ShiftApi _shiftApi = ShiftApi();
  final UserApi _userApi = UserApi();
  final DepartmentApi _departmentApi = DepartmentApi();

  List<Shift> _shifts = [];
  List<Shift> _filteredShifts = [];
  List<User> _users = [];
  List<Department> _departments = [];
  bool _isLoading = true;

  final List<String> _statusOptions = [
    'scheduled',
    'completed',
    'cancelled',
    'available_for_exchange'
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterShifts);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchShifts(),
      _fetchUsers(),
      _fetchDepartments(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchDepartments() async {
    try {
      final departments = await _departmentApi.getAllDepartments();
      setState(() {
        _departments = departments;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load departments: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterShifts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredShifts = _shifts.where((shift) {
        final departmentName = shift.departmentName.toLowerCase();
        final status = shift.status.toLowerCase();
        final date = DateFormat('yyyy-MM-dd').format(shift.startTime);
        return departmentName.contains(query) ||
            status.contains(query) ||
            date.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchShifts() async {
    try {
      final response = await _shiftApi.getAllShifts();
      setState(() {
        _shifts = response.shifts;
        _filteredShifts = response.shifts;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load shifts: $e');
    }
  }

  Future<void> _fetchUsers() async {
    try {
      final users = await _userApi.getAllUsers();
      setState(() {
        _users = users;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load users: $e');
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

  Future<void> _showAddShiftDialog() async {
    final dateController = TextEditingController();
    final startTimeController = TextEditingController();
    final endTimeController = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    Department? selectedDepartment;
    String selectedStatus = 'scheduled'; // Default status

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add New Shift'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: dateController,
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            selectedDate = date;
                            dateController.text =
                                DateFormat('yyyy-MM-dd').format(date);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: startTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Start Time',
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            startTime = time;
                            startTimeController.text = time.format(context);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: endTimeController,
                      decoration: const InputDecoration(
                        labelText: 'End Time',
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            endTime = time;
                            endTimeController.text = time.format(context);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Department>(
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        prefixIcon: Icon(Icons.business),
                      ),
                      value: selectedDepartment,
                      items: _departments.map((Department department) {
                        return DropdownMenuItem<Department>(
                          value: department,
                          child: Text(department.name),
                        );
                      }).toList(),
                      onChanged: (Department? newValue) {
                        setState(() {
                          selectedDepartment = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(Icons.assignment_turned_in),
                      ),
                      value: selectedStatus,
                      items: _statusOptions.map((String status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child:
                              Text(status.replaceAll('_', ' ').toTitleCase()),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedStatus = newValue ?? 'scheduled';
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedDate != null &&
                        startTime != null &&
                        endTime != null &&
                        selectedDepartment != null) {
                      try {
                        final startDateTime = DateTime(
                          selectedDate!.year,
                          selectedDate!.month,
                          selectedDate!.day,
                          startTime!.hour,
                          startTime!.minute,
                        );
                        final endDateTime = DateTime(
                          selectedDate!.year,
                          selectedDate!.month,
                          selectedDate!.day,
                          endTime!.hour,
                          endTime!.minute,
                        );

                        await _shiftApi.createShift({
                          'start_time': startDateTime.toIso8601String(),
                          'end_time': endDateTime.toIso8601String(),
                          'status': selectedStatus,
                          'department_id': selectedDepartment!.id,
                          'scheduled_by_id': await JwtDecoder.getUserId(),
                        });
                        Navigator.of(context).pop();
                        await _fetchShifts();
                      } catch (e) {
                        _showErrorSnackBar('Failed to create shift: $e');
                      }
                    } else {
                      _showErrorSnackBar('Please fill in all fields');
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

    void _showAssignShiftDialog(Shift shift) {
    // Get the day of week (0 = Sunday, 6 = Saturday)
    final dayOfWeek = shift.startTime.weekday % 7;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
              'Assign Shift - ${DateFormat('MMM dd, yyyy').format(shift.startTime)}'),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.6, // Make dialog bigger
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final isAssigned = shift.userId == user.id;
                final availability = user.getAvailabilityForDay(dayOfWeek);

                // Format availability time
                String availabilityText = 'Not available';
                Color availabilityColor = Colors.red;
                bool isAvailableForShift = false;

                if (availability != null && availability.isAvailable) {
                  if (availability.startTime != null && availability.endTime != null) {
                    // Parse shift times
                    final shiftStart = TimeOfDay(
                      hour: shift.startTime.hour,
                      minute: shift.startTime.minute,
                    );
                    final shiftEnd = TimeOfDay(
                      hour: shift.endTime.hour,
                      minute: shift.endTime.minute,
                    );

                    // Parse availability times
                    final availStart = _parseTimeString(availability.startTime!);
                    final availEnd = _parseTimeString(availability.endTime!);

                    // Check if shift falls within availability
                    isAvailableForShift = _isTimeInRange(shiftStart, availStart, availEnd) &&
                        _isTimeInRange(shiftEnd, availStart, availEnd);

                    availabilityText = 'Available ${availability.startTime} - ${availability.endTime}';
                    availabilityColor = isAvailableForShift ? Colors.green : Colors.orange;
                  }
                }

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RadioListTile<int>(
                          title: Text(
                            '${user.firstName} ${user.lastName}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isAvailableForShift ? null : Colors.grey,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.email),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    isAvailableForShift
                                        ? Icons.check_circle
                                        : Icons.warning,
                                    size: 16,
                                    color: availabilityColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    availabilityText,
                                    style: TextStyle(
                                      color: availabilityColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              if (!isAvailableForShift)
                                const Text(
                                  'Warning: Shift time conflicts with availability',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          value: user.id,
                          groupValue: shift.userId,
                          onChanged: (int? value) async {
                            if (value != null) {
                              if (!isAvailableForShift) {
                                // Show confirmation dialog for assigning outside availability
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Availability Conflict'),
                                    content: const Text(
                                      'This user is not available during the shift hours. '
                                      'Are you sure you want to assign them to this shift?'
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Assign Anyway'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm != true) return;
                              }
                              
                              try {
                                await _shiftApi.assignShift(shift.id, value);
                                await _fetchShifts();
                                Navigator.of(context).pop();
                              } catch (e) {
                                _showErrorSnackBar('Failed to assign shift: $e');
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Helper method to parse time string (HH:mm:ss) to TimeOfDay
  TimeOfDay _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  // Helper method to check if a time falls within a range
  bool _isTimeInRange(TimeOfDay time, TimeOfDay start, TimeOfDay end) {
    final timeMinutes = time.hour * 60 + time.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    
    return timeMinutes >= startMinutes && timeMinutes <= endMinutes;
  }

  Future<void> _updateShiftStatus(Shift shift, String newStatus) async {
    try {
      await _shiftApi.updateShift(shift.id, {'status': newStatus});
      await _fetchShifts();
    } catch (e) {
      _showErrorSnackBar('Failed to update shift status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Management'),
      ),
      drawer: const ManagerDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddShiftDialog,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search Shifts',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterShifts();
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredShifts.length,
                      itemBuilder: (context, index) {
                        final shift = _filteredShifts[index];
                        final assignedUser = _users.firstWhere(
                          (user) => user.id == shift.userId,
                          orElse: () => User(
                            id: -1,
                            firstName: 'Unassigned',
                            lastName: '',
                            email: '',
                            phoneNumber: '',
                            hourlyRate: 0,
                            role: '',
                            isManager: false,
                            departments: [],
                            fullTime: true, // Default value for unassigned user
                            availability: [],
                          ),
                        );

                        return Card(
                          child: ListTile(
                            title: Text(
                              '${DateFormat('MMM dd, yyyy').format(shift.startTime)} - ${shift.departmentName}',
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${DateFormat('HH:mm').format(shift.startTime)} - ${DateFormat('HH:mm').format(shift.endTime)}',
                                ),
                                Row(
                                  children: [
                                    const Text('Status: '),
                                    DropdownButton<String>(
                                      value: shift.status,
                                      underline: Container(),
                                      items:
                                          _statusOptions.map((String status) {
                                        return DropdownMenuItem<String>(
                                          value: status,
                                          child: Text(
                                            status
                                                .replaceAll('_', ' ')
                                                .toTitleCase(),
                                            style: TextStyle(
                                              color: _getStatusColor(status),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (String? newValue) {
                                        if (newValue != null) {
                                          _updateShiftStatus(shift, newValue);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Assigned to: ${assignedUser.firstName} ${assignedUser.lastName}',
                                      ),
                                    ),
                                    if (assignedUser.id != -1)
                                      TextButton.icon(
                                        onPressed: () async {
                                          try {
                                            await _shiftApi
                                                .unassignShift(shift.id);
                                            await _fetchShifts();
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Successfully unassigned shift'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          } catch (e) {
                                            _showErrorSnackBar(
                                                'Failed to unassign shift: $e');
                                          }
                                        },
                                        icon: const Icon(Icons.person_remove,
                                            size: 18),
                                        label: const Text('Unassign'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showAssignShiftDialog(shift),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'scheduled':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'available_for_exchange':
        return Colors.orange;
      default:
        return Colors.black;
    }
  }
}

extension StringExtension on String {
  String toTitleCase() {
    return split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
}
