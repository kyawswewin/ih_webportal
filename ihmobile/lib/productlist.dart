// lib/product_list_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ihmobile/login.dart';
import 'dart:convert';
import 'package:ihmobile/productdetail.dart';
import 'package:ihmobile/profile.dart';
import 'package:ihmobile/cart_page.dart';
import 'package:ihmobile/order_history_page.dart';
import 'package:logging/logging.dart';

// Initialize a logger for this file, good practice for debugging
final _log = Logger('ProductListPage');

class ProductListPage extends StatefulWidget {
  final String token;
  const ProductListPage({super.key, required this.token});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  List items = [];
  Map<int, int> cart = {};

  // Store user profile details for passing to CartPage
  String? _userName;
  String? _userPhone;
  String? _userAddress;

  @override
  void initState() {
    super.initState();
    fetchFurniture();
    _fetchUserProfile(); // Fetch user profile when the page loads
  }

  // Method to fetch user profile
  Future<void> _fetchUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/profile/'),
        headers: {'Authorization': 'Token ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final profileData = jsonDecode(response.body);
        setState(() {
          _userName = profileData['username'];
          _userPhone = profileData['phone'];
          // Assuming 'nrc' holds the address or you have a dedicated 'address' field
          _userAddress = profileData['nrc'];
        });
      } else {
        _log.warning('Failed to load profile: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _log.severe('Error fetching profile: $e');
    }
  }

  // Method to fetch furniture items
  Future<void> fetchFurniture() async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/furniture/'),
        headers: {'Authorization': 'Token ${widget.token}'},
      );
      if (response.statusCode == 200) {
        setState(() {
          items = (jsonDecode(response.body) as List)
              .map((item) {
                item['price'] = double.tryParse(item['price'].toString()) ?? 0.0;
                return item;
              })
              .toList();
        });
        _log.info('Successfully fetched ${items.length} furniture items.');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load furniture: ${response.statusCode}')),
          );
        }
        _log.warning('Failed to load furniture: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Could not fetch furniture.')),
        );
      }
      _log.severe('Network error fetching furniture: $e');
    }
  }

  // Method to add item to cart and show a beautiful SnackBar
  void addToCart(int id) {
    setState(() {
      cart[id] = (cart[id] ?? 0) + 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Added to cart!', // Concise message
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: Colors.teal.shade600, // A pleasant green-teal color
        behavior: SnackBarBehavior.floating, // Makes it float above content
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10), // Rounded corners
        ),
        margin: const EdgeInsets.all(10), // Adds some margin around the snackbar
        duration: const Duration(seconds: 2), // Show for 2 seconds
        action: SnackBarAction(
          label: 'View Cart',
          textColor: Colors.white,
          onPressed: () {
            // Navigate to cart page when "View Cart" is pressed
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CartPage(
                  initialCart: cart,
                  token: widget.token,
                  productItems: items,
                  onOrderPlaced: () {
                    // This callback is for the order success scenario.
                    // _onCartDataUpdated will also be called from CartPage
                    // when the cart is cleared after order.
                  },
                  onCartUpdated: _onCartDataUpdated,
                  userName: _userName,
                  userPhone: _userPhone,
                  userAddress: _userAddress,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Callback to update cart data from CartPage
  void _onCartDataUpdated(Map<int, int> updatedCart) {
    setState(() {
      cart = updatedCart;
    });
  }

  // Logout function
  void logout() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    // Calculate shadow color for the product cards
    final Color baseGreyShadowColor = Colors.grey;
    final int cardShadowAlpha = ((baseGreyShadowColor.a * 255.0).round() * 0.3).round();
    final Color finalCardShadowColor = Color.fromARGB(
      cardShadowAlpha,
      (baseGreyShadowColor.r * 255.0).round() & 0xff,
      (baseGreyShadowColor.g * 255.0).round() & 0xff,
      (baseGreyShadowColor.b * 255.0).round() & 0xff,
    );

    return Scaffold(
      // --- Custom AppBar with Gradient and Shadow ---
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 10), // Slightly taller AppBar
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 90, 150, 155), // Darker teal-blue start
                Color.fromARGB(255, 130, 170, 180), // Lighter teal-blue end
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 10,
                offset: Offset(0, 4), // More pronounced shadow
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent, // Make AppBar transparent to show Container gradient
            elevation: 0, // No default AppBar shadow
            centerTitle: true,
            title: const Text(
              'INHOUSE FURNITURE', // Simplified title
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Color(0xFFFFE066), // A bright gold/amber for prominence
                fontFamily: 'Montserrat', // A modern font, make sure to add to pubspec.yaml
              ),
            ),
            actions: [
              // History Icon Button
              IconButton(
                icon: const Icon(Icons.history, color: Color(0xFFFFD700)),
                tooltip: 'Order History', // Added tooltip
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderHistoryPage(token: widget.token),
                    ),
                  );
                },
              ),
              // Profile Icon Button
              IconButton(
                icon: const Icon(Icons.person, color: Color(0xFFFFD700)),
                tooltip: 'Profile', // Added tooltip
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfilePage(token: widget.token),
                    ),
                  );
                },
              ),
              // Logout Icon Button
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Logout', // Added tooltip
                onPressed: logout,
              ),
              // Shopping Cart Icon with Badge
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart, color: Colors.white),
                    tooltip: 'View Cart', // Added tooltip
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CartPage(
                            initialCart: cart,
                            token: widget.token,
                            productItems: items,
                            onOrderPlaced: () {},
                            onCartUpdated: _onCartDataUpdated,
                            userName: _userName,
                            userPhone: _userPhone,
                            userAddress: _userAddress,
                          ),
                        ),
                      );
                    },
                  ),
                  if (cart.isNotEmpty)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: CircleAvatar(
                        radius: 9, // Slightly smaller badge
                        backgroundColor: const Color.fromARGB(255, 255, 99, 71), // Orange-red for attention
                        child: Text(
                          '${cart.values.fold(0, (sum, item) => sum + item)}',
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      // --- Body: Product List ---
      body: items.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 20),
                  Text(
                    'Loading amazing furniture...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12), // Consistent padding
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final String formattedPrice = '\$${(item['price'] as num).toStringAsFixed(2)}';

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), // More rounded corners
                  elevation: 5, // Slightly more elevation
                  shadowColor: finalCardShadowColor, // Soft shadow with explicit alpha
                  child: InkWell( // Use InkWell for ripple effect on tap
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailPage(
                          product: item,
                          onAddToCart: addToCart,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0), // Padding inside card
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product Image
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 5,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: FadeInImage.assetNetwork(
                                placeholder: 'assets/placeholder.png', // Ensure this asset exists
                                image: item['image'].startsWith('http')
                                    ? item['image']
                                    : 'http://127.0.0.1:8000${item['image']}',
                                fit: BoxFit.cover,
                                imageErrorBuilder: (context, error, stackTrace) =>
                                    const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          // Product Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.teal, // Highlight name
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Category: ${item['category']?['name'] ?? 'N/A'}', // Display category
                                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  formattedPrice,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrange, // Highlight price
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Add to Cart Button
                          Align(
                            alignment: Alignment.bottomRight,
                            child: IconButton(
                              icon: const Icon(
                                Icons.add_shopping_cart,
                                color: Colors.teal, // Icon color
                                size: 28, // Slightly larger icon
                              ),
                              tooltip: 'Add to Cart',
                              onPressed: () => addToCart(item['id']),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
