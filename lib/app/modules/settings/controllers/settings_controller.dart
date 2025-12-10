import 'package:get/get.dart';
import 'package:liion_app/app/core/utils/snackbar_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsController extends GetxController {
  Future<void> openFaq() async {
    try {
      const url = 'https://liionpower.tech/pages/faq';
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        AppSnackbars.showSuccess(
          title: 'Error',
          message: 'Could not open FAQ page',
        );
      }
    } catch (e) {
      AppSnackbars.showSuccess(
        title: 'Error',
        message: 'An error occurred: $e',
      );
    }
  }
}
