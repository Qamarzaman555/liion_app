import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import '../controllers/advanced_settings_controller.dart';

class AdvancedSettingsView extends GetView<AdvancedSettingsController> {
  const AdvancedSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: AppBar(
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.blackColor),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Advanced Settings',
          style: TextStyle(
            color: AppColors.blackColor,
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Advanced Configuration',
              style: TextStyle(
                color: Color(0xFF282828),
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure advanced options and system settings.',
              style: TextStyle(
                color: Color(0xFF888888),
                fontFamily: 'Inter',
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('System'),
            const SizedBox(height: 12),
            _buildSettingTile(
              icon: Icons.battery_saver,
              title: 'Battery Optimization',
              subtitle: 'Manage battery optimization settings',
              onTap: () {
                Get.snackbar(
                  'Info',
                  'Battery optimization settings',
                  snackPosition: SnackPosition.BOTTOM,
                );
              },
            ),
            _buildSettingTile(
              icon: Icons.notifications_active,
              title: 'Notifications',
              subtitle: 'Configure notification preferences',
              onTap: () {
                Get.snackbar(
                  'Info',
                  'Notification settings',
                  snackPosition: SnackPosition.BOTTOM,
                );
              },
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('Data & Storage'),
            const SizedBox(height: 12),
            _buildSettingTile(
              icon: Icons.storage,
              title: 'Clear Cache',
              subtitle: 'Clear app cache and temporary files',
              onTap: () {
                _showClearCacheDialog(context);
              },
            ),
            _buildSettingTile(
              icon: Icons.delete_outline,
              title: 'Clear Data',
              subtitle: 'Clear all app data (requires restart)',
              onTap: () {
                _showClearDataDialog(context);
              },
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('Debug'),
            const SizedBox(height: 12),
            _buildSettingTile(
              icon: Icons.bug_report,
              title: 'Debug Mode',
              subtitle: 'Enable debug logging and diagnostics',
              trailing: Switch(
                value: false,
                onChanged: (value) {
                  Get.snackbar(
                    'Info',
                    'Debug mode: ${value ? "Enabled" : "Disabled"}',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                },
              ),
            ),
            _buildSettingTile(
              icon: Icons.analytics,
              title: 'Analytics',
              subtitle: 'View app analytics and statistics',
              onTap: () {
                Get.snackbar(
                  'Info',
                  'Analytics feature coming soon',
                  snackPosition: SnackPosition.BOTTOM,
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF888888),
        fontFamily: 'Inter',
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Card(
      elevation: 0,
      color: AppColors.cardBGColor,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primaryColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF282828),
            fontFamily: 'Inter',
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF888888),
            fontFamily: 'Inter',
          ),
        ),
        trailing: trailing ?? const Icon(
          Icons.chevron_right,
          color: Color(0xFF888888),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear all cached data. The app will continue to work normally.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              Get.snackbar(
                'Success',
                'Cache cleared successfully',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: AppColors.primaryColor,
                colorText: AppColors.whiteColor,
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will delete all app data including settings and cached files. '
          'The app will restart after clearing data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              Get.snackbar(
                'Warning',
                'Clear data feature coming soon',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.orange,
                colorText: AppColors.whiteColor,
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
