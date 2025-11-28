import 'package:flutter/material.dart';

class BatteryCapacityRow extends StatelessWidget {
  final String label;
  final String value;

  const BatteryCapacityRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 15.0),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF282828),
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 15.0),
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF282828),
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

