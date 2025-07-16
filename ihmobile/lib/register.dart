// lib/register.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:intl/intl.dart'; // Import for date formatting

final _log = Logger('RegisterPage'); // Logger for the RegisterPage

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>(); // GlobalKey for form validation

  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final nrcController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  DateTime? selectedDate;
  bool isLoading = false;
  bool _obscurePassword = true; // For password visibility toggle
  bool _obscureConfirmPassword = true; // For confirm password visibility toggle

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Consistent with Login page
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic, // Consistent with Login page
      ),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
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
    emailController.dispose();
    phoneController.dispose();
    nrcController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // Function to show a custom styled SnackBar
  void _showSnackBar(String message, {Color backgroundColor = Colors.red}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.teal.shade700, // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Colors.blueGrey.shade800, // Body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.teal.shade700, // Button text color
              ),
            ),
            dialogTheme: DialogThemeData( // Use DialogThemeData here
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> register() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill in all required fields correctly.', backgroundColor: Colors.red.shade700);
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      _showSnackBar('Passwords do not match!', backgroundColor: Colors.red.shade700);
      return;
    }

    if (selectedDate == null) {
      _showSnackBar('Please select your Date of Birth.', backgroundColor: Colors.red.shade700);
      return;
    }

    setState(() => isLoading = true);
    _log.info('Attempting registration for user: ${usernameController.text}, email: ${emailController.text}');

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': usernameController.text.trim(),
          'email': emailController.text.trim(),
          'phone': phoneController.text.trim(),
          'nrc': nrcController.text.trim(),
          'dob': DateFormat('yyyy-MM-dd').format(selectedDate!),
          'password': passwordController.text,
          'password2': confirmPasswordController.text,
        }),
      );

      _log.info('Response status: ${response.statusCode}');
      _log.fine('Response body: ${response.body}');

      if (!mounted) return;

      setState(() => isLoading = false);

      if (response.statusCode == 201) {
        _showSnackBar('Registration successful! Please log in.', backgroundColor: Colors.green.shade600);
        _log.info('Registration successful. Navigating back.');
        Navigator.pop(context); // Go back to Login Page
      } else {
        String errorMessage = 'Registration failed. Please check your input.';
        try {
          final Map<String, dynamic> errorBody = jsonDecode(response.body);

          if (errorBody.containsKey('error')) {
            errorMessage = errorBody['error'].toString();
          } else if (errorBody.containsKey('username')) {
            errorMessage = 'Username: ${errorBody['username'][0]}';
          } else if (errorBody.containsKey('email')) {
            errorMessage = 'Email: ${errorBody['email'][0]}';
          } else if (errorBody.containsKey('phone')) { // Use 'phone' as per your model
            errorMessage = 'Phone Number: ${errorBody['phone'][0]}';
          } else if (errorBody.containsKey('nrc')) {
            errorMessage = 'NRC: ${errorBody['nrc'][0]}';
          } else if (errorBody.containsKey('dob')) { // Use 'dob' as per your model
            errorMessage = 'Date of Birth: ${errorBody['dob'][0]}';
          } else if (errorBody.containsKey('password')) {
            errorMessage = 'Password: ${errorBody['password'][0]}';
          } else if (errorBody.containsKey('non_field_errors')) {
            errorMessage = errorBody['non_field_errors'][0];
          } else if (errorBody.containsKey('detail')) {
            errorMessage = errorBody['detail'];
          } else {
            errorMessage = 'Registration failed. Server response: ${response.body}';
          }
        } catch (e) {
          _log.severe('Failed to parse error response body: $e');
          errorMessage = 'Registration failed. Unable to interpret server response.';
        }
        _log.warning('Registration failed: $errorMessage');
        _showSnackBar(errorMessage, backgroundColor: Colors.red.shade700);
      }
    } catch (e) {
      setState(() => isLoading = false);
      _log.severe('Error during registration: $e');
      _showSnackBar('Network error. Please check your internet connection.', backgroundColor: Colors.red.shade700);
    }
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
          // --- Background gradient (matching Login page) ---
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.teal.shade800, // Deeper teal
                  Colors.teal.shade400, // Lighter teal
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.1, 0.9],
              ),
            ),
          ),
          // --- Registration content ---
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    elevation: 15,
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Form( // Wrap with Form for validation
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // --- App Icon/Logo ---
                            Icon(Icons.person_add_alt_1_rounded, size: 90, color: Colors.teal.shade600),
                            const SizedBox(height: 25),

                            // --- Welcome Text ---
                            Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade900,
                                letterSpacing: 0.8,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Join us to explore amazing furniture!',
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
                              keyboardType: TextInputType.text,
                              decoration: InputDecoration(
                                labelText: 'Username',
                                hintText: 'Choose a unique username',
                                prefixIcon: Icon(Icons.person_outline, color: Colors.teal.shade500),
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
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Username is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // --- Email Field ---
                            TextFormField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                hintText: 'Enter your email address',
                                prefixIcon: Icon(Icons.email_outlined, color: Colors.teal.shade500),
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
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Email is required';
                                }
                                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // --- Phone Number Field ---
                            TextFormField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                hintText: 'e.g., +959xxxxxxxx',
                                prefixIcon: Icon(Icons.phone, color: Colors.teal.shade500),
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
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Phone number is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // --- NRC Field ---
                            TextFormField(
                              controller: nrcController,
                              keyboardType: TextInputType.text,
                              decoration: InputDecoration(
                                labelText: 'NRC (e.g., 12/ABC(N)123456)',
                                hintText: 'Enter your NRC number',
                                prefixIcon: Icon(Icons.credit_card, color: Colors.teal.shade500),
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
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'NRC is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // --- Date of Birth Field ---
                            GestureDetector(
                              onTap: () => _selectDate(context),
                              child: AbsorbPointer(
                                child: TextFormField(
                                  controller: TextEditingController(
                                    text: selectedDate == null
                                        ? ''
                                        : DateFormat('yyyy-MM-dd').format(selectedDate!),
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Date of Birth',
                                    hintText: 'YYYY-MM-DD',
                                    prefixIcon: Icon(Icons.calendar_today, color: Colors.teal.shade500),
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
                                  validator: (value) {
                                    if (selectedDate == null) {
                                      return 'Date of Birth is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // --- Password Field ---
                            TextFormField(
                              controller: passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                hintText: 'Create a strong password',
                                prefixIcon: Icon(Icons.lock_outline, color: Colors.teal.shade500),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.grey.shade500,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
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
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Password is required';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters long';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // --- Confirm Password Field ---
                            TextFormField(
                              controller: confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              decoration: InputDecoration(
                                labelText: 'Confirm Password',
                                hintText: 'Re-enter your password',
                                prefixIcon: Icon(Icons.lock_reset, color: Colors.teal.shade500),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.grey.shade500,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword = !_obscureConfirmPassword;
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
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Confirm password is required';
                                }
                                if (value != passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 30),

                            // --- Register Button ---
                            isLoading
                                ? CircularProgressIndicator(color: Colors.teal.shade600)
                                : SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: register,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal.shade700,
                                        padding: const EdgeInsets.symmetric(vertical: 18),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                        elevation: 8,
                                        foregroundColor: Colors.white,
                                        // Use Color.fromARGB to set the alpha explicitly
                                        shadowColor: finalShadowColor,
                                      ),
                                      child: const Text(
                                        'REGISTER',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                            const SizedBox(height: 20),

                            // --- Already have an account? Link ---
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Already have an account?",
                                  style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 15),
                                ),
                                TextButton(
                                  onPressed: () {
                                    _log.info('Navigating back to LoginPage.');
                                    Navigator.pop(context); // Go back to Login Page
                                  },
                                  child: Text(
                                    'Login',
                                    style: TextStyle(
                                      color: Colors.teal.shade600,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
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
          ),
        ],
      ),
    );
  }
}
