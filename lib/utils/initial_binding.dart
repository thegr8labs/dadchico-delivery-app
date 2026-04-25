import 'package:get/get.dart';
import '../services/storage_service.dart';
import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(StorageService(), permanent: true);
    Get.lazyPut(() => AuthController());
    Get.lazyPut(() => HomeController());
  }
}
