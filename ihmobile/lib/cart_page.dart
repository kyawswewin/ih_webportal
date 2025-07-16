// lib/cart_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logging/logging.dart';

final _log = Logger('CartPage');

class CartPage extends StatefulWidget {
  final Map<int, int> initialCart;
  final String token;
  final List productItems;
  final Function() onOrderPlaced;
  final Function(Map<int, int>) onCartUpdated;
  final String? userName; // Added: Optional initial username
  final String? userPhone; // Added: Optional initial user phone
  final String? userAddress; // Added: Optional initial user address

  const CartPage({
    super.key,
    required this.initialCart,
    required this.token,
    required this.productItems,
    required this.onOrderPlaced,
    required this.onCartUpdated,
    this.userName, // Now userName is optional in constructor
    this.userPhone, // Now userPhone is optional in constructor
    this.userAddress, // Now userAddress is optional in constructor
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late Map<int, int> _cart;
  bool _isPlacingOrder = false;

  // Added: Controllers for customer details
  late TextEditingController _customerNameController;
  late TextEditingController _customerPhoneController;
  late TextEditingController _customerAddressController;

  final _formKey = GlobalKey<FormState>(); // Added: Form key for validation

  @override
  void initState() {
    super.initState();
    _cart = Map.from(widget.initialCart);

    // Initialize controllers with initial values from widget or empty string
    _customerNameController = TextEditingController(text: widget.userName ?? '');
    _customerPhoneController = TextEditingController(text: widget.userPhone ?? '');
    _customerAddressController = TextEditingController(text: widget.userAddress ?? '');
  }

  @override
  void dispose() {
    // Dispose controllers to free up resources
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _getProductById(int id) {
    try {
      return widget.productItems.firstWhere((item) => item['id'] == id);
    } catch (e) {
      _log.warning('Product with ID $id not found in fetched items: $e');
      return null;
    }
  }

  void _incrementQuantity(int id) {
    setState(() {
      _cart[id] = (_cart[id] ?? 0) + 1;
    });
    widget.onCartUpdated(_cart);
  }

  void _decrementQuantity(int id) {
    setState(() {
      if ((_cart[id] ?? 0) > 1) {
        _cart[id] = (_cart[id] ?? 0) - 1;
      } else {
        _cart.remove(id);
      }
    });
    widget.onCartUpdated(_cart);
  }

  void _removeItem(int id) {
    setState(() {
      _cart.remove(id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Item removed from cart!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red.shade600, // Red for removal
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
    widget.onCartUpdated(_cart);
  }

  double _calculateTotalPrice() {
    double total = 0.0;
    _cart.forEach((id, quantity) {
      final product = _getProductById(id);
      if (product != null && product['price'] != null) {
        final productPrice = double.tryParse(product['price'].toString()) ?? 0.0;
        total += (productPrice * quantity);
      }
    });
    return total;
  }

  Future<void> _placeOrder() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Your cart is empty. Add items before placing an order.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Validate the form fields
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please fill in all customer details.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isPlacingOrder = true;
    });

    final List<Map<String, dynamic>> itemsToSend =
        _cart.entries.map((e) => {'furniture_id': e.key, 'quantity': e.value}).toList();

    // Added: Customer details to the payload
    final Map<String, dynamic> orderPayload = {
      'items': itemsToSend,
      'customer_name': _customerNameController.text.trim(),
      'customer_phone': _customerPhoneController.text.trim(),
      'customer_address': _customerAddressController.text.trim(),
    };

    _log.info('Attempting to place order with payload: $orderPayload');

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/orders/create/'),
        headers: {
          'Authorization': 'Token ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(orderPayload), // Use the new payload
      );

      if (!mounted) return;

      setState(() {
        _isPlacingOrder = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Order placed successfully!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          _cart.clear(); // Clear local cart
          // Clear text fields after successful order
          _customerNameController.clear();
          _customerPhoneController.clear();
          _customerAddressController.clear();
        });
        widget.onOrderPlaced();
        widget.onCartUpdated(_cart);
        Navigator.pop(context);
        _log.info('Order placed successfully.');
      } else {
        final errorBody = jsonDecode(response.body);
        String errorMessage = 'Unknown error';
        if (errorBody is Map && errorBody.containsKey('error')) {
          errorMessage = errorBody['error'].toString();
        } else if (errorBody is Map && errorBody.containsKey('detail')) {
          errorMessage = errorBody['detail'].toString();
        } else if (errorBody is Map) {
          // Attempt to parse validation errors
          errorMessage = errorBody.values.join(', ');
        } else {
          errorMessage = 'Failed to place order (Status: ${response.statusCode}).';
        }

        _log.warning('Order failed: ${response.statusCode} - $errorMessage');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order failed: $errorMessage',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPlacingOrder = false;
        });
        _log.severe('Network error during order placement: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Network error. Please check your connection and try again.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPrice = _calculateTotalPrice();

    // Calculate shadow color for the product cards
    final Color baseBlackShadowColor = Colors.black;
    final int cardShadowAlpha = ((baseBlackShadowColor.a * 255.0).round() * 0.1).round();
    final Color finalCardShadowColor = Color.fromARGB(
      cardShadowAlpha,
      (baseBlackShadowColor.r * 255.0).round() & 0xff,
      (baseBlackShadowColor.g * 255.0).round() & 0xff,
      (baseBlackShadowColor.b * 255.0).round() & 0xff,
    );

    // Calculate shadow color for the Place Order button
    final Color baseTealShadowColor = Colors.teal.shade900;
    final int buttonShadowAlpha = ((baseTealShadowColor.a * 255.0).round() * 0.5).round();
    final Color finalButtonShadowColor = Color.fromARGB(
      buttonShadowAlpha,
      (baseTealShadowColor.r * 255.0).round() & 0xff,
      (baseTealShadowColor.g * 255.0).round() & 0xff,
      (baseTealShadowColor.b * 255.0).round() & 0xff,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Your Cart',
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
      body: _cart.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 100, color: Colors.grey.shade300), // Larger, lighter icon
                  const SizedBox(height: 25),
                  Text(
                    'Your cart is empty!',
                    style: TextStyle(fontSize: 24, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Looks like you haven\'t added anything yet.',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Go back to product list
                    },
                    icon: const Icon(Icons.storefront, color: Colors.white),
                    label: const Text(
                      'Start Shopping',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade600,
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 5,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final productId = _cart.keys.elementAt(index);
                      final quantity = _cart[productId]!;
                      final product = _getProductById(productId);

                      if (product == null) {
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          color: Colors.red.shade50, // Light red for error cards
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                const Icon(Icons.error, color: Colors.red, size: 40),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Product Not Found (ID: $productId)',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                                      ),
                                      Text(
                                        'Quantity: $quantity',
                                        style: const TextStyle(fontSize: 14, color: Colors.redAccent),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                                  tooltip: 'Remove Item',
                                  onPressed: () => _removeItem(productId),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final num productPriceNum = double.tryParse(product['price'].toString()) ?? 0.0;
                      final String formattedPrice = '\$${productPriceNum.toStringAsFixed(2)}';
                      final String formattedSubtotal = '\$${(productPriceNum * quantity).toStringAsFixed(2)}';
                      final String imageUrl = product['image'].startsWith('http')
                          ? product['image']
                          : 'http://127.0.0.1:8000${product['image']}';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 5, // Increased elevation
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), // More rounded corners
                        shadowColor: finalCardShadowColor, // Softer, subtle shadow
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Product Image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  imageUrl,
                                  width: 90, // Slightly larger image
                                  height: 90,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 90,
                                    height: 90,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
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
                                      product['name'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 17, color: Colors.teal),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'Unit Price: $formattedPrice',
                                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'Subtotal: $formattedSubtotal',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                                    ),
                                  ],
                                ),
                              ),
                              // Quantity Controls and Remove Button
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () => _decrementQuantity(productId),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.shade100,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.remove, size: 20, color: Colors.teal.shade700),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                        child: Text('$quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      ),
                                      InkWell(
                                        onTap: () => _incrementQuantity(productId),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.shade100,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.add, size: 20, color: Colors.teal.shade700),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 24),
                                    tooltip: 'Remove Item',
                                    onPressed: () => _removeItem(productId),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // --- Customer Details Input Fields ---
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customer Details',
                          style: Theme.of(context).textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _customerNameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            prefixIcon: Icon(Icons.person, color: Colors.teal.shade500),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter customer name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _customerPhoneController,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            prefixIcon: Icon(Icons.phone, color: Colors.teal.shade500),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _customerAddressController,
                          decoration: InputDecoration(
                            labelText: 'Delivery Address',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            prefixIcon: Icon(Icons.location_on, color: Colors.teal.shade500),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          maxLines: 3, // Allow multiple lines for address
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter delivery address';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // --- End Customer Details Input Fields ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -5),
                      ),
                    ],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          Text(
                            '\$${totalPrice.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isPlacingOrder ? null : _placeOrder,
                          icon: _isPlacingOrder
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
                          label: Text(
                            _isPlacingOrder ? 'Placing Order...' : 'Place Order',
                            style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 7,
                            foregroundColor: Colors.white,
                            shadowColor: finalButtonShadowColor, // Thematic shadow
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
