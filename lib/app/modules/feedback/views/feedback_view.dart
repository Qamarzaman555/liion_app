import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/feedback_controller.dart';

class FeedbackView extends GetView<FeedbackController> {
  const FeedbackView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Feedback View'),
      ),
    );
  }
}

