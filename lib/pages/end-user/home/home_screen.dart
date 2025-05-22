import 'package:flutter/material.dart';
import '../ticket/ticket_screen.dart';
import '../profile/profile_screen.dart';
import '../../../components/BottomNavigatorBar.dart';
import '../../../services/api_service.dart';
import 'subscription_header.dart';
import 'billing_cycle_chart.dart';

class HomeScreen extends StatefulWidget {
  final String? loginMessage;

  const HomeScreen({super.key, this.loginMessage});

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
      final response = await ApiService.getSubscriptions();
      if (response['status'] == 'success' && response['data'].isNotEmpty) {
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
        _subscriptionData!['id'].toString(),
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

  Widget _buildHomeContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_subscriptionData == null) {
      return const Center(
        child: Text(
          'No subscription data available',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SubscriptionHeader(
            serviceLineNumber: _subscriptionData!['serviceLineNumber'] ?? 'N/A',
            nickname: _subscriptionData!['nickname'] ?? 'N/A',
            address: _subscriptionData!['address'] ?? 'N/A',
            active:
                _subscriptionData!['active'] == '1' ||
                _subscriptionData!['active'] == 'true',
          ),
          const SizedBox(height: 24),
          BillingCycleChart(billingCycles: _billingCycles),
          const SizedBox(height: 24),
          // Add more home screen content here
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Update the home screen content
    _screens[0] = Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        centerTitle: true,
        elevation: 2,
        backgroundColor: const Color(0xFF133343),
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
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
