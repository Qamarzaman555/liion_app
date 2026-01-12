import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/widgets/animated_bottom_navbar.dart';
import 'package:liion_app/app/routes/app_routes.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/constants/sizes.dart';

class ScanningLeoScreen extends StatelessWidget {
  const ScanningLeoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(AppSizes.defaultSpace),
          child: Column(
            children: [
              Center(child: SvgPicture.asset(AppImages.appLogoColored)),
              const SizedBox(height: AppSizes.spaceBtwSections),

              // Tab content switcher for scanning
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Get.back(id: 1);
                        },
                        child: SvgPicture.asset(AppImages.leoLogoOutlinedLg),
                      ),
                      const SizedBox(height: AppSizes.spaceBtwSections),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.circle,
                            color: NewAppColors.blue,
                            size: 12,
                          ),
                          const SizedBox(width: AppSizes.sm),
                          const Text(
                            "Scanning for Leo's nearby",
                            style: TextStyle(
                              fontSize: AppSizes.fontSizeMd,
                              fontWeight: FontWeight.w400,
                              fontFamily: "SF Pro Text",
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: AppSizes.xs),
                          SvgPicture.asset(AppImages.loadingRight),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Get.toNamed(
                            '${AppRoutes.newNavBarView}${AppRoutes.leoHome}${AppRoutes.deviceList}',
                            id: 1,
                          );
                        },
                        child: Text('Go to Device List Screen'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar:
            // Bottom navigation tabs
            const AnimatedBottomNavBar(),
      ),
    );
  }
}
