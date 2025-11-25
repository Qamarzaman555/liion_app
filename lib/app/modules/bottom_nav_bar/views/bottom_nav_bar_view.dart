import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../controllers/bottom_nav_bar_controller.dart';

class BottomNavBarView extends GetView<BottomNavBarController> {
  const BottomNavBarView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      bottomNavigationBar: SafeArea(
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30.0),
            topRight: Radius.circular(30.0),
          ),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Obx(
              () => BottomNavigationBar(
                elevation: 20,
                currentIndex: controller.currentIndex.value,
                onTap: controller.changeIndex,
                type: BottomNavigationBarType.fixed,
                unselectedLabelStyle: const TextStyle(
                  color: AppColors.primaryColor,
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                selectedLabelStyle: const TextStyle(
                  color: AppColors.secondaryColor,
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                showSelectedLabels: true,
                showUnselectedLabels: true,
                selectedFontSize: 10,
                unselectedFontSize: 10,
                backgroundColor: AppColors.whiteColor,
                selectedItemColor: AppColors.secondaryColor,
                unselectedItemColor: AppColors.primaryColor,
                items: [
                  BottomNavigationBarItem(
                    label: "Leo",
                    icon: SvgPicture.asset(
                      SvgAssets.leoHomeIcon,
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        controller.currentIndex.value == 0
                            ? AppColors.secondaryColor
                            : AppColors.primaryColor,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  BottomNavigationBarItem(
                    label: "Phone",
                    icon: SvgPicture.asset(
                      SvgAssets.leoBatteryIcon,
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        controller.currentIndex.value == 1
                            ? AppColors.secondaryColor
                            : AppColors.primaryColor,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  BottomNavigationBarItem(
                    label: "Settings",
                    icon: SvgPicture.asset(
                      SvgAssets.leoSettingsIcon,
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        controller.currentIndex.value == 2
                            ? AppColors.secondaryColor
                            : AppColors.primaryColor,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Obx(() => controller.currentView),
    );
  }
}
