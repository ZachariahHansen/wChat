import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wchat/data/models/shift.dart';
import 'package:wchat/services/api/shift_api.dart';

class ShiftPickupScreen extends StatefulWidget {
  const ShiftPickupScreen({super.key});

  @override
  State<ShiftPickupScreen> createState() => _ShiftPickupScreenState();
}

class _ShiftPickupScreenState extends State<ShiftPickupScreen> {
  final ShiftApi _shiftApi = ShiftApi();
  List<Shift> _availableShifts = [];
  bool _isLoading = true;
  Shift? _selectedShift;
  bool _isPickingUpShift = false;

  @override
  void initState() {
    super.initState();
    _fetchAvailableShifts();
  }

  Future<void> _fetchAvailableShifts() async {
    try {
      final response = await _shiftApi.getAvailableShifts();
      setState(() {
        _availableShifts = response['shifts']
            .map<Shift>((shift) => Shift.fromJson(shift))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load available shifts');
    }
  }

  Future<void> _pickupShift() async {
    if (_selectedShift == null) return;

    setState(() {
      _isPickingUpShift = true;
    });

    try {
      await _shiftApi.pickupShift(_selectedShift!.id);
      _showSuccessSnackBar('Shift picked up successfully');
      // Refresh the list of available shifts
      _fetchAvailableShifts();
    } catch (e) {
      _showErrorSnackBar(e.toString());
    } finally {
      setState(() {
        _isPickingUpShift = false;
        _selectedShift = null;
      });
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Shifts'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _availableShifts.isEmpty
                      ? const Center(
                          child: Text('No available shifts'),
                        )
                      : ListView.builder(
                          itemCount: _availableShifts.length,
                          padding: const EdgeInsets.all(8),
                          itemBuilder: (context, index) {
                            final shift = _availableShifts[index];
                            return ShiftCard(
                              shift: shift,
                              isSelected: _selectedShift?.id == shift.id,
                              onTap: () {
                                setState(() {
                                  _selectedShift =
                                      _selectedShift?.id == shift.id ? null : shift;
                                });
                              },
                            );
                          },
                        ),
                ),
                if (_availableShifts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedShift == null || _isPickingUpShift
                            ? null
                            : _pickupShift,
                        child: _isPickingUpShift
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Pick Up Shift'),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class ShiftCard extends StatelessWidget {
  final Shift shift;
  final bool isSelected;
  final VoidCallback onTap;

  const ShiftCard({
    super.key,
    required this.shift,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MMM dd, yyyy');
    final timeFormatter = DateFormat('hh:mm a');

    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateFormatter.format(shift.date),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${timeFormatter.format(shift.startTime)} - ${timeFormatter.format(shift.endTime)}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  Text(
                    shift.departmentName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}