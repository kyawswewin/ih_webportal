// lib/profile.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart'; // Import logging

final _log = Logger('ProfilePage'); // Initialize logger for this file

class ProfilePage extends StatefulWidget {
  final String token;
  const ProfilePage({super.key, required this.token});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? userProfile;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  void logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600, // Red for logout confirmation
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clears all stored data, including the token

    if (!mounted) return;

    // Navigate back to the login page and remove all previous routes
    // Ensure '/login' is a named route in your MaterialApp in main.dart
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    _log.info('User logged out successfully.');
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/profile/'), // Assuming this endpoint exists
        headers: {'Authorization': 'Token ${widget.token}'},
      );

      if (!mounted) return; // Check mounted state after async operation

      if (response.statusCode == 200) {
        setState(() {
          userProfile = jsonDecode(response.body);
          isLoading = false;
        });
        _log.info('User profile fetched successfully.');
      } else if (response.statusCode == 401) {
        // Token invalid or expired, force logout
        _log.warning('Authentication failed (401) during profile fetch. Forcing logout.');
        logout(); // Call logout to clear token and redirect
      } else {
        final errorBody = jsonDecode(response.body);
        String errorMsg = 'Failed to load profile: ${response.statusCode}';
        if (errorBody is Map && errorBody.containsKey('detail')) {
          errorMsg += ' - ${errorBody['detail']}';
        }
        setState(() {
          errorMessage = errorMsg;
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
        _log.warning('Failed to load profile: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Network error: $e';
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Could not load profile.')),
      );
      _log.severe('Network error fetching profile: $e');
    }
  }

  // Helper function to get color based on member_level for the Card background
  Color _getMemberLevelCardColor(String? memberLevel) {
    switch (memberLevel) {
      case 'Legend':
        return Colors.purple.shade50; // Very light purple
      case 'Diamond':
        return Colors.cyan.shade50; // Very light cyan
      case 'Platinum':
        return Colors.blue.shade50; // Very light blue
      case 'Gold':
        return Colors.yellow.shade50; // Very light yellow
      case 'Silver':
        return Colors.blueGrey.shade50; // Very light grey
      case 'Bronze':
        return Colors.brown.shade50; // Very light brown
      default:
        return Colors.white; // Default color
    }
  }

  // Helper function to get text color for better contrast on the card
  Color _getMemberLevelTextColor(String? memberLevel) {
    switch (memberLevel) {
      case 'Legend':
        return Colors.purple.shade900;
      case 'Diamond':
        return Colors.cyan.shade900;
      case 'Platinum':
        return Colors.blue.shade900;
      case 'Gold':
        return Colors.yellow.shade900;
      case 'Silver':
        return Colors.blueGrey.shade900;
      case 'Bronze':
        return Colors.brown.shade900;
      default:
        return Colors.black87;
    }
  }

  // Helper function to get a strong accent color for borders and avatar background
  Color _getMemberLevelAccentColor(String? memberLevel) {
    switch (memberLevel) {
      case 'Legend':
        return Colors.purple.shade700;
      case 'Diamond':
        return Colors.cyan.shade700;
      case 'Platinum':
        return Colors.blue.shade700;
      case 'Gold':
        return Colors.amber.shade700; // Adjusted for better contrast
      case 'Silver':
        return Colors.blueGrey.shade700;
      case 'Bronze':
        return Colors.brown.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  // Helper widget to build consistent profile rows
  Widget _buildProfileRow(String label, String value, Color textColor) {
    // Calculate softer text color for the label using Color.fromARGB
    final int labelAlpha = ((textColor.a * 255.0).round() * 0.7).round();
    final Color labelColor = Color.fromARGB(
      labelAlpha,
      (textColor.r * 255.0).round() & 0xff,
      (textColor.g * 255.0).round() & 0xff,
      (textColor.b * 255.0).round() & 0xff,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label, // Label without colon, as it's part of the design
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600, // Slightly bolder for label
              color: labelColor, // Softer color for label
              fontFamily: 'Roboto', // Consistent font
            ),
          ),
          const SizedBox(height: 4), // Reduced space
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              color: textColor, // Full color for value
              fontWeight: FontWeight.normal,
              fontFamily: 'Roboto',
            ),
          ),
          const Divider(height: 15, thickness: 0.5, color: Colors.grey), // Thinner divider
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? memberLevel = userProfile?['member_level'] as String?;
    Color cardColor = _getMemberLevelCardColor(memberLevel);
    Color textColor = _getMemberLevelTextColor(memberLevel);
    Color accentColor = _getMemberLevelAccentColor(memberLevel);

    // Calculate shadow color for the avatar using Color.fromARGB
    final int avatarShadowAlpha = ((accentColor.a * 255.0).round() * 0.4).round();
    final Color avatarShadowColor = Color.fromARGB(
      avatarShadowAlpha,
      (accentColor.r * 255.0).round() & 0xff,
      (accentColor.g * 255.0).round() & 0xff,
      (accentColor.b * 255.0).round() & 0xff,
    );

    // Calculate border color for the membership details card using Color.fromARGB
    final int borderAlpha = ((accentColor.a * 255.0).round() * 0.6).round();
    final Color cardBorderColor = Color.fromARGB(
      borderAlpha,
      (accentColor.r * 255.0).round() & 0xff,
      (accentColor.g * 255.0).round() & 0xff,
      (accentColor.b * 255.0).round() & 0xff,
    );

    // Calculate shadow color for the logout button using Color.fromARGB
    final Color baseLogoutShadowColor = Colors.red.shade900;
    final int logoutShadowAlpha = ((baseLogoutShadowColor.a * 255.0).round() * 0.4).round();
    final Color finalLogoutShadowColor = Color.fromARGB(
      logoutShadowAlpha,
      (baseLogoutShadowColor.r * 255.0).round() & 0xff,
      (baseLogoutShadowColor.g * 255.0).round() & 0xff,
      (baseLogoutShadowColor.b * 255.0).round() & 0xff,
    );


    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'User Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 90, 150, 155), // Darker teal-blue start
                Color.fromARGB(255, 130, 170, 180), // Lighter teal-blue end
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal.shade700),
                  const SizedBox(height: 20),
                  const Text(
                    'Loading profile...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 60),
                        const SizedBox(height: 15),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 25),
                        ElevatedButton.icon(
                          onPressed: _fetchUserProfile,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text('Retry', style: TextStyle(color: Colors.white, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade600,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center, // Center the avatar and username
                    children: [
                      // --- Profile Avatar and Username ---
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: avatarShadowColor, // Use the new calculated shadow color
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 70, // Larger avatar
                          backgroundColor: accentColor,
                          child: const Icon(Icons.person, size: 90, color: Colors.white), // Larger icon
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        userProfile?['username'] ?? 'User',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade900, // Darker teal for username
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Member Level: ${memberLevel ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: accentColor, // Member level text uses accent color
                        ),
                      ),
                      const SizedBox(height: 30),

                      // --- Membership Details Card ---
                      Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(color: cardBorderColor, width: 1.5), // Use the new calculated border color
                        ),
                        color: cardColor,
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Text(
                                  'Membership Overview',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                    fontFamily: 'Montserrat',
                                  ),
                                ),
                              ),
                              const Divider(height: 25, thickness: 1, color: Colors.grey),
                              _buildProfileRow('Customer Code', userProfile?['c_code'] ?? 'N/A', textColor),
                              _buildProfileRow('Total Purchased Amount', userProfile?['amount']?.toStringAsFixed(2) ?? '0.00', textColor),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- Personal Details Card ---
                      Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                        ),
                        color: Colors.white, // Keep this card white for contrast
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Text(
                                  'Personal Information',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey.shade800,
                                    fontFamily: 'Montserrat',
                                  ),
                                ),
                              ),
                              const Divider(height: 25, thickness: 1, color: Colors.grey),
                              _buildProfileRow('Email', userProfile?['email'] ?? 'N/A', Colors.blueGrey.shade800),
                              _buildProfileRow('Phone', userProfile?['phone'] ?? 'N/A', Colors.blueGrey.shade800),
                              _buildProfileRow('NRC', userProfile?['nrc'] ?? 'N/A', Colors.blueGrey.shade800),
                              _buildProfileRow(
                                'Date of Birth',
                                userProfile?['dob'] != null && userProfile!['dob'] is String
                                    ? DateFormat('yyyy-MM-dd').format(
                                        DateTime.parse(userProfile!['dob']),
                                      )
                                    : 'N/A',
                                Colors.blueGrey.shade800,
                              ),
                              _buildProfileRow(
                                'Joined Date',
                                userProfile?['date_joined'] != null && userProfile!['date_joined'] is String
                                    ? DateFormat('yyyy-MM-dd HH:mm').format(
                                        DateTime.parse(userProfile!['date_joined']),
                                      )
                                    : 'N/A',
                                Colors.blueGrey.shade800,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // --- Logout Button ---
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: logout,
                          icon: const Icon(Icons.logout, color: Colors.white, size: 24),
                          label: const Text(
                            'LOGOUT',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600, // Prominent red for logout
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 5,
                            shadowColor: finalLogoutShadowColor, // Use the new calculated shadow color
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
