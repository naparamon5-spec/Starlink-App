import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/pages/customer/ticket/customer_ticket_screen.dart';
import '../../../services/api_service.dart';
import 'customer_edit_profile.dart';
import 'customer_security_settings.dart';
import 'customer_notification.dart';
import '../../login_screen.dart';
import '../ticket/customer_ticket.dart';

class CustomerProfileScreen extends StatefulWidget {
  final bool showAppBar;

  const CustomerProfileScreen({super.key, this.showAppBar = true});

  @override
  _CustomerProfileScreenState createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  bool _isLoading = true;
  String? _userName;
  String? _userEmail;
  String? _userPhone;
  String? _userAddress;
  String? _userId;
  String? _jobTitle;
  String? _companyName;
  String? _userType;

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

      if (response['success'] == true && response['data'] != null) {
        final userData = response['data'];

        setState(() {
          _userId = userData['id']?.toString() ?? 'N/A';
          _userName = userData['name'] ?? 'N/A';
          _userType = userData['role'] ?? 'customer';
          _isLoading = false;
        });

        // Save to SharedPreferences for offline access
        await prefs.setString('userId', _userId!);
        await prefs.setString('name', _userName!);
        await prefs.setString('userType', _userType!);
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch user data');
      }
    } catch (e) {
      print('Error loading profile data: $e');
      // Fallback to SharedPreferences if there's an error
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userId = prefs.getString('userId') ?? 'N/A';
        _userName = prefs.getString('name') ?? 'N/A';
        _userType = prefs.getString('userType') ?? 'customer';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateProfileData(Map<String, String> data) {
    setState(() {
      if (data['name'] != null) {
        _userName = data['name']!;
      }
    });
  }

  Future<void> _handleLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error logging out: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToSecuritySettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SecuritySettingsScreen()),
    );
  }

  void _navigateToTickets() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomerTicketHistory(showAppBar: true),
      ),
    );
  }

  String _getUserTypeDisplay() {
    return _userType?.toUpperCase() ?? 'CUSTOMER';
  }

  Widget _buildProfileInfo() {
    return Column(
      children: [
        // Contact Info
        _InfoItem(
          icon: Icons.person_outline,
          label: 'Name',
          value: _userName ?? 'Not set',
        ),

        const Divider(height: 24),

        _InfoItem(
          icon: Icons.badge_outlined,
          label: 'ID',
          value: _userId ?? 'Not set',
        ),

        const Divider(height: 24),

        _InfoItem(
          icon: Icons.work_outline,
          label: 'Role',
          value: _getUserTypeDisplay(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          widget.showAppBar
              ? AppBar(
                title: const Text('Profile'),
                centerTitle: true,
                elevation: 2,
                backgroundColor: const Color(0xFF133343),
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(15),
                  ),
                ),
              )
              : null,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Container(
                decoration: BoxDecoration(color: Colors.grey[50]),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Profile Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              // Profile Image
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context).primaryColor,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundImage: const AssetImage(
                                    'assets/images/profile_placeholder.png',
                                  ),
                                  backgroundColor: Colors.grey[200],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Profile Name
                              Text(
                                _userName ?? 'User',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),

                              const SizedBox(height: 4),

                              // User Role and ID
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_getUserTypeDisplay()}',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              _buildProfileInfo(),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action Buttons
                      Column(
                        children: [
                          _ActionButton(
                            icon: Icons.edit,
                            label: 'Edit Profile',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => EditProfileScreen(
                                        onProfileUpdated: _updateProfileData,
                                      ),
                                ),
                              );
                            },
                            backgroundColor: Colors.grey[300] ?? Colors.grey,
                            iconColor: Colors.black87,
                            textColor: Colors.black87,
                          ),

                          const SizedBox(height: 12),

                          _ActionButton(
                            icon: Icons.security,
                            label: 'Security Settings',
                            onPressed: _navigateToSecuritySettings,
                            backgroundColor: Colors.grey[300] ?? Colors.grey,
                            iconColor: Colors.black87,
                            textColor: Colors.black87,
                          ),

                          const SizedBox(height: 12),

                          _ActionButton(
                            icon: Icons.confirmation_number,
                            label: 'Tickets',
                            onPressed: _navigateToTickets,
                            backgroundColor: Colors.grey[300] ?? Colors.grey,
                            iconColor: Colors.black87,
                            textColor: Colors.black87,
                          ),

                          const SizedBox(height: 12),

                          _ActionButton(
                            icon: Icons.notifications_active,
                            label: 'Notification',
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
                            backgroundColor: Colors.grey[300] ?? Colors.grey,
                            iconColor: Colors.black87,
                            textColor: Colors.black87,
                          ),

                          const SizedBox(height: 12),

                          _ActionButton(
                            icon: Icons.logout,
                            label: 'Logout',
                            onPressed: _handleLogout,
                            backgroundColor: Colors.grey[300] ?? Colors.grey,
                            iconColor: Colors.black87,
                            textColor: Colors.black87,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}

// Component for profile information items
class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.grey[700], size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }
}

// Component for action buttons
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color iconColor;
  final Color textColor;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.iconColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
