// lib/productdetail.dart
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final _log = Logger('ProductDetailPage');

class ProductDetailPage extends StatelessWidget {
  final Map product;
  final Function(int productId) onAddToCart;

  const ProductDetailPage({
    super.key,
    required this.product,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    _log.info('Product Detail Page - Image URL: ${product['image']}');

    final double price = double.tryParse(product['price'].toString()) ?? 0.0;
    final String imageUrl = product['image'].startsWith('http')
        ? product['image']
        : 'http://127.0.0.1:8000${product['image']}';

    // Determine the shadow color with explicit alpha to address deprecation warning
    final Color baseShadowColor = Colors.teal.shade900;
    final int shadowAlpha = ((baseShadowColor.a * 255.0).round() * 0.5).round(); // Use .a for opacity
    final Color finalShadowColor = Color.fromARGB(
      shadowAlpha,
      (baseShadowColor.r * 255.0).round() & 0xff, // Use .r for red component
      (baseShadowColor.g * 255.0).round() & 0xff, // Use .g for green component
      (baseShadowColor.b * 255.0).round() & 0xff, // Use .b for blue component
    );

    return Scaffold(
      // --- Enhanced AppBar ---
      appBar: AppBar(
        title: Text(
          product['name'],
          style: const TextStyle(
            color: Colors.white, // White title for better contrast on gradient
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true, // Center the title
        iconTheme: const IconThemeData(color: Colors.white), // White back arrow
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
        elevation: 0, // Remove default AppBar shadow as Container has it
      ),
      // --- Body Content ---
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20), // Increased padding for more space
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Product Image (Hero) ---
            Center(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20), // More rounded corners for the image container
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 15, // Increased blur for a softer shadow
                      offset: const Offset(0, 8), // More pronounced shadow
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 16 / 9, // Standard wide aspect ratio
                    child: FadeInImage.assetNetwork(
                      placeholder: 'assets/placeholder.png', // Ensure this asset exists
                      image: imageUrl,
                      fit: BoxFit.cover,
                      imageErrorBuilder: (context, error, stackTrace) {
                        _log.severe('Error loading image for ${product['name']}: $error');
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, size: 80, color: Colors.grey),
                              SizedBox(height: 10),
                              Text('Image Failed to Load', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30), // More vertical space

            // --- Product Name ---
            Text(
              product['name'],
              style: const TextStyle(
                fontSize: 28, // Larger font size for name
                fontWeight: FontWeight.bold,
                color: Colors.teal, // Highlight with a thematic color
                fontFamily: 'RobotoSlab', // Try a different font for headings
              ),
            ),
            const SizedBox(height: 15),

            // --- Product Code (Styled Tag) ---
            if (product['item_code'] != null && product['item_code'].isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50, // Light background for the tag
                  borderRadius: BorderRadius.circular(25.0), // Fully rounded pill shape
                  border: Border.all(color: Colors.teal.shade100, width: 1.0),
                ),
                child: Text(
                  'P.Code: ${product['item_code']}',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            const SizedBox(height: 15),

            // --- Product Price ---
            Text(
              'Price: \$${price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 24, // Larger font size for price
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange, // Prominent color for price
              ),
            ),
            const SizedBox(height: 25),

            // --- Description Header ---
            const Text(
              'Description:',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontFamily: 'RobotoSlab',
              ),
            ),
            const Divider(height: 10, thickness: 1, color: Colors.grey), // Divider for visual separation
            const SizedBox(height: 10),

            // --- Product Description ---
            Text(
              product['description'] ?? 'No detailed description available for this product.',
              style: TextStyle(
                fontSize: 16,
                height: 1.5, // Line height for readability
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.justify, // Justify text for a clean block
            ),
            const SizedBox(height: 30), // Space before bottom bar
          ],
        ),
      ),
      // --- Bottom Navigation Bar (Add to Cart) ---
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 15, 20, 20), // Adjusted padding
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10, // Softer, wider shadow
              offset: const Offset(0, -5),
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25), // More rounded top corners
            topRight: Radius.circular(25),
          ),
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: () {
              onAddToCart(product['id']);
              // Show a refined SnackBar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '${product['name']} added!',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green.shade600, // A vibrant green for success
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  margin: EdgeInsets.all(10),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.shopping_cart, color: Colors.white, size: 28), // Larger icon
            label: const Text(
              'Add to Cart',
              style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600), // Larger, bolder text
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700, // Matching your app's primary theme color
              padding: const EdgeInsets.symmetric(vertical: 18), // Taller button
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15), // Rounded button
              ),
              elevation: 7, // More button elevation
              shadowColor: finalShadowColor, // Thematic shadow color with explicit alpha
            ),
          ),
        ),
      ),
    );
  }
}
