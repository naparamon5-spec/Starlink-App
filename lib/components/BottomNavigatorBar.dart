import 'package:flutter/material.dart';

class BottomNavigatorBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>
  onTap; // Callback to notify parent widget of tab changes

  const BottomNavigatorBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap, // Notify parent widget when a tab is tapped
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Color(0XFFFF5969),
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
          icon: Icon(Icons.confirmation_num),
          label: 'Ticket',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}
