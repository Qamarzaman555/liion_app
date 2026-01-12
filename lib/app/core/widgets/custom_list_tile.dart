import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/constants/sizes.dart';

class CustomListTile extends StatelessWidget {
  final VoidCallback? onTap;
  final String titleText, suffixIconPath;
  final Color? backgroundColor;
  final double? fontSize;
  const CustomListTile({
    super.key,
    this.backgroundColor,
    required this.onTap,
    required this.titleText,
    required this.suffixIconPath,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 3,
        color: backgroundColor ?? NewAppColors.lightContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadiusSm),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.defaultSpace - 4,
                vertical: AppSizes.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    AppImages.leoImageLg,
                    height: MediaQuery.sizeOf(context).width * 0.3,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      titleText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fontSize ?? AppSizes.fontSizeMd,
                        fontFamily: 'SF Pro Text',
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 18,
              right: 18,
              child: SvgPicture.asset(suffixIconPath, height: 18),
            ),
          ],
        ),
      ),
    );
  }
}
