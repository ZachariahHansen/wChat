import 'package:flutter/material.dart';
import 'package:wchat/data/app_theme.dart';

class ManagerDrawer extends StatelessWidget {
  const ManagerDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: <Widget>[
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  _buildDrawerItem(
                    context,
                    icon: Icons.dashboard_outlined,
                    title: 'Dashboard',
                    onTap: () => Navigator.pushReplacementNamed(context, '/manager'),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.business_outlined,
                    title: 'Departments',
                    onTap: () => Navigator.pushReplacementNamed(context, '/manager/departments'),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.work_outline,
                    title: 'Roles',
                    onTap: () => Navigator.pushReplacementNamed(context, '/manager/roles'),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.schedule_outlined,
                    title: 'Shifts',
                    onTap: () => Navigator.pushReplacementNamed(context, '/manager/shifts'),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.verified_user_outlined,
                    title: 'Users',
                    onTap: () => Navigator.pushReplacementNamed(context, '/manager/users'),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.calendar_today_outlined,
                    title: 'Time Off Requests',
                    onTap: () => Navigator.pushReplacementNamed(context, '/manager/time_off'),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.auto_awesome_outlined,
                    title: 'Generate Shifts (AI)',
                    onTap: () => Navigator.pushReplacementNamed(context, '/manager/generate_shifts'),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.arrow_back_outlined,
                    title: 'Back to Employee View',
                    onTap: () => Navigator.pushReplacementNamed(context, '/home'),
                    highlight: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.secondary,
            AppColors.secondaryLight,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'wChat',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.textLight,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manager Dashboard',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textLight.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: highlight ? AppColors.secondary : AppColors.textSecondary,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: highlight ? AppColors.secondary : AppColors.textPrimary,
          fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      onTap: onTap,
      dense: true,
      visualDensity: const VisualDensity(horizontal: -4, vertical: -2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
    );
  }
}