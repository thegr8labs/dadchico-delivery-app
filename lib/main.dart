import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'utils/app_colors.dart';
import 'utils/initial_binding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  runApp(const DeliveryApp());
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Delivery App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: AppColors.primaryGreen,
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGreen,
          primary: AppColors.primaryGreen,
        ),
      ),
      initialRoute: '/',
      initialBinding: InitialBinding(),
      getPages: [
        GetPage(
          name: '/',
          page: () => const SplashScreen(),
          transition: Transition.fade,
        ),
        GetPage(
          name: '/login',
          page: () => const LoginScreen(),
          transition: Transition.rightToLeftWithFade,
        ),
        GetPage(
          name: '/home',
          page: () => const MainScreen(),
          transition: Transition.fadeIn,
        ),
      ],
    );
  }
}
