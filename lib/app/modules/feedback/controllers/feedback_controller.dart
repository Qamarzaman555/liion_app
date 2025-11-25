import 'package:get/get.dart';

class FeedbackController extends GetxController {
  final feedbackText = ''.obs;

  void setFeedback(String text) {
    feedbackText.value = text;
  }
}

