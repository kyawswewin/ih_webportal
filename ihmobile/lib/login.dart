// lib/login.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ihmobile/productlist.dart';
import 'package:ihmobile/register.dart';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = Logger('LoginPage');

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  String? token;
  bool isLoading = false; // Manages loading state for the button
  bool _obscurePassword = true; // State for password visibility toggle

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Slightly longer duration for smoother animation
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic, // A more pronounced ease-out curve
      ),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate( // Starts slightly lower
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    // Validate inputs before making the API call
    if (usernameController.text.isEmpty || passwordController.text.isEmpty) {
      _showError('Please enter both username and password.');
      return;
    }

    setState(() => isLoading = true);
    _log.info('Attempting login for user: ${usernameController.text}');

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/login/'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'username': usernameController.text,
          'password': passwordController.text,
        }),
      );

      _log.info('Response status: ${response.statusCode}');
      _log.fine('Response body: ${response.body}');

      if (!mounted) return; // Check if the widget is still in the tree after async operation

      setState(() => isLoading = false); // Stop loading regardless of success/failure

      if (response.statusCode == 200) {
        final resultToken = jsonDecode(response.body)['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', resultToken);

        setState(() {
          token = resultToken;
        });

        _log.info('Login successful. Navigating to product page.');
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProductListPage(token: resultToken),
          ),
        );
      } else {
        try {
          final body = jsonDecode(response.body);
          // Prioritize 'non_field_errors', then 'detail', then other errors
          final error = body['non_field_errors']?.first ?? body['detail'] ?? 'Login failed. Please check your credentials.';
          _showError(error);
        } catch (_) {
          _showError('Unexpected server response. Please try again later.');
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
      _log.severe('Error during login: $e');
      _showError('Network error. Please check your internet connection.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red.shade700, // A darker, more prominent red
        behavior: SnackBarBehavior.floating, // Makes it float above content
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // Rounded corners
        margin: const EdgeInsets.all(16), // Margin from edges
        duration: const Duration(seconds: 3), // Display for 3 seconds
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine the shadow color with explicit alpha to address deprecation warning
    final Color baseShadowColor = Colors.teal.shade900;
    // Updated to use .a for opacity and .r, .g, .b for color components as suggested by deprecation warnings
    final int shadowAlpha = ((baseShadowColor.a * 255.0).round() * 0.4).round();
    final Color finalShadowColor = Color.fromARGB(
      shadowAlpha,
      (baseShadowColor.r * 255.0).round() & 0xff,
      (baseShadowColor.g * 255.0).round() & 0xff,
      (baseShadowColor.b * 255.0).round() & 0xff,
    );

    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevents keyboard from resizing the whole screen
      body: Stack(
        children: [
          // --- Background Gradient ---
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.teal.shade800, // Deeper teal
                  Colors.teal.shade400, // Lighter teal
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.1, 0.9], // Control the spread of colors
              ),
            ),
          ),
          // --- Main Content (Login Card) ---
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0), // More vertical padding
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)), // More rounded corners
                    elevation: 15, // Increased elevation for a floating effect
                    // Removed margin from Card, let SingleChildScrollView handle padding
                    child: Padding(
                      padding: const EdgeInsets.all(40), // More generous padding inside the card
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // --- App Icon/Logo ---
                          Icon(Icons.shopping_bag_outlined, size: 90, color: Colors.teal.shade600), // Larger, more relevant icon
                          const SizedBox(height: 25),

                          // --- Welcome Text ---
                          Text(
                            'Welcome Back!',
                            style: TextStyle(
                              fontSize: 32, // Larger title
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade900, // Darker teal for title
                              letterSpacing: 0.8, // Slight letter spacing
                              fontFamily: 'Montserrat', // Example font family
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Sign in to continue',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 40),

                          // --- Username Field ---
                          TextFormField(
                            controller: usernameController,
                            keyboardType: TextInputType.emailAddress, // Hint for email input
                            decoration: InputDecoration(
                              labelText: 'Username',
                              hintText: 'Enter your username or email',
                              prefixIcon: Icon(Icons.person_outline, color: Colors.teal.shade500),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15), // More rounded input borders
                                borderSide: BorderSide.none, // Remove default border
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100, // Light fill color
                              contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(color: Colors.teal.shade600, width: 2), // Teal focus border
                              ),
                            ),
                            cursorColor: Colors.teal.shade600, // Custom cursor color
                          ),
                          const SizedBox(height: 20),

                          // --- Password Field ---
                          TextFormField(
                            controller: passwordController,
                            obscureText: _obscurePassword, // Use the state variable here
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              prefixIcon: Icon(Icons.lock_outline, color: Colors.teal.shade500),
                              suffixIcon: IconButton( // Added a toggle for password visibility
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey.shade500,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword; // Toggle visibility
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
                              ),
                            ),
                            cursorColor: Colors.teal.shade600,
                          ),
                          const SizedBox(height: 30),

                          // --- Login Button ---
                          isLoading
                              ? CircularProgressIndicator(color: Colors.teal.shade600)
                              : SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal.shade700, // Stronger teal
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15), // More rounded button
                                      ),
                                      elevation: 8, // More prominent shadow
                                      foregroundColor: Colors.white,
                                      shadowColor: finalShadowColor, // Custom shadow color with explicit alpha
                                    ),
                                    child: const Text(
                                      'LOGIN',
                                      style: TextStyle(
                                        fontSize: 20, // Larger text
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 1.0, // More spacing for impact
                                      ),
                                    ),
                                  ),
                                ),
                          const SizedBox(height: 20),

                          // --- Forgot Password Link ---
                          TextButton(
                            onPressed: () {
                              _log.info('Forgot password pressed.');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Forgot Password feature coming soon!'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: Colors.teal.shade600, // Teal link color
                                decoration: TextDecoration.underline,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // --- Sign Up Link ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account?",
                                style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 15),
                              ),
                              TextButton(
                                onPressed: () {
                                  _log.info('Navigating to RegisterPage.');
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const RegisterPage()),
                                  );
                                },
                                child: Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    color: Colors.teal.shade600,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16, // Slightly larger
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
