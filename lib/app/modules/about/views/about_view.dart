import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';
import '../../leo_empty/controllers/leo_home_controller.dart';
import '../controllers/about_controller.dart';

class AboutView extends GetView<AboutController> {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: AppBar(
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: AppColors.blackColor,
          ),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'About',
          style: TextStyle(
            color: Color(0xFF282828),
            fontFamily: 'Inter',
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Obx(
          () => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildInfoRow(
                  title: 'App Name',
                  value: controller.appName.value.isEmpty
                      ? 'Loading...'
                      : controller.appName.value,
                  icon: SvgAssets.appNameInfoIcon,
                ),
                _buildInfoRow(
                  title: 'App Package Name',
                  value: controller.packageName.value.isEmpty
                      ? 'Loading...'
                      : controller.packageName.value,
                  icon: SvgAssets.appPackageInfoIcon,
                ),
                _buildInfoRow(
                  title: 'App Version',
                  value: controller.version.value.isEmpty
                      ? 'Loading...'
                      : controller.version.value,
                  icon: SvgAssets.appVersionInfoIcon,
                ),
                _buildInfoRow(
                  title: 'App Build Number',
                  value: controller.buildNumber.value.isEmpty
                      ? 'Loading...'
                      : controller.buildNumber.value,
                  icon: SvgAssets.appBuildNoInfoIcon,
                ),
                if (Get.find<LeoHomeController>().connectionState.value ==
                        BleConnectionState.connected &&
                    controller.leoFirmwareVersion.value.isNotEmpty)
                  _buildInfoRow(
                    title: 'Leo Firmware Version',
                    value: controller.leoFirmwareVersion.value,
                    icon: SvgAssets.leoVersionInfoIcon,
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String title,
    required String value,
    required String icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.primaryColor,
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SvgPicture.asset(icon, width: 45, height: 45),
        ],
      ),
    );
  }
}
