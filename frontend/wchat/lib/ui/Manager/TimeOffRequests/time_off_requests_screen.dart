import 'package:flutter/material.dart';
import 'package:wchat/data/app_theme.dart';
import 'package:wchat/services/api/time_off_api.dart';
import 'package:wchat/ui/Home/app_drawer.dart';
import 'package:intl/intl.dart';
import 'package:wchat/ui/Home/manager_app_drawer.dart';

class TimeOffRequestsScreen extends StatefulWidget {
  const TimeOffRequestsScreen({super.key});

  @override
  State<TimeOffRequestsScreen> createState() => _TimeOffRequestsScreenState();
}

class _TimeOffRequestsScreenState extends State<TimeOffRequestsScreen> with SingleTickerProviderStateMixin {
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
          title: Text('Respond to ${request['requester_name']}\'s Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Time Off Request Details:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Type: ${request['request_type']}'),
              Text('Dates: ${_dateFormat.format(DateTime.parse(request['start_date']))} - '
                   '${_dateFormat.format(DateTime.parse(request['end_date']))}'),
              Text('Reason: ${request['reason']}'),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Response Notes',
                  hintText: 'Add any notes about your decision...',
                ),
                maxLines: 3,
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
                _updateRequestStatus(request['id'], 'denied', notesController.text);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
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
              ),
              child: const Text('Approve'),
            ),
          ],
        );
      },
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  request['requester_name'] ?? 'Unknown User',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildStatusChip(request['status']),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${request['request_type'].toString().toUpperCase()} - $duration ${duration == 1 ? 'day' : 'days'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_dateFormat.format(startDate)} - ${_dateFormat.format(endDate)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Reason: ${request['reason']}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (request['status'] == 'pending')
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _showResponseDialog(request),
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
    Color textColor = AppColors.textLight;
    
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Off Requests'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Denied'),
          ],
        ),
      ),
      drawer: const ManagerDrawer (),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildRequestList('pending'),
              _buildRequestList('approved'),
              _buildRequestList('denied'),
            ],
          ),
    );
  }

  Widget _buildRequestList(String status) {
    final filteredRequests = _filterRequests(status);
    
    return filteredRequests.isEmpty
      ? Center(
          child: Text(
            'No ${status.toLowerCase()} requests',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        )
      : RefreshIndicator(
          onRefresh: _loadRequests,
          child: ListView.builder(
            itemCount: filteredRequests.length,
            itemBuilder: (context, index) => _buildRequestCard(filteredRequests[index]),
          ),
        );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}