import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../controllers/splash_controller.dart';

class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 200,
                    width: 130,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(height: 200, color: Colors.white),
                        AnimatedBuilder(
                          animation: controller.animationController,
                          builder: (BuildContext context, Widget? child) {
                            return ClipRect(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                heightFactor: controller.animation.value,
                                child: ColorFiltered(
                                  colorFilter: ColorFilter.mode(
                                    controller.animation.value == 1.0
                                        ? AppColors.primaryColor
                                        : AppColors.secondaryColor,
                                    BlendMode.srcIn,
                                  ),
                                  child: Image.asset(
                                    PngAssets.liionSplashScreen,
                                    height: 200,
                                    width: 130,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
