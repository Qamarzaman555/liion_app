import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';

class PermissionDeniedDialog extends StatelessWidget {
  const PermissionDeniedDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'Permissions Required',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF282828),
        ),
      ),
      content: const Text(
        'Bluetooth permissions are required to connect to Leo. Please grant permissions in app settings.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Color(0xFF282828),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.of(context).pop();
            await openAppSettings();
          },
          child: const Text(
            'Open Settings',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryColor,
            ),
          ),
        ),
      ],
    );
  }
}
