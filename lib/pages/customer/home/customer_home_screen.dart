import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../components/Table.dart';
import '../../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ticket/customer_ticket_screen.dart';
import '../ticket/customer_ticket.dart';
import '../profile/customer_profile.dart';
import '../profile/customer_notification.dart';
import '../ticket/customer_ticket_modal.dart';
import 'customer_details.dart';

class CustomerHomeScreen extends StatefulWidget {
  final String loginMessage;

  const CustomerHomeScreen({super.key, required this.loginMessage});

  @override
  _CustomerHomeScreenState createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _selectedIndex = 0;
  String? _userName;
  String? _userFirstName;
  String? _userEmail;
  String? _userRole;
  bool _isLoading = true;
  int? _userId;
  List<Map<String, dynamic>> _subscriptions = [];
  List<Map<String, dynamic>> _billingCycles = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      if (userId == null) {
        throw Exception('User ID not found');
      }

      // Get data from API
      final response = await ApiService.getCurrentUser(userId);

      if (response['status'] == 'success' && response['data'] != null) {
        final userData = response['data'];

        setState(() {
          _userId = userId; // Keep the original int userId
          _userName = userData['name'];
          _userFirstName = userData['first_name'];
          _userEmail = userData['email'];
          _userRole = userData['role'];
          _isLoading = false;
        });

        // Save to SharedPreferences for offline access
        await prefs.setInt('user_id', userId); // Save as int
        await prefs.setString('name', _userName ?? '');
        await prefs.setString('first_name', _userFirstName ?? '');
        await prefs.setString('email', _userEmail ?? '');
        await prefs.setString('role', _userRole ?? '');

        // Load subscriptions after user data is loaded
        await _loadSubscriptions();
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch user data');
      }
    } catch (e) {
      print('Error loading user data: $e');
      // Fallback to SharedPreferences if there's an error
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userId = prefs.getInt('user_id'); // Get as int
        _userName = prefs.getString('name');
        _userFirstName = prefs.getString('first_name');
        _userEmail = prefs.getString('email');
        _userRole = prefs.getString('role');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSubscriptions() async {
    try {
      print('Loading subscriptions...');
      final response = await ApiService.getSubscriptionsByCustomerCode(
        _userId.toString(),
      );

      if (response['status'] == 'success' && response['data'] != null) {
        final subscriptions = List<Map<String, dynamic>>.from(response['data']);
        print('Received ${subscriptions.length} subscriptions');

        setState(() {
          _subscriptions = subscriptions;
        });

        // Load billing cycles for each subscription
        for (var subscription in _subscriptions) {
          if (subscription['id'] != null) {
            await _loadBillingCycles(subscription['id'].toString());
          } else {
            print(
              'Warning: Subscription missing ID: ${subscription.toString()}',
            );
          }
        }
      } else {
        print('Error response from getSubscriptions: ${response.toString()}');
        throw Exception(response['message'] ?? 'Failed to fetch subscriptions');
      }
    } catch (e) {
      print('Error loading subscriptions: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading subscriptions: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadBillingCycles(String subscriptionId) async {
    try {
      print('Loading billing cycles for subscription ID: $subscriptionId');
      final response = await ApiService.getBillingCycles(subscriptionId);

      if (response['status'] == 'success' && response['data'] != null) {
        final cycles = List<Map<String, dynamic>>.from(response['data']);
        print('Received ${cycles.length} billing cycles');

        setState(() {
          _billingCycles.addAll(cycles);
        });
      } else {
        print('Error response from getBillingCycles: ${response.toString()}');
        throw Exception(
          response['message'] ?? 'Failed to fetch billing cycles',
        );
      }
    } catch (e) {
      print(
        'Error loading billing cycles for subscription $subscriptionId: $e',
      );
      // Don't throw the error, just log it and continue
      // This prevents the entire subscription loading from failing
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showNewTicketModal() {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User ID not found. Please try again later.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => CustomerTicketModal(
            userId: _userId!,
            onConfirm: (ticket) async {
              // Check if forceRefresh is true
              if (ticket['forceRefresh'] == true) {
                // Set selected index to tickets screen to refresh the view
                setState(() {
                  _selectedIndex = 1;
                });
              }
            },
            onCancel: () => Navigator.of(context).pop(),
          ),
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Customer Dashboard';
      case 1:
        return 'My Tickets';
      case 2:
        return 'Profile';
      default:
        return 'Customer Dashboard';
    }
  }

  Widget _buildBody() {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        _buildDashboard(),
        const CustomerTicketScreen(showAppBar: false),
        const CustomerProfileScreen(showAppBar: false),
      ],
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF133343), Color(0xFF1E4B5F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF133343).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userFirstName ?? 'User',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Text(
                                '2',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You have 2 new notifications',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      const CustomerNotificationScreen(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF133343),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  // Handle view all actions
                },
                icon: const Icon(Icons.more_horiz, color: Color(0xFF133343)),
                label: const Text(
                  'View All',
                  style: TextStyle(color: Color(0xFF133343)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.add_circle_outline,
                  title: 'New Ticket',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF133343), Color(0xFF1E4B5F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () {
                    setState(() => _selectedIndex = 1);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.history,
                  title: 'Ticket History',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                const CustomerTicketHistory(showAppBar: true),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Subscriptions Table
          const Text(
            'My Subscriptions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF133343),
            ),
          ),
          const SizedBox(height: 16),
          _subscriptions.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.subscriptions_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No subscriptions found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your subscriptions will appear here',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
              : SizedBox(
                height: 360,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _subscriptions.length,
                  itemBuilder: (context, index) {
                    final subscription = _subscriptions[index];
                    final isActive = subscription['active'] == true;

                    return Container(
                      width: 340,
                      margin: EdgeInsets.only(
                        left: index == 0 ? 0 : 12,
                        right: index == _subscriptions.length - 1 ? 12 : 0,
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => CustomerDetailsScreen(
                                    subscription: subscription,
                                  ),
                            ),
                          );
                        },
                        child: Stack(
                          children: [
                            // Background Card
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                            ),
                            // Content
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Status Bar
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isActive
                                              ? const Color(0xFFE8F5E9)
                                              : const Color(0xFFFFEBEE),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isActive
                                              ? Icons.check_circle
                                              : Icons.cancel,
                                          size: 16,
                                          color:
                                              isActive
                                                  ? const Color(0xFF2E7D32)
                                                  : const Color(0xFFC62828),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          isActive ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                isActive
                                                    ? const Color(0xFF2E7D32)
                                                    : const Color(0xFFC62828),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  // Subscription Name
                                  Text(
                                    subscription['nickname'] ?? 'N/A',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF133343),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Service Line
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF133343,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.router_outlined,
                                          color: Color(0xFF133343),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Service Line',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              subscription['serviceLineNumber'] ??
                                                  'N/A',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF133343),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Address
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF133343,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.location_on_outlined,
                                          color: Color(0xFF133343),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Address',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              subscription['address'] ?? 'N/A',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF133343),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Gradient gradient,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        centerTitle: true,
        elevation: 2,
        backgroundColor: const Color(0xFF133343),
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.confirmation_number),
            label: 'Tickets',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF133343),
        onTap: _onItemTapped,
      ),
    );
  }
}
