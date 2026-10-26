import 'package:get/get.dart';
import '../services/storage_service.dart';
import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Normally already loaded in main(); this covers tests that pump the app directly.
    if (!Get.isRegistered<StorageService>()) Get.put(StorageService(), permanent: true);
    Get.lazyPut(() => AuthController(), fenix: true);
    Get.lazyPut(() => HomeController(), fenix: true);
  }
}
