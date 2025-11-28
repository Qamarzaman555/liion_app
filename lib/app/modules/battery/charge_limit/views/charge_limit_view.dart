import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/widgets/custom_button.dart';
import 'package:liion_app/app/core/widgets/custom_switch.dart';
import 'package:liion_app/app/modules/battery/controllers/battery_controller.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import '../controllers/charge_limit_controller.dart';

class ChargeLimitView extends GetView<ChargeLimitController> {
  const ChargeLimitView({super.key});

  @override
  Widget build(BuildContext context) {
    final batteryController = Get.find<BatteryController>();

    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: controller.formKey,
            child: Column(
              children: [
                _buildHeader(batteryController),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitle(controller),
                      const SizedBox(height: 24),
                      const _DescriptionText(),
                      const SizedBox(height: 24),
                      Obx(
                        () => controller.chargeLimitEnabled.value
                            ? Column(
                                children: [
                                  _buildInputCard(controller),
                                  const SizedBox(height: 24),
                                  _buildSaveButton(controller),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildHeader(BatteryController batteryController) {
  return Padding(
    padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.blackColor),
          onPressed: () => Get.back(),
        ),
        Obx(
          () => Container(
            decoration: BoxDecoration(
              color: AppColors.yellowColor,
              borderRadius: BorderRadius.circular(20.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: Text(
              "${batteryController.phoneBatteryLevel.value}%",
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildTitle(ChargeLimitController controller) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Text(
        "Custom Charge Limit",
        style: TextStyle(
          color: Color(0xFF282828),
          fontFamily: 'Inter',
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
      Obx(
        () => CustomSwitch(
          value: controller.chargeLimitEnabled.value,
          onChanged: (value) {
            if (!controller.isConnected.value) {
              Get.snackbar(
                'Not Connected',
                'Please connect to Leo to enable charge limit',
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 2),
              );
              return;
            }
            controller.toggleChargeLimit(value);
          },
        ),
      ),
    ],
  );
}

class _DescriptionText extends StatelessWidget {
  const _DescriptionText();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'This feature works only on this device and requires:\n\n',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text:
                '• The app installed on this device and connected to Leo via Bluetooth\n'
                '• The device being charged directly by the Bluetooth-connected Leo\n\n'
                '(If you disable Custom Charge Limit or charge a different device without the app, Leo will apply its own automatic charge limit instead).',
            style: TextStyle(fontFamily: 'Inter', fontSize: 14),
          ),
        ],
      ),
    );
  }
}

Widget _buildInputCard(ChargeLimitController controller) {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10.0),
      color: AppColors.secondaryColor,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    child: Column(
      children: [
        TextFormField(
          controller: controller.limitTextController,
          onChanged: controller.updateFromText,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          validator: controller.validateLimit,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(
            hint: "${controller.chargeLimit.value}%",
          ),
        ),
        const SizedBox(height: 30),
        _buildSlider(controller),
      ],
    ),
  );
}

InputDecoration _inputDecoration({required String hint}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white),
    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(width: 3, color: Colors.white),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(width: 3, color: Colors.white),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(width: 3, color: AppColors.redColor),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(width: 3, color: AppColors.redColor),
    ),
    errorStyle: const TextStyle(
      color: AppColors.redColor,
      fontSize: 12,
      fontFamily: 'Inter',
    ),
  );
}

Widget _buildSlider(ChargeLimitController controller) {
  return Obx(
    () => SfSliderTheme(
      data: SfSliderThemeData(
        inactiveLabelStyle: TextStyle(
          color: const Color(0xFF282828).withOpacity(0.5),
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w400,
        ),
        activeLabelStyle: TextStyle(
          color: const Color(0xFF282828).withOpacity(0.5),
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w400,
        ),
      ),
      child: SfSlider(
        activeColor: Colors.white,
        inactiveColor: const Color(0xFF282828).withOpacity(0.5),
        min: 0.0,
        max: 100.0,
        interval: 20,
        value: controller.sliderValue.value,
        stepSize: 1,
        showTicks: true,
        showLabels: true,
        labelFormatterCallback: (dynamic value, String _) =>
            '${value.toInt()}%',
        onChanged: (dynamic value) => controller.updateSlider(value.toDouble()),
      ),
    ),
  );
}

Widget _buildSaveButton(ChargeLimitController controller) {
  return CustomButton(
    backgroundColor: AppColors.secondaryColor,
    text: "Save Charge Limit",
    onPressed: () {
      if (!controller.isConnected.value) {
        Get.snackbar(
          'Not Connected',
          'Please connect to Leo to save limit',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
        return;
      }
      controller.saveChargeLimit();
    },
  );
}
