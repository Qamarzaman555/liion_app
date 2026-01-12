import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/constants/sizes.dart';
import 'package:liion_app/app/core/widgets/custom_list_tile.dart';
import 'package:liion_app/app/routes/app_routes.dart';

class LeoHomeScreen extends StatelessWidget {
  const LeoHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,

        body: Stack(
          children: [
            _buildBackgroundGradient(context),

            // Backdrop filter for blur effect
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.3),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.defaultSpace,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(AppSizes.defaultSpace),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: SvgPicture.asset(
                            AppImages.appLogoWhite,
                            height: MediaQuery.sizeOf(context).width * 0.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceBtwSections),

                  const Text(
                    "Add Devices",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceBtwTexts),
                  CustomListTile(
                    onTap: () {
                      Get.toNamed(
                        '${AppRoutes.newNavBarView}${AppRoutes.leoHome}${AppRoutes.scan}',
                        id: 1,
                      );
                    },
                    titleText: "Leo: The Battery Life Extender",
                    suffixIconPath: AppImages.addSymbol,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundGradient(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    return Stack(
      children: [
        // Main large green circle (top-left area)
        Positioned(
          top: -screenSize.height * 0.3,
          left: -screenSize.width * 1.2,
          child: Container(
            height: screenSize.height * 0.8,
            width: screenSize.height * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF00C896).withOpacity(0.8),
                  const Color(0xFF00C896).withOpacity(0.4),
                  const Color(0xFF00C896).withOpacity(0.1),
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
          ),
        ),

        // Secondary green circle (bottom-right area)
        Positioned(
          bottom: -screenSize.height * 0.3,
          right: -screenSize.width * 0.9,
          child: Container(
            height: screenSize.height * 0.8,
            width: screenSize.height * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF00A876).withOpacity(0.6),
                  const Color(0xFF00A876).withOpacity(0.3),
                  const Color(0xFF00A876).withOpacity(0.05),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),

        // // Additional accent circle (center-right)
        // Positioned(
        //   top: screenSize.height * 0.4,
        //   right: -screenSize.width * 0.2,
        //   child: Container(
        //     height: screenSize.height * 0.4,
        //     width: screenSize.height * 0.4,
        //     decoration: BoxDecoration(
        //       shape: BoxShape.circle,
        //       gradient: RadialGradient(
        //         colors: [
        //           const Color(0xFF00E8A6).withOpacity(0.4),
        //           const Color(0xFF00E8A6).withOpacity(0.2),
        //           Colors.transparent,
        //         ],
        //         stops: const [0.0, 0.5, 1.0],
        //       ),
        //     ),
        //   ),
        // ),
      ],
    );
  }
}
