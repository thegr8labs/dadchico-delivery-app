import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'utils/app_colors.dart';
import 'utils/initial_binding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  // Order alerts (push + local). Never blocks startup if Firebase isn't configured.
  await Get.putAsync(() => NotificationService().init(), permanent: true);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  runApp(const DeliveryApp());
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryGreen,
        primary: AppColors.primaryGreen,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    return GetMaterialApp(
      title: 'Dadchico Delivery',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        primaryColor: AppColors.primaryGreen,
        textTheme: GoogleFonts.interTextTheme(base.textTheme),
        snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primaryGreen),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primaryGreen.withValues(alpha: 0.45),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      initialRoute: '/',
      initialBinding: InitialBinding(),
      getPages: [
        GetPage(name: '/', page: () => const SplashScreen(), transition: Transition.fade),
        GetPage(name: '/login', page: () => const LoginScreen(), transition: Transition.fadeIn),
        GetPage(name: '/home', page: () => const MainScreen(), transition: Transition.fadeIn),
      ],
    );
  }
}
