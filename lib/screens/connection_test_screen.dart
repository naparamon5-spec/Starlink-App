import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ConnectionTestScreen extends StatefulWidget {
  const ConnectionTestScreen({Key? key}) : super(key: key);

  @override
  _ConnectionTestScreenState createState() => _ConnectionTestScreenState();
}

class _ConnectionTestScreenState extends State<ConnectionTestScreen> {
  String _connectionStatus = 'Testing connection...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  Future<void> _testConnection() async {
    try {
      final result = await ApiService.testConnection();
      setState(() {
        _connectionStatus = result['message'] ?? 'Unknown status';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Database Connection Test')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Text(
                  _connectionStatus,
                  style: TextStyle(
                    color:
                        _connectionStatus.contains('successful')
                            ? Colors.green
                            : Colors.red,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _testConnection,
                child: const Text('Test Connection Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
