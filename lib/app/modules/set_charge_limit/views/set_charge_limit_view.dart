import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import '../controllers/set_charge_limit_controller.dart';

class SetChargeLimitView extends GetView<SetChargeLimitController> {
  const SetChargeLimitView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: AppBar(
        title: const Text('Set Charge Limit'),
        centerTitle: true,
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.whiteColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              Obx(
                () => _buildStatusCard(
                  controller.isConnected.value,
                  controller.chargeLimitEnabled.value,
                  controller.chargeLimitConfirmed.value,
                  controller.chargeLimit.value,
                ),
              ),

              const SizedBox(height: 24),

              // Enable/Disable Switch
              Obx(
                () => _buildEnableSwitch(
                  controller.chargeLimitEnabled.value,
                  controller.isConnected.value,
                ),
              ),

              const SizedBox(height: 24),

              // Charge Limit Input Section
              const Text(
                'Charge Limit',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF282828),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Set a maximum charge percentage. Your device will stop charging when it reaches this limit.',
                style: TextStyle(fontSize: 14, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 16),

              // Text Field
              TextFormField(
                controller: controller.limitTextController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                validator: controller.validateLimit,
                decoration: InputDecoration(
                  hintText: 'Enter charge limit (0-100)',
                  suffixText: '%',
                  suffixStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
                  filled: true,
                  fillColor: AppColors.cardBGColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryColor,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.errorColor,
                      width: 2,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.errorColor,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 24),

              // Quick Select Buttons
              const Text(
                'Quick Select',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF282828),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickSelectButton(60),
                  _buildQuickSelectButton(70),
                  _buildQuickSelectButton(80),
                  _buildQuickSelectButton(90),
                ],
              ),

              const SizedBox(height: 32),

              // Save Button
              Obx(
                () => SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: controller.isConnected.value
                        ? () => controller.saveChargeLimit()
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: AppColors.whiteColor,
                      disabledBackgroundColor: AppColors.greyColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      controller.isConnected.value
                          ? 'Save Charge Limit'
                          : 'Connect to Leo to Save',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Info Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primaryColor),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Setting a charge limit helps preserve battery health by preventing overcharging.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF282828),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnableSwitch(bool isEnabled, bool isConnected) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBGColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Charge Limit',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF282828),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isEnabled ? 'Enabled' : 'Disabled',
                style: TextStyle(
                  fontSize: 14,
                  color: isEnabled ? AppColors.greenColor : AppColors.greyColor,
                ),
              ),
            ],
          ),
          Switch(
            value: isEnabled,
            onChanged: isConnected
                ? (value) => controller.toggleChargeLimit(value)
                : null,
            activeColor: AppColors.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    bool isConnected,
    bool isEnabled,
    bool isConfirmed,
    int currentLimit,
  ) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (!isConnected) {
      statusColor = AppColors.greyColor;
      statusText = 'Not Connected';
      statusIcon = Icons.bluetooth_disabled;
    } else if (isEnabled && isConfirmed) {
      statusColor = AppColors.greenColor;
      statusText = 'Active - $currentLimit%';
      statusIcon = Icons.check_circle;
    } else if (isEnabled) {
      statusColor = Colors.orange;
      statusText = 'Pending Confirmation';
      statusIcon = Icons.hourglass_empty;
    } else {
      statusColor = AppColors.greyColor;
      statusText = 'Disabled';
      statusIcon = Icons.power_off;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor.withOpacity(0.8), statusColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusIcon, size: 32, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Charge Limit Status',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSelectButton(int value) {
    return InkWell(
      onTap: () {
        controller.limitTextController.text = value.toString();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 70,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.cardBGColor,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          '$value%',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF282828),
          ),
        ),
      ),
    );
  }
}
