import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/widgets/custom_switch.dart';
import '../controllers/ghost_mode_beta_controller.dart';

class GhostModeBetaView extends GetView<GhostModeBetaController> {
  const GhostModeBetaView({super.key});

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
          'Ghost Mode Beta',
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
            Center(
              child: SvgPicture.asset(
                SvgAssets.ghostModeIcon,
                width: 80,
                height: 80,
                colorFilter: const ColorFilter.mode(
                  AppColors.primaryColor,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Ghost Mode Beta',
              style: TextStyle(
                color: Color(0xFF282828),
                fontFamily: 'Inter',
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Enable fast, unrestricted charging with no battery-saving optimizations. This mode prioritizes charging speed over battery health.',
              style: TextStyle(
                color: Color(0xFF888888),
                fontFamily: 'Inter',
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 0,
              color: AppColors.cardBGColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enable Ghost Mode',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF282828),
                              fontFamily: 'Inter',
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Turn on fast charging mode',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF888888),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Obx(
                      () => CustomSwitch(
                        value: controller.advancedGhostModeEnabled.value,

                        onChanged: (value) {
                          controller.toggleGhostMode(value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.primaryColor,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Note: Ghost Mode is a beta feature. Use with caution as it may affect battery longevity.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF282828),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
