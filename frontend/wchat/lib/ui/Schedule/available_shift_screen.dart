import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wchat/data/models/shift.dart';
import 'package:wchat/services/api/shift_api.dart';
import 'package:wchat/data/app_theme.dart';

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
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Shifts'),
        elevation: 0,
      ),
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
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: _availableShifts.isEmpty
                        ? _buildEmptyState()
                        : _buildShiftsList(),
                  ),
                  if (_availableShifts.isNotEmpty) _buildPickupButton(),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No shifts available',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new opportunities',
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftsList() {
    return ListView.builder(
      itemCount: _availableShifts.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final shift = _availableShifts[index];
        return ShiftCard(
          shift: shift,
          isSelected: _selectedShift?.id == shift.id,
          onTap: () {
            setState(() {
              _selectedShift = _selectedShift?.id == shift.id ? null : shift;
            });
          },
        );
      },
    );
  }

  Widget _buildPickupButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: AppColors.textSecondary.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _selectedShift == null || _isPickingUpShift
              ? null
              : _pickupShift,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: AppColors.secondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isPickingUpShift
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.textLight),
                  ),
                )
              : const Text(
                  'Pick Up Shift',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? AppColors.primary
              : AppColors.primaryLight.withOpacity(0.2),
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected
          ? AppColors.primary.withOpacity(0.1)
          : AppColors.background,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateFormatter.format(shift.date),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      shift.departmentName,
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
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
                    '${timeFormatter.format(shift.startTime)} - ${timeFormatter.format(shift.endTime)}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              if (isSelected) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tap "Pick Up Shift" below to claim this shift',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}