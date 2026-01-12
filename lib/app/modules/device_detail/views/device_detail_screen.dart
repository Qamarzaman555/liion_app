import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/constants/sizes.dart';
import 'package:liion_app/app/core/widgets/custom_appbar.dart';
import 'package:liion_app/app/modules/device_detail/views/widgets/charging_mode_expansion_tile.dart';
import 'package:liion_app/app/routes/app_routes.dart';

class DeviceDetailScreen extends StatelessWidget {
  const DeviceDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: NewAppColors.whiteBackground,
        appBar: CustomAppBar(
          title: 'Leo USB EVNC10427',
          height: AppSizes.appBarHeight * 1.5,
          backgroundColor: NewAppColors.whiteBackground,
          titleColor: Colors.black,
          centerTitle: true,
          showBackButton: true,
          onBackPressed: () {
            Get.back(id: 1);
          },
          elevation: 2.0,
          actions: [
            GestureDetector(
              onTap: () => Get.toNamed(
                '${AppRoutes.newNavBarView}${AppRoutes.leoHome}${AppRoutes.advanceSettings}',
                id: 1,
              ),
              child: SvgPicture.asset(AppImages.settings),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.defaultSpace),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Spacer(flex: 8),
                    Image.asset(
                      AppImages.leoImageLg,
                      height: MediaQuery.sizeOf(context).width * 0.6,
                    ),
                    const SizedBox(width: AppSizes.xs),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 30),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            color: NewAppColors.accent,
                            size: 8,
                          ),
                          SizedBox(width: AppSizes.xs / 1.2),
                          Text("Connected", style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const Spacer(flex: 3),
                  ],
                ),
                const SizedBox(height: AppSizes.spaceBtwSections),
                const Text(
                  'Charging Mode',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    fontFamily: "SF Pro Text",
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: AppSizes.spaceBtwTexts),
                const ChargingModeExpansionTile(),
                const SizedBox(height: AppSizes.spaceBtwInputFields),
                const Text(
                  'Leo Measurement',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    fontFamily: "SF Pro Text",
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: AppSizes.spaceBtwTexts),
                Row(
                  children: [
                    _buildMeasurementCard('Current', '422 mA'),
                    _buildMeasurementCard('Voltage', '3941 mV'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeasurementCard(String title, String value) {
    return Expanded(
      child: Card(
        color: NewAppColors.whiteBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadiusLg),
          side: const BorderSide(color: NewAppColors.containerBorder, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spaceBtwSectionsHalf,
            vertical: AppSizes.defaultSpace - 4,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  fontFamily: "SF Pro Text",
                  color: NewAppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: NewAppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
