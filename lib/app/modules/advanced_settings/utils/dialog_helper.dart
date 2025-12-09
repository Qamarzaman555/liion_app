import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class DialogHelper {
  static void showConfirmationDialog(
    BuildContext context, {
    String? title,
    Widget? middleTextWidget,
    Widget? customSwitch,
  }) {
    Get.defaultDialog(
      title: title ?? '',
      titlePadding: const EdgeInsets.only(top: 20, bottom: 10),
      titleStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.only(left: 20, right: 20),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.of(context).size.height * 0.6, // Constrain height
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (middleTextWidget != null) middleTextWidget,
              if (customSwitch != null) customSwitch,
            ],
          ),
        ),
      ),
    );
  }
}
