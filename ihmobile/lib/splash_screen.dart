import 'package:flutter/material.dart';
import 'package:ihmobile/login.dart';
import 'package:lottie/lottie.dart'; // Import Lottie

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);

    // Navigate to the login page after the animation finishes or a set duration
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Ensure the widget is still mounted before navigating
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Or a background color that complements your animation
      body: Center(
        child: Lottie.asset(
          'animation.json', // Path to your Lottie JSON file
          controller: _animationController,
          onLoaded: (composition) {
            // Configure the AnimationController to play the animation once
            _animationController
              ..duration = composition.duration
              ..forward();
          },
          fit: BoxFit.contain, // Adjust fit as needed
          repeat: false, // Play the animation only once
        ),
      ),
    );
  }
}