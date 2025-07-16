// lib/order_history_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logging/logging.dart'; // Assuming you have logger setup
import 'package:intl/intl.dart'; // Import for date formatting

final Logger _log = Logger('OrderHistoryPage');

// Custom Painter for a dashed line, to mimic a voucher tear-off
class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    const double dashWidth = 5.0;
    const double dashSpace = 5.0;
    double currentX = 0;
    while (currentX < size.width) {
      canvas.drawLine(Offset(currentX, 0), Offset(currentX + dashWidth, 0), paint);
      currentX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class OrderHistoryPage extends StatefulWidget {
  final String token;

  const OrderHistoryPage({super.key, required this.token});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> with SingleTickerProviderStateMixin {
  List orders = [];
  bool isLoading = true;
  String errorMessage = '';

  // Animation controller for list items
  late AnimationController _listAnimationController;

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Longer duration for more noticeable animation
    );

    _fetchOrderHistory();
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrderHistory() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/orders/history/'), // Adjust URL for emulator/device if needed
        headers: {
          'Authorization': 'Token ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return; // Check mounted state after async operation

      if (response.statusCode == 200) {
        setState(() {
          orders = (jsonDecode(response.body) as List).map((order) {
            // Process order items to ensure price_at_purchase is a number
            if (order['items'] is List) {
              order['items'] = (order['items'] as List).map((item) {
                if (item['price_at_purchase'] is String) {
                  // Convert string price to double
                  item['price_at_purchase'] = double.tryParse(item['price_at_purchase']) ?? 0.0;
                }
                return item;
              }).toList();
            }
            // Ensure total_amount is also a number (if it could come as string)
            if (order['total_amount'] is String) {
              order['total_amount'] = double.tryParse(order['total_amount']) ?? 0.0;
            }
            return order;
          }).toList();
          isLoading = false;
        });
        _log.info('Order history fetched successfully. Total orders: ${orders.length}');
        // Start animation after data is loaded
        _listAnimationController.forward(from: 0.0);
      } else if (response.statusCode == 401) {
        setState(() {
          errorMessage = 'Authentication failed. Please log in again.';
          isLoading = false;
        });
        _log.warning('Order history failed: 401 - Unauthorized');
        // Optionally, navigate back to login page if token is invalid
        // Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      } else {
        final errorBody = jsonDecode(response.body);
        setState(() {
          errorMessage = errorBody['detail'] ?? 'Failed to load order history.';
          isLoading = false;
        });
        _log.warning('Order history failed: ${response.statusCode} - ${errorBody['detail'] ?? 'Unknown error'}');
      }
    } catch (e) {
      if (!mounted) return; // Check mounted state after async operation
      setState(() {
        errorMessage = 'Network error: $e';
        isLoading = false;
      });
      _log.severe('Network error fetching order history: $e');
    }
  }

  // Helper to format date and time
  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'N/A';
    try {
      final DateTime dateTime = DateTime.parse(dateTimeString);
      return DateFormat('MMM d,yyyy HH:mm').format(dateTime);
    } catch (e) {
      _log.warning('Failed to parse date string: $dateTimeString - $e');
      return 'Invalid Date';
    }
  }

  // Helper to get status icon and color
  Widget _buildStatusChip(String status) {
    IconData icon;
    Color color;
    Color textColor = Colors.white;

    switch (status.toLowerCase()) {
      case 'pending':
        icon = Icons.pending_actions;
        color = Colors.orange.shade600;
        break;
      case 'processing':
        icon = Icons.sync;
        color = Colors.blue.shade600;
        break;
      case 'shipped':
        icon = Icons.local_shipping;
        color = Colors.lightBlue.shade600;
        break;
      case 'delivered':
        icon = Icons.check_circle;
        color = Colors.green.shade600;
        break;
      case 'cancelled':
        icon = Icons.cancel;
        color = Colors.red.shade600;
        break;
      default:
        icon = Icons.info_outline;
        color = Colors.grey.shade600;
        break;
    }

    return Chip(
      avatar: Icon(icon, color: textColor, size: 18),
      label: Text(
        status,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Order History',
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
                    'Loading your order history...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 60),
                        const SizedBox(height: 15),
                        Text(
                          errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 25),
                        ElevatedButton.icon(
                          onPressed: _fetchOrderHistory,
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
              : orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 100, color: Colors.grey.shade300),
                          const SizedBox(height: 25),
                          Text(
                            'No orders found!',
                            style: TextStyle(fontSize: 24, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            'It looks like you haven\'t placed any orders yet.',
                            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context); // Go back to product list/home
                            },
                            icon: const Icon(Icons.storefront, color: Colors.white),
                            label: const Text(
                              'Explore Products',
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
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        // final String orderId = order['id']?.toString() ?? 'N/A';
                        final String orderno = order['order_number']?.toString() ?? 'N/A';

                        final String orderDate = _formatDateTime(order['created_at']);
                        final String totalAmount = '\$${(order['total_amount'] as num).toStringAsFixed(2)}';
                        final String orderStatus = order['status'] ?? 'Unknown';
                        final String paymentStatus = order['payment_status'] ?? 'N/A';
                        final String paymentMethod = order['payment_method'] ?? 'N/A';

                        // Calculate total quantity for the order
                        double orderTotalQuantity = 0.0;
                        if (order['items'] != null && order['items'].isNotEmpty) {
                          for (var item in order['items']) {
                            orderTotalQuantity += (item['quantity'] as num).toDouble();
                          }
                        }

                        // Calculate staggered animation delay
                        final double delay = index * 0.1; // 100ms delay per item

                        return FadeTransition(
                          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                            CurvedAnimation(
                              parent: _listAnimationController,
                              curve: Interval(delay, 1.0, curve: Curves.easeIn),
                            ),
                          ),
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
                              CurvedAnimation(
                                parent: _listAnimationController,
                                curve: Interval(delay, 1.0, curve: Curves.easeOutCubic),
                              ),
                            ),
                            child: Card(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 8, // More pronounced elevation
                              shadowColor: Colors.teal.shade100, // Subtle shadow matching theme
                              child: ExpansionTile( // Re-introducing ExpansionTile here
                                tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.teal.shade500,
                                  radius: 25,
                                  child: Text(
                                    orderTotalQuantity.toInt().toString(), // Display total quantity
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                                  ),
                                ),
                                title: Text(
                                  'Order #$orderno',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.teal.shade800,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                        const SizedBox(width: 5),
                                        Text('Date: $orderDate', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.attach_money, size: 16, color: Colors.green),
                                        const SizedBox(width: 5),
                                        Text('Total: $totalAmount', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    _buildStatusChip(orderStatus), // Styled status chip
                                  ],
                                ),
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Customer Details
                                        const SizedBox(height: 15),
                                        Text(
                                          'Customer Details',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.teal.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text('Name: ${order['customer_name'] ?? 'N/A'}', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                        Text('Phone: ${order['customer_phone'] ?? 'N/A'}', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                        Text('Address: ${order['customer_address'] ?? 'N/A'}', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                        const SizedBox(height: 15),

                                        // Dashed Line
                                        CustomPaint(
                                          size: Size(MediaQuery.of(context).size.width - 64, 1),
                                          painter: DashedLinePainter(),
                                        ),
                                        const SizedBox(height: 15),

                                        // Order Items
                                        Text(
                                          'Order Items',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.teal.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Table for order items
                                        Table(
                                          columnWidths: const {
                                            0: FlexColumnWidth(3), // Item Name
                                            1: FlexColumnWidth(1), // Quantity
                                            2: FlexColumnWidth(1.5), // Price
                                          },
                                          border: TableBorder.all(color: Colors.grey.shade200, width: 0.5),
                                          children: [
                                            // Table Header
                                            TableRow(
                                              decoration: BoxDecoration(color: Colors.teal.shade50),
                                              children: const [
                                                Padding(
                                                  padding: EdgeInsets.all(8.0),
                                                  child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal)),
                                                ),
                                                Padding(
                                                  padding: EdgeInsets.all(8.0),
                                                  child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal)),
                                                ),
                                                Padding(
                                                  padding: EdgeInsets.all(8.0),
                                                  child: Text('Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal)),
                                                ),
                                              ],
                                            ),
                                            // Table Rows (Order Items)
                                            if (order['items'] != null && order['items'].isNotEmpty)
                                              ...order['items'].map<TableRow>((item) {
                                                final price = (item['price_at_purchase'] is num) ? item['price_at_purchase'] : double.tryParse(item['price_at_purchase'].toString()) ?? 0.0;
                                                return TableRow(
                                                  children: [
                                                    Padding(
                                                      padding: const EdgeInsets.all(8.0),
                                                      child: Text(item['furniture_name'], style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.all(8.0),
                                                      child: Text(item['quantity'].toString(), style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.all(8.0),
                                                      child: Text('\$${price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                                    ),
                                                  ],
                                                );
                                              }).toList()
                                            else
                                              TableRow(
                                                children: [
                                                  TableCell(
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(8.0),
                                                      child: Text('No items found for this order.', style: TextStyle(color: Colors.grey)),
                                                    ),
                                                  ),
                                                  TableCell(child: Container()), // Empty cell for alignment
                                                  TableCell(child: Container()), // Empty cell for alignment
                                                ],
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 10), // Add some space

                                        // Total Quantity of Items
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Total Items Quantity:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.teal.shade700,
                                              ),
                                            ),
                                            Text(
                                              orderTotalQuantity.toInt().toString(), // Display as integer
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: Colors.teal.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 15), // Space before dashed line

                                        // Dashed Line
                                        CustomPaint(
                                          size: Size(MediaQuery.of(context).size.width - 64, 1),
                                          painter: DashedLinePainter(),
                                        ),
                                        const SizedBox(height: 15),

                                        // Total Amount
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'TOTAL AMOUNT:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: Colors.teal.shade900,
                                              ),
                                            ),
                                            Text(
                                              totalAmount,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 22,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Payment Method: $paymentMethod',
                                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                                        ),
                                        Text(
                                          'Payment Status: $paymentStatus',
                                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                                        ),
                                      ],
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
