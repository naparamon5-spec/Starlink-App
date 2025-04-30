import 'package:flutter/material.dart';
import '../ticket/ticket_screen.dart';
import '../profile/profile_screen.dart';
import '../../components/BottomNavigatorBar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

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
