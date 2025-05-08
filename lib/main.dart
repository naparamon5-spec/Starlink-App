import 'package:flutter/material.dart';
import 'pages/login_screen.dart'; // Import the LoginScreen

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Starlink App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: LoginScreen(), // Set LoginScreen as the initial screen
    );
  }
}
