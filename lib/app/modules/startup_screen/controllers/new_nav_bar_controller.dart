import 'package:get/get.dart';

class NewNavBarController extends GetxController {
  var currentIndex = 0.obs;
  var selectedTab = 'Leo'.obs;

  void changePage(int index) {
    currentIndex.value = index;
    selectedTab.value = index == 0 ? 'Leo' : 'Phone';
  }

  void switchToTab(String tabName) {
    if (tabName == 'Leo') {
      currentIndex.value = 0;
      selectedTab.value = 'Leo';
    } else if (tabName == 'Phone') {
      currentIndex.value = 1;
      selectedTab.value = 'Phone';
    }
  }

  void changeIndex(int index) {
    changePage(index);
  }
}
