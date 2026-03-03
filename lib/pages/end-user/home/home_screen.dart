import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ticket/ticket_screen.dart';
import '../profile/profile_screen.dart';
import '../../../components/BottomNavigatorBar.dart';
import '../../../services/api_service.dart';
import 'subscription_header.dart';
import 'billing_cycle_chart.dart';

class HomeScreen extends StatefulWidget {
  final String? loginMessage;
  final int userId;

  const HomeScreen({super.key, this.loginMessage, required this.userId});

  @override
  // ignore: library_private_types_in_public_api
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  Map<String, dynamic>? _subscriptionData;
  List<Map<String, dynamic>> _billingCycles = [];
  String? _errorMessage;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
    // Show login message after the screen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.loginMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.loginMessage!),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  Future<void> _loadSubscriptionData() async {
    try {
      print('[DEBUG] HomeScreen: Starting to load subscription data');
      // Get current user profile using /api/v1/auth/me
      print('[DEBUG] HomeScreen: Loading user profile from /api/v1/auth/me');
      final userData = await ApiService.getCurrentUserProfile();

      if (userData['status'] != 'success' || userData['data'] == null) {
        throw Exception(
          userData['message'] ?? 'Failed to get user data. Please login again.',
        );
      }

      final user = userData['data'];
      print('[DEBUG] HomeScreen: Profile loaded from /me - User ID: ${user['id']}, Email: ${user['email']}');
      
      // Get detailed user profile using /api/v1/users/:id
      final userId = user['id']?.toString() ?? widget.userId.toString();
      print('[DEBUG] HomeScreen: Loading detailed profile from /api/v1/users/$userId');
      final detailedProfileResponse = await ApiService.getUserById(userId);
      
      if (detailedProfileResponse['status'] == 'success' && detailedProfileResponse['data'] != null) {
        setState(() {
          _userProfile = detailedProfileResponse['data'];
        });
        print('[DEBUG] HomeScreen: Detailed profile loaded - Full data: $_userProfile');
        
        // Store detailed user data in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userProfile', json.encode(_userProfile));
        print('[DEBUG] HomeScreen: User profile stored in SharedPreferences');
      } else {
        print('[DEBUG] HomeScreen: Failed to load detailed profile: ${detailedProfileResponse['message']}');
        // Try to load from SharedPreferences if available
        try {
          final prefs = await SharedPreferences.getInstance();
          final storedProfile = prefs.getString('userProfile');
          if (storedProfile != null) {
            setState(() {
              _userProfile = json.decode(storedProfile);
            });
            print('[DEBUG] HomeScreen: Loaded profile from SharedPreferences');
          }
        } catch (e) {
          print('[DEBUG] HomeScreen: Failed to load from SharedPreferences: $e');
        }
      }

      // Try different possible EU code / customer code field names
      String? euCode;
      if (user['eu_code'] != null) {
        euCode = user['eu_code'].toString();
      } else if (user['com_eu_code'] != null) {
        euCode = user['com_eu_code'].toString();
      } else if (user['customer_code'] != null) {
        euCode = user['customer_code'].toString();
      } else if (user['company'] != null && user['company'] is String) {
        // For /me, company is a code string like "A-4A100426"
        euCode = user['company'].toString();
      } else if (user['company'] != null && user['company'] is Map) {
        // Check if company has eu_code
        final company = user['company'] as Map<String, dynamic>;
        if (company['eu_code'] != null) {
          euCode = company['eu_code'].toString();
        } else if (company['customer_code'] != null) {
          euCode = company['customer_code'].toString();
        }
      }

      if (euCode == null || euCode.isEmpty) {
        // If no EU code found in user data, try to get it from end_users table
        try {
          final userId = user['id'] ?? widget.userId;
          final endUserData = await ApiService.getEndUserByUserId(
            userId is int ? userId : int.tryParse(userId.toString()) ?? widget.userId,
          );

          if (endUserData['status'] == 'success' &&
              endUserData['data'] != null) {
            euCode =
                endUserData['data']['eu_code']?.toString() ??
                endUserData['data']['customer_code']?.toString();
          }
        } catch (e) {
          throw Exception(
            'Could not find EU code for user. Please contact support.',
          );
        }
      }

      if (euCode == null || euCode.isEmpty) {
        throw Exception(
          'Could not find EU code for user. Please contact support.',
        );
      }

      // Now fetch subscriptions using the EU code
      final response = await ApiService.getSubscriptionsByEuCode(euCode);

      if (response['status'] == 'success' && response['data'] != null) {
        setState(() {
          _subscriptionData = response['data'][0]; // Get first subscription
          _isLoading = false;
        });
        // Load billing cycles after getting subscription data
        await _loadBillingCycles();
      } else {
        setState(() {
          _errorMessage = 'No subscription data available';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading subscription data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBillingCycles() async {
    if (_subscriptionData == null) return;

    try {
      final response = await ApiService.getBillingCycles(
        _subscriptionData!['serviceLineNumber'].toString(),
      );
      if (response['status'] == 'success') {
        setState(() {
          _billingCycles = List<Map<String, dynamic>>.from(response['data']);
        });
      }
    } catch (e) {
      print('Error loading billing cycles: $e');
    }
  }

  final List<Widget> _screens = [
    // Home content will be built dynamically
    Container(),

    // Ticket screen - no appBar here, it will be in TicketScreen
    TicketScreen(),

    // Profile screen - no appBar here, it will be in ProfileScreen
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'N/A' : value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF133343)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFE57373), size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Color(0xFFE57373),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadSubscriptionData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF133343),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_subscriptionData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.subscriptions_outlined,
              color: Colors.grey,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'No subscription data available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.grey[50]!],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Card
            if (_userProfile != null)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'User Profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF133343),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildProfileRow('ID', _userProfile!['id']?.toString() ?? 'N/A'),
                      _buildProfileRow('Email', _userProfile!['email']?.toString() ?? 'N/A'),
                      _buildProfileRow('Name', _userProfile!['name']?.toString() ?? 
                          '${_userProfile!['first_name'] ?? ''} ${_userProfile!['last_name'] ?? ''}'.trim()),
                      if (_userProfile!['first_name'] != null)
                        _buildProfileRow('First Name', _userProfile!['first_name']?.toString() ?? 'N/A'),
                      if (_userProfile!['last_name'] != null)
                        _buildProfileRow('Last Name', _userProfile!['last_name']?.toString() ?? 'N/A'),
                      if (_userProfile!['middle_name'] != null)
                        _buildProfileRow('Middle Name', _userProfile!['middle_name']?.toString() ?? 'N/A'),
                      _buildProfileRow('Role', _userProfile!['role']?.toString() ?? 'N/A'),
                      if (_userProfile!['company'] != null)
                        _buildProfileRow('Company', _userProfile!['company'] is Map
                            ? (_userProfile!['company'] as Map)['name']?.toString() ?? 'N/A'
                            : _userProfile!['company']?.toString() ?? 'N/A'),
                    ],
                  ),
                ),
              ),
            if (_userProfile != null) const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SubscriptionHeader(
                  serviceLineNumber:
                      _subscriptionData!['serviceLineNumber'] ?? 'N/A',
                  nickname: _subscriptionData!['nickname'] ?? 'N/A',
                  address: _subscriptionData!['address'] ?? 'N/A',
                  active:
                      _subscriptionData!['active'] == '1' ||
                      _subscriptionData!['active'] == 'true',
                  currentBillingCycle:
                      _billingCycles.isNotEmpty ? _billingCycles[0] : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Billing History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF133343),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: BillingCycleChart(billingCycles: _billingCycles),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Update the home screen content
    _screens[0] = Scaffold(
      appBar: AppBar(
        title: const Text(
          'Home',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF133343),
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: _buildHomeContent(),
    );

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigatorBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
