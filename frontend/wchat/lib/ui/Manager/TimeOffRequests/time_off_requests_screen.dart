import 'package:flutter/material.dart';
import 'package:wchat/data/app_theme.dart';
import 'package:wchat/services/api/time_off_api.dart';
import 'package:wchat/ui/Home/app_drawer.dart';
import 'package:intl/intl.dart';
import 'package:wchat/ui/Home/manager_app_drawer.dart';
import 'package:wchat/data/app_theme.dart';

class TimeOffRequestsScreen extends StatefulWidget {
  const TimeOffRequestsScreen({super.key});

  @override
  State<TimeOffRequestsScreen> createState() => _TimeOffRequestsScreenState();
}

class _TimeOffRequestsScreenState extends State<TimeOffRequestsScreen>
    with SingleTickerProviderStateMixin {
  final TimeOffRequestApi _timeOffApi = TimeOffRequestApi();
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];
  late TabController _tabController;
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final requests = await _timeOffApi.getTimeOffRequests();
      setState(() {
        _requests = requests ?? [];
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading time off requests: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateRequestStatus(int requestId, String status, String notes) async {
    try {
      setState(() => _isLoading = true);
      
      final success = await _timeOffApi.updateTimeOffRequest(
        requestId,
        TimeOffRequestApi.createStatusUpdateData(
          status: status,
          respondedById: 1, // TODO: Get actual manager ID
          notes: notes,
        ),
      );

      if (success) {
        await _loadRequests();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Request ${status.toLowerCase()} successfully'),
              backgroundColor: status == 'approved' ? AppColors.secondary : AppColors.error,
            ),
          );
        }
      } else {
        throw Exception('Failed to update request');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update request'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showResponseDialog(Map<String, dynamic> request) async {
    final TextEditingController notesController = TextEditingController();
    
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            'Respond to ${request['requester_name']}\'s Request',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Time Off Request Details:',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                'Type',
                request['request_type'],
                Icons.category,
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Dates',
                '${_dateFormat.format(DateTime.parse(request['start_date']))} - '
                '${_dateFormat.format(DateTime.parse(request['end_date']))}',
                Icons.date_range,
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Reason',
                request['reason'],
                Icons.notes,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: 'Response Notes',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  hintText: 'Add any notes about your decision...',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
                maxLines: 3,
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
                _updateRequestStatus(request['id'], 'denied', notesController.text);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Deny'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateRequestStatus(request['id'], 'approved', notesController.text);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Approve'),
            ),
          ],
          actionsPadding: const EdgeInsets.all(16),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _filterRequests(String status) {
    return _requests.where((request) => request['status'] == status).toList();
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final startDate = DateTime.parse(request['start_date']);
    final endDate = DateTime.parse(request['end_date']);
    final duration = endDate.difference(startDate).inDays + 1;
    
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
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        request['requester_name']?[0] ?? 'U',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      request['requester_name'] ?? 'Unknown User',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                _buildStatusChip(request['status']),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoChip(
              '${request['request_type'].toString().toUpperCase()} - $duration ${duration == 1 ? 'day' : 'days'}',
              AppColors.primary,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.date_range,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_dateFormat.format(startDate)} - ${_dateFormat.format(endDate)}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primaryLight.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.notes,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request['reason'],
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (request['status'] == 'pending')
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => _showResponseDialog(request),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Respond'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor = AppColors.background;
    
    switch (status.toLowerCase()) {
      case 'approved':
        backgroundColor = AppColors.secondary;
        break;
      case 'denied':
        backgroundColor = AppColors.error;
        break;
      case 'pending':
        backgroundColor = AppColors.primary;
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
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Off Requests'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Denied'),
          ],
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
        ),
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
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRequestList('pending'),
                _buildRequestList('approved'),
                _buildRequestList('denied'),
              ],
            ),
      ),
    );
  }

  Widget _buildRequestList(String status) {
    final filteredRequests = _filterRequests(status);
    
    return filteredRequests.isEmpty
      ? Center(
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
                'No ${status.toLowerCase()} requests',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        )
      : RefreshIndicator(
          onRefresh: _loadRequests,
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: filteredRequests.length,
            itemBuilder: (context, index) => _buildRequestCard(filteredRequests[index]),
          ),
        );
  }
}