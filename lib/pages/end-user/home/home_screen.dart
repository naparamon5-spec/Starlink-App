import 'package:flutter/material.dart';
import '../ticket/ticket_screen.dart';
import '../profile/profile_screen.dart';
import '../../../components/BottomNavigatorBar.dart';

class HomeScreen extends StatefulWidget {
  final String? loginMessage;

  const HomeScreen({super.key, this.loginMessage});

  @override
  // ignore: library_private_types_in_public_api
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
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

  final List<Widget> _screens = [
    // Home content
    Scaffold(
      appBar: AppBar(title: Text('Home'), centerTitle: true),
      body: Center(child: Text('Home Page')),
    ),

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigatorBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
