import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/widgets/custom_list_tile.dart';
import 'package:liion_app/app/routes/app_routes.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/constants/sizes.dart';

class DeviceListScreen extends StatelessWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(AppSizes.defaultSpace),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(50),
                    onTap: () {
                      Get.back(id: 1);
                    },
                    child: Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  Center(
                    child: SvgPicture.asset(
                      AppImages.appLogoColored,
                      height: MediaQuery.sizeOf(context).width * 0.2,
                    ),
                  ),
                  const SizedBox.shrink(),
                ],
              ),
              const SizedBox(height: AppSizes.spaceBtwSections),
              const Text(
                "Available Devices",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  fontFamily: "SF Pro Text",
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: AppSizes.spaceBtwTexts),
              Expanded(
                child: ListView.separated(
                  itemCount: 2,
                  itemBuilder: (context, asyncSnapshot) {
                    return CustomListTile(
                      onTap: () {
                        Get.toNamed(
                          '${AppRoutes.newNavBarView}${AppRoutes.leoHome}${AppRoutes.deviceDetail}',
                          id: 1,
                        );
                      },
                      svgIcon: SvgPicture.asset(SvgAssets.leoTabIcon),
                      titleText: "Leo USB EVNC10427",
                      suffixIconPath: AppImages.addSymbol,
                      backgroundColor: NewAppColors.whiteBackground,
                      suffixIconTopPadding: 25,
                      spaceBtwSection: 16,
                    );
                  },
                  separatorBuilder: (BuildContext context, int index) {
                    return const SizedBox(
                      height: AppSizes.spaceBtwInputFields / 3,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
