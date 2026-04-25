import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../widgets/bottom_nav.dart';
import 'home_screen.dart';
import 'earnings_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController homeController = Get.put(HomeController());

    final List<Widget> pages = [
      const HomeScreen(),
      const EarningsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: Obx(() => pages[homeController.selectedTab.value]),
      bottomNavigationBar: const CustomBottomNavBar(),
    );
  }
}
