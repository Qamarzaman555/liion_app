import 'package:flutter/material.dart';

class UpdateLeoText extends StatelessWidget {
  const UpdateLeoText({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'A new update for Leo is available!',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 16),
        const Text(
          'To enjoy the latest features, fixes, and improvements, please update your Leo:',
        ),
        const SizedBox(height: 12),
        _buildStep(
          context,
          number: '1',
          title: 'Update the App:',
          description: 'Go to Settings > Update App.',
        ),
        _buildStep(
          context,
          number: '2',
          title: 'Avoid Charging:',
          description: 'Make sure nothing is charging during the update.',
        ),
        _buildStep(
          context,
          number: '3',
          title: 'Update Leo:',
          description: 'Press \'Update Leo\' in the app.',
        ),
        _buildStep(
          context,
          number: '4',
          title: 'Wait for Completion:',
          description:
              'Allow the update to finish and wait for the 1-minute timer to pass. If a red light appears, please repeat the update until it is successful.',
        ),
        const SizedBox(height: 16),
        const Wrap(
          children: [
            Text(
              'Note:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 8),
            Text(
              'Keep your phone close to Leo and connected via Bluetooth throughout the process.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep(
    BuildContext context, {
    required String number,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(description, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
