import 'package:flutter/material.dart';
import 'package:wchat/data/app_theme.dart';
import 'package:wchat/services/api/time_off_api.dart';
import 'package:wchat/services/storage/jwt_decoder.dart';
import 'package:table_calendar/table_calendar.dart';

class TimeOffRequestDialog extends StatefulWidget {
  const TimeOffRequestDialog({Key? key}) : super(key: key);

  @override
  State<TimeOffRequestDialog> createState() => _TimeOffRequestDialogState();
}

class _TimeOffRequestDialogState extends State<TimeOffRequestDialog> {
  final TimeOffRequestApi _timeOffApi = TimeOffRequestApi();
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _selectedDay;
  DateTime? _startDate;
  DateTime? _endDate;
  String _requestType = 'vacation';
  bool _isLoading = false;
  int? _userId;
  bool _isRangeMode = false;

  final List<DropdownMenuItem<String>> _requestTypes = [
    const DropdownMenuItem(value: 'vacation', child: Text('Vacation')),
    const DropdownMenuItem(value: 'sick_leave', child: Text('Sick Leave')),
    const DropdownMenuItem(value: 'personal', child: Text('Personal')),
    const DropdownMenuItem(value: 'other', child: Text('Other')),
  ];

  @override
  void initState() {
    super.initState();
    _initializeUserId();
  }

  Future<void> _initializeUserId() async {
    final userId = await JwtDecoder.getUserId();
    setState(() {
      _userId = userId;
    });
  }

  Future<void> _submitRequest() async {
    if (_formKey.currentState!.validate() && _userId != null) {
      // For single day selection, use _selectedDay for both start and end
      final effectiveStartDate = _isRangeMode ? _startDate! : _selectedDay!;
      final effectiveEndDate = _isRangeMode ? _endDate! : _selectedDay!;

      setState(() => _isLoading = true);

      try {
        final requestData = TimeOffRequestApi.createTimeOffRequestData(
          userId: _userId!,
          startDate: effectiveStartDate,
          endDate: effectiveEndDate,
          requestType: _requestType,
          reason: _reasonController.text,
          notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        );

        final requestId = await _timeOffApi.createTimeOffRequest(requestData);

        if (requestId != null) {
          if (mounted) {
            Navigator.of(context).pop(true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Time off request submitted successfully'),
                backgroundColor: AppColors.secondary,
              ),
            );
          }
        } else {
          throw Exception('Failed to create time off request');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to submit time off request'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Request Time Off',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Toggle switch between single day and range selection
                Row(
                  children: [
                    const Text('Multiple Days'),
                    Switch(
                      value: _isRangeMode,
                      onChanged: (value) {
                        setState(() {
                          _isRangeMode = value;
                          // Reset selections when switching modes
                          _selectedDay = null;
                          _startDate = null;
                          _endDate = null;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TableCalendar(
                  firstDay: DateTime.now(),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _selectedDay ?? DateTime.now(),
                  selectedDayPredicate: (day) {
                    if (!_isRangeMode) {
                      return _selectedDay != null && isSameDay(day, _selectedDay!);
                    }
                    return _startDate != null && _endDate != null
                        ? (day.isAtSameMomentAs(_startDate!) ||
                            day.isAtSameMomentAs(_endDate!) ||
                            (day.isAfter(_startDate!) && day.isBefore(_endDate!)))
                        : false;
                  },
                  rangeStartDay: _isRangeMode ? _startDate : null,
                  rangeEndDay: _isRangeMode ? _endDate : null,
                  calendarFormat: CalendarFormat.month,
                  rangeSelectionMode: _isRangeMode 
                      ? RangeSelectionMode.enforced 
                      : RangeSelectionMode.disabled,
                  onDaySelected: !_isRangeMode 
                      ? (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                          });
                        }
                      : null,
                  onRangeSelected: _isRangeMode
                      ? (start, end, focusedDay) {
                          setState(() {
                            _startDate = start;
                            _endDate = end;
                          });
                        }
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _requestType,
                  decoration: const InputDecoration(
                    labelText: 'Request Type',
                    border: OutlineInputBorder(),
                  ),
                  items: _requestTypes,
                  onChanged: (value) {
                    setState(() {
                      _requestType = value!;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a request type';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please provide a reason';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Additional Notes (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading || 
                        (_isRangeMode ? (_startDate == null || _endDate == null) : _selectedDay == null)
                        ? null
                        : _submitRequest,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Submit Request'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}