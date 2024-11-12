import 'package:flutter/material.dart';
import 'package:wchat/data/app_theme.dart';
import 'package:wchat/services/storage/jwt_decoder.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _isManager = false;

  @override
  void initState() {
    super.initState();
    _checkManagerStatus();
  }

  Future<void> _checkManagerStatus() async {
    try {
      final payload = await JwtDecoder.decode();
      setState(() {
        _isManager = payload['is_manager'] ?? false;
      });
    } catch (e) {
      setState(() {
        _isManager = false;
      });
    }
  }

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
                    icon: Icons.home_outlined,
                    title: 'Home',
                    onTap: () => Navigator.pushReplacementNamed(context, '/home'),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.calendar_today_outlined,
                    title: 'Schedule',
                    onTap: () => Navigator.pushReplacementNamed(context, '/schedule'),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.message_outlined,
                    title: 'Messages',
                    onTap: () => Navigator.pushReplacementNamed(context, '/messages'),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.book_outlined,
                    title: 'Directory',
                    onTap: () => Navigator.pushReplacementNamed(context, '/directory'),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.event_available_outlined,
                    title: 'Availability',
                    onTap: () => Navigator.pushReplacementNamed(context, '/availability'),
                  ),
                  if (_isManager) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(height: 1),
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Manager View',
                      onTap: () => Navigator.pushReplacementNamed(context, '/manager'),
                      highlight: true,
                    ),
                  ],
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
            AppColors.primary,
            AppColors.primaryLight,
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
            'Employee Dashboard',
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
          color: highlight ? AppColors.primary : AppColors.textSecondary,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: highlight ? AppColors.primary : AppColors.textPrimary,
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
