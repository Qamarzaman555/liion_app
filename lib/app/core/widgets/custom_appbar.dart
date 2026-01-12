import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/constants/sizes.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final double height;
  final Color backgroundColor;
  final Color titleColor;
  final bool centerTitle;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Widget? titleWidget;
  final double elevation;
  final BorderRadius? borderRadius;
  final double? paddingHorizontal;

  const CustomAppBar({
    super.key,
    this.title = '',
    this.leading,
    this.actions,
    this.height = 60.0,
    this.backgroundColor = NewAppColors.whiteBackground,
    this.titleColor = Colors.black,
    this.centerTitle = true,
    this.showBackButton = true,
    this.onBackPressed,
    this.titleWidget,
    this.elevation = 0.0,
    this.borderRadius,
    this.paddingHorizontal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: paddingHorizontal ?? 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Leading widget (back button or custom)
                  if (leading != null)
                    leading!
                  else if (showBackButton)
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 22,
                        color: Colors.black,
                      ),
                      onPressed:
                          onBackPressed ??
                          () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                    ),

                  // Title
                  Expanded(
                    child:
                        titleWidget ??
                        Text(
                          title,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                            fontFamily: "SF Pro Text",
                          ),
                          textAlign: centerTitle
                              ? TextAlign.center
                              : TextAlign.start,
                          // overflow: TextOverflow.ellipsis,
                        ),
                  ),

                  // Actions
                  if (actions != null) ...actions!,
                ],
              ),
              const SizedBox(height: AppSizes.xs * 2.5),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(height);
}
