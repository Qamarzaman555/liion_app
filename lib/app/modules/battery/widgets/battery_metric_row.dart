import 'package:flutter/material.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';

class BatteryMetricRow extends StatelessWidget {
  final String title;
  final String value;
  final double screenHeight;

  const BatteryMetricRow({
    super.key,
    required this.title,
    required this.value,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF282828),
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        Container(
          width: 150,
          height: screenHeight * 0.06,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            color: AppColors.secondaryColor,
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: Center(
              child: Text(
                value,
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

