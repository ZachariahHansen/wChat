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
import 'package:wchat/data/app_theme.dart';

class ShiftsScreen extends StatefulWidget {
  const ShiftsScreen({super.key});

  @override
  State<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends State<ShiftsScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ShiftApi _shiftApi = ShiftApi();
  final UserApi _userApi = UserApi();
  final DepartmentApi _departmentApi = DepartmentApi();
  late TabController _tabController;

  List<Shift> _shifts = [];
  List<Shift> _upcomingShifts = [];
  List<Shift> _previousShifts = [];
  List<Shift> _filteredUpcomingShifts = [];
  List<Shift> _filteredPreviousShifts = [];
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
    _tabController = TabController(length: 2, vsync: this);
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
    _tabController.dispose();
    super.dispose();
  }

  void _filterShifts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUpcomingShifts = _upcomingShifts.where((shift) {
        final departmentName = shift.departmentName.toLowerCase();
        final status = shift.status.toLowerCase();
        final date = DateFormat('yyyy-MM-dd').format(shift.startTime);
        return departmentName.contains(query) ||
            status.contains(query) ||
            date.contains(query);
      }).toList();

      _filteredPreviousShifts = _previousShifts.where((shift) {
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
      final now = DateTime.now();
      setState(() {
        _shifts = response.shifts;
        _upcomingShifts = response.shifts.where((shift) => shift.startTime.isAfter(now)).toList();
        _previousShifts = response.shifts.where((shift) => shift.startTime.isBefore(now)).toList();
        _filteredUpcomingShifts = _upcomingShifts;
        _filteredPreviousShifts = _previousShifts;
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
        backgroundColor: AppColors.error,
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
    String selectedStatus = 'scheduled';

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
                'Add New Shift',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: dateController,
                      decoration: InputDecoration(
                        labelText: 'Date',
                        prefixIcon: Icon(Icons.calendar_today, color: AppColors.primary),
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
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
                      decoration: InputDecoration(
                        labelText: 'Start Time',
                        prefixIcon: Icon(Icons.access_time, color: AppColors.primary),
                        labelStyle: TextStyle(color: AppColors.textSecondary),
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
                      decoration: InputDecoration(
                        labelText: 'End Time',
                        prefixIcon: Icon(Icons.access_time, color: AppColors.primary),
                        labelStyle: TextStyle(color: AppColors.textSecondary),
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
                      decoration: InputDecoration(
                        labelText: 'Department',
                        prefixIcon: Icon(Icons.business, color: AppColors.primary),
                        labelStyle: TextStyle(color: AppColors.textSecondary),
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
                      decoration: InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(Icons.assignment_turned_in, color: AppColors.primary),
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                      ),
                      value: selectedStatus,
                      items: _statusOptions.map((String status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(status.replaceAll('_', ' ').toTitleCase()),
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
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Create'),
                ),
              ],
              actionsPadding: const EdgeInsets.all(16),
            );
          },
        );
      },
    );
  }

  void _showAssignShiftDialog(Shift shift) {
    final dayOfWeek = shift.startTime.weekday % 7;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            'Assign Shift - ${DateFormat('MMM dd, yyyy').format(shift.startTime)}',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.6,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final isAssigned = shift.userId == user.id;
                final availability = user.getAvailabilityForDay(dayOfWeek);

                String availabilityText = 'Not available';
                Color availabilityColor = AppColors.error;
                bool isAvailableForShift = false;

                if (availability != null && availability.isAvailable) {
                  if (availability.startTime != null && availability.endTime != null) {
                    final shiftStart = TimeOfDay(
                      hour: shift.startTime.hour,
                      minute: shift.startTime.minute,
                    );
                    final shiftEnd = TimeOfDay(
                      hour: shift.endTime.hour,
                      minute: shift.endTime.minute,
                    );

                    final availStart = _parseTimeString(availability.startTime!);
                    final availEnd = _parseTimeString(availability.endTime!);

                    isAvailableForShift = _isTimeInRange(shiftStart, availStart, availEnd) &&
                        _isTimeInRange(shiftEnd, availStart, availEnd);

                    availabilityText = 'Available ${availability.startTime} - ${availability.endTime}';
                    availabilityColor = isAvailableForShift ? AppColors.secondary : AppColors.primary;
                  }
                }

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: AppColors.primaryLight.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
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
                              color: isAvailableForShift ? AppColors.textPrimary : AppColors.textSecondary,
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
                                Text(
                                  'Warning: Shift time conflicts with availability',
                                  style: TextStyle(
                                    color: AppColors.primary,
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
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    title: Text(
                                      'Availability Conflict',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    content: const Text(
                                      'This user is not available during the shift hours. '
                                      'Are you sure you want to assign them to this shift?'
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(color: AppColors.textSecondary),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.secondary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
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
              child: Text(
                'Close',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        );
      },
    );
  }

  TimeOfDay _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

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

  Widget _buildShiftList(List<Shift> shifts) {
    if (shifts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 48,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No shifts found',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: shifts.length,
      itemBuilder: (context, index) {
        final shift = shifts[index];
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
            fullTime: true,
            availability: [],
          ),
        );

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    Text(
                      '${DateFormat('MMM dd, yyyy').format(shift.startTime)} - ${shift.departmentName}',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _buildStatusChip(shift.status),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${DateFormat('HH:mm').format(shift.startTime)} - ${DateFormat('HH:mm').format(shift.endTime)}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Assigned to: ${assignedUser.firstName} ${assignedUser.lastName}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (assignedUser.id != -1)
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            await _shiftApi.unassignShift(shift.id);
                            await _fetchShifts();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Successfully unassigned shift'),
                                backgroundColor: AppColors.secondary,
                              ),
                            );
                          } catch (e) {
                            _showErrorSnackBar('Failed to unassign shift: $e');
                          }
                        },
                        icon: const Icon(Icons.person_remove, size: 18),
                        label: const Text('Unassign'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showAssignShiftDialog(shift),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit Assignment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor = AppColors.background;
    
    switch (status.toLowerCase()) {
      case 'scheduled':
        backgroundColor = AppColors.primary;
        break;
      case 'completed':
        backgroundColor = AppColors.secondary;
        break;
      case 'cancelled':
        backgroundColor = AppColors.error;
        break;
      case 'available_for_exchange':
        backgroundColor = AppColors.primaryLight;
        break;
      default:
        backgroundColor = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Management'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming Shifts'),
            Tab(text: 'Previous Shifts'),
          ],
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
        ),
      ),
      drawer: const ManagerDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddShiftDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
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
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search Shifts',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      prefixIcon: Icon(Icons.search, color: AppColors.primary),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.clear, color: AppColors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          _filterShifts();
                        },
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.primaryLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildShiftList(_filteredUpcomingShifts),
                        _buildShiftList(_filteredPreviousShifts),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

extension StringExtension on String {
  String toTitleCase() {
    return split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
}
