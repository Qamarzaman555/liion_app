// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:liion_app/app/core/constants/app_colors.dart';
// import 'package:liion_app/app/core/constants/app_assets.dart';
// import '../controllers/led_timeout_controller.dart';
// import 'package:liion_app/app/core/widgets/custom_button.dart';
//
// class LedTimeoutView extends GetView<LedTimeoutController> {
//   const LedTimeoutView({super.key, required controller});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.whiteColor,
//       appBar: AppBar(
//         backgroundColor: AppColors.whiteColor,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: AppColors.blackColor),
//           onPressed: () => Get.back(),
//         ),
//         title: const Text(
//           'LED Timeout',
//           style: TextStyle(
//             color: AppColors.blackColor,
//             fontFamily: 'Inter',
//             fontSize: 20,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const SizedBox(height: 20),
//             Center(
//               child: SvgPicture.asset(
//                 SvgAssets.ledTimeBtnIcon,
//                 width: 80,
//                 height: 80,
//                 colorFilter: const ColorFilter.mode(
//                   AppColors.primaryColor,
//                   BlendMode.srcIn,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 32),
//             const Text(
//               'LED Timeout',
//               style: TextStyle(
//                 color: Color(0xFF282828),
//                 fontFamily: 'Inter',
//                 fontSize: 24,
//                 fontWeight: FontWeight.w700,
//               ),
//             ),
//             const SizedBox(height: 12),
//             const Text(
//               'Configure how long the LED indicator should remain active before automatically turning off.',
//               style: TextStyle(
//                 color: Color(0xFF888888),
//                 fontFamily: 'Inter',
//                 fontSize: 14,
//               ),
//             ),
//             const SizedBox(height: 32),
//             const SizedBox(height: 24),
//             Form(
//               key: controller.formKey,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     'Timeout Duration (seconds)',
//                     style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.w600,
//                       color: Color(0xFF282828),
//                       fontFamily: 'Inter',
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   TextFormField(
//                     controller: controller.timeoutTextController,
//                     keyboardType: TextInputType.number,
//                     validator: controller.validateTimeout,
//                     decoration: InputDecoration(
//                       hintText: 'Enter value between 0-99999',
//                       hintStyle: const TextStyle(
//                         color: Color(0xFF888888),
//                         fontFamily: 'Inter',
//                         fontSize: 14,
//                       ),
//                       contentPadding: const EdgeInsets.symmetric(
//                         vertical: 12,
//                         horizontal: 14,
//                       ),
//                       enabledBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12),
//                         borderSide: const BorderSide(
//                           color: Color(0xFFE0E0E0),
//                           width: 1.5,
//                         ),
//                       ),
//                       focusedBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12),
//                         borderSide: const BorderSide(
//                           color: AppColors.primaryColor,
//                           width: 2,
//                         ),
//                       ),
//                       errorBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12),
//                         borderSide: const BorderSide(
//                           color: Colors.red,
//                           width: 1.5,
//                         ),
//                       ),
//                       focusedErrorBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12),
//                         borderSide: const BorderSide(
//                           color: Colors.red,
//                           width: 1.5,
//                         ),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 20),
//                   CustomButton(
//                     text: 'Set Timeout',
//                     onPressed: () {
//                       controller.updateTimeoutFromInput();
//                     },
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 40),
//           ],
//         ),
//       ),
//     );
//   }
// }
