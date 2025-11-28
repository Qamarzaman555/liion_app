import 'package:flutter/material.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';

class CustomSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const CustomSwitch({super.key, required this.value, required this.onChanged});

  @override
  State<CustomSwitch> createState() => _CustomSwitchState();
}

class _CustomSwitchState extends State<CustomSwitch> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onChanged(!widget.value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 32,
        width: 60,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: widget.value
              ? AppColors.primaryColor
              : Colors.grey.withOpacity(0.3),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          alignment: widget.value
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Container(
            height: 24,
            width: 24,
            decoration: BoxDecoration(
              color: widget.value
                  ? Colors.white
                  : AppColors.primaryColor.withOpacity(0.8),
              shape: BoxShape.circle,
              //
            ),
          ),
        ),
      ),
    );
  }
}
