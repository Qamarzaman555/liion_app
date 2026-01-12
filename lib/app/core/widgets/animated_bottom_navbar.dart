import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/modules/startup_screen/controllers/new_nav_bar_controller.dart';

class AnimatedBottomNavBar extends GetView<NewNavBarController> {
  const AnimatedBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Padding(
        padding: const EdgeInsets.only(left: 32, right: 32, bottom: 12),
        child: Card(
          // elevation: 3,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => controller.switchToTab('Leo'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: controller.selectedTab.value == "Leo"
                          ? NewAppColors.navBarSelected
                          : NewAppColors.transparent,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(SvgAssets.leoTabIcon, height: 36),
                        const SizedBox(width: 12),
                        const Text(
                          'Leo',
                          style: TextStyle(
                            color: Color(0xFF545454),
                            fontWeight: FontWeight.w500,
                            fontFamily: 'SF Pro Text',
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => controller.switchToTab('Phone'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: controller.selectedTab.value == "Phone"
                          ? NewAppColors.navBarSelected
                          : NewAppColors.transparent,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(SvgAssets.phoneTabIcon, height: 36),
                        const SizedBox(width: 12),
                        const Text(
                          'Phone',
                          style: TextStyle(
                            color: Color(0xFF545454),
                            fontWeight: FontWeight.w500,
                            fontFamily: 'SF Pro Text',
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
